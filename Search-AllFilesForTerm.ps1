<#

Authored by:    Dominic Cauglia 

Purpose:        Search all files of both Drives for a specific term
   
#>

# Set Strictmode to avoid any PowerShell ambiguity
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'

# Define the path to search
[System.Collections.ArrayList]$searchPath = @("C:\", "D:\")  # Replace with the directory where you want to start the search

$searchString = "D:\MHI_Basis\Export\daten\Pforzheim"
foreach ($sPath in $searchPath) {
    # Get all files recursively in the specified directory
    $files = Get-ChildItem -Path $sPath -Recurse -File
    
    foreach ($f in $files) {
        try {
            # Check if the file content contains the search string
            if (Get-Content -Path $f.FullName -ErrorAction Stop | Select-String -Pattern [regex]::Escape($searchString)) {
                # Output the file path if the search string is found
                Write-Output "Found in: $($f.FullName)"
            }
        }
        catch {
            # Handle any errors (e.g., access denied or unsupported file type errors)
            Write-Warning "Could not read file: $($f.FullName) - $($_.Exception.Message -Replace '\s+',' ')"
        }
    }
}


