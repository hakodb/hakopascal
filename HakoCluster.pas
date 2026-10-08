{ HakoDB cluster surface for Free Pascal (FPC/Lazarus).

  Ergonomic layer over the hakocluster C ABI (open/put/get/delete/query,
  promote/epoch/health/tick + multidatabase registry). Docs and queries
  cross as UTF-8 JSON strings, never as structs — see the generated
  `hakocluster.h` (cbindgen, from hakocluster releases).

  The units link `hakocluster.dll` / `libhakocluster.so` by filename: put
  it next to your binary, on PATH, or under `./native/` (populated by
  `sync-cluster.ps1`). N > 1 needs a unix host (socket peering);
  elsewhere open refuses N > 1 and N = 1 works as a degenerate
  single-node cluster. }
unit HakoCluster;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, ctypes;

const
{$if defined(Windows)}
  HAKOCLUSTER_LIB = 'hakocluster.dll';
{$elseif defined(Darwin)}
  HAKOCLUSTER_LIB = 'libhakocluster.dylib';
{$else}
  HAKOCLUSTER_LIB = 'libhakocluster.so';
{$endif}

type
  PHK_Cluster = Pointer;
  PHK_Databases = Pointer;

  EHakoClusterError = class(Exception);

{ Raw ABI, transcribed from the cbindgen hakocluster.h of the release
  in use. Keep in sync with that header, not with memory. }
function hk_cluster_open(paths_json, sock_dir: PChar): PHK_Cluster; cdecl; external HAKOCLUSTER_LIB;
function hk_cluster_open_with_config(paths_json, config_json: PChar): PHK_Cluster; cdecl; external HAKOCLUSTER_LIB;
procedure hk_cluster_close(handle: PHK_Cluster); cdecl; external HAKOCLUSTER_LIB;
function hk_cluster_put(handle: PHK_Cluster; collection, doc_id, doc_json: PChar): PChar; cdecl; external HAKOCLUSTER_LIB;
function hk_cluster_get(handle: PHK_Cluster; collection, doc_id: PChar): PChar; cdecl; external HAKOCLUSTER_LIB;
function hk_cluster_delete(handle: PHK_Cluster; collection, doc_id: PChar): cint32; cdecl; external HAKOCLUSTER_LIB;
function hk_cluster_query(handle: PHK_Cluster; query_json: PChar): PChar; cdecl; external HAKOCLUSTER_LIB;
function hk_cluster_promote(handle: PHK_Cluster; index: SizeUInt): cint64; cdecl; external HAKOCLUSTER_LIB;
function hk_cluster_epoch(handle: PHK_Cluster): QWord; cdecl; external HAKOCLUSTER_LIB;
function hk_cluster_refresh_health(handle: PHK_Cluster): PChar; cdecl; external HAKOCLUSTER_LIB;
function hk_cluster_tick_flush(handle: PHK_Cluster): cint32; cdecl; external HAKOCLUSTER_LIB;
function hk_databases_open(config_json: PChar): PHK_Databases; cdecl; external HAKOCLUSTER_LIB;
procedure hk_databases_close(handle: PHK_Databases); cdecl; external HAKOCLUSTER_LIB;
function hk_db_get(handle: PHK_Databases; name: PChar): PHK_Cluster; cdecl; external HAKOCLUSTER_LIB;
function hk_databases_names(handle: PHK_Databases): PChar; cdecl; external HAKOCLUSTER_LIB;
procedure hk_cluster_string_free(value: PChar); cdecl; external HAKOCLUSTER_LIB;
function hk_cluster_last_error: PChar; cdecl; external HAKOCLUSTER_LIB;

type
  { One cluster handle (one mesh). Close frees it. }
  THakoCluster = class
  private
    FHandle: PHK_Cluster;
  public
    { Default config + explicit sock dir ('./socks' when ''). }
    constructor Create(const PathsJson, SockDir: string); overload;
    { Full config JSON (stagger policies, ManualRotation, lag guard). }
    constructor CreateWithConfig(const PathsJson, ConfigJson: string); overload;
    constructor CreateFromHandle(H: PHK_Cluster);
    destructor Destroy; override;
    { Write a doc given as JSON object; returns the id. }
    function Put(const Collection, DocID, DocJson: string): string;
    { Point read as JSON (with "_time"). '' on key-miss; raises on error. }
    function Get(const Collection, DocID: string): string;
    procedure Delete(const Collection, DocID: string);
    { Fan-out query. QueryJson: {"collection":"b","where":{"field":"g",
      "op":"eq","value":"g1"},"limit":20}. Returns the raw JSON rows. }
    function Query(const QueryJson: string): string;
    { Manual failover. Returns the promotion epoch. }
    function Promote(Index: SizeUInt): Int64;
    function Epoch: QWord;
    { Lag guard + health as raw JSON. }
    function RefreshHealth: string;
    procedure TickFlush;
    property Handle: PHK_Cluster read FHandle;
  end;

  { Multidatabase registry (one process, N named databases). }
  THakoDatabases = class
  private
    FHandle: PHK_Databases;
  public
    constructor Create(const ConfigJson: string);
    destructor Destroy; override;
    { Exact-name lookup: fresh THakoCluster over the SAME cluster
      (one mesh, many handles). Raises on unknown name. }
    function Get(const Name: string): THakoCluster;
    function Names: TStringList;
  end;

