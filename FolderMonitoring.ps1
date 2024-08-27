# Set the source and destination paths
$sourceFolder      = "D:\MHI_Basis\Export\archiv\Pforzheim"
$destinationFolder = "C:\Users\MHI\Documents\Sync-SFTP-FolderCheck"

# Set the log path
$LogPath = "C:\RZ-Github\monitoring.log"

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
        $items = Get-ChildItem -Path $sourceFolder
        
        # Check if the folder is not empty
        if ($items.Count -gt 0) {
            # Copy the folder recursively to the destination
            Copy-Item -Path $sourceFolder -Destination $destinationFolder -Recurse -Force
            Out-Log "Folder copied successfully at $(Get-Date)"
        } else {
            Out-Log "Folder exists but is empty at $(Get-Date)"
        }
    } else {
        Out-Log "Folder not found at $(Get-Date)"
    }

    # Wait for 1 minute (60 seconds)
    Start-Sleep -Seconds 60
}
