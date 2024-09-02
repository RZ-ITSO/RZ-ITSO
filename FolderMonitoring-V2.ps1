# Set the source and destination paths
$sourceFolder = "D:\MHI_Basis\Export\archiv\Pforzheim"
$targetFolder = "C:\Sync-SFTP-FolderCheck"

# Set the log path
$LogPath = "C:\RZ-Github\monitoring.log"

# Define a logging function
Function Out-Log ($String) {
    $MessageString = "$(Get-Date -Format "HH:mm:ss dd.MM.yyyy") - " + $String
    $MessageString | Out-File -Append -FilePath $LogPath -Force -Encoding utf8
}

# Infinite loop to keep the script running
while ($true) {
    Out-Log "Starting folder check..."

    # Check if the source folder exists
    if (Test-Path $sourceFolder) {
        # Get all folders in the source folder recursively
        $foldersSource = Get-ChildItem -Path $sourceFolder -Directory -Recurse
        
        if ($foldersSource.Count -gt 0) {
            foreach ($folder in $foldersSource) {
                $relativePath = $folder.FullName.Substring($sourceFolder.Length).TrimStart("\")
                $targetPath = Join-Path $targetFolder $relativePath

                # Check if the folder already exists in the target location
                if (-not (Test-Path $targetPath)) {
                    Out-Log "Folder '$relativePath' does not exist in target. Starting copy..."

                    # Copy all items from the source to the target folder
                    Copy-Item -Path $folder.FullName -Destination $targetPath -Recurse -Force
                    Out-Log "Folder '$relativePath' copied successfully using Copy-Item."
                    
                } else {
                    Out-Log "Folder '$relativePath' already exists in the target. Skipping copy."
                }
            }
        } else {
            Out-Log "No folders found in the source directory."
        }
    } else {
        Out-Log "Source folder not found."
    }

    # Wait for 5 minutes (300 seconds) before next check
    Out-Log "Waiting for 5 minutes before the next check..."
    Start-Sleep -Seconds 300
}
