unit Form.Main;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, System.Actions,
  System.StrUtils, System.Types,
  Data.DB,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Grids,
  Vcl.DBGrids, Vcl.ComCtrls, Vcl.ActnList, Vcl.StdCtrls, Vcl.Menus,
  Command.GenerateProxy;

type
  TFormMain = class(TForm)
    grbxAppCommands: TGroupBox;
    Button1: TButton;
    PageControl1: TPageControl;
    tshDataSet: TTabSheet;
    tshProxyCode: TTabSheet;
    GridPanel2: TGridPanel;
    btnGenerateDAO: TButton;
    DBGrid1: TDBGrid;
    tmrReady: TTimer;
    mmProxyCode: TMemo;
    Label1: TLabel;
    Splitter1: TSplitter;
    Button2: TButton;
    DataSource1: TDataSource;
    // --------------------------------------------------------------------
    ActionList1: TActionList;
    actGenerateProxy: TAction;
    actConnect: TAction;
    actSelectConnectionDef: TAction;
    actExecSQL: TAction;
    actQueryBuilder: TAction;
    actChangeProxyName: TAction;
    // --------------------------------------------------------------------
    Panel1: TPanel;
    Label2: TLabel;
    mmSqlStatement: TMemo;
    GridPanel1: TGridPanel;
    pmnRecentConnections: TPopupMenu;
    Button3: TButton;
    Label3: TLabel;
    Button4: TButton;
    GroupBox1: TGroupBox;
    edtProxyName: TEdit;
    Label4: TLabel;
    // --------------------------------------------------------------------
    // Startup
    procedure FormCreate(Sender: TObject);
    procedure tmrReadyTimer(Sender: TObject);
    // --------------------------------------------------------------------
    // Action events
    procedure actSelectConnectionDefExecute(Sender: TObject);
    procedure actConnectExecute(Sender: TObject);
    procedure actExecSQLExecute(Sender: TObject);
    procedure actGenerateProxyExecute(Sender: TObject);
    procedure actQueryBuilderExecute(Sender: TObject);
    procedure actChangeProxyNameExecute(Sender: TObject);
    // --------------------------------------------------------------------
    procedure edtProxyNameKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    cmdProxyGenerator: TProxyGeneratorCommand;
    CurrentConnDefName: string;
    FMainDataSet: TDataSet;
    ConnectionMruList: string;
    FCurrentProxyName: string;
    FGeneratedCode: string;
    procedure InitializeControls;
    procedure UpdateActionEnable;
    procedure StoreConnectionDefinitionInMRUList(const ConnDefName: string);
    function GetConnectionDefinitionMRUList: TStringDynArray;
    procedure FillConnectionMRUPopupMenu;
    procedure PopupMenuRecentConnectionsItemClick(Sender: TObject);
    function UpdateMRUList(const ConnDefName: string): boolean;
    procedure SetCurrentConnectionDefinition(ConnDefName: string);
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

uses
  System.Win.Registry,
  Helper.TApplication, Helper.TDBGrid,
  App.AppInfo,
  DataModule.Main,
  Dialog.SelectDefinition, Dialog.QueryBuilder;

const
  AUTOOPEN_Application = False;
  AppRegistryKey = 'Software\DelphiPower\DataSetProxyGenerator';


  // --------------------------------------------------------------------------
  // Connection Definition MRU List
  // * Storage level
  // * Domain level
  // --------------------------------------------------------------------------
  // TODO: Extract because of SOLID #1: SRP (Single Responsibility)

function TFormMain.UpdateMRUList(const ConnDefName: string): boolean;
var
  list: System.Types.TStringDynArray;
  len: Integer;
  i: Integer;
  j: Integer;
begin
  // TODO: Separate mru-list as an independent component
  if ConnectionMruList = '' then
  begin
    ConnectionMruList := ConnDefName;
    Result := True;
  end
  else
  begin
    list := System.StrUtils.SplitString(ConnectionMruList, ',');
    len := Length(list);
    if (list[0] = ConnDefName) then
      Result := False
    else
    begin
      i := 1;
      while (i < len) and (list[i] <> ConnDefName) do
        inc(i);
      if i < len then
      begin
        for j := i + 1 to len - 1 do
          list[j - 1] := list[j - 1];
        SetLength(list, len - 1);
      end;
      ConnectionMruList := ConnDefName + ',' + String.Join(',', list);
      Result := True;
    end;
  end;
