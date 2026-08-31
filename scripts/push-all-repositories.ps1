# Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

# Copyright 2026 D-o-M-Pl
# Licensed under the Apache License, Version 2.0.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [string]$Owner = "D-o-M-Pl",
    [string]$Branch = "security/char-code-2-production-hardening",
    [string]$CommitMessage = "security: harden Char-code 2.0 production release",
    [string]$RepositoriesCsv = "Char-code,volunteer-platform,cloud-billing-anomaly,Desing-Azure-AI-Architecy-governed-agent",
    [switch]$DiscoverLocalRepositories,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required."
}

$workspace = (Resolve-Path $WorkspaceRoot).Path

$repositories = if ($DiscoverLocalRepositories) {
    Get-ChildItem $workspace -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName ".git") } |
        Select-Object -ExpandProperty Name
}
else {
    $RepositoriesCsv.Split(",") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
}

$failures = @()

foreach ($repo in ($repositories | Sort-Object -Unique)) {
    $repoPath = Join-Path $workspace $repo

    if (-not (Test-Path (Join-Path $repoPath ".git"))) {
        Write-Warning "Skipping missing local Git repository: $repoPath"
        continue
    }

    try {
        Push-Location $repoPath

        $origin = (& git remote get-url origin).Trim()
        if ($origin -notmatch "github\.com[:/]$([regex]::Escape($Owner))/$([regex]::Escape($repo))(\.git)?$") {
            throw "Unexpected origin '$origin'."
        }

        & git status --short
        if ($LASTEXITCODE -ne 0) { throw "git status failed." }

        if ($DryRun) {
            Write-Host "DRY RUN $repo :: switch $Branch Ôćĺ add Ôćĺ commit -s Ôćĺ push"
            continue
        }

        & git fetch origin --prune
        if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }

        $current = (& git branch --show-current).Trim()

        if ($current -ne $Branch) {
            & git show-ref --verify --quiet "refs/heads/$Branch"
            if ($LASTEXITCODE -eq 0) {
                & git switch $Branch
            }
            else {
                & git switch -c $Branch
            }

            if ($LASTEXITCODE -ne 0) { throw "git switch failed." }
        }

        & git add --all
        if ($LASTEXITCODE -ne 0) { throw "git add failed." }

        & git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) {
            & git commit -s -m $CommitMessage
            if ($LASTEXITCODE -ne 0) {
                throw "git commit failed. Verify user.name/user.email and DCO."
            }
        }
        else {
            Write-Host "No staged changes in $repo."
        }

        & git push --set-upstream origin $Branch
        if ($LASTEXITCODE -ne 0) { throw "git push failed." }

        Write-Host "PASS $repo"
    }
    catch {
        $failures += "$repo :: $($_.Exception.Message)"
        Write-Error $_ -ErrorAction Continue
    }
    finally {
        Pop-Location
    }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    $failures | ForEach-Object { Write-Host "- $_" }
    exit 1
}

Write-Host "ALL ACCESSIBLE LOCAL REPOSITORIES COMPLETED."