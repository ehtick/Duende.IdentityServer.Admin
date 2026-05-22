param(
    [Parameter(Mandatory = $true)][string] $version,
    [Parameter(Mandatory = $true)][string] $key
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$packagePath = Resolve-Path (Join-Path $PSScriptRoot "../templates/Skoruba.Duende.IdentityServer.Admin.Templates.$version.nupkg") -ErrorAction SilentlyContinue

if (-not $packagePath) {
    throw "Template package not found for version $version."
}

dotnet nuget push $packagePath.Path -k $key -s https://api.nuget.org/v3/index.json --skip-duplicate

if ($LASTEXITCODE -ne 0) {
    throw "dotnet nuget push failed for template package $($packagePath.Path)."
}
