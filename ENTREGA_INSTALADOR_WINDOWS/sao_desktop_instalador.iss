#define MyAppName "SAO Desktop"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "SAO"
#define MyAppExeName "sao_desktop.exe"
#define MyAppId "SAODesktop"
#define MySourceDir "..\desktop_flutter\sao_desktop\build\windows\x64\runner\Release"
#define MyOutputDir "..\desktop_flutter\sao_desktop\build\windows\installer"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\SAO Desktop
DefaultGroupName=SAO Desktop
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#MyOutputDir}
OutputBaseFilename=SAO_Desktop_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\desktop_flutter\sao_desktop\windows\runner\resources\app_icon.ico

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SAO Desktop"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\SAO Desktop"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir SAO Desktop"; Flags: nowait postinstall skipifsilent
