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
param()

$ErrorActionPreference = "Stop"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Check([string]$Name, [string]$Status, [string]$Details) {
  $results.Add([PSCustomObject]@{ Check=$Name; Status=$Status; Details=$Details })
}

try {
  $d = Get-MpComputerStatus
  Add-Check "Defender" $(if ($d.RealTimeProtectionEnabled) {"PASS"} else {"FAIL"}) "Real-time protection"
} catch { Add-Check "Defender" "WARN" "Unavailable" }

try {
  $disabled = @(Get-NetFirewallProfile | Where-Object { -not $_.Enabled })
  Add-Check "Firewall" $(if ($disabled.Count -eq 0) {"PASS"} else {"FAIL"}) "Domain/Private/Public"
} catch { Add-Check "Firewall" "WARN" "Unavailable" }

try {
  $uac = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA).EnableLUA
  Add-Check "UAC" $(if ($uac -eq 1) {"PASS"} else {"FAIL"}) "User Account Control"
} catch { Add-Check "UAC" "WARN" "Unavailable" }

try {
  $smb = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
  Add-Check "SMBv1" $(if ($smb.State -eq "Enabled") {"FAIL"} else {"PASS"}) "Should remain disabled"
} catch { Add-Check "SMBv1" "WARN" "Unavailable" }

try {
  $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive
  Add-Check "BitLocker" $(if ($volume.ProtectionStatus -eq "On") {"PASS"} else {"WARN"}) $env:SystemDrive
} catch { Add-Check "BitLocker" "INFO" "Unavailable or unsupported edition" }

$results | Format-Table -AutoSize -Wrap

if (@($results | Where-Object Status -eq "FAIL").Count -gt 0) {
  exit 1
}