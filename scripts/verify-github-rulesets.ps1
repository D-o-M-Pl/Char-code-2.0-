# Copyright 2026 D-o-M-Pl
# Licensed under the Apache License, Version 2.0.

[CmdletBinding()]
param(
    [string]$Owner = "D-o-M-Pl",
    [string]$RepositoriesCsv = "volunteer-platform,Char-code,cloud-billing-anomaly,Desing-Azure-AI-Architecy-governed-agent",
    [switch]$DiscoverOwnedRepositories
)

$ErrorActionPreference = "Stop"
$ApiVersion = "2026-03-10"

function Invoke-GhJson {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $output = & gh api `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: $ApiVersion" `
        @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "gh api failed: $($Arguments -join ' ')"
    }

    $text = ($output -join "`n")
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text | ConvertFrom-Json
}

function Get-OwnedRepositories {
    $repos = @()
    $page = 1

    while ($true) {
        $batch = Invoke-GhJson @(
            "--method","GET",
            "/user/repos?affiliation=owner&per_page=100&page=$page"
        )

        if (-not $batch -or @($batch).Count -eq 0) { break }

        foreach ($repo in @($batch)) {
            if ($repo.owner.login -eq $Owner -and -not $repo.archived) {
                $repos += $repo.name
            }
        }

        if (@($batch).Count -lt 100) { break }
        $page += 1
    }

    return $repos | Sort-Object -Unique
}

function Get-FullRuleset {
    param([string]$Repo, [int64]$Id)

    return Invoke-GhJson @(
        "--method","GET",
        "/repos/$Owner/$Repo/rulesets/$Id"
    )
}

function Assert-Ruleset {
    param(
        [string]$Repo,
        [object[]]$Summaries,
        [string]$Name,
        [string]$Target,
        [string]$Include,
        [string[]]$RuleTypes
    )

    $summary = @($Summaries) |
        Where-Object { $_.name -eq $Name -and $_.source_type -eq "Repository" } |
        Select-Object -First 1

    if (-not $summary) { throw "Missing ruleset '$Name'." }
    if ($summary.enforcement -ne "active") { throw "Ruleset '$Name' is not active." }

    $full = Get-FullRuleset -Repo $Repo -Id $summary.id

    if ($full.target -ne $Target) {
        throw "Ruleset '$Name' target '$($full.target)' != '$Target'."
    }

    if (@($full.conditions.ref_name.include) -notcontains $Include) {
        throw "Ruleset '$Name' missing include '$Include'."
    }

    $actualTypes = @($full.rules).type
    foreach ($type in $RuleTypes) {
        if ($actualTypes -notcontains $type) {
            throw "Ruleset '$Name' missing rule '$type'."
        }
    }

    if (@($full.bypass_actors).Count -ne 0) {
        throw "Ruleset '$Name' contains bypass actors."
    }

    Write-Host "PASS $Repo :: $Name"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI 'gh' is required."
}

& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated."
}

$repositories = if ($DiscoverOwnedRepositories) {
    Get-OwnedRepositories
}
else {
    $RepositoriesCsv.Split(",") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
}

$expected = @(
    @{ Name="all-branches-immutable-history"; Target="branch"; Include="~ALL"; Rules=@("deletion","non_fast_forward") },
    @{ Name="main-production-gate"; Target="branch"; Include="refs/heads/main"; Rules=@("deletion","non_fast_forward","pull_request","required_status_checks") },
    @{ Name="release-branches-production-gate"; Target="branch"; Include="refs/heads/release/*"; Rules=@("deletion","non_fast_forward","pull_request","required_status_checks") },
    @{ Name="immutable-version-tags"; Target="tag"; Include="refs/tags/v*"; Rules=@("deletion","update") },
    @{ Name="immutable-v2.0.0-tag"; Target="tag"; Include="refs/tags/v2.0.0"; Rules=@("deletion","update") }
)

$failures = @()

foreach ($repo in ($repositories | Sort-Object -Unique)) {
    try {
        $null = Invoke-GhJson @("--method","GET","/repos/$Owner/$repo")

        $summaries = Invoke-GhJson @(
            "--method","GET",
            "/repos/$Owner/$repo/rulesets?includes_parents=false&per_page=100"
        )

        foreach ($item in $expected) {
            Assert-Ruleset `
                -Repo $repo `
                -Summaries @($summaries) `
                -Name $item.Name `
                -Target $item.Target `
                -Include $item.Include `
                -RuleTypes $item.Rules
        }

        $mainRules = Invoke-GhJson @(
            "--method","GET",
            "/repos/$Owner/$repo/rules/branches/main"
        )

        $mainTypes = @($mainRules).type
        foreach ($required in @("deletion","non_fast_forward","pull_request","required_status_checks")) {
            if ($mainTypes -notcontains $required) {
                throw "Active main rules missing '$required'."
            }
        }

        Write-Host "PASS $repo :: active main rules"
    }
    catch {
        $failures += "$Owner/$repo :: $($_.Exception.Message)"
        Write-Error $_ -ErrorAction Continue
    }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "RULESET VERIFICATION FAILED"
    $failures | ForEach-Object { Write-Host "- $_" }
    exit 1
}

Write-Host ""
Write-Host "ALL ACCESSIBLE REPOSITORIES ARE PROTECTED."
