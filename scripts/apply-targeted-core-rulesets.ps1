ã~}sV¼å®[mº{Ïuç†ÜÑæús¶º÷‡^ó­# Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

[CmdletBinding()]
param(
    [string]$Owner = "D-o-M-Pl",
    [string[]]$Repositories = @(
        "cloud-billing-anomaly",
        "volunteer-platform",
        "Desing-Azure-AI-Architecy-governed-agent"
    ),
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ApiVersion = "2022-11-28"
$AllowedRepositories = @(
    "cloud-billing-anomaly",
    "volunteer-platform",
    "Desing-Azure-AI-Architecy-governed-agent"
)

$RequiredChecks = @{
    "cloud-billing-anomaly" = @("test-and-scan")
    "volunteer-platform" = @("build", "Analyze TypeScript")
    "Desing-Azure-AI-Architecy-governed-agent" = @()
}

function Invoke-GhJson {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $result = & gh api `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: $ApiVersion" `
        @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "gh api failed: $($Arguments -join ' ')"
    }

    $text = $result -join "`n"
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text | ConvertFrom-Json
}

function New-RefConditions {
    param([Parameter(Mandatory)][string[]]$Include, [string[]]$Exclude = @())
    return @{ ref_name = @{ include = $Include; exclude = $Exclude } }
}

function New-MainRuleset {
    param([Parameter(Mandatory)][string]$Repository)

    $rules = @(
        @{ type = "deletion" },
        @{ type = "non_fast_forward" },
        @{
            type = "pull_request"
            parameters = @{
                required_approving_review_count = 0
                dismiss_stale_reviews_on_push = $true
                require_code_owner_review = $false
                require_last_push_approval = $false
                required_review_thread_resolution = $true
            }
        }
    )

    $checks = @($RequiredChecks[$Repository])
    if ($checks.Count -gt 0) {
        $rules += @{
            type = "required_status_checks"
            parameters = @{
                strict_required_status_checks_policy = $true
                do_not_enforce_on_create = $false
                required_status_checks = @(
                    $checks | ForEach-Object { @{ context = $_ } }
                )
            }
        }
    }

    return @{
        name = "main-production-gate"
        target = "branch"
        enforcement = "active"
        bypass_actors = @()
        conditions = New-RefConditions -Include @("refs/heads/main")
        rules = $rules
    }
}

function Get-Rulesets {
    param([Parameter(Mandatory)][string]$Repository)
    return @(Invoke-GhJson @("--method", "GET", "/repos/$Owner/$Repository/rulesets?includes_parents=false&per_page=100"))
}

function Set-Ruleset {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][hashtable]$Payload
    )

    $existing = Get-Rulesets -Repository $Repository |
        Where-Object { $_.name -eq $Payload.name -and $_.source_type -eq "Repository" } |
        Select-Object -First 1

    $method = if ($existing) { "PUT" } else { "POST" }
    $endpoint = if ($existing) {
        "/repos/$Owner/$Repository/rulesets/$($existing.id)"
    } else {
        "/repos/$Owner/$Repository/rulesets"
    }

    Write-Host "$method $Owner/$Repository :: $($Payload.name)"
    if ($DryRun) { return }

    $temp = New-TemporaryFile
    try {
        $Payload | ConvertTo-Json -Depth 20 | Set-Content -Path $temp -Encoding utf8
        $null = Invoke-GhJson @("--method", $method, $endpoint, "--input", $temp.FullName)
    }
    finally {
        Remove-Item -LiteralPath $temp.FullName -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI 'gh' is required."
}

& gh auth status
if ($LASTEXITCODE -ne 0) { throw "GitHub CLI is not authenticated." }

foreach ($repository in ($Repositories | Sort-Object -Unique)) {
    if ($AllowedRepositories -notcontains $repository) {
        throw "Repository is outside the approved target list: $repository"
    }

    $null = Invoke-GhJson @("--method", "GET", "/repos/$Owner/$repository")

    $rulesets = @(
        @{
            name = "all-branches-immutable-history"
            target = "branch"
            enforcement = "active"
            bypass_actors = @()
            conditions = New-RefConditions -Include @("~ALL")
            rules = @(@{ type = "deletion" }, @{ type = "non_fast_forward" })
        },
        (New-MainRuleset -Repository $repository),
        @{
            name = "release-branches-production-gate"
            target = "branch"
            enforcement = "active"
            bypass_actors = @()
            conditions = New-RefConditions -Include @("refs/heads/release/*")
            rules = @(
                @{ type = "deletion" },
                @{ type = "non_fast_forward" },
                @{
                    type = "pull_request"
                    parameters = @{
                        required_approving_review_count = 0
                        dismiss_stale_reviews_on_push = $true
                        require_code_owner_review = $false
                        require_last_push_approval = $false
                        required_review_thread_resolution = $true
                    }
                }
            )
        },
        @{
            name = "immutable-version-tags"
            target = "tag"
            enforcement = "active"
            bypass_actors = @()
            conditions = New-RefConditions -Include @("refs/tags/v*") -Exclude @("refs/tags/v*-rc.*")
            rules = @(
                @{ type = "deletion" },
                @{ type = "update"; parameters = @{ update_allows_fetch_and_merge = $false } }
            )
        }
    )

    foreach ($ruleset in $rulesets) {
        Set-Ruleset -Repository $repository -Payload $ruleset
    }
}

if (-not $DryRun) {
    foreach ($repository in ($Repositories | Sort-Object -Unique)) {
        $activeNames = @(Get-Rulesets -Repository $repository |
            Where-Object { $_.enforcement -eq "active" } |
            ForEach-Object { $_.name })

        foreach ($expected in @(
            "all-branches-immutable-history",
            "main-production-gate",
            "release-branches-production-gate",
            "immutable-version-tags"
        )) {
            if ($activeNames -notcontains $expected) {
                throw "Verification failed: $repository is missing active '$expected'."
            }
        }
        Write-Host "PASS $repository :: four active core rulesets"
    }
}
