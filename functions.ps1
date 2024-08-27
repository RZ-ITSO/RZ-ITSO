function write-RZlogAndOutput {
    param($logFile = $logFile, $text, $color = "white")

    Write-Host $text -ForegroundColor $color

    $logDate = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"

    Add-Content $logFile "[$logDate] $text"
}

function endScript {
    param($file)
    #log
    write-RZlogAndOutput -text "-- Script End`n" -color "green"

    Remove-Item $PSScriptRoot\$file
}