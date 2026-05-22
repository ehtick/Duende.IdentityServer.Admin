param(
    [Parameter(Mandatory = $true)][string] $Version,
    [string] $NuGetApiKey,
    [string] $NpmTag,
    [string] $NpmToken,
    [int] $NuGetPollTimeoutMinutes = 20,
    [int] $NuGetPollIntervalSeconds = 30,
    [string] $SmokeTestProjectName = "MyProject",
    [switch] $SkipNpmPublish,
    [switch] $SkipNuGetPublish,
    [switch] $SkipTemplateSmokeTest,
    [switch] $SkipTemplatePublish,
    [switch] $SkipChangelogUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$buildDir = Join-Path $root "build"
$templatesDir = Join-Path $root "templates"
$typescriptClientDir = Join-Path $root "src/Skoruba.Duende.IdentityServer.Admin.Api/TypescriptClient"
$packagesDir = Join-Path $buildDir "packages"

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][scriptblock] $Action
    )

    Write-Host ""
    Write-Host "=== $Name ==="
    & $Action
}

function Invoke-CheckedExternalCommand {
    param(
        [Parameter(Mandatory = $true)][scriptblock] $Command,
        [Parameter(Mandatory = $true)][string] $ErrorMessage
    )

    & $Command

    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

function Get-NpmTagFromVersion {
    param([Parameter(Mandatory = $true)][string] $ReleaseVersion)

    if ($ReleaseVersion -match "-rc") {
        return "rc"
    }

    if ($ReleaseVersion -match "-preview") {
        return "preview"
    }

    return "latest"
}

function Assert-ReleaseConfiguration {
    if ((-not $SkipNuGetPublish -or -not $SkipTemplatePublish) -and [string]::IsNullOrWhiteSpace($NuGetApiKey)) {
        throw "NuGetApiKey is required unless both -SkipNuGetPublish and -SkipTemplatePublish are specified."
    }

    if ($SkipTemplateSmokeTest -and -not $SkipTemplatePublish) {
        throw "Template publish currently depends on the smoke test step because that step builds the local template package. Remove -SkipTemplateSmokeTest or add -SkipTemplatePublish."
    }
}

function Publish-TypeScriptClient {
    param(
        [Parameter(Mandatory = $true)][string] $PublishTag,
        [string] $Token
    )

    Push-Location $typescriptClientDir

    $tempNpmConfig = $null

    try {
        Invoke-CheckedExternalCommand -Command { npm run build } -ErrorMessage "TypeScript client build failed."

        $publishArgs = @("publish", "--tag", $PublishTag, "--access", "public")

        if (-not [string]::IsNullOrWhiteSpace($Token)) {
            $tempNpmConfig = Join-Path ([System.IO.Path]::GetTempPath()) ("skoruba-release-" + [System.Guid]::NewGuid().ToString("N") + ".npmrc")
            Set-Content -Path $tempNpmConfig -Encoding UTF8 -NoNewline -Value @"
@skoruba:registry=https://registry.npmjs.org/
//registry.npmjs.org/:_authToken=$Token
always-auth=true
"@
            $publishArgs += @("--userconfig", $tempNpmConfig)
        }

        Invoke-CheckedExternalCommand -Command { npm @publishArgs } -ErrorMessage "TypeScript client publish failed."
    }
    finally {
        if ($tempNpmConfig -and (Test-Path $tempNpmConfig)) {
            Remove-Item $tempNpmConfig -Force
        }

        Pop-Location
    }
}

function Get-ReleasePackageIds {
    param([Parameter(Mandatory = $true)][string] $ReleaseVersion)

    $packages = Get-ChildItem -Path $packagesDir -Filter "*.$ReleaseVersion.nupkg" -File |
        Where-Object { $_.Name -notlike "*.symbols.nupkg" }

    if (-not $packages) {
        throw "No NuGet packages were found in $packagesDir for version $ReleaseVersion."
    }

    return $packages | ForEach-Object {
        $_.BaseName.Substring(0, $_.BaseName.Length - ".$ReleaseVersion".Length)
    }
}

function Wait-ForNuGetPackages {
    param(
        [Parameter(Mandatory = $true)][string[]] $PackageIds,
        [Parameter(Mandatory = $true)][string] $ReleaseVersion,
        [Parameter(Mandatory = $true)][int] $TimeoutMinutes,
        [Parameter(Mandatory = $true)][int] $IntervalSeconds
    )

    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    $pending = [System.Collections.Generic.List[string]]::new()
    $PackageIds | Sort-Object -Unique | ForEach-Object { [void] $pending.Add($_) }

    while ($pending.Count -gt 0) {
        foreach ($packageId in @($pending)) {
            $packageIdLower = $packageId.ToLowerInvariant()
            $versionLower = $ReleaseVersion.ToLowerInvariant()
            $packageUrl = "https://api.nuget.org/v3-flatcontainer/$packageIdLower/$versionLower/$packageIdLower.$versionLower.nupkg"

            try {
                $response = Invoke-WebRequest -Uri $packageUrl -Method Head -ErrorAction Stop

                if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
                    [void] $pending.Remove($packageId)
                }
            }
            catch {
            }
        }

        if ($pending.Count -eq 0) {
            return
        }

        if ((Get-Date) -ge $deadline) {
            throw "Timed out waiting for NuGet packages to become available: $($pending -join ', ')"
        }

        Write-Host "Waiting for NuGet availability: $($pending -join ', ')"
        Start-Sleep -Seconds $IntervalSeconds
    }
}

