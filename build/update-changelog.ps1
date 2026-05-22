param([Parameter(Mandatory = $true)][string] $version)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$changelogPath = Join-Path $root "CHANGELOG.md"

if (-not (Test-Path $changelogPath)) {
    throw "CHANGELOG.md was not found at $changelogPath."
}

$content = Get-Content $changelogPath -Raw -Encoding UTF8
$newline = if ($content -match "`r`n") { "`r`n" } else { "`n" }

if ($content -match "(?m)^## \[$([regex]::Escape($version))\]") {
    Write-Host "CHANGELOG.md already contains version $version."
    return
}

$today = Get-Date -Format "yyyy-MM-dd"
$heading = if ($version.Contains("-")) { "## [$version]" } else { "## [$version] – $today" }

$newSection = @"
$heading

### Added

- TODO

### Changed

- TODO

### Fixed

- TODO

---

"@
$newSection = $newSection -replace "`r?`n", $newline

if ($content.StartsWith("# Changelog")) {
    $updated = $content -replace "^# Changelog\r?\n\r?\n", "# Changelog${newline}${newline}$newSection"
}
else {
    $updated = "$newSection$content"
}

Set-Content $changelogPath -Encoding UTF8 -NoNewline -Value $updated
