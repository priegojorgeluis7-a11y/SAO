#define MyAppName "SAO Campo"
#define MyAppVersion "2.0.3"
#define MyAppPublisher "SAO"
#define MyAppExeName "sao_windows.exe"
#define MyAppId "SAOCampo"
#define MySourceDir "..\frontend_flutter\sao_windows\build\windows\x64\runner\Release"
#define MyOutputDir "..\frontend_flutter\sao_windows\build\windows\installer"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\SAO Campo
DefaultGroupName=SAO Campo
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#MyOutputDir}
OutputBaseFilename=SAO_Campo_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\frontend_flutter\sao_windows\windows\runner\resources\app_icon.ico

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SAO Campo"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\SAO Campo"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir SAO Campo"; Flags: nowait postinstall skipifsilent
