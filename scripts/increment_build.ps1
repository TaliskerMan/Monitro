# scripts/increment_build.ps1
$pubspec = "pubspec.yaml"
if (-Not (Test-Path $pubspec)) {
    Write-Error "pubspec.yaml not found"
    exit 1
}

$content = Get-Content $pubspec
$newContent = @()
$newVersion = ""

foreach ($line in $content) {
    if ($line -match "^version:\s+(.+)$") {
        $currentVersion = $Matches[1]
        
        if ($currentVersion -match "\+(.+)$") {
            $baseVersion = $currentVersion -replace "\+.+$",""
            $buildNum = [int]$Matches[1]
            $newBuildNum = $buildNum + 1
            $newVersion = "$baseVersion+$newBuildNum"
        } else {
            $baseVersion = $currentVersion
            $newVersion = "$baseVersion+1"
        }
        $newContent += "version: $newVersion"
    } else {
        $newContent += $line
    }
}

$newContent | Set-Content $pubspec
Write-Output $newVersion
