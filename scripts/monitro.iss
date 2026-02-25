[Setup]
AppName=Monitro
AppVersion=1.2.0
AppPublisher=Chuck Talk / Nordheim Online
DefaultDirName={autopf}\Monitro
DefaultGroupName=Monitro
OutputBaseFilename=Monitro_1.2.0_Windows_Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\backend\monitro_collector.exe"; DestDir: "{app}\backend"; Flags: ignoreversion

[Icons]
Name: "{group}\Monitro"; Filename: "{app}\monitro.exe"
Name: "{commondesktop}\Monitro"; Filename: "{app}\monitro.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"
