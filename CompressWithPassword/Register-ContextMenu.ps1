# Register-ContextMenu.ps1
# Run once from the same folder that contains CompressWithPassword.ps1

$scriptPath = Join-Path $PSScriptRoot "CompressWithPassword.ps1"

if (-not (Test-Path -LiteralPath $scriptPath)) {
    Write-Error "CompressWithPassword.ps1 not found next to this registration script."
    exit 1
}

$verbKey = "HKCU:\Software\Classes\AllFilesystemObjects\shell\CompressWithPassword"
$commandKey = "$verbKey\command"

# Clean any previous registration
if (Test-Path $verbKey) {
    Remove-Item -Path $verbKey -Recurse -Force
}

New-Item -Path $verbKey -Force | Out-Null
Set-ItemProperty -Path $verbKey -Name "(default)" -Value "Compress with Password"
Set-ItemProperty -Path $verbKey -Name "MultiSelectModel" -Value "Player"
Set-ItemProperty -Path $verbKey -Name "Icon" -Value "imageres.dll,166"   # generic archive icon; change if you prefer

New-Item -Path $commandKey -Force | Out-Null

# %1 is expanded by Explorer to every selected path when MultiSelectModel=Player
$cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" `"%1`""
Set-ItemProperty -Path $commandKey -Name "(default)" -Value $cmd

Write-Host "Context menu registered successfully."
Write-Host "Right-click any file(s) or folder(s) in Explorer → Compress with Password"
Write-Host ""
Write-Host "To remove later, run:"
Write-Host "  Remove-Item -Path '$verbKey' -Recurse -Force"