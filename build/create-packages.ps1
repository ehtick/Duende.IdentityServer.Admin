Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$packagesOutput = ".\packages"

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][scriptblock] $Command,
        [Parameter(Mandatory = $true)][string] $ErrorMessage
    )

    & $Command

    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

function Sync-UiClientApiDependency {
    param(
        [Parameter(Mandatory = $true)][string] $ClientPath,
        [int] $RetryCount = 8,
        [int] $RetryDelaySeconds = 15
    )

    $packageJsonPath = Join-Path $ClientPath "package.json"
    $packageJson = Get-Content $packageJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $expectedVersion = $packageJson.dependencies.'@skoruba/duende.identityserver.admin.api.client'

    if ([string]::IsNullOrWhiteSpace($expectedVersion)) {
        throw "Expected @skoruba/duende.identityserver.admin.api.client dependency was not found in $packageJsonPath."
    }

    $installedPackageJsonPath = Join-Path $ClientPath "node_modules/@skoruba/duende.identityserver.admin.api.client/package.json"
    $installedVersion = $null

    if (Test-Path $installedPackageJsonPath) {
        $installedVersion = (Get-Content $installedPackageJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json).version
    }

    if ($installedVersion -eq $expectedVersion) {
        Write-Host "UI client already uses API client version $expectedVersion."
        return
    }

    Push-Location $ClientPath

    try {
        for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
            Write-Host "Installing @skoruba/duende.identityserver.admin.api.client@$expectedVersion for the UI client (attempt $attempt/$RetryCount)."

            npm install "@skoruba/duende.identityserver.admin.api.client@$expectedVersion" --save-exact

            if ($LASTEXITCODE -eq 0) {
                return
            }

            if ($attempt -eq $RetryCount) {
                throw "Failed to install @skoruba/duende.identityserver.admin.api.client@$expectedVersion after $RetryCount attempts."
            }

            Write-Warning "npm install failed, retrying in $RetryDelaySeconds seconds."
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
    finally {
        Pop-Location
    }
}

# Clean packages output directory
if (Test-Path $packagesOutput) {
    Get-ChildItem -Path $packagesOutput -Force | Remove-Item -Recurse -Force
}

# Build SPA assets for client before packing
$clientPath = Resolve-Path ".\..\src\Skoruba.Duende.IdentityServer.Admin.UI.Client" -ErrorAction SilentlyContinue

if (-not $clientPath) {
    throw "Client path not found: .\..\src\Skoruba.Duende.IdentityServer.Admin.UI.Client"
}

Sync-UiClientApiDependency -ClientPath $clientPath.Path

Push-Location $clientPath.Path

try {
    Invoke-CheckedCommand -Command { npm run build:spa } -ErrorMessage "Client build failed (npm run build:spa)."
}
finally {
    Pop-Location
}

$projects = @(
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.BusinessLogic\Skoruba.Duende.IdentityServer.Admin.BusinessLogic.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Identity\Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Identity.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Shared\Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Shared.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Shared.Configuration\Skoruba.Duende.IdentityServer.Shared.Configuration.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.EntityFramework\Skoruba.Duende.IdentityServer.Admin.EntityFramework.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Extensions\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Extensions.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Identity\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Identity.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Shared\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Shared.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Configuration\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Configuration.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Admin\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Admin.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Admin.Storage\Skoruba.Duende.IdentityServer.Admin.EntityFramework.Admin.Storage.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.UI\Skoruba.Duende.IdentityServer.Admin.UI.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.UI.Spa\Skoruba.Duende.IdentityServer.Admin.UI.Spa.csproj",
    ".\..\src\Skoruba.Duende.IdentityServer.Admin.UI.Api\Skoruba.Duende.IdentityServer.Admin.UI.Api.csproj"
)

foreach ($project in $projects) {
    Invoke-CheckedCommand -Command { dotnet pack $project -c Release -o $packagesOutput } -ErrorMessage "dotnet pack failed for $project."
}
