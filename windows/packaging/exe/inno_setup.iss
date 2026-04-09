[Setup]
AppId=B9F6E402-0CAE-4045-BDE6-14BD6C39C4EA
AppVersion=1.12.1+26
AppPublisher=CloudBeatz
AppPublisherURL=https://cloudbeatz.web.app/
AppSupportURL=https://cloudbeatz.web.app/
AppUpdatesURL=https://github.com/AkashKumar-Behera/cloudbeatzdownload
DefaultDirName={autopf}\cloudbeatz
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=cloudbeatz-1.12.1
Compression=lzma
SolidCompression=yes
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
WizardStyle=modern
PrivilegesRequired=lowest
LicenseFile=..\..\LICENSE
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\CloudBeatz.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\CloudBeatz"; Filename: "{app}\CloudBeatz.exe"
Name: "{autodesktop}\CloudBeatz"; Filename: "{app}\CloudBeatz.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\CloudBeatz.exe"; Description: "{cm:LaunchProgram,{#StringChange('Cloud Beatz', '&', '&&')}}"; Flags: nowait postinstall skipifsilent