end;

procedure TFormMain.SetCurrentConnectionDefinition(ConnDefName: string);
var
  IsSelectedDef: boolean;
begin
  if (CurrentConnDefName = '') or (ConnDefName <> '') then
  begin
    CurrentConnDefName := ConnDefName;
    IsSelectedDef := (CurrentConnDefName <> '');
    if IsSelectedDef then
      actSelectConnectionDef.Caption := 'Definition: ' + CurrentConnDefName
    else
      actSelectConnectionDef.Caption := 'Select Connection';
    actConnect.Enabled := IsSelectedDef;
  end;
end;

procedure TFormMain.StoreConnectionDefinitionInMRUList
  (const ConnDefName: string);
var
  reg: TRegistry;
begin
  if UpdateMRUList(ConnDefName) then
  begin
    // ----
    // Store MRU list
    // ----
    reg := TRegistry.Create(KEY_READ);
    try
      reg.RootKey := HKEY_CURRENT_USER;
      if not reg.KeyExists(AppRegistryKey) then
      begin
        reg.CreateKey(AppRegistryKey);
        // TODO: Check if CreateKey = True and log error
      end;
      reg.Access := KEY_WRITE;
      if reg.OpenKey(AppRegistryKey, False) then
      begin
        reg.WriteString('ConnectionMruList', ConnectionMruList);
      end;
    finally
      reg.Free;
    end;
  end;
end;

function TFormMain.GetConnectionDefinitionMRUList: TStringDynArray;
var
  reg: TRegistry;
begin
  if ConnectionMruList = '' then
  begin
    reg := TRegistry.Create(KEY_READ);
    try
      reg.RootKey := HKEY_CURRENT_USER;
      if reg.KeyExists(AppRegistryKey) then
        if reg.OpenKey(AppRegistryKey, False) then
          ConnectionMruList := reg.ReadString('ConnectionMruList');
    finally
      reg.Free;
    end;
  end;
  if ConnectionMruList = '' then
    Result := nil
  else
    Result := System.StrUtils.SplitString(ConnectionMruList, ',')
end;

procedure TFormMain.FillConnectionMRUPopupMenu;
var
  list: System.Types.TStringDynArray;
  i: Integer;
  item: TMenuItem;
begin
  list := GetConnectionDefinitionMRUList;
  pmnRecentConnections.Items.Clear;
  for i := 0 to High(list) do
  begin
    item := TMenuItem.Create(pmnRecentConnections);
    with item do
    begin
      Caption := list[i];
      Tag := i;
      OnClick := PopupMenuRecentConnectionsItemClick;
    end;
    pmnRecentConnections.Items.Add(item);
  end;
end;

procedure TFormMain.PopupMenuRecentConnectionsItemClick(Sender: TObject);
var
  ConnDefName: string;
begin
  if Sender is TMenuItem then
  begin
    ConnDefName := Vcl.Menus.StripHotkey((Sender as TMenuItem).Caption);
    if DataModule1.IsConnected then
      actConnect.Execute;
    SetCurrentConnectionDefinition(ConnDefName);
  end;
end;


// --------------------------------------------------------------------------
// Application start-up
// --------------------------------------------------------------------------

procedure TFormMain.InitializeControls;
begin
  PageControl1.ActivePageIndex := 0;
  PageControl1.Align := alClient;
  mmProxyCode.Align := alClient;
  mmSqlStatement.Clear;
  mmProxyCode.Clear;
  Self.Caption := TAppInfo.AppName + ' - ' + TAppInfo.Version;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  // -------------------------------------------------------
  FCurrentProxyName := TProxyGeneratorCommand.BaseProxyName;
  edtProxyName.Text := FCurrentProxyName;
  FGeneratedCode := '';
  // -------------------------------------------------------
  cmdProxyGenerator := TProxyGeneratorCommand.Create(Self);
  FMainDataSet := DataModule1.GetMainDataQuery;
  DataSource1.DataSet := FMainDataSet;
  InitializeControls;
  // -------------------------------------------------------
  // Inititialize actions
  // -------------------------------------------------------
  if Application.InDeveloperMode then
    ReportMemoryLeaksOnShutdown := True;
  actConnect.Enabled := False;
  UpdateActionEnable;
