param([switch]$force)

#load config
. $PSScriptRoot\config.ps1

#load functions
. $PSScriptRoot\functions.ps1

if((Test-Path $PSScriptRoot\maintain) -and !($force)){
    write-RZlogAndOutput -text "-- Maintain" -color "red"
    Exit
}

if(Test-Path $PSScriptRoot\run_proforzheimSync){
    write-RZlogAndOutput -text "-- Always running" -color "red"
    Exit
}

#log
write-RZlogAndOutput -text "-- Script Start - sync-data" -color "green"

Add-Content -Value $now -Path $PSScriptRoot\run_sync

$customers = Import-Csv "$PSScriptRoot\syncFiles.csv" -Delimiter ";"

foreach ($customer in $customers){
    write-RZlogAndOutput -text "-- Customer: $($customer.name)" -color "green"

    #creds
    $sshCreds = New-Object System.Management.Automation.PSCredential ($customer.name, (ConvertTo-SecureString $customer.pass -AsPlainText -Force))

    $sftpSession = (New-SFTPSession -ComputerName $storageServer01 -Credential $sshCreds -AcceptKey).SessionId

    #local config
    $remoteRootPath = "./upload"

    #lokal files
    $files = ls $customer.folder -Recurse -file

    $moveFolder = $customer.folderDone + "\" + (get-date -UFormat "%Y%m%d")

    if(!(Test-Path $moveFolder)){
        mkdir $moveFolder | Out-Null
        sleep -m 500
    }

    foreach($file in $files){
        write-RZlogAndOutput -text "Fileupload: $($file.fullname)" -color "yellow"
        Set-SFTPItem -SessionId $sftpSession -Path $file.fullname -Destination $remoteRootPath -Force
        sleep -m 150
        Move-Item $file.fullname -Destination $moveFolder
    }


    #lokal files
    $files = ls $customer.folder -Recurse -file

    if(!($files)){
        #lokal folders
        $folders = (ls $customer.folder -Recurse -Directory).FullName
        
        $folders | Remove-Item -Recurse -ErrorAction SilentlyContinue
    }

    #end
    Get-SFTPSession | Remove-SFTPSession | Out-Null
}

endScript -file run_sync