unit example_main;

{ Hako Lazarus minimal demo form. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Hako, HakoComponent;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnRun: TButton;
    Hako1: THakoComponent;
    Memo1: TMemo;
    procedure btnRunClick(Sender: TObject);
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.btnRunClick(Sender: TObject);
var
  Users: THKCollection;
  Ref: THKDocumentRef;
  Doc, Got: THKDocument;
  Q: THKQuery;
begin
  Memo1.Lines.Clear;
  try
    if not Hako1.IsOpen then
      Hako1.Open;
    Memo1.Lines.Add('opened ' + Hako1.DatabasePath);

    Users := Hako1.Collection('users');
    try
      Doc := THKDocument.Create;
      try
        Doc.InsertStr('name', 'Alice').InsertInt('age', 32).InsertBool('active', True);
        Ref := Users.Doc('u1');
        try
          Ref.SetDoc(Doc);
        finally
          Ref.Free;
        end;
      finally
        Doc.Free;
      end;
      Memo1.Lines.Add('inserted u1');

      Ref := Users.Doc('u1');
      try
        Got := Ref.Get;
        try
          if Got <> nil then Memo1.Lines.Add('u1 -> ' + Got.ToJSON);
        finally
          Got.Free;
        end;
      finally
        Ref.Free;
      end;

      Q := Users.Query;
      try
        Memo1.Lines.Add('count(users) = ' + IntToStr(Q.Count));
      finally
        Q.Free;
      end;
    finally
      Users.Free;
    end;

    { NetSync + CloudSync are configured via the Object Inspector
      (NetSyncName / NetSyncRoomKey / NetSyncPort / CloudSync*) and started
      with one call each. Requires the net-sync/cloud-sync feature build. }
    // Hako1.StartNetSync;
    // Hako1.StartCloudSync;

    Memo1.Lines.Add('stats: ' + Hako1.GetStats);
    Memo1.Lines.Add('done');
  except
    on E: Exception do
      Memo1.Lines.Add('ERROR: ' + E.Message);
  end;
end;

end.
