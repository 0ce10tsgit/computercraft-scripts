# deploy-rednet-tracer.ps1
# Copies rednet_tracer startup.lua to each target computer, then uploads via SFTP.
# Fill in $targets with the computer IDs once assigned in-game.

$ErrorActionPreference = "Stop"

$source  = Join-Path $PSScriptRoot "startup\startup.lua"
$root    = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$targets = @("9")  # TODO: add computer IDs e.g. @("8")

# ── Local copy ────────────────────────────────────────────────────────────────
Write-Host "Copying files locally..."
foreach ($id in $targets) {
    $dir  = Join-Path $root "$id\startup"
    $dest = Join-Path $dir "startup.lua"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Copy-Item -Path $source -Destination $dest -Force
    Write-Host "  -> $dest"
}

# ── SFTP upload ───────────────────────────────────────────────────────────────
$sftp = Get-Content (Join-Path $root ".vscode\sftp.json") -Raw | ConvertFrom-Json

if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Host "Posh-SSH not found, installing..."
    Install-Module -Name Posh-SSH -Force -Scope CurrentUser
}
Import-Module Posh-SSH -ErrorAction Stop

$cred = New-Object System.Management.Automation.PSCredential(
    $sftp.username,
    (ConvertTo-SecureString $sftp.password -AsPlainText -Force)
)

Write-Host "Connecting to $($sftp.host):$($sftp.port)..."
$session = New-SFTPSession -ComputerName $sftp.host -Port $sftp.port -Credential $cred -AcceptKey

foreach ($id in $targets) {
    $local     = Join-Path $root "$id\startup\startup.lua"
    $remoteDir = "$($sftp.remotePath)$id/startup"

    if (-not (Test-SFTPPath -SessionId $session.SessionId -Path $remoteDir)) {
        New-SFTPItem -SessionId $session.SessionId -Path $remoteDir -ItemType Directory | Out-Null
    }

    Set-SFTPItem -SessionId $session.SessionId -Path $local -Destination $remoteDir -Force
    Write-Host "  -> $remoteDir/startup.lua"
}

Remove-SFTPSession -SessionId $session.SessionId | Out-Null

Write-Host ""
Write-Host "Done. Reboot target computers in-game to apply."
