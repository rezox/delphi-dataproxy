﻿{ * ------------------------------------------------------------------------
  * ♥
  * ♥ DataSet to Delphi Code (create TFDMemTable with the data)
  * ♥
  * Component: TGenerateDataSetCode
  * Project: https://github.com/bogdanpolak/datasetToDelphiCode
  * ReleaseDate: ↓ see below in the component const section ↓
  * ReleaseVersion: ↓ see below in the component const section ↓
  * ------------------------------------------------------------------------ }

unit Comp.Generator.DataSetCode;

interface

uses
  System.Classes, System.Types, System.SysUtils,
  Data.DB,
  FireDAC.Comp.Client;

type
  TGenerateDataSetCode = class(TComponent)
  const
    // * --------------------------------------------------------------------
    // * Signature
    ReleaseDate = '2019.09.24';
    ReleaseVersion = '1.2';
    // * --------------------------------------------------------------------
    MaxLiteralLenght = 70;
  private
    FCodeWithStructue: TStrings;
    FCodeWithAppendData: TStrings;
    FDataSet: TDataSet;
    FHeader: TStrings;
    FFooter: TStrings;
    FIndentationText: String;
    procedure Guard;
    function GenCodeLineFieldDefAdd(fld: TField): string;
    function GenCodeLineSetFieldValue(fld: TField): string;
    procedure GenCodeCreateMockTableWithStructure(dataSet: TDataSet);
    procedure GenCodeAppendDataToMockTable(dataSet: TDataSet);
    function GetDataFieldPrecision(fld: TField): integer;
    function FormatLongStringLiterals(const Literal: string): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Execute;
    property dataSet: TDataSet read FDataSet write FDataSet;
    property CodeWithStructure: TStrings read FCodeWithStructue;
    property CodeWithAppendData: TStrings read FCodeWithAppendData;
    class function GenerateAsString(ds: TDataSet): string;
    class function GenerateAsArray(ds: TDataSet): TStringDynArray;
    property IndentationText: String read FIndentationText
      write FIndentationText;
  end;

implementation

uses
  System.Rtti, Helper.TStrings;

constructor TGenerateDataSetCode.Create(AOwner: TComponent);
begin
  inherited;
  FCodeWithStructue := TStringList.Create;
  FCodeWithAppendData := TStringList.Create;
  FHeader := TStringList.Create;
  FFooter := TStringList.Create;
  FIndentationText := '  ';
end;

destructor TGenerateDataSetCode.Destroy;
begin
  FCodeWithStructue.Free;
  FCodeWithAppendData.Free;
  FHeader.Free;
  FFooter.Free;
  inherited;
end;

function FieldTypeToString(ft: TFieldType): string;
begin
  Result := System.Rtti.TRttiEnumerationType.GetName(ft);
end;

function TGenerateDataSetCode.GetDataFieldPrecision(fld: TField): integer;
begin
  System.Assert((fld is TBCDField) or (fld is TFMTBCDField) or
    (fld is TFloatField));
  if fld is TBCDField then
    Result := (fld as TBCDField).Precision
  else if fld is TFMTBCDField then
    Result := (fld as TFMTBCDField).Precision
  else
    Result := (fld as TFloatField).Precision
end;