end;

procedure TFormMain.tmrReadyTimer(Sender: TObject);
begin
  tmrReady.Enabled := False;
  FillConnectionMRUPopupMenu;
  if Application.InDeveloperMode and AUTOOPEN_Application then
  begin
    CurrentConnDefName := 'SQLite_Demo';
    actSelectConnectionDef.Caption := 'Definition: ' + CurrentConnDefName;
    actConnect.Enabled := True;
    actConnect.Execute;
    actQueryBuilder.Execute;
    // actExecSQL.Execute;
    // actGenerateProxy.Execute;
  end;
end;

procedure TFormMain.UpdateActionEnable();
var
  IsConnected: boolean;
  IsDataSetActive: boolean;
begin
  IsConnected := DataModule1.IsConnected;
  IsDataSetActive := FMainDataSet.Active;
  actQueryBuilder.Enabled := IsConnected;
  actExecSQL.Enabled := IsConnected;
  actGenerateProxy.Enabled := IsDataSetActive;
end;


// --------------------------------------------------------------------------
// Action events
// --------------------------------------------------------------------------

procedure TFormMain.actSelectConnectionDefExecute(Sender: TObject);
begin
  if TDialogSelectDefinition.Execute then
  begin
    if DataModule1.IsConnected then
      actConnect.Execute;
    SetCurrentConnectionDefinition(TDialogSelectDefinition.ConnectionDef);
  end;
end;

procedure TFormMain.edtProxyNameKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Shift = [ssCtrl]) and (Key = VK_RETURN) then
    actChangeProxyName.Execute;
end;

procedure TFormMain.actConnectExecute(Sender: TObject);
begin
  if not DataModule1.IsConnected then
  begin
    DataModule1.OpenConnection(CurrentConnDefName);
    // TODO: misleading method name (2 responsibilities)
    // * AddOrUpdateConnection_MruList = UpdateMRUList
    // * WriteConnectionMruList
    StoreConnectionDefinitionInMRUList(CurrentConnDefName);
    FillConnectionMRUPopupMenu;
    actConnect.Caption := 'Disconnect';
  end
  else
  begin
    DataModule1.CloseConnection;
    actConnect.Caption := 'Connect';
    PageControl1.ActivePageIndex := 0;
    mmProxyCode.Clear;
  end;
  UpdateActionEnable();
end;

procedure TFormMain.actExecSQLExecute(Sender: TObject);
begin
  DataModule1.ExecuteSQL(mmSqlStatement.Text);
  Self.UpdateActionEnable;
  DBGrid1.AutoSizeColumns();
end;

procedure TFormMain.actGenerateProxyExecute(Sender: TObject);
begin
  PageControl1.ActivePage := tshProxyCode;
  FGeneratedCode := cmdProxyGenerator.Execute(DataSource1.DataSet);
  mmProxyCode.Lines.Text := FGeneratedCode;
  FCurrentProxyName := TProxyGeneratorCommand.BaseProxyName;
  edtProxyName.Text := FCurrentProxyName;
end;

procedure TFormMain.actQueryBuilderExecute(Sender: TObject);
var
  sql: string;
begin
  sql := TDialogQueryBuilder.Execute;
  if sql <> '' then
    mmSqlStatement.Text := sql;
end;

procedure TFormMain.actChangeProxyNameExecute(Sender: TObject);
begin
  if edtProxyName.Text = '' then
    edtProxyName.Text := TProxyGeneratorCommand.BaseProxyName;
  if (FGeneratedCode <> '') and (edtProxyName.Text <> FCurrentProxyName) then
  begin
    mmProxyCode.Lines.Text := StringReplace(FGeneratedCode,
      TProxyGeneratorCommand.BaseProxyName, edtProxyName.Text, [rfReplaceAll]);
    FCurrentProxyName := edtProxyName.Text;
  end;
end;

// --------------------------------------------------------------------------
// --------------------------------------------------------------------------

end.
