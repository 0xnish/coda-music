[Setup]
AppName=Coda Music
AppVersion=2.5.0
AppVerName=Coda Music 2.5.0
AppPublisher=coder-nishanth
AppPublisherURL=https://github.com/coder-nishanth/coda-music
DefaultDirName={autopf}\Coda Music
DefaultGroupName=Coda Music
UninstallDisplayIcon={app}\coda-music.exe
UninstallDisplayName=Coda Music
Compression=lzma2
SolidCompression=yes
OutputDir=..\installers
OutputBaseFilename=coda-music-Setup-2.5.0
SetupIconFile=runner\resources\app_icon.ico
VersionInfoVersion=2.5.0.0
VersionInfoCompany=coder-nishanth
VersionInfoDescription=Coda Music Installer
VersionInfoProductName=Coda Music
VersionInfoProductVersion=2.5.0
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Coda Music"; Filename: "{app}\coda-music.exe"; IconFilename: "{app}\coda-music.exe"
Name: "{group}\Uninstall Coda Music"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\coda-music.exe"; Description: "Launch Coda Music"; Flags: postinstall nowait skipifsilent
