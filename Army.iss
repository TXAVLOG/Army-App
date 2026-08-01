; ============================================================
; Inno Setup Script - Army
; Tác giả: TXA TEAM
; ============================================================

#define MyAppName "Army"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "TXA TEAM"
#define MyAppURL "https://army.web.app"
#define MyAppExeName "army.exe"
#define MyAppIcon "windows\runner\resources\app_icon.ico"
#define BuildDir "build\windows\x64\runner\Release"

[Setup]
AppId={{C5A7E9B1-4F2D-4E8A-8C3B-1F6E9A2D4B5C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=production
OutputBaseFilename=Army Setup
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Installer
VersionInfoTextVersion={#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
CloseApplications=no
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; === Main Executable ===
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; === Flutter Engine & Plugin DLLs ===
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; === ICU Data ===
Source: "{#BuildDir}\data\icudtl.dat"; DestDir: "{app}\data"; Flags: ignoreversion

; === Flutter Assets ===
Source: "{#BuildDir}\data\flutter_assets\AssetManifest.bin"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion
Source: "{#BuildDir}\data\flutter_assets\FontManifest.json"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion
Source: "{#BuildDir}\data\flutter_assets\NativeAssetsManifest.json"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion
Source: "{#BuildDir}\data\flutter_assets\NOTICES.Z"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion

; === AOT Compiled Dart ===
Source: "{#BuildDir}\data\app.so"; DestDir: "{app}\data"; Flags: ignoreversion

; === App Assets ===
Source: "{#BuildDir}\data\flutter_assets\assets\*"; DestDir: "{app}\data\flutter_assets\assets"; Flags: ignoreversion recursesubdirs createallsubdirs

; === Fonts ===
Source: "{#BuildDir}\data\flutter_assets\fonts\*"; DestDir: "{app}\data\flutter_assets\fonts"; Flags: ignoreversion recursesubdirs createallsubdirs

; === Packages ===
Source: "{#BuildDir}\data\flutter_assets\packages\*"; DestDir: "{app}\data\flutter_assets\packages"; Flags: ignoreversion recursesubdirs createallsubdirs

; === Shaders ===
Source: "{#BuildDir}\data\flutter_assets\shaders\*"; DestDir: "{app}\data\flutter_assets\shaders"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"

[Code]
const
  APP_EXE_NAME = 'army.exe';

function KillAppIfRunning(): Boolean;
var
  ResultCode: Integer;
begin
  Result := True;
  if Exec('taskkill', '/F /IM ' + APP_EXE_NAME, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Sleep(1000);
    Log('Killed ' + APP_EXE_NAME);
  end;
end;

function InitializeSetup(): Boolean;
begin
  KillAppIfRunning();
  Result := True;
end;

function InitializeUninstall(): Boolean;
begin
  KillAppIfRunning();
  Result := True;
end;
