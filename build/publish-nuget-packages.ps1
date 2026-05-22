param(
    [Parameter(Mandatory = $true)][string] $version,
    [Parameter(Mandatory = $true)][string] $key
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$packagesDir = Join-Path $PSScriptRoot "packages"
$packages = Get-ChildItem -Path $packagesDir -Filter "*.$version.nupkg" -File |
    Where-Object { $_.Name -notlike "*.symbols.nupkg" } |
    Sort-Object Name

if (-not $packages) {
    throw "No NuGet packages were found in $packagesDir for version $version."
}

foreach ($package in $packages) {
    Write-Host "Publishing $($package.Name)"
    dotnet nuget push $package.FullName -k $key -s https://api.nuget.org/v3/index.json --skip-duplicate

    if ($LASTEXITCODE -ne 0) {
        throw "dotnet nuget push failed for $($package.FullName)."
    }
}