function TGenerateDataSetCode.GenCodeLineFieldDefAdd(fld: TField): string;
begin
  (*
    ---------------------------------------------------------------------------
    [Doc]
    TFieldType = (ftUnknown, ftString, ftSmallint, ftInteger, ftWord, // 0..4
    ftBoolean, ftFloat, ftCurrency, ftBCD, ftDate, ftTime, ftDateTime, // 5..11
    ftBytes, ftVarBytes, ftAutoInc, ftBlob, ftMemo, ftGraphic, ftFmtMemo, // 12..18
    ftParadoxOle, ftDBaseOle, ftTypedBinary, ftCursor, ftFixedChar, ftWideString, // 19..24
    ftLargeint, ftADT, ftArray, ftReference, ftDataSet, ftOraBlob, ftOraClob, // 25..31
    ftVariant, ftInterface, ftIDispatch, ftGuid, ftTimeStamp, ftFMTBcd, // 32..37
    ftFixedWideChar, ftWideMemo, ftOraTimeStamp, ftOraInterval, // 38..41
    ftLongWord, ftShortint, ftByte, ftExtended, ftConnection, ftParams, ftStream, //42..48
    ftTimeStampOffset, ftObject, ftSingle); //49..51
    ---------------------------------------------------------------------------
  *)
  if fld.DataType in [ftAutoInc, ftInteger, ftWord, ftSmallint, ftLargeint,
    ftBoolean, ftFloat, ftCurrency, ftDate, ftTime, ftDateTime] then
    Result := 'FieldDefs.Add(' + QuotedStr(fld.FieldName) + ', ' +
      FieldTypeToString(fld.DataType) + ');'
  else if (fld.DataType in [ftBCD, ftFMTBcd]) then
    Result := 'with FieldDefs.AddFieldDef do begin' + sLineBreak +
      IndentationText + '    ' +
      Format('Name := ''%s'';  DataType := %s;  Precision := %d;  Size := %d;',
      [fld.FieldName, FieldTypeToString(fld.DataType),
      GetDataFieldPrecision(fld), fld.Size]) + sLineBreak + IndentationText
      + '  end;'
  else if (fld.DataType in [ftString, ftWideString]) and (fld.Size > 9999) then
    Result := 'FieldDefs.Add(' + QuotedStr(fld.FieldName) + ', ' +
      FieldTypeToString(fld.DataType) + ', 100);'
  else if (fld.DataType in [ftString, ftWideString]) then
    Result := 'FieldDefs.Add(' + QuotedStr(fld.FieldName) + ', ' +
      FieldTypeToString(fld.DataType) + ', ' + fld.Size.ToString + ');'
  else
    Result := 'FieldDefs.Add(' + QuotedStr(fld.FieldName) + ', ' +
      FieldTypeToString(fld.DataType) + ', ' + fld.Size.ToString + ');';
end;

function FloatToCode(val: Extended): string;
begin
  Result := FloatToStr(val);
  Result := StringReplace(Result, ',', '.', []);
end;

function DateToCode(dt: TDateTime): string;
var
  y, m, d: word;
begin
  DecodeDate(dt, y, m, d);
  Result := Format('EncodeDate(%d,%d,%d)', [y, m, d]);
end;

function TimeToCode(dt: TDateTime): string;
var
  h, min, s, ms: word;
begin
  DecodeTime(dt, h, min, s, ms);
  Result := Format('EncodeTime(%d,%d,%d,%d)', [h, min, s, ms]);
end;

function DateTimeToCode(dt: TDateTime): string;
begin
  Result := DateToCode(dt);
  if Frac(dt) > 0 then
    Result := Result + '+' + TimeToCode(dt);
end;

function TGenerateDataSetCode.FormatLongStringLiterals(const Literal
  : string): string;
var
  s1: string;
  s2: string;
begin
  if Length(Literal) <= MaxLiteralLenght then
  begin
    Result := Literal
  end
  else
  begin
    s1 := Literal;
    s2 := sLineBreak;
    while s1 <> '' do
    begin
      if Length(s1) < MaxLiteralLenght then
      begin
        s2 := s2 + IndentationText + '    ' + s1;
        s1 := '';
      end
      else
      begin
        s2 := s2 + IndentationText + IndentationText + IndentationText +
          s1.Substring(0, MaxLiteralLenght - 1) + '''+' + sLineBreak;
        s1 := '''' + s1.Substring(MaxLiteralLenght - 1);
      end;
    end;
    Result := s2;
  end;
end;

function TGenerateDataSetCode.GenCodeLineSetFieldValue(fld: TField): string;
var
  sByNameValue: string;
