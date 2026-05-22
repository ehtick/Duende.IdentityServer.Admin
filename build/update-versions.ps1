param([Parameter(Mandatory = $true)][string] $new)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

$targets = @(
    @{
        Path = Join-Path $root "Directory.Build.props"
        Replacements = @(
            @{
                Pattern = "<Version>[^<]+</Version>"
                Replacement = "<Version>$new</Version>"
            }
        )
    },
    @{
        Path = Join-Path $root "templates/template-build/Skoruba.Duende.IdentityServer.Admin.Templates.nuspec"
        Replacements = @(
            @{
                Pattern = "<version>[^<]+</version>"
                Replacement = "<version>$new</version>"
            }
        )
    },
    @{
        Path = Join-Path $root "templates/template-publish/Skoruba.Duende.IdentityServer.Admin.Templates.nuspec"
        Replacements = @(
            @{
                Pattern = "<version>[^<]+</version>"
                Replacement = "<version>$new</version>"
            }
        )
    },
    @{
        Path = Join-Path $root "src/Skoruba.Duende.IdentityServer.Admin.UI.Client/package.json"
        Replacements = @(
            @{
                Pattern = '(?m)^(\s*)"version"\s*:\s*"[^"]+"'
                Replacement = "$1`"version`": `"$new`""
            },
            @{
                Pattern = '(?m)^(\s*)"@skoruba/duende\.identityserver\.admin\.api\.client"\s*:\s*"[^"]+"'
                Replacement = "$1`"@skoruba/duende.identityserver.admin.api.client`": `"$new`""
            }
        )
    },
    @{
        Path = Join-Path $root "src/Skoruba.Duende.IdentityServer.Admin.UI.Client/package-lock.json"
        Replacements = @(
            @{
                Pattern = '(?ms)("name"\s*:\s*"skoruba-duende-identityserver-admin"\s*,\s*"version"\s*:\s*")[^"]+(")'
                Replacement = "`$1$new`$2"
            },
            @{
                Pattern = '(?ms)(""\s*:\s*\{\s*"name"\s*:\s*"skoruba-duende-identityserver-admin"\s*,\s*"version"\s*:\s*")[^"]+(")'
                Replacement = "`$1$new`$2"
            },
            @{
                Pattern = '(?m)^(\s*)"@skoruba/duende\.identityserver\.admin\.api\.client"\s*:\s*"[^"]+"'
                Replacement = "$1`"@skoruba/duende.identityserver.admin.api.client`": `"$new`""
            }
        )
    },
    @{
        Path = Join-Path $root "src/Skoruba.Duende.IdentityServer.Admin.Api/TypescriptClient/package.json"
        Replacements = @(
            @{
                Pattern = '(?m)^(\s*)"version"\s*:\s*"[^"]+"'
                Replacement = "$1`"version`": `"$new`""
            }
        )
    },
    @{
        Path = Join-Path $root "src/Skoruba.Duende.IdentityServer.Admin.Api/TypescriptClient/package-lock.json"
        Replacements = @(
            @{
                Pattern = '(?ms)("name"\s*:\s*"@skoruba/duende\.identityserver\.admin\.api\.client"\s*,\s*"version"\s*:\s*")[^"]+(")'
                Replacement = "`$1$new`$2"
            },
            @{
                Pattern = '(?ms)(""\s*:\s*\{\s*"name"\s*:\s*"@skoruba/duende\.identityserver\.admin\.api\.client"\s*,\s*"version"\s*:\s*")[^"]+(")'
                Replacement = "`$1$new`$2"
            }
        )
    }
)

foreach ($target in $targets) {
    if (-not (Test-Path $target.Path)) {
        throw "File not found: $($target.Path)"
    }

    Write-Host $target.Path

    $content = Get-Content $target.Path -Raw -Encoding UTF8
    $updated = $content

    foreach ($replacement in $target.Replacements) {
        $updated = $updated -replace $replacement.Pattern, $replacement.Replacement
    }

    Set-Content $target.Path -Encoding UTF8 -NoNewline -Value $updated
}
