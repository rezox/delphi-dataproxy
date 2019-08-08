unit Comp.Proxy.CodeGenerator;

interface

uses
  Data.DB,
  System.Classes,
  System.Generics.Collections,
  System.SysUtils;

type
  EProxyGenError = class(Exception);

  TProxyCodeGenerator = class(TComponent)
  private
    Fields: TList<TField>;
    FDataSet: TDataSet;
    FCode: String;
    procedure FillFieldsFromDataSet(ds: TDataSet);
    procedure SetDataSet(const aDataSet: TDataSet);
    procedure SetCode(const aCode: String);
  protected
    procedure DoGenerateProxy(ds: TDataSet; const Code: TStrings);
  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
    property Code: String read FCode write SetCode;
    property DataSet: TDataSet read FDataSet write SetDataSet;
    procedure Generate;
  end;

implementation

uses
  Helper.TField,
  App.AppInfo;

resourcestring
  ErrDataSetIsRequired = 'DataSet is required to generate new proxy';
  ErrDataSetNotActive = 'DataSet have to be active!';

constructor TProxyCodeGenerator.Create(Owner: TComponent);
begin
  inherited;
  Fields := TList<TField>.Create();
end;

destructor TProxyCodeGenerator.Destroy;
begin
  Fields.Free;
  inherited;
end;

procedure TProxyCodeGenerator.FillFieldsFromDataSet(ds: TDataSet);
var
  i: integer;
begin
  Fields.Clear;
  for i := 0 to ds.Fields.Count - 1 do
    Fields.Add(ds.Fields[i]);
end;

procedure TProxyCodeGenerator.DoGenerateProxy(ds: TDataSet;
  const Code: TStrings);
var
  fld: TField;
begin
  FillFieldsFromDataSet(ds);
  Code.Add('// Generated by ' + TAppInfo.AppName + ' at ' +
    FormatDateTime('yyyy-mm-dd hh:nn', Now));
  Code.Add('uses');
  Code.Add('  Data.DB,');
  Code.Add('  Data.DataProxy;');
  Code.Add('');
  Code.Add('type');
  Code.Add('  T{ObjectName}Proxy = class(TDatasetProxy)');
  Code.Add('  private');
  for fld in Fields do
    Code.Add('    F' + fld.FieldName + ' :' + fld.ToClass.ClassName + ';');
  Code.Add('  protected');
  Code.Add('    procedure ConnectFields; override;');
  Code.Add('  public');
  for fld in Fields do
    Code.Add('    property ' + fld.FieldName + ' :' + fld.ToClass.ClassName +
      ' read F' + fld.FieldName + ';');
  Code.Add('    // this property should be hidden, but during migration can be usefull');
  Code.Add('    // property DataSet: TDataSet read FDataSet;');
  Code.Add('  end;');
  Code.Add('');
  Code.Add('implementation');
  Code.Add('');
  Code.Add('uses');
  Code.Add('  System.SysUtils,');
  Code.Add('  Database.Connector;');
  Code.Add('');
  Code.Add('procedure T{ObjectName}Proxy.ConnectFields;');
  Code.Add('begin');
  for fld in Fields do
    Code.Add('  F' + fld.FieldName + ' := FDataSet.FieldByName(' +
      QuotedStr(fld.FieldName) + ') as ' + fld.ToClass.ClassName + ';');
  Code.Add('end;');
end;

procedure TProxyCodeGenerator.Generate;
var
  CodeList: TStringList;
begin
  if DataSet = nil then
    raise EProxyGenError.Create(ErrDataSetIsRequired);
  if not DataSet.Active then
    raise EProxyGenError.Create(ErrDataSetNotActive);
  CodeList := TStringList.Create;
  try
    DoGenerateProxy(DataSet, CodeList);
    Code := CodeList.Text;
  finally
    CodeList.Free;
  end;
end;

procedure TProxyCodeGenerator.SetCode(const aCode: String);
begin
  FCode := aCode;
end;

procedure TProxyCodeGenerator.SetDataSet(const aDataSet: TDataSet);
begin
  FDataSet := aDataSet;
end;

end.
