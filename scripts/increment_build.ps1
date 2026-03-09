# scripts/increment_build.ps1
param (
    [Parameter(Mandatory=$true)]
    [string]$Platform
)

$VersionFile = ".\scripts\version_${Platform}.txt"

if (-Not (Test-Path $VersionFile)) {
    Write-Error "Error: $VersionFile not found"
    exit 1
}

$CurrentVersion = (Get-Content $VersionFile).Trim()

if ($CurrentVersion -match "\+") {
    $parts = $CurrentVersion -split "\+"
    $BaseVersion = $parts[0]
    $BuildNum = [int]$parts[1]
    $NewBuildNum = $BuildNum + 1
} else {
    $BaseVersion = $CurrentVersion
    $NewBuildNum = 1
}

$NewVersion = "$BaseVersion+$NewBuildNum"
Set-Content -Path $VersionFile -Value $NewVersion -NoNewline

Write-Output $NewVersion