function Remove-ReleaseArtifacts {
    param([Parameter(Mandatory = $true)][string] $ReleaseVersion)

    $pathsToRemove = @(
        (Join-Path $templatesDir $SmokeTestProjectName),
        (Join-Path $templatesDir "SkorubaDuende.IdentityServerAdmin"),
        (Join-Path $templatesDir "Skoruba.Duende.IdentityServer.Admin.Templates.$ReleaseVersion.nupkg")
    )

    foreach ($path in $pathsToRemove) {
        if (Test-Path $path) {
            Remove-Item $path -Recurse -Force
        }
    }
}

function Invoke-TemplateSmokeTest {
    param([Parameter(Mandatory = $true)][string] $ReleaseVersion)

    Remove-ReleaseArtifacts -ReleaseVersion $ReleaseVersion

    Push-Location $templatesDir

    try {
        Invoke-CheckedExternalCommand -Command { .\install.ps1 -packagesVersions $ReleaseVersion } -ErrorMessage "Template install script failed."

        $generatedProjectDir = Join-Path $templatesDir $SmokeTestProjectName

        if (-not (Test-Path $generatedProjectDir)) {
            throw "Generated template project was not created at $generatedProjectDir."
        }

        $solutions = Get-ChildItem -Path $generatedProjectDir -Filter *.sln -Recurse -File | Sort-Object FullName

        if (-not $solutions) {
            throw "No solution files were found in $generatedProjectDir."
        }

        foreach ($solution in $solutions) {
            Invoke-CheckedExternalCommand -Command { dotnet restore $solution.FullName } -ErrorMessage "dotnet restore failed for $($solution.FullName)."
            Invoke-CheckedExternalCommand -Command { dotnet build $solution.FullName -c Release --no-restore } -ErrorMessage "dotnet build failed for $($solution.FullName)."
        }
    }
    finally {
        Pop-Location
    }
}

if ([string]::IsNullOrWhiteSpace($NpmTag)) {
    $NpmTag = Get-NpmTagFromVersion -ReleaseVersion $Version
}

Assert-ReleaseConfiguration

Invoke-Step -Name "Update versions to $Version" -Action {
    Invoke-CheckedExternalCommand -Command { & (Join-Path $buildDir "update-versions.ps1") -new $Version } -ErrorMessage "Version update failed."
}

if (-not $SkipNpmPublish) {
    Invoke-Step -Name "Build and publish TypeScript client" -Action {
        Publish-TypeScriptClient -PublishTag $NpmTag -Token $NpmToken
    }
}

Invoke-Step -Name "Create NuGet packages" -Action {
    Push-Location $buildDir

    try {
        Invoke-CheckedExternalCommand -Command { .\create-packages.ps1 } -ErrorMessage "NuGet package creation failed."
    }
    finally {
        Pop-Location
    }
}

if (-not $SkipNuGetPublish) {
    Invoke-Step -Name "Publish NuGet packages" -Action {
        Invoke-CheckedExternalCommand -Command { & (Join-Path $buildDir "publish-nuget-packages.ps1") -version $Version -key $NuGetApiKey } -ErrorMessage "NuGet package publish failed."
    }

    Invoke-Step -Name "Wait for NuGet packages to become available" -Action {
        $packageIds = Get-ReleasePackageIds -ReleaseVersion $Version
        Wait-ForNuGetPackages -PackageIds $packageIds -ReleaseVersion $Version -TimeoutMinutes $NuGetPollTimeoutMinutes -IntervalSeconds $NuGetPollIntervalSeconds
    }
}

if (-not $SkipTemplateSmokeTest) {
    Invoke-Step -Name "Generate and smoke test the publish template" -Action {
        Invoke-TemplateSmokeTest -ReleaseVersion $Version
    }
}

if (-not $SkipTemplatePublish) {
    Invoke-Step -Name "Publish template package" -Action {
        Invoke-CheckedExternalCommand -Command { & (Join-Path $buildDir "publish-nuget-project-template.ps1") -version $Version -key $NuGetApiKey } -ErrorMessage "Template package publish failed."
    }
}

if (-not $SkipChangelogUpdate) {
    Invoke-Step -Name "Update changelog" -Action {
        Invoke-CheckedExternalCommand -Command { & (Join-Path $buildDir "update-changelog.ps1") -version $Version } -ErrorMessage "CHANGELOG update failed."
    }
}

Write-Host ""
Write-Host "Release flow completed for version $Version."
