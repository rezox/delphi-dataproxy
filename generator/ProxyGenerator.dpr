program ProxyGenerator;

uses
  Vcl.Forms,
  Form.Main in 'Form.Main.pas' {FormMain},
  Dialog.SelectDefinition in 'Dialog.SelectDefinition.pas' {DialogSelectDefinition},
  DataModule.Main in 'DataModule.Main.pas' {DataModule1: TDataModule},
  Helper.TApplication in 'Helper.TApplication.pas',
  App.AppInfo in 'App.AppInfo.pas',
  Helper.TDBGrid in 'Helper.TDBGrid.pas',
  Dialog.QueryBuilder in 'Dialog.QueryBuilder.pas' {DialogQueryBuilder},
  Helper.TField in 'Helper.TField.pas',
  Comp.Generator.DataSetCode in 'Comp.Generator.DataSetCode.pas',
  Helper.TStrings in 'Helper.TStrings.pas',
  Command.GenerateProxy in 'Command.GenerateProxy.pas',
  Comp.Generator.ProxyCode in 'Comp.Generator.ProxyCode.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TDataModule1, DataModule1);
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
