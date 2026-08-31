# Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

# Copyright 2026 D-o-M-Pl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
[CmdletBinding()]
param(
  [ValidateSet("auto", "local", "web", "audit")]
  [string]$Mode = "auto",
  [string]$HostedUrl = $env:CHAR_CODE_HOSTED_URL,
  [switch]$Build
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Has([string]$Name) {
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

$os = Get-CimInstance Win32_OperatingSystem
$is64 = [Environment]::Is64BitOperatingSystem
$isWin11 = [int]$os.BuildNumber -ge 22000

Write-Host "Char-code 2.0"
Write-Host "System: $($os.Caption), build $($os.BuildNumber)"
Write-Host "64-bit OS: $is64"

if ($isWin11 -and -not $is64) {
  throw "Windows 11 32-bit nie istnieje jako wspierana konfiguracja."
}

if ($Mode -eq "audit") {
  Write-Host "Node: $(Has node)"
  Write-Host "WSL: $(Has wsl.exe)"
  Write-Host "Docker: $(Has docker)"
  Write-Host "Tryb Web/PWA: dost─Öpny"
  exit 0
}

function Open-Web {
  if ([string]::IsNullOrWhiteSpace($HostedUrl)) {
    throw "Ustaw CHAR_CODE_HOSTED_URL."
  }
  $uri = [Uri]$HostedUrl
  if ($uri.Scheme -ne "https" -and $uri.Host -notin @("localhost","127.0.0.1")) {
    throw "Wersja hostowana musi u┼╝ywa─ç HTTPS."
  }
  Start-Process $HostedUrl
}

function Start-Local {
  if (-not $is64) {
    throw "Windows x86 u┼╝ywa wy┼é─ůcznie wersji Web/PWA."
  }
  if (-not (Has docker)) {
    throw "Brak Docker Desktop."
  }
  & docker version *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop nie odpowiada."
  }

  Push-Location $RepoRoot
  try {
    $args = @("-f","docker-compose.windows.yml")
    if ($Build) {
      & docker compose @args build --pull
      if ($LASTEXITCODE -ne 0) { throw "Docker build failed." }
    }
    & docker compose @args up --remove-orphans
    if ($LASTEXITCODE -ne 0) { throw "Docker Compose failed." }
  }
  finally {
    Pop-Location
  }
}

if ($Mode -eq "web") { Open-Web; exit 0 }
if ($Mode -eq "local") { Start-Local; exit 0 }
if (-not $is64) { Open-Web } else { Start-Local }