program smoke_graphrag;
{ GraphRAG smoke vs the 0.20.6 DLL: v2 binary_stage1 ABI (9-arg), hybrid
  RRF, pagerank, subgraph. Compile: fpc -Px86_64 smoke_graphrag.pp
  Run: hakodb.dll on PATH. }
{$mode objfpc}{$H+}
uses SysUtils, HakoRaw, Hako;

var
  DBPath: string;
  DB: THako;
  S: string;
  N: Integer;
  Emb: array[0..7] of Byte;

  procedure Fail(const Msg: string);
  begin
    Writeln('FAIL: ', Msg);
    Halt(1);
  end;

  procedure PutDoc(const Col, ID, Title: string; X, Y: Single);
  var
    D: THKDocument;
    B: array[0..7] of Byte absolute X;
  begin
    { Overlap trick only maps X; encode Y by hand. }
    Move(X, Emb[0], 4);
    Move(Y, Emb[4], 4);
    D := THKDocument.Create.InsertStr('title', Title).InsertBin('emb', @Emb[0], 8);
    DB.Collection(Col).Doc(ID).SetDoc(D);
  end;

begin
  try
    DBPath := GetEnvironmentVariable('TEMP') + DirectorySeparator + 'hako_pas_graphrag.db';
    if FileExists(DBPath) then DeleteFile(DBPath);
    DB := THako.Create(DBPath);
    try
      { Graph: a -> b -> c (plain-string ref convention). }
      DB.Collection('g').CreateTraverseIndex;
      DB.Collection('g').Doc('a').SetDoc(THKDocument.Create.InsertRef('link', 'g', 'b'));
      DB.Collection('g').Doc('b').SetDoc(THKDocument.Create.InsertRef('link', 'g', 'c'));
      DB.Collection('g').Doc('c').SetDoc(THKDocument.Create.InsertInt('v', 1));

      S := DB.Collection('g').Subgraph('a', 2);
      if Pos('"id":"c"', S) = 0 then Fail('subgraph missing c: ' + S);

      S := DB.Collection('g').GraphPagerank([], 0, 3);
      if Pos('"node":"g/c"', S) = 0 then Fail('pagerank missing g/c: ' + S);

      { Hybrid: indexes first, docs second (write-time indexing).
        Sides may need a maintenance tick before hits appear - poll. }
      DB.Collection('docs').CreateFTSIndex('title');
      { binary_stage1 ABI check: 9-arg v2 must not crash or garble. }
      DB.Collection('docs').CreateVectorIndexV2('emb', 2, HK_VECTOR_COSINE, 0, 0, 0, True);
      PutDoc('docs', 'd1', 'red apple', 1.0, 0.0);
      PutDoc('docs', 'd2', 'blue sky', 0.0, 1.0);
      PutDoc('docs', 'd3', 'red sky', 0.9, 0.1);

      S := '';
      for N := 1 to 50 do
      begin
        S := DB.Collection('docs').HybridSearch('title', 'red', 'emb', [1.0, 0.0], 2);
        if (Pos('"d1"', S) <> 0) or (Pos('"d3"', S) <> 0) then Break;
        Sleep(100);
      end;
      if Pos('"d2"', S) <> 0 then Fail('hybrid returned off-topic d2: ' + S);
      if (Pos('"d1"', S) = 0) and (Pos('"d3"', S) = 0) then Fail('hybrid empty after settle: ' + S);

      Writeln('graphrag smoke OK');
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
