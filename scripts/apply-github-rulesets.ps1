# Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

# Copyright 2026 D-o-M-Pl
# Licensed under the Apache License, Version 2.0.

[CmdletBinding()]
param(
    [string]$Owner = "D-o-M-Pl",

    [string[]]$Repositories = @(
        "volunteer-platform",
        "Char-code",
        "cloud-billing-anomaly",
        "Desing-Azure-AI-Architecy-governed-agent"
    ),

    [switch]$DiscoverOwnedRepositories,

    [switch]$DryRun,

    [switch]$SkipVerification
)

$ErrorActionPreference = "Stop"
$ApiVersion = "2026-03-10"
$Root = Split-Path -Parent $PSScriptRoot
$RulesDir = Join-Path $Root ".github\rulesets"

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found."
    }
}

function Invoke-GhApiJson {
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = & gh api `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: $ApiVersion" `
        @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "gh api failed: $($Arguments -join ' ')"
    }

    if ([string]::IsNullOrWhiteSpace(($output -join "`n"))) {
        return $null
    }

    return ($output -join "`n") | ConvertFrom-Json
}

function Get-OwnedRepositories {
    param([Parameter(Mandatory)][string]$ExpectedOwner)

    $repos = @()
    $page = 1

    while ($true) {
        $batch = Invoke-GhApiJson -Arguments @(
            "--method", "GET",
            "/user/repos?affiliation=owner&per_page=100&page=$page"
        )

        if (-not $batch -or @($batch).Count -eq 0) {
            break
        }

        foreach ($repo in @($batch)) {
            if (
                $repo.owner.login -eq $ExpectedOwner -and
                -not $repo.archived
            ) {
                $repos += $repo.name
            }
        }

        if (@($batch).Count -lt 100) {
            break
        }

        $page += 1
    }

    return $repos | Sort-Object -Unique
}

function Get-ExistingRuleset {
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Name
    )

    $items = Invoke-GhApiJson -Arguments @(
        "--method", "GET",
        "/repos/$Owner/$Repo/rulesets?includes_parents=false&per_page=100"
    )

    foreach ($item in @($items)) {
        if ($item.name -eq $Name -and $item.source_type -eq "Repository") {
            return $item
        }
    }

    return $null
}

function Set-RepositoryRuleset {
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$File
    )

    $path = Join-Path $RulesDir $File
    if (-not (Test-Path $path)) {
        throw "Ruleset file does not exist: $path"
    }

    $payload = Get-Content $path -Raw | ConvertFrom-Json
    $existing = Get-ExistingRuleset -Repo $Repo -Name $payload.name

    if ($existing) {
        Write-Host "UPDATE $Owner/$Repo :: $($payload.name)"

        if (-not $DryRun) {
            & gh api `
                --method PUT `
                -H "Accept: application/vnd.github+json" `
                -H "X-GitHub-Api-Version: $ApiVersion" `
                "/repos/$Owner/$Repo/rulesets/$($existing.id)" `
                --input $path

            if ($LASTEXITCODE -ne 0) {
                throw "Failed updating ruleset '$($payload.name)' in $Owner/$Repo."
            }
        }

        return
    }

    Write-Host "CREATE $Owner/$Repo :: $($payload.name)"

    if (-not $DryRun) {
        & gh api `
            --method POST `
            -H "Accept: application/vnd.github+json" `
            -H "X-GitHub-Api-Version: $ApiVersion" `
            "/repos/$Owner/$Repo/rulesets" `
            --input $path

        if ($LASTEXITCODE -ne 0) {
            throw "Failed creating ruleset '$($payload.name)' in $Owner/$Repo."
        }
    }
}

function Test-RepositoryAccess {
    param([Parameter(Mandatory)][string]$Repo)

    try {
        $repo = Invoke-GhApiJson -Arguments @(
            "--method", "GET",
            "/repos/$Owner/$Repo"
        )

        return $null -ne $repo
    }
    catch {
        Write-Warning "Skipping inaccessible repository: $Owner/$Repo"
        return $false
    }
}

Assert-Command "gh"

& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run: gh auth login"
}

if ($DiscoverOwnedRepositories) {
    $Repositories = Get-OwnedRepositories -ExpectedOwner $Owner
}

if (-not $Repositories -or $Repositories.Count -eq 0) {
    throw "No repositories selected."
}

$ruleFiles = @(
    "all-branches.json",
    "main.json",
    "release.json",
    "tags-v.json",
    "tag-v2.0.0.json"
)

Write-Host "Owner: $Owner"
Write-Host "Repositories: $($Repositories -join ', ')"
Write-Host "DryRun: $DryRun"

foreach ($repo in ($Repositories | Sort-Object -Unique)) {
    if (-not (Test-RepositoryAccess -Repo $repo)) {
        continue
    }

    Write-Host ""
    Write-Host "=== $Owner/$repo ==="

    foreach ($ruleFile in $ruleFiles) {
        Set-RepositoryRuleset -Repo $repo -File $ruleFile
    }
}

Write-Host ""
Write-Host "Ruleset synchronization finished."
Write-Host "Verify each repository under Settings -> Rules -> Rulesets."


if (-not $DryRun -and -not $SkipVerification) {
    $csv = ($Repositories -join ",")
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy","Bypass",
        "-File",(Join-Path $PSScriptRoot "verify-github-rulesets.ps1"),
        "-Owner",$Owner,
        "-RepositoriesCsv",$csv
    )

    if ($DiscoverOwnedRepositories) {
        $args += "-DiscoverOwnedRepositories"
    }

    & powershell.exe @args

    if ($LASTEXITCODE -ne 0) {
        throw "Post-deployment ruleset verification failed."
    }
}