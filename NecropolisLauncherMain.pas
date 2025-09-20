unit NecropolisLauncherMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  System.Generics.Collections, System.Generics.Defaults, Vcl.Samples.Spin,
  System.UITypes;

type
  TMainForm = class(TForm)
    Image1: TImage;
    ComboBox1: TComboBox;
    SaveAndPlayBtn: TButton;
    Label1: TLabel;
    Button1: TButton;
    VSync: TCheckBox;
    fullscreen: TCheckBox;
    anims: TCheckBox;
    debug: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure SaveAndPlayBtnClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    procedure LoadSettings;
    procedure SaveSettings;
  end;

var
  MainForm: TMainForm;

implementation

uses
  WinApi.ShellApi, System.AnsiStrings;

{$R *.dfm}

function GetSysDir: string;
var
  Buffer: array[0..MAX_PATH] of Char;
begin
  GetSystemDirectory(Buffer, MAX_PATH - 1);
  SetLength(Result, StrLen(Buffer));
  Result := Buffer;
end;

function BoolTo10(b: boolean): integer;
begin
  if b then
    result := 1
  else
    result := 0;
end;

{$REGION 'List display modes'}

type
  TDisplayMode = record
    Width: Integer;
    Height: Integer;
    Bits: Integer;
    function ToString: string;
  end;

function TDisplayMode.ToString: string;
begin
  Result := Format('%dx%dx%d', [Width, Height, Bits]);
end;

function GetPrimaryDeviceName: string;
var
  dd: TDisplayDevice;
  i: Integer;
begin
  Result := '';
  i := 0;
  ZeroMemory(@dd, SizeOf(dd));
  dd.cb := SizeOf(dd);
  while EnumDisplayDevices(nil, i, dd, 0) do
  begin
    if (dd.StateFlags and DISPLAY_DEVICE_PRIMARY_DEVICE) <> 0 then
      Exit(dd.DeviceName);
    Inc(i);
    ZeroMemory(@dd, SizeOf(dd));
    dd.cb := SizeOf(dd);
  end;
end;

function CompareDisplayModes(const A, B: TDisplayMode): Integer;
begin
  if A.Width <> B.Width then
    result := A.Width - B.Width
  else if A.Height <> B.Height then
    result := A.Height - B.Height
  else
    result := A.Bits - B.Bits;
end;

procedure ListDisplayModes(sl: TStrings);
var
  DevMode: TDevMode;
  ModeNum: Integer;
  ModesDict: TDictionary<string, TDisplayMode>;
  ModeRec: TDisplayMode;
  ModesList: TList<TDisplayMode>;
  Key: string;
  I: Integer;
  dn: string;
  pdn: PChar;
begin
  ModesDict := TDictionary<string, TDisplayMode>.Create;
  try
    ModeNum := 0;
    FillChar(DevMode, SizeOf(DevMode), 0);
    DevMode.dmSize := SizeOf(DevMode);

    dn := GetPrimaryDeviceName;
    if dn <> '' then
      pdn := PChar(dn)
    else
      pdn := nil;
    while EnumDisplaySettings(pdn, ModeNum, DevMode) do
    begin
      ModeRec.Width := DevMode.dmPelsWidth;
      ModeRec.Height := DevMode.dmPelsHeight;
      ModeRec.Bits := DevMode.dmBitsPerPel;

      if (ModeRec.Width = 0) or (ModeRec.Height = 0) then
      begin
        Inc(ModeNum);
        Continue;
      end;

      Key := Format('%dx%dx%d', [ModeRec.Width, ModeRec.Height, ModeRec.Bits]);
      if not ModesDict.ContainsKey(Key) then
        ModesDict.Add(Key, ModeRec);

      Inc(ModeNum);
    end;

    ModesList := TList<TDisplayMode>.Create;
    try
      for ModeRec in ModesDict.Values do
        ModesList.Add(ModeRec);

      ModesList.Sort(
        TComparer<TDisplayMode>.Construct(
          function(const L, R: TDisplayMode): Integer
          begin
            Result := CompareDisplayModes(L, R);
          end
        )
      );

      for I := 0 to ModesList.Count - 1 do
        sl.Add(ModesList[I].ToString);
    finally
      FreeAndNil(ModesList);
    end;
  finally
    FreeAndNil(ModesDict);
  end;
end;

{$ENDREGION}

procedure TMainForm.SaveAndPlayBtnClick(Sender: TObject);
resourcestring
  LNG_S_IsMissing = '%s is missing.';
