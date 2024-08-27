<#

Authored by:    Eric Zielonka 
Edited by:      Dominic Cauglia 

Purpose:        Automatically transfer files between the local folders to the customer's SFTP server.
            
Stuff Needed:   * syncFiles.csv - SFTP credentials, local and remote paths
                * functions.ps1 - Logging and script exiting function, which removes status files
                * config.ps1    - Path to log.txt file
#>


param([switch]$force)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'

# Load config
Import-Module "C:\RZ-Github\config.ps1"

# Load functions
Import-Module "C:\RZ-Github\functions.ps1"

# Check if maintenance status file exists and if 'force' parameter is set - Exit script, if maintenance file is found and force param is not set.
if((Test-Path "C:\RZ-Github\maintain") -and ($force -eq $false)){
    write-RZlogAndOutput -text "-- Maintain" -color "red"
    Exit
}

# Check if sync process is already running
if(Test-Path "C:\RZ-Github\run_proforzheimSync"){
    write-RZlogAndOutput -text "-- Always running" -color "red"
    Exit
}

# Log start of process
write-RZlogAndOutput -text "-- Script Start - sync-data" -color "green"

# Create status file 'run_sync'
Add-Content -Value $now -Path "C:\RZ-Github\run_sync"

# Load CSV file with customer name, file paths and SFTP credentials
$customers = Import-Csv "C:\RZ-Github\syncFiles.csv" -Delimiter ";"

# Looping through each customer in file
foreach ($customer in $customers){
    write-RZlogAndOutput -text "-- Customer: $($customer.name)" -color "green"

    # Building SFTP credentials
    $sshCreds = New-Object System.Management.Automation.PSCredential ($customer.name, (ConvertTo-SecureString $customer.pass -AsPlainText -Force))

    # Creating new SFTP sessions
    $sftpSession = (New-SFTPSession -ComputerName $storageServer01 -Credential $sshCreds -AcceptKey).SessionId

    # Defining the remote upload path on SFTP Server
    $remoteRootPath = "./upload"

    # Fetching local files and establishing count
    $files      = Get-ChildItem $customer.folder -Recurse -file
    $filesCount = $files.Count 

    # Creating a folder for already uploaded files to be moved into
    $moveFolder = $customer.folderDone + "\" + (Get-Date -UFormat "%Y%m%d")

    # If folder doesn't exist, create it. 
    if(!(Test-Path $moveFolder)){
        
        $null = New-Item -Path $moveFolder -ItemType Directory
        Start-Sleep -Milliseconds 500

    } else { # If it can't be created, exit script and remove the status file 'run_sync'
        write-RZlogAndOutput -text "-- Couldn't create folder: '$($moveFolder)'"
        endScript -file run_sync
        Exit
    }
    
    # Defining ArrayList for failed file uploads
    [System.Collections.ArrayList]$failedUploads = @()

    # Looping through each file
    foreach($file in $files){

        # Defining while loop conditions - retries for each failed fileupload
        $whileCounterCurrent = 0 
        $whileCounterMaximum = 5
        $checkFile  = $false
        
        # As long as the check is unsuccessful and the maximum amount of retries is not reached, while loop is active
        while (($checkFile -eq $false) -and $whileCounterCurrent -lt $whileCounterMaximum) {
            
            try {
                # Trying to upload the file
                write-RZlogAndOutput -text "Fileupload: $($file.fullname)" -color "yellow"
                Set-SFTPItem -SessionId $sftpSession -Path $file.fullname -Destination $remoteRootPath -Force
                Start-Sleep -Milliseconds 150
                
                # Defining upload path for current file and testing if was uploaded
                $filePath = $remoteRootPath + "/$($file.Name)" 
                $checkFile = Test-SFTPPath -SessionId $sftpSession -Path $filePath
                
                # If check is not 'True' (file upload successful), write remote path into log
                if ($checkFile) {
                    Move-Item $file.fullname -Destination $moveFolder
                } else {
                    write-RZlogAndOutput -text "Couldn't find file in remote folder: '$($filePath)'" -color "red"
                }

            } catch { # If a terminating error is encountered, write an error message into the log
                $myError = $_
                $ErrorMessage = ($myError.Exception.Message -Replace "\s+"," ")
                write-RZlogAndOutput -text $ErrorMessage -color "red"
            }

            # IF file upload wasn't successfull, the counter goes up by 1 and while loop sleeps (pauses) for 2 seconds
            $whileCounterCurrent++
            if ($whileCounterCurrent -eq $whileCounterMaximum) {
                $null = $failedUploads.Add($file.FullName)
            }
            Start-Sleep -Milliseconds 500
        }
    }

    # Check item count on remote folder
    $remoteFilesCount = (Get-SFTPChildItem -SessionId $sftpSession -Path $remoteRootPath | measure-object).count

    # If the remote files count and the local files count are the same, the upload was successful.
    if ($remoteFilesCount -eq $filesCount) {
        write-RZlogAndOutput -text "All files have been successfully transferred" -color "green"
        
    } else { # If not, write each unsuccessful file into the log

        write-RZlogAndOutput -text "NOT ALL files have been transferred to SFTP server!" -color "red"
        
        $failedUploads | ForEach-Object {
            write-RZlogAndOutput -text $_ -color "yellow" 
        }
    }

    # Fetching all local files from customer folder
    $files = Get-ChildItem $customer.folder -Recurse -file

    # If there are no files in folder anymore
    if([string]::IsNullOrEmpty($files)){
    
        while (Test-Path -Path $customer.folder) {
            
            # Fetching local customer folder 
            $folders = (Get-ChildItem $customer.folder -Recurse -Directory).FullName
            
            # Deleting local folder
            try {
                $folders | Remove-Item -Recurse -ErrorAction Stop
                
            } catch { # If a terminating error is encountered, write an error message into the log
                $myError = $_
                $ErrorMessage = ($myError.Exception.Message -Replace "\s+"," ")
                write-RZlogAndOutput -text $ErrorMessage -color "red"
            }
        }
    }

    # End SFTP Session to current customers remote SFTP Server
    Get-SFTPSession | Remove-SFTPSession | Out-Null
}

# Ending script and removing 'run_sync' status file
endScript -file run_sync