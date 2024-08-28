# Set the source and destination paths
$sourceFolder = "D:\MHI_Basis\Export\archiv\Pforzheim"
$targetFolder = "C:\Users\MHI\Documents\Sync-SFTP-FolderCheck"

# Set the log path
$LogPath = "C:\RZ-Github\monitoring.log"


$LastCopyTime = (Get-Date).AddDays(-1)  # This is set one day behind, so at start the next copy can be created, and variable is still a datetime object.
$CopyTimeOut  = 86400                   # 1 Day in seconds


# Define a logging function
Function Out-Log ($String){
    
    $MessageString = "$(get-Date -Format "HH:mm:ss dd.MM.yyyy")- " + $String
    $MessageString | Out-File -Append -FilePath $LogPath -Force -Encoding utf8   
}

# Infinite loop to keep the script running
while ($true) {
    # Check if the folder exists
    if (Test-Path $sourceFolder) {
        # Get the list of items in the folder
        $itemsSource = Get-ChildItem -Path $sourceFolder -Recurse
        
        <# See, if there is a difference between folders -> now unnecessary, since I check for datetime and timeout
        $itemsTarget = Get-ChildItem -Path $targetFolder -Recurse
        $compareFolders = Compare-Object -ReferenceObject $sourceFolder -DifferenceObject $targetFolder #>

        # Check if the folder is not empty and it timeout of 1 day, since last copy has been reached
        if ($itemsSource.Count -gt 0 -and (New-TimeSpan -Start $LastCopyTime.TotalSeconds -gt ($CopyTimeOut)) ) {
            # Copy the folder recursively to the destination
            Copy-Item -Path $sourceFolder -Destination $targetFolder -Recurse -Force
            $LastCopyTime = Get-Date
            Out-Log "Folder copied successfully"
        } else {
            Out-Log "Folder exists but is empty"
        }
    } else {
        Out-Log "Folder not found"
    }

    # Wait for 5 minute (300 seconds)
    Start-Sleep -Seconds 300
}
