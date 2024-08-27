param([switch]$force)

#load config
. $PSScriptRoot\config.ps1

#load functions
. $PSScriptRoot\functions.ps1

if((Test-Path $PSScriptRoot\maintain) -and !($force)){
    write-RZlogAndOutput -text "-- Maintain" -color "red"
    Exit
}

if(Test-Path $PSScriptRoot\run_serverSet){
    write-RZlogAndOutput -text "-- Always running" -color "red"
    Exit
}

#log
write-RZlogAndOutput -text "-- Script Start - set-server" -color "green"

#load time config
$dateRanges = Import-Excel -Path "$PSScriptRoot\times.xlsx" -WorksheetName "dateRanges"
$times = Import-Excel -Path "$PSScriptRoot\times.xlsx" -WorksheetName "times"

#load server types
$serverTypes = Import-Csv -Delimiter ";" -Path "$PSScriptRoot\serverTypes.csv"

#dates..
$now = [string](Get-Date -UFormat "%H%M")
$today = Get-Date #-Month 1 #-day 16
$year = [string](Get-Date -UFormat "%Y")

Add-Content -Value $now -Path $PSScriptRoot\run_serverSet

#search date range..
$dateRanges | % {
    $fromTmp = ($_.dateFrom).trimend(".").split(".")
    $fromDay = $fromTmp[0]
    $fromMonth = $fromTmp[1]
    $from = Get-Date -Day $fromDay -Month $fromMonth -Year $year -Hour 0 -Minute 0 -Second 0

    $tillTmp = ($_.datetill).trimend(".").split(".")
    $tillDay = $tillTmp[0]
    $tillMonth = $tillTmp[1]
    $till = Get-Date -Day $tillDay -Month $tillMonth -Year $year -Hour 23 -Minute 59 -Second 59

    if(($from -lt $today) -and ($till -gt $today)){
        $dateRangeId = $_.id
    }
}

$times = $times | ? dateRange -eq $dateRangeId

#set new Server scale
$serverTypeLevel = ($times | ? startTime -lt $now | sort startTime | Select-Object -last 1).level

$serverType = ($serverTypes | ? level -eq $serverTypeLevel).server_type

#load servers
$servers = Import-Csv -Delimiter ";" -Path "$PSScriptRoot\servers.csv" | Sort-Object {Get-Random}   

#check all online states
$break = $false

foreach ($server in $servers){
    if(!(Test-NetConnection -ComputerName $server.ip -port $portToCheck -wa si).TcpTestSucceeded){
        $break = $true
    }
}

#load all Servers from API
$hetznerServerData = (Invoke-RestMethod -Uri "$apiMainEndPoint/servers" -Headers $authHeader -Method Get).servers

#load offline Servers
$offlineServers = $hetznerServerData | ? status -ne "running"

#try to start
$offlineServers | %{
    write-RZlogAndOutput -text "Offline Server: $($_.name)" -color "red"

    #start server
    Invoke-RestMethod -Uri "$apiMainEndPoint/servers/$($_.id)/actions/poweron" -Headers $authHeader -Method Post | Out-Null

    #set break
    $break = $true
}

if($break){
    write-RZlogAndOutput -text "++ System not Ready!" -color "red"

    endScript -file "run_serverSet"
    #do nothing
    exit
}

foreach ($server in $servers){
    $serverTypeRequest = [PSCustomObject]@{
        upgrade_disk = $false
        server_type = $serverType
    } | ConvertTo-Json -Compress

    $serverData = $hetznerServerData | ? name -eq $server.name

    write-RZlogAndOutput -text "Actual state: '$($server.name)' -> $($serverData.server_type.name)" -color "Yellow"

    if($serverData.server_type.name -eq $serverType){
        write-RZlogAndOutput -text "no Changes needed"
        continue
    } else {
        write-RZlogAndOutput -text "Change to state: $serverType" -color "Green"
        write-RZlogAndOutput -text "Monitoring Pause.."

        invoke-RestMethod -Uri "https://monitoring.sn-plus.de/api/pauseobjectfor.htm?id=$($server.monitoringId)&pausemsg=serverChange&duration=$monitoringPauseDuration&apitoken=$monitoringApiKey"
    }

    #stop server
    write-RZlogAndOutput -text "stopping server"
    Invoke-RestMethod -Uri "$apiMainEndPoint/servers/$($serverData.id)/actions/poweroff" -Headers $authHeader -Method Post -TimeoutSec 15 | Out-Null

    #check in loop!
    $serverOnline = $true

    do {
        if(!(Test-NetConnection -ComputerName $server.ip -wa si).PingSucceeded){
            $serverOnline = $false
        }

        #wait for next check
        sleep 1
    } while ($serverOnline)

    #wait short for offline state
    sleep 10

    #change server
    write-RZlogAndOutput -text "Change Server Type"
    
    try{
        Invoke-RestMethod -Uri "$apiMainEndPoint/servers/$($serverData.id)/actions/change_type" -Body $serverTypeRequest -Headers $authHeader -Method Post -ContentType "application/json" -ErrorAction Stop | Out-Null
    } catch {
        write-RZlogAndOutput -text "Fehler im Serverchange" -color "red"

        sleep 3

        #start server
        Invoke-RestMethod -Uri "$apiMainEndPoint/servers/$($serverData.id)/actions/poweron" -Headers $authHeader -Method Post | Out-Null
    }

    #emergency exit
    $running = 0
    
    #check online
    do {
        if((Test-NetConnection -ComputerName $server.ip -port $portToCheck -wa si).TcpTestSucceeded){
            $serverOnline = $true
        }

        sleep -m 500 

        $running++
        #$running

        if($running -ge 25){
            write-RZlogAndOutput -text "++ Emergency Exit.."
            #exit loop
            $serverOnline = $true
            $break = $true

            #start server
            Invoke-RestMethod -Uri "$apiMainEndPoint/servers/$($serverData.id)/actions/poweron" -Headers $authHeader -Method Post | Out-Null
        }

    } while (!($serverOnline))

    if($break){
        endScript -file "run_serverSet"
        Exit
    }

    #wait for next Server
    sleep 15
}

endScript -file "run_serverSet"