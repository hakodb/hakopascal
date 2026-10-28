program smoke_softdel;
{ Soft-delete / sweeper / restore smoke vs the 0.20.0 DLL.
  Compile: fpc -Px86_64 smoke_softdel.pp   Run: DLL on PATH. }
{$mode objfpc}{$H+}
uses SysUtils, Hako;

var
  DBPath: string;
  DB: THako;
  Ref: THKDocumentRef;
  S: string;
  N: Integer;

  procedure Fail(const Msg: string);
  begin
    Writeln('FAIL: ', Msg);
    Halt(1);
  end;

begin
  try
    DBPath := GetEnvironmentVariable('TEMP') + DirectorySeparator + 'hako_pas_softdel.db';
    if FileExists(DBPath) then DeleteFile(DBPath);
    DB := THako.Create(DBPath);
    try
      Ref := DB.Collection('users').Doc('u1');
      Ref.SetDoc(THKDocument.Create.InsertStr('name', 'Alice').InsertInt('age', 32));

      { Default delete is soft since core 0.20.0. }
      Ref.Delete;
      if Ref.Get <> nil then Fail('deleted doc visible');

      S := DB.RestoreAvailable('');
      if Pos('"id":"u1"', S) = 0 then Fail('restoreAvailable: ' + S);
      if DB.DeleteQueue('') <> '[]' then Fail('deleteQueue not empty');

      Ref.Restore;
      if Ref.Get = nil then Fail('restore did not bring the doc back');
      if DB.RestoreAvailable('') <> '[]' then Fail('record not consumed');

      { Force parity: legacy shape retains nothing. }
      DB.Collection('users').Doc('u2').SetDoc(THKDocument.Create.InsertStr('name', 'Bob'));
      DB.DeleteEx('users', 'u2', True);
      if DB.RestoreAvailable('') <> '[]' then Fail('force delete retained');

      { Escape hatch works regardless of maintenance mode. }
      N := DB.SweepNow;
      if N < 0 then Fail('sweepNow failed');

      Writeln('soft-delete smoke OK (sweepNow=', N, ')');
    finally
      DB.Free;
    end;
  except
    on E: Exception do begin
      Writeln('FAIL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
