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
  [ValidateSet("all","exe","msi")]
  [string]$Target = "all"
)

$ErrorActionPreference = "Stop"
$InstallerRoot = $PSScriptRoot
$Output = Join-Path $InstallerRoot "output"
New-Item -ItemType Directory -Force -Path $Output | Out-Null

function Find-Executable {
  param(
    [string[]]$Names,
    [string[]]$Candidates = @()
  )

  foreach ($name in $Names) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }

  foreach ($candidate in $Candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  return $null
}

if ($Target -in @("all","exe")) {
  $iscc = Find-Executable `
    -Names @("iscc.exe","iscc") `
    -Candidates @(
      "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
      "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
      "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
      "$env:ProgramFiles\Inno Setup 7\ISCC.exe"
    )

  if (-not $iscc) {
    throw "Inno Setup 6/7 is required to build CharCode-Setup.exe."
  }

  & $iscc (Join-Path $InstallerRoot "inno\CharCode.iss")
  if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup build failed."
  }
}

if ($Target -in @("all","msi")) {
  $wix = Find-Executable `
    -Names @("wix.exe","wix") `
    -Candidates @("$env:USERPROFILE\.dotnet\tools\wix.exe")

  if (-not $wix) {
    throw "WiX Toolset 5 is required to build CharCode.msi."
  }

  & $wix build `
    (Join-Path $InstallerRoot "wix\Package.wxs") `
    -o (Join-Path $Output "CharCode.msi")

  if ($LASTEXITCODE -ne 0) {
    throw "WiX MSI build failed."
  }
}