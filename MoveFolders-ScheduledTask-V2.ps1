<#
Authored by:    Dominic Cauglia, IT-Systems OST GmbH

Purpose:        Automatically transfer files between the archive folders to the data transfer folder.
                This script is part of a scheduled task which runs daily at 5 AM. 

#>


# Define the source and destination folders 
$SourceFolder      = "D:\MHI_Basis\Export\archiv\Essen"
$DestinationFolder = "D:\HiDriveAdmin\HiDrive\Essen\Datenaustausch Essen\Export\Archiv"        
$LogFolder         = "C:\RZ-Github\Logs"
$LogFile           = "$LogFolder\MoveScript.log"
$MaxRetries        = 5
$RetryInterval     = 60     # Wait time in seconds before retrying
$VerboseLogging    = $true  # Set to $true for detailed logging

Clear-Host

# Ensure the log folder exists
if (!(Test-Path -Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

# Logging function
function Log {
    param (
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Host "$($Timestamp) - $($Message)"
}

# Function to copy and verify files
function Move-WithVerification {
    param (
        [string]$Source, 
        [string]$Destination
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Log "Attempt $($attempt) : Copying files from '$($Source)' to '$($Destination)'."

        # Copy all files and folders
        try {
            Copy-Item -Path "$($Source)\*" -Destination $Destination -Recurse -Force -ErrorAction Stop
        } catch {
            Log "Error copying files: $_"
            Start-Sleep -Seconds $RetryInterval
            continue
        }

        Log "Copy operation completed. Verifying integrity..."

        # Verify that all files and folders exist in the destination
        $SourceItems = Get-ChildItem -Path $Source -Recurse
        
        $AllCopied = $false
        foreach ($Item in $SourceItems) {
            $RelativePath = $Item.FullName.Substring($Source.Length).TrimStart('\')
            $DestinationPath = Join-Path -Path $Destination -ChildPath $RelativePath
            
            if (!(Test-Path -Path $DestinationPath)) {
                Log "Verification failed! Missing: $DestinationPath"
                break
            } else {
                $AllCopied = $true
            }
            
            if ($VerboseLogging) {
                Log "Verified: $DestinationPath"
            }
        }

        if ($AllCopied -eq $true) {
            Log "All files verified. Proceeding with deletion from source."
            try {
                Remove-Item -Path "$Source\*" -Recurse -Force -ErrorAction Stop
                Log "Successfully moved all files from '$Source' to '$Destination'."
                return
            } catch {
                Log "Error deleting source files: $_"
            }
        }
        
        Log "Retrying in $RetryInterval seconds..."
        Start-Sleep -Seconds $RetryInterval
    }

    Log "ERROR: Maximum retry attempts reached. Move operation failed."
}

# Run the move operation
Move-WithVerification -Source $SourceFolder -Destination $DestinationFolder

Log "Script execution completed. Exiting."