implementation

function ConsumeClusterCString(P: PChar): string;
begin
  if P = nil then Exit('');
  Result := string(P);
  hk_cluster_string_free(P);
end;

procedure CheckClusterStatus(Code: cint32; const Context: string);
var P: PChar;
begin
  if Code <> 0 then begin
    P := hk_cluster_last_error;
    raise EHakoClusterError.CreateFmt('%s failed: %s', [Context, string(P)]);
  end;
end;

procedure RaiseClusterError(const Context: string);
var P: PChar;
begin
  P := hk_cluster_last_error;
  if (P <> nil) and (P^ <> #0) then
    raise EHakoClusterError.CreateFmt('%s failed: %s', [Context, string(P)]);
  raise EHakoClusterError.CreateFmt('%s failed', [Context]);
end;

{ THakoCluster }

constructor THakoCluster.Create(const PathsJson, SockDir: string);
var
  Sock: string;
begin
  Sock := SockDir;
  if Sock = '' then Sock := './socks';
  FHandle := hk_cluster_open(PChar(PathsJson), PChar(Sock));
  if FHandle = nil then RaiseClusterError('Cluster.Create');
end;

constructor THakoCluster.CreateWithConfig(const PathsJson, ConfigJson: string);
begin
  FHandle := hk_cluster_open_with_config(PChar(PathsJson), PChar(ConfigJson));
  if FHandle = nil then RaiseClusterError('Cluster.CreateWithConfig');
end;

constructor THakoCluster.CreateFromHandle(H: PHK_Cluster);
begin
  if H = nil then RaiseClusterError('Cluster.CreateFromHandle');
  FHandle := H;
end;

destructor THakoCluster.Destroy;
begin
  if FHandle <> nil then hk_cluster_close(FHandle);
  inherited;
end;

function THakoCluster.Put(const Collection, DocID, DocJson: string): string;
begin
  Result := ConsumeClusterCString(hk_cluster_put(FHandle, PChar(Collection), PChar(DocID), PChar(DocJson)));
  if Result = '' then RaiseClusterError('Cluster.Put');
end;

function THakoCluster.Get(const Collection, DocID: string): string;
var P, E: PChar;
begin
  P := hk_cluster_get(FHandle, PChar(Collection), PChar(DocID));
  if P = nil then begin
    { NULL is miss OR error: miss leaves last_error empty. }
    E := hk_cluster_last_error;
    if (E <> nil) and (E^ <> #0) then RaiseClusterError('Cluster.Get');
    Exit('');
  end;
  Result := string(P);
  hk_cluster_string_free(P);
end;

procedure THakoCluster.Delete(const Collection, DocID: string);
begin
  CheckClusterStatus(hk_cluster_delete(FHandle, PChar(Collection), PChar(DocID)), 'Cluster.Delete');
end;

function THakoCluster.Query(const QueryJson: string): string;
begin
  Result := ConsumeClusterCString(hk_cluster_query(FHandle, PChar(QueryJson)));
  if Result = '' then RaiseClusterError('Cluster.Query');
end;

function THakoCluster.Promote(Index: SizeUInt): Int64;
var R: cint64;
begin
  R := hk_cluster_promote(FHandle, Index);
  if R < 0 then RaiseClusterError('Cluster.Promote');
  Result := R;
end;

function THakoCluster.Epoch: QWord;
begin
  Result := hk_cluster_epoch(FHandle);
end;

function THakoCluster.RefreshHealth: string;
begin
  Result := ConsumeClusterCString(hk_cluster_refresh_health(FHandle));
  if Result = '' then RaiseClusterError('Cluster.RefreshHealth');
end;

procedure THakoCluster.TickFlush;
begin
  CheckClusterStatus(hk_cluster_tick_flush(FHandle), 'Cluster.TickFlush');
end;

{ THakoDatabases }

constructor THakoDatabases.Create(const ConfigJson: string);
begin
  FHandle := hk_databases_open(PChar(ConfigJson));
  if FHandle = nil then RaiseClusterError('Databases.Create');
end;

destructor THakoDatabases.Destroy;
begin
  if FHandle <> nil then hk_databases_close(FHandle);
  inherited;
end;

function THakoDatabases.Get(const Name: string): THakoCluster;
var H: PHK_Cluster;
begin
  H := hk_db_get(FHandle, PChar(Name));
  Result := THakoCluster.CreateFromHandle(H);
end;

function THakoDatabases.Names: TStringList;
var S: string; P: TJSONParser; A: TJSONArray; I: Integer;
begin
  Result := TStringList.Create;
  S := ConsumeClusterCString(hk_databases_names(FHandle));
  if S = '' then RaiseClusterError('Databases.Names');
  P := TJSONParser.Create(S);
  try
    A := TJSONArray(P.Parse);
    for I := 0 to A.Count - 1 do Result.Add(A.Strings[I]);
  finally
    P.Free;
  end;
end;

end.
