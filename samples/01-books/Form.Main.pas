unit Form.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs, FireDAC.VCLUI.Wait,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB,
  FireDAC.Comp.DataSet, FireDAC.Comp.Client, Vcl.StdCtrls, Vcl.ExtCtrls,
  Data.Proxy.Book, Data.Mock.Book;

type
  TForm1 = class(TForm)
    FDConnection1: TFDConnection;
    FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink;
    Button1: TButton;
    ListBox1: TListBox;
    GroupBox1: TGroupBox;
    Splitter1: TSplitter;
    Button2: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
  private
    BookProxy: TBookProxy;
    InsideUnitTests: Boolean;
    procedure InitializeMoreExpensiveButtons(ABookProxy: TBookProxy);
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  Data.DataProxy, Data.DataProxy.Factory;

procedure TForm1.FormCreate(Sender: TObject);
var
  ds: TDataSet;
begin
  InitializeMoreExpensiveButtons(nil);
  // ----------------------------------
  InsideUnitTests := True;
  // ----------------------------------
  if InsideUnitTests then
  begin
    BookProxy := TBookProxy.Create(Self);
    ds := CreateMockTableBook(BookProxy);
    with BookProxy do
    begin
      ConnectWithDataSet(ds);
      Open;
    end;
  end
  else
  BookProxy := TDataProxyFactory.CreateAndOpenProxy(TBookProxy, Self,
    FDConnection1, 'SELECT ISBN, Title, Authors, Status, ' +
    'ReleseDate, Pages, Price, Currency, Imported, Description FROM Books')
    as TBookProxy;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  ListBox1.ItemIndex := -1;
  InitializeMoreExpensiveButtons(nil);
  ListBox1.Clear;
  BookProxy.ForEach(
    procedure
    begin
      ListBox1.Items.Add(BookProxy.ISBN.Value + ' ' + BookProxy.ToString);
    end);
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  Button2.Caption := Format('More expensive books = %d',
    [BookProxy.CountMoreExpensiveBooks]);
end;

procedure TForm1.ListBox1Click(Sender: TObject);
var
  s: string;
  ISBN: string;
begin
  if (ListBox1.ItemIndex >= 0) then
  begin
    s := ListBox1.Items[ListBox1.ItemIndex];
    ISBN := s.Substring(0, 14);
    BookProxy.LocateISBN(ISBN);
    Self.Caption := BookProxy.Title.Value;
    InitializeMoreExpensiveButtons(BookProxy);
  end;
end;

procedure TForm1.InitializeMoreExpensiveButtons(ABookProxy: TBookProxy);
begin
  Button2.Enabled := (ABookProxy <> nil);
  if ABookProxy = nil then
  begin
    Button2.Caption := 'Load books and select one of them'
  end
  else
  begin
    Button2.Caption := 'Count more expensive books then: ' +
      ABookProxy.Price.AsString + ' ' + BookProxy.Currency.Value;
  end;
end;

end.
