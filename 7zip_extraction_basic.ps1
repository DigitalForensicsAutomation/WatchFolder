Clear-Host
Write-Host "=== 7-Zip Auto Extract Watcher ===`n"

# -------------------------------
# USER INTERACTION (CHANGE PATHS)
# -------------------------------

function Prompt-ForFolder($promptText, $defaultPath) {
    Write-Host "$promptText"
    Write-Host "Press Enter to keep default: $defaultPath"
    $inputPath = Read-Host "Path"
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        return $defaultPath
    } else {
        return $inputPath
    }
}

$watchFolderDefault  = "D:\WatchFolder\new"
$extractFolderDefault = "D:\WatchFolder\Extracted"
$sevenZipDefault     = "C:\Program Files\7-Zip\7z.exe"

$watchFolder  = Prompt-ForFolder "Enter folder to WATCH" $watchFolderDefault
$extractBase  = Prompt-ForFolder "Enter folder to EXTRACT TO" $extractFolderDefault
$sevenZip     = Prompt-ForFolder "Path to 7z.exe" $sevenZipDefault

Write-Host "`nUsing:"
Write-Host "  Watch Folder : $watchFolder"
Write-Host "  Extract To   : $extractBase"
Write-Host "  7-Zip Path   : $sevenZip"
Write-Host ""

# Validate 7z.exe path
if (-not (Test-Path $sevenZip)) {
    Write-Host "ERROR: 7z.exe not found at: $sevenZip" -ForegroundColor Red
    exit
}

# Ensure directories exist
New-Item -ItemType Directory -Force -Path $watchFolder | Out-Null
New-Item -ItemType Directory -Force -Path $extractBase | Out-Null

Write-Host "Starting watcher... polling every 30 seconds.`n"

# -------------------------------
# MAIN LOOP
# -------------------------------

while ($true) {

    # Get zip or split zip starters
    $archives = Get-ChildItem $watchFolder -File | Where-Object {
        $_.Extension -match "\.zip$|\.001$|\.z01$"
    }

    foreach ($file in $archives) {

        $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $extractDir = Join-Path $extractBase $baseName
        $rootPart = $file.FullName  # FIX: no ternary operator needed

        Write-Host "Found archive: $($file.Name)"
        Write-Host "Extracting to: $extractDir"
        New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

        # -------------------------------
        # 7-Zip extraction
        # -------------------------------
        & "$sevenZip" x "`"$rootPart`"" "-o$extractDir" -y | Write-Host

        if ($LASTEXITCODE -eq 0) {
            Write-Host "SUCCESS: Extracted $($file.Name)" -ForegroundColor Green

            # Delete all parts belonging to the same split archive
            $pattern = "$baseName.*"
            $parts = Get-ChildItem $watchFolder | Where-Object { $_.Name -like $pattern }

            foreach ($p in $parts) {
                Remove-Item $p.FullName -Force
                Write-Host "Deleted: $($p.Name)"
            }
        }
        else {
            Write-Host "ERROR: Failed to extract $($file.Name)" -ForegroundColor Red
        }
    }

    Write-Host "Waiting 30 seconds..."
    Start-Sleep -Seconds 30
}
