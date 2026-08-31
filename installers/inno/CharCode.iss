#define MyAppName "Char-code 2.0"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "D-o-M-Pl"

[Setup]
AppId={{9C3623E9-BB69-4F31-91F4-BEA820D71C6D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Char-code
DefaultGroupName=Char-code
ArchitecturesAllowed=x86compatible x64compatible arm64
ArchitecturesInstallIn64BitMode=x64compatible arm64
OutputDir=..\output
OutputBaseFilename=CharCode-Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=lowest
WizardStyle=modern

[Files]
Source: "..\..\scripts\windows-launch.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "..\..\docker-compose.windows.yml"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Char-code"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\windows-launch.ps1"" -Mode auto"; WorkingDir: "{app}"
Name: "{autodesktop}\Char-code"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\windows-launch.ps1"" -Mode auto"; WorkingDir: "{app}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Utwórz skrót na pulpicie"

[Run]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\windows-launch.ps1"" -Mode audit"; Description: "Sprawdź środowisko Char-code"; Flags: postinstall nowait skipifsilent