begin
  Result := '';
  if not(fld.IsNull) then
  begin
    sByNameValue := 'FieldByName(' + QuotedStr(fld.FieldName) + ').Value';
    case fld.DataType of
      ftAutoInc, ftInteger, ftWord, ftSmallint, ftLargeint:
        Result := sByNameValue + ' := ' + fld.AsString + ';';
      ftBoolean:
        Result := sByNameValue + ' := ' + BoolToStr(fld.AsBoolean, true) + ';';
      ftFloat, ftCurrency, ftBCD, ftFMTBcd:
        Result := sByNameValue + ' := ' + FloatToCode(fld.AsExtended) + ';';
      ftDate:
        Result := sByNameValue + ' := ' + DateToCode(fld.AsDateTime) + ';';
      ftTime:
        Result := sByNameValue + ' := ' + TimeToCode(fld.AsDateTime) + ';';
      ftDateTime:
        Result := sByNameValue + ' := ' + DateTimeToCode(fld.AsDateTime) + ';';
      ftString, ftWideString:
        Result := sByNameValue + ' := ' + FormatLongStringLiterals
          (QuotedStr(fld.Value)) + ';';
    end;
  end;
end;

class function TGenerateDataSetCode.GenerateAsString(ds: TDataSet): string;
var
  gen: TGenerateDataSetCode;
begin
  gen := TGenerateDataSetCode.Create(nil);
  try
    gen.dataSet := ds;
    gen.Execute;
    Result := gen.CodeWithStructure.Text + sLineBreak + sLineBreak +
      gen.CodeWithAppendData.Text;
  finally
    gen.Free;
  end;
end;

class function TGenerateDataSetCode.GenerateAsArray(ds: TDataSet)
  : TStringDynArray;
var
  gen: TGenerateDataSetCode;
begin
  gen := TGenerateDataSetCode.Create(nil);
  try
    gen.dataSet := ds;
    gen.Execute;
    Result := gen.CodeWithStructure.ToStringDynArray + [sLineBreak, sLineBreak]
      + gen.CodeWithStructure.ToStringDynArray;
  finally
    gen.Free;
  end;
end;

procedure TGenerateDataSetCode.Guard;
begin
  Assert(dataSet <> nil, 'Property DataSet not assigned!');
end;

procedure TGenerateDataSetCode.GenCodeCreateMockTableWithStructure
  (dataSet: TDataSet);
var
  fld: TField;
begin
  with CodeWithStructure do
  begin
    Add(IndentationText + 'ds := TFDMemTable.Create(AOwner);');
    Add(IndentationText + 'with ds do');
    Add(IndentationText + 'begin');
    for fld in dataSet.Fields do
      Add(IndentationText + IndentationText + GenCodeLineFieldDefAdd(fld));
    Add(IndentationText + IndentationText + 'CreateDataSet;');
    Add(IndentationText + 'end;');
  end;
end;

procedure TGenerateDataSetCode.GenCodeAppendDataToMockTable(dataSet: TDataSet);
var
  fld: TField;
  s1: string;
begin
  CodeWithAppendData.Add('{$REGION ''Append data to MemTable''}');
  dataSet.DisableControls;
  dataSet.Open;
  dataSet.First;
  while not dataSet.Eof do
  begin
    with CodeWithAppendData do
    begin
      Add(IndentationText + 'with ds do');
      Add(IndentationText + 'begin');
      Add(IndentationText + IndentationText + 'Append;');
      for fld in dataSet.Fields do
      begin
        s1 := GenCodeLineSetFieldValue(fld);
        if s1 <> '' then
          Add(IndentationText + IndentationText + s1);
      end;
      Add(IndentationText + IndentationText + 'Post;');
      Add(IndentationText + 'end;');
    end;
    dataSet.Next;
  end;
  dataSet.EnableControls;
  CodeWithAppendData.Add('{$ENDREGION}');
end;

procedure TGenerateDataSetCode.Execute;
begin
  Guard;
  CodeWithStructure.Clear;
  CodeWithAppendData.Clear;
  GenCodeCreateMockTableWithStructure(dataSet);
  GenCodeAppendDataToMockTable(dataSet);
end;

end.
