[Setup]
AppName=Coda Music
AppVersion=3.3.0
AppPublisher=0xnish
DefaultDirName={autopf}\Coda Music
DefaultGroupName=Coda Music
OutputDir=..\release
OutputBaseFilename=Coda Music v3.3.0 Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=icons\app_icon.ico
UninstallDisplayIcon={app}\coda-music.exe
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "build\windows\x64\runner\Release\coda-music.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Coda Music"; Filename: "{app}\coda-music.exe"
Name: "{group}\Uninstall Coda Music"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Coda Music"; Filename: "{app}\coda-music.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: checkedonce

[Run]
Filename: "{app}\coda-music.exe"; Description: "Launch Coda Music"; Flags: nowait postinstall skipifsilent