begin
  SaveSettings;

  {$REGION 'Check for DirectX 9.0c'}
  // These two DLL files are required by DBProSetupDebug.dll (that is unpacked into the Temp directory)
  // For Necropolis, an error message shows that DBProSetupDebug.dll cannot be loaded (because DirectX DLL is missing)
  // Necropolis however, does not show any message and just don't start.
  // d3d9.dll is installed on Windows 10, but d3dx9_35.dll is not, unless the DirectX Runtime is installed.
  if not FileExists(IncludeTrailingPathDelimiter(GetSysDir) + 'd3d9.dll') or
     not FileExists(IncludeTrailingPathDelimiter(GetSysDir) + 'd3dx9_35.dll') then
  begin
    if MessageDlg('You need to install DirectX 9.0c in order to play this game. Download DirectX 9.0c now?', TMsgDlgType.mtInformation, mbYesNoCancel, 0) = mrYes then
      ShellExecute(0, 'open', 'https://github.com/danielmarschall/necropolis/releases', '', '', SW_NORMAL);
    Abort;
  end;
  {$ENDREGION}

  {$REGION 'Start the game'}

  if not FileExists('Necropolis.exe') then
    raise Exception.CreateFmt(LNG_S_IsMissing, ['Necropolis.exe']);
  ShellExecute(0, 'open', PChar('Necropolis.exe'), '', '', SW_NORMAL);
  // Close;

  {$ENDREGION}
end;

procedure TMainForm.SaveSettings;
var
  Parts: TArray<string>;
  S: string;
  tmp: DWORD;
  fs: TFileStream;
begin
  fs := TFileStream.Create('settings.dat', fmCreate);
  try
    S := ComboBox1.Text;
    Parts := S.Split(['x']);
    TryStrToInt(Parts[0], integer(tmp)); fs.WriteBuffer(tmp, SizeOf(tmp));
    TryStrToInt(Parts[1], integer(tmp)); fs.WriteBuffer(tmp, SizeOf(tmp));
    TryStrToInt(Parts[2], integer(tmp)); fs.WriteBuffer(tmp, SizeOf(tmp));
    tmp := BoolTo10(VSync.Checked);      fs.WriteBuffer(tmp, SizeOf(tmp));
    tmp := BoolTo10(fullscreen.Checked); fs.WriteBuffer(tmp, SizeOf(tmp));
    tmp := BoolTo10(anims.Checked);      fs.WriteBuffer(tmp, SizeOf(tmp));
    tmp := BoolTo10(debug.Checked);      fs.WriteBuffer(tmp, SizeOf(tmp));
  finally
    FreeAndNil(fs);
  end;
end;

procedure TMainForm.Button1Click(Sender: TObject);
begin
  DeleteFile('settings.dat');
  LoadSettings;
end;

procedure TMainForm.LoadSettings;
var
  Mode: TDisplayMode;
  idx: integer;
  tmp: DWORD;
  fs: TFileStream;
begin
  if FileExists('settings.dat') then
  begin
    fs := TFileStream.Create('settings.dat', fmOpenRead or fmShareDenyWrite);
    try
      fs.ReadBuffer(tmp, SizeOf(tmp)); Mode.Width  := tmp;
      fs.ReadBuffer(tmp, SizeOf(tmp)); Mode.Height := tmp;
      fs.ReadBuffer(tmp, SizeOf(tmp)); Mode.Bits   := tmp;
      fs.ReadBuffer(tmp, SizeOf(tmp)); VSync.Checked      := tmp <> 0;
      fs.ReadBuffer(tmp, SizeOf(tmp)); fullscreen.Checked := tmp <> 0;
      fs.ReadBuffer(tmp, SizeOf(tmp)); anims.Checked      := tmp <> 0;
      fs.ReadBuffer(tmp, SizeOf(tmp)); debug.Checked      := tmp <> 0;
    finally
      FreeAndNil(fs);
    end;
  end
  else
  begin
    // Keep default settings in sync between Necropolis.dba and NecropolisLauncherMain.pas
    Mode.Width  := 640;
    Mode.Height := 480;
    Mode.Bits   := 32;
    vsync.Checked      := true;
    fullscreen.Checked := false;
    anims.Checked      := true;
    debug.Checked      := false;
  end;

  idx := ComboBox1.Items.IndexOf(Mode.ToString);
  if idx = -1 then idx := 0;
  ComboBox1.ItemIndex := idx;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  SetCurrentDir(ExtractFilePath(ParamStr(0)));

  {$REGION 'List screen resolutions'}
  ComboBox1.Clear;
  ListDisplayModes(ComboBox1.Items);
  if ComboBox1.Items.Count = 0 then
  begin
    ComboBox1.Items.Add('640x480x16');
    ComboBox1.Items.Add('640x480x24');
    ComboBox1.Items.Add('640x480x32');
    ComboBox1.Items.Add('800x600x16');
    ComboBox1.Items.Add('800x600x24');
    ComboBox1.Items.Add('800x600x32');
    ComboBox1.Items.Add('1024x768x16');
    ComboBox1.Items.Add('1024x768x24');
    ComboBox1.Items.Add('1024x768x32');
    ComboBox1.Items.Add('1280x800x16');
    ComboBox1.Items.Add('1280x800x24');
    ComboBox1.Items.Add('1280x800x32');
    ComboBox1.Items.Add('1366x768x16');
    ComboBox1.Items.Add('1366x768x24');
    ComboBox1.Items.Add('1366x768x32');
    ComboBox1.Items.Add('1920x1080x16');
    ComboBox1.Items.Add('1920x1080x24');
    ComboBox1.Items.Add('1920x1080x32');
  end;
  {$ENDREGION}

  try
    LoadSettings;
  except
    DeleteFile('settings.dat');
    LoadSettings;
  end;
end;

end.
