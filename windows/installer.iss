[Setup]
AppName=Coda Music
AppVersion=3.3.1
AppVerName=Coda Music 3.3.1
AppPublisher=0xnish
AppPublisherURL=https://github.com/0xnish/coda-music
DefaultDirName={autopf}\Coda Music
DefaultGroupName=Coda Music
UninstallDisplayIcon={app}\coda-music.exe
UninstallDisplayName=Coda Music
Compression=lzma2
SolidCompression=yes
OutputDir=..\installers
OutputBaseFilename=coda-music-Setup-3.3.1
SetupIconFile=runner\resources\app_icon.ico
VersionInfoVersion=3.3.1.0
VersionInfoCompany=0xnish
VersionInfoDescription=Coda Music Installer
VersionInfoProductName=Coda Music
VersionInfoProductVersion=3.3.1
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Coda Music"; Filename: "{app}\coda-music.exe"; IconFilename: "{app}\coda-music.exe"
Name: "{group}\Uninstall Coda Music"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\coda-music.exe"; Description: "Launch Coda Music"; Flags: postinstall nowait skipifsilent
