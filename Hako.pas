unit Hako;

{$mode objfpc}{$H+}
{$macro on}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, SyncObjs, ctypes, HakoRaw;

type
  EHakoError = class(Exception);

  THKDurabilityMode = (dmAlways, dmInterval, dmManual, dmOnCommit);

  THKCloudSyncMode = (csmServer, csmClient);

  THKDiscoveryMode = (dmMdns = 0, dmBroadcast = 1, dmBoth = 2);

  TOnSnapshotCallback = procedure(const JsonSnapshot: string) of object;

  IFLSubscription = interface
    ['{91E1FC85-5B6F-4F66-B070-8698E120AF7E}']
    procedure Stop;
  end;

  THako = class;
  THKCollection = class;
  THKDocument = class;
  THKArray = class;
  THKQuery = class;
  THKRawDoc = class;
  THKRawResultSet = class;
  THKViewDoc = class;
  THKBatch = class;
  THKTransaction = class;
  THKDocumentRef = class;
  THKCloudSync = class;

  { THKArray: Builder for List/Array types }
  THKArray = class
  private
    FHandle: PHK_Array;
    FOwned: Boolean;
    procedure EnsureHandle;
  public
    constructor Create;
    destructor Destroy; override;
    function AppendStr(const Value: string): THKArray;
    function AppendInt(Value: Int64): THKArray;
    function AppendDoc(ADoc: THKDocument): THKArray;
    property Handle: PHK_Array read FHandle;
  end;

  { THKConfig: Advanced Configuration Builder }
  THKConfig = class
  private
    FHandle: PHK_Config;
  public
    constructor Create;
    destructor Destroy; override;
    function SetDurability(Mode: THKDurabilityMode): THKConfig;
    function SetEncryptionKey(const Key: string): THKConfig;
    function SetEncryptedCollections(const Collections: array of string): THKConfig;
    function SetAuditLog(Enabled: Boolean; const LogPath: string = ''): THKConfig;
    function SetQueryWorkers(Count: NativeUInt): THKConfig;
    function SetMemoryLimits(MMapSize, MaxInlinedBytes: NativeUInt): THKConfig;
    function SetStorageTuning(PageSize, CompactionThreshold, GroupCommitMaxOps: NativeUInt): THKConfig;
    function SetBlobThreshold(ThresholdBytes: NativeUInt): THKConfig;
    function SetCompression(Enabled: Boolean; Level: Integer = 3): THKConfig;
    function SetBackgroundMaintenance(Enabled: Boolean): THKConfig;
    property Handle: PHK_Config read FHandle;
  end;

  { THKDocument: Binary Document Model }
  THKDocument = class
  private
    FHandle: PHK_Doc;
    FOwned: Boolean;
  public
    constructor Create; overload;
    constructor CreateFromHandle(AHandle: PHK_Doc; AOwned: Boolean); overload;
    destructor Destroy; override;

    function InsertStr(const Key, Value: string): THKDocument;
    function InsertInt(const Key: string; Value: Int64): THKDocument;
    function InsertFloat(const Key: string; Value: Double): THKDocument;
    function InsertBool(const Key: string; Value: Boolean): THKDocument;
    function InsertNull(const Key: string): THKDocument;
    function InsertBin(const Key: string; Data: PByte; Len: NativeUInt): THKDocument;
    function InsertTimestamp(const Key: string; Micros: Int64): THKDocument;
    function InsertServerTimestamp(const Key: string): THKDocument;
    function InsertDoc(const Key: string; ADoc: THKDocument): THKDocument;
    function InsertArray(const Key: string; AArray: THKArray): THKDocument;
    function InsertRef(const Key, TargetCol, TargetID: string): THKDocument;

    class function FromJSON(const Obj: TJSONObject): THKDocument;
    function ToJSON: string;
    property Handle: PHK_Doc read FHandle;
  end;

  { THKBatch: Atomic Write Operations }
  THKBatch = class
  private
    FDBHandle: PHK_Engine;
    FHandle: PHK_Batch;
    FCommitted: Boolean;
  public
    constructor Create(ADBHandle: PHK_Engine);
    destructor Destroy; override;
    function SetDoc(const Col, ID: string; Doc: THKDocument): THKBatch;
    function Delete(const Col, ID: string): THKBatch;
    procedure Commit;
  end;

  { THKTransaction: Serializable RMW }
  THKTransaction = class
  private
    FDBHandle: PHK_Engine;
    FHandle: PHK_Transaction;
  public
    constructor Create(ADBHandle: PHK_Engine);
    destructor Destroy; override;
    function Get(const Col, ID: string): THKDocument;
    procedure SetDoc(const Col, ID: string; Doc: THKDocument);
    procedure Commit;
  end;

  { THKRawDoc: borrowed row of a raw result set (v0.8.3+). The wrapper is
    yours to free; the native handle belongs to the THKRawResultSet. }
  THKRawDoc = class
  private
    FDB: THako;
    FHandle: PHK_RawDoc;
  public
    constructor CreateBorrowed(ADB: THako; AHandle: PHK_RawDoc);
    function Id: string;
    function Bytes: TBytes;
    { Decode into an owned THKDocument (blobs inflated). Free the result. }
    function Resolve(const Collection: string): THKDocument;
    property Handle: PHK_RawDoc read FHandle;
  end;

  { THKRawResultSet: pinned storage bytes per row (v0.8.3+). }
  THKRawResultSet = class
  private
    FDB: THako;
    FHandle: PHK_RawResultSet;
  public
    constructor Create(ADB: THako; AHandle: PHK_RawResultSet);
    destructor Destroy; override;
    function Count: NativeUInt;
    { Borrowed row — valid until Free/Destroy. Free the wrapper, not the handle. }
    function Get(Index: NativeUInt): THKRawDoc;
    procedure Free;
    property Handle: PHK_RawResultSet read FHandle;
  end;

  { THKViewDoc: owned pinned-bytes handle with lazy typed pulls (v0.8.11+).
    No decode, no owned construction; strict scalar matches. Free it. }
  THKViewDoc = class
  private
    FHandle: PHK_ViewDoc;
  public
    constructor Create(AHandle: PHK_ViewDoc);
    destructor Destroy; override;
    function FieldCount: NativeUInt;
    function HasField(const Key: string): Boolean;
    function GetInt(const Key: string; out Value: Int64): Boolean;
    function GetFloat(const Key: string; out Value: Double): Boolean;
    function GetBool(const Key: string; out Value: Boolean): Boolean;
    function GetStr(const Key: string): string;
    function GetBytes(const Key: string): TBytes;
    { Full owned decode. Free the result. }
    function ToDoc(const DocID: string): THKDocument;
    property Handle: PHK_ViewDoc read FHandle;
  end;

  { THKQuery: Optimized Parallel Query Engine }
  THKQuery = class
  private
    FDB: THako;
    FCollection: string;
    FWhereStr: array of record Field, Value, Op: string; end;
    FWhereInt: array of record Field: string; Value: Int64; Op: string; end;
    FWhereBool: array of record Field: string; Value: Boolean; end;
    FWhereIn: array of record Field: string; Data: TJSONArray; end;
    FWhereNotIn: array of record Field: string; Data: TJSONArray; end;
    FWhereArrayContainsAny: array of record Field: string; Data: TJSONArray; end;
    FOrderByField: string;
    FOrderByAsc: Boolean;
FLimit, FOffset: NativeUInt;
FHasLimit, FHasOffset: Boolean;
FDeferBlobs: Boolean;
    FSelectFields: TStringList;
    FStartAt, FStartAfter, FEndAt, FEndBefore: PHK_Doc;
    FStartAfterRaw: PHK_RawDoc;
    FWhereOrStr: array of record Field, Value: string; end;
    FWhereOrInt: array of record Field: string; Value: Int64; end;

    function BuildNativeQuery: PHK_Query;
  public
    constructor Create(ADB: THako; const ACollection: string);
    destructor Destroy; override;

    function WhereEqStr(const Field, Value: string): THKQuery;
    function WhereEqBool(const Field: string; Value: Boolean): THKQuery;
    function WhereEqInt(const Field: string; Value: Int64): THKQuery;
    function WhereNeStr(const Field, Value: string): THKQuery;
    function WhereNeInt(const Field: string; Value: Int64): THKQuery;
    function WhereGtStr(const Field, Value: string): THKQuery;
    function WhereGtInt(const Field: string; Value: Int64): THKQuery;
    function WhereGteStr(const Field, Value: string): THKQuery;
    function WhereGteInt(const Field: string; Value: Int64): THKQuery;
    function WhereLtStr(const Field, Value: string): THKQuery;
    function WhereLtInt(const Field: string; Value: Int64): THKQuery;
    function WhereLteStr(const Field, Value: string): THKQuery;
    function WhereLteInt(const Field: string; Value: Int64): THKQuery;
    function WhereIn(const Field: string; const Values: array of const): THKQuery;
    function WhereNotIn(const Field: string; const Values: array of const): THKQuery;
    function ArrayContains(const Field, Value: string): THKQuery;
    function ArrayContainsAny(const Field: string; const Values: array of const): THKQuery;
    function Match(const Field, Value: string): THKQuery;
    function MatchPrefix(const Field, Value: string): THKQuery;
    function Contains(const Field, Value: string): THKQuery;
    function StartsWith(const Field, Value: string): THKQuery;
    
    function OrderBy(const Field: string; Ascending: Boolean = True): THKQuery;
    function Limit(ACount: NativeUInt): THKQuery;
    function Offset(ACount: NativeUInt): THKQuery;
    function Select(const Fields: array of string): THKQuery;
{ Blob fields come back as placeholders (no blob reads); resolve per doc. }
function DeferBlobs(Defer: Boolean = True): THKQuery;

    function StartAt(ASnapshot: THKDocument): THKQuery;
    function StartAfter(ASnapshot: THKDocument): THKQuery;
    function StartAfterRaw(ARaw: THKRawDoc): THKQuery;
    function EndAt(ASnapshot: THKDocument): THKQuery;
    function EndBefore(ASnapshot: THKDocument): THKQuery;

    function WhereOrStr(const Field, Value: string): THKQuery;
    function WhereOrInt(const Field: string; Value: Int64): THKQuery;

    function Count: Int64;
    function Sum(const Field: string): Double;
    function Avg(const Field: string): Double;

    function GetJSON: string;
    { Raw execution (v0.8.3+): pinned bytes per row. Free the result. }
    function ExecuteRaw: THKRawResultSet;
    { Zero-alloc walk (v0.8.6+): one call per scan. Returns rows visited. }
    function Walk(Callback: THK_WalkCallback; UserData: Pointer): Int64;
    { Lazy view walk (v0.8.11+): each row lent as a borrowed view handle. }
    function WalkView(Callback: THK_ViewWalkCallback; UserData: Pointer): Int64;
    function Delete: Int64;
    function DeleteLocal: Int64;
    function Patch(Doc: THKDocument): Int64;
    function OnSnapshot(const Callback: TOnSnapshotCallback; QueueToMainThread: Boolean = True): IFLSubscription;
  end;

  THKDocumentRef = class
  private
    FDB: THako;
    FCollection, FDocID: string;
  public
    constructor Create(ADB: THako; const ACollection, ADocID: string);
    procedure SetDoc(const Doc: THKDocument);
    function Get: THKDocument;
    procedure Delete;
    procedure DeleteLocal;
  end;

  THKCollection = class
  private
    FDB: THako;
    FName: string;
  public
    constructor Create(ADB: THako; const AName: string);
    function Doc(const DocID: string): THKDocumentRef;
    function Query: THKQuery;
    
    { Shortcut Methods }
    function WhereEqStr(const Field, Value: string): THKQuery;
    function WhereEqInt(const Field: string; Value: Int64): THKQuery;
    function Match(const Field, Value: string): THKQuery;
    function Limit(ACount: NativeUInt): THKQuery;

    procedure CreateIndex(const Field: string);
    procedure CreateFTSIndex(const Field: string);
    procedure CreateCompositeIndex(const Fields: array of string);
    function ListIndexes: string;
  end;

  THKNetSyncer = class
  private
    FHandle: PHK_NetSyncer;
  public
    constructor Create(ADBHandle: PHK_Engine; const Name, RoomKey: string);
    destructor Destroy; override;
    procedure Start(APort: Word);
    procedure SetDiscoveryMode(AMode: THKDiscoveryMode);
    function StatusJSON: string;
  end;

  THKCloudSync = class
  private
    FHandle: PHK_CloudSync;
  public
    constructor Create(ADBHandle: PHK_Engine; Mode: THKCloudSyncMode; const ClientID, RoomName, RoomKey, AuthToken: string);
    constructor CreateServer(ADBHandle: PHK_Engine; const ServerID, AuthToken: string);
    constructor CreateClient(ADBHandle: PHK_Engine; const ClientID, RoomName, RoomKey, AuthToken: string);
    destructor Destroy; override;
    procedure Start(const Address: string);
    function StatusJSON: string;
    procedure Stop;
  end;

  THako = class
  private
    FHandle: PHK_Engine;
  public
    constructor Create(const DBPath: string); overload;
    constructor Create(const DBPath: string; AConfig: THKConfig); overload;
    destructor Destroy; override;
    function Collection(const Name: string): THKCollection;
    function ListCollections: TStringList;
    function ListIndexes(const ACollection: string): string;
    function GetStats: string;
    function GetAuditLog: string;
    function Backup(const Path: string): Integer;
    procedure Compact;
    function IsIndexesReady: Boolean;
    { Borrowed point view (v0.8.11+): lazy pulls, no decode. Free it.
      Returns nil when missing. }
    function GetView(const Col, ID: string): THKViewDoc;
    procedure SnapshotIndices;
    function InsertSubDoc(const Col, ID, SubCol, SubID: string; Doc: THKDocument): Integer;
    function GetByRef(Doc: THKDocument; const FieldKey: string): THKDocument;
    procedure CreateCompositeIndex(const ACollection: string; const Fields: array of string);
    function StartBatch: THKBatch;
    function StartTransaction: THKTransaction;
    procedure SetCollectionLocal(const ACollection: string; Local: Boolean);
    procedure ReplicateKey(const ACollection, ADocID: string);
    procedure ReplicateCollection(const ACollection: string);
    function VacuumCollection(const ACollection: string): Integer;
    function CreateNetSyncer(const Name, RoomKey: string): THKNetSyncer;
    function CreateCloudSyncer(Mode: THKCloudSyncMode; const ClientID, RoomName, RoomKey, AuthToken: string): THKCloudSync;
    function CreateCloudServerSyncer(const ServerID, AuthToken: string): THKCloudSync;
    function CreateCloudClientSyncer(const ClientID, RoomName, RoomKey, AuthToken: string): THKCloudSync;
    property Handle: PHK_Engine read FHandle;
  end;

implementation

{ Internal Helpers }

function ConsumeCString(P: PChar): string;
begin
  if P = nil then Exit('');
  Result := string(P);
  hk_string_free(P);
end;

procedure CheckStatus(Code: cint32; const Context: string);
var P: PChar;
begin
  if Code <> 0 then begin
    P := hk_last_error;
    raise EHakoError.CreateFmt('%s failed: %s', [Context, string(P)]);
  end;
end;

{ THKArray }

constructor THKArray.Create;
begin FHandle := hk_array_new; FOwned := True; end;

destructor THKArray.Destroy;
begin if FOwned and (FHandle <> nil) then hk_array_free(FHandle); inherited; end;

procedure THKArray.EnsureHandle;
begin if FHandle = nil then raise EHakoError.Create('Array handle consumed'); end;

function THKArray.AppendStr(const Value: string): THKArray;
begin EnsureHandle; hk_array_append_str(FHandle, PChar(Value)); Result := Self; end;

function THKArray.AppendInt(Value: Int64): THKArray;
begin EnsureHandle; hk_array_append_int(FHandle, Value); Result := Self; end;

function THKArray.AppendDoc(ADoc: THKDocument): THKArray;
begin EnsureHandle; hk_array_append_doc(FHandle, ADoc.Handle); Result := Self; end;

{ THKConfig }

constructor THKConfig.Create;
begin
  inherited Create;
  FHandle := hk_config_new;
end;

destructor THKConfig.Destroy;
begin
  if FHandle <> nil then hk_config_free(FHandle);
  inherited;
end;

function THKConfig.SetDurability(Mode: THKDurabilityMode): THKConfig;
begin
  hk_config_set_durability(FHandle, Ord(Mode));
  Result := Self;
end;

function THKConfig.SetEncryptionKey(const Key: string): THKConfig;
begin
  hk_config_set_encryption_key(FHandle, PChar(Key));
  Result := Self;
end;

function THKConfig.SetAuditLog(Enabled: Boolean; const LogPath: string): THKConfig;
begin
  if LogPath = '' then
    hk_config_set_audit_log(FHandle, Enabled, nil)
  else
    hk_config_set_audit_log(FHandle, Enabled, PChar(LogPath));
  Result := Self;
end;

function THKConfig.SetQueryWorkers(Count: NativeUInt): THKConfig;
begin
  hk_config_set_query_workers(FHandle, Count);
  Result := Self;
end;

function THKConfig.SetMemoryLimits(MMapSize, MaxInlinedBytes: NativeUInt): THKConfig;
begin
  hk_config_set_memory_limits(FHandle, MMapSize, MaxInlinedBytes);
  Result := Self;
end;

function THKConfig.SetEncryptedCollections(const Collections: array of string): THKConfig;
var
  I: Integer;
  S: string;
begin
  S := '[';
  for I := Low(Collections) to High(Collections) do begin
    if I > Low(Collections) then S := S + ',';
    S := S + '"' + Collections[I] + '"';
  end;
  S := S + ']';
  CheckStatus(hk_config_set_encrypted_collections(FHandle, PChar(S)), 'SetEncryptedCollections');
  Result := Self;
end;

function THKConfig.SetStorageTuning(PageSize, CompactionThreshold, GroupCommitMaxOps: NativeUInt): THKConfig;
begin
  hk_config_set_storage_tuning(FHandle, PageSize, CompactionThreshold, GroupCommitMaxOps);
  Result := Self;
end;

function THKConfig.SetBlobThreshold(ThresholdBytes: NativeUInt): THKConfig;
begin
  hk_config_set_blob_threshold(FHandle, ThresholdBytes);
  Result := Self;
end;

function THKConfig.SetCompression(Enabled: Boolean; Level: Integer): THKConfig;
begin
  hk_config_set_compression(FHandle, Enabled, Level);
  Result := Self;
end;

function THKConfig.SetBackgroundMaintenance(Enabled: Boolean): THKConfig;
begin
  hk_config_set_background_maintenance(FHandle, Enabled);
  Result := Self;
end;

{ THKDocument }

constructor THKDocument.Create;
begin FHandle := hk_doc_new; FOwned := True; end;

constructor THKDocument.CreateFromHandle(AHandle: PHK_Doc; AOwned: Boolean);
begin FHandle := AHandle; FOwned := AOwned; end;

destructor THKDocument.Destroy;
begin if FOwned and (FHandle <> nil) then hk_doc_free(FHandle); inherited; end;

function THKDocument.InsertStr(const Key, Value: string): THKDocument;
begin hk_doc_insert_str(FHandle, PChar(Key), PChar(Value)); Result := Self; end;

function THKDocument.InsertInt(const Key: string; Value: Int64): THKDocument;
begin hk_doc_insert_int(FHandle, PChar(Key), Value); Result := Self; end;

function THKDocument.InsertFloat(const Key: string; Value: Double): THKDocument;
begin hk_doc_insert_float(FHandle, PChar(Key), Value); Result := Self; end;

function THKDocument.InsertBool(const Key: string; Value: Boolean): THKDocument;
begin hk_doc_insert_bool(FHandle, PChar(Key), Value); Result := Self; end;

function THKDocument.InsertNull(const Key: string): THKDocument;
begin hk_doc_insert_null(FHandle, PChar(Key)); Result := Self; end;

function THKDocument.InsertBin(const Key: string; Data: PByte; Len: NativeUInt): THKDocument;
begin hk_doc_insert_bin(FHandle, PChar(Key), Data, Len); Result := Self; end;

function THKDocument.InsertTimestamp(const Key: string; Micros: Int64): THKDocument;
begin hk_doc_insert_timestamp(FHandle, PChar(Key), Micros); Result := Self; end;

function THKDocument.InsertServerTimestamp(const Key: string): THKDocument;
begin hk_doc_insert_server_timestamp(FHandle, PChar(Key)); Result := Self; end;

function THKDocument.InsertDoc(const Key: string; ADoc: THKDocument): THKDocument;
begin hk_doc_insert_doc(FHandle, PChar(Key), ADoc.Handle); Result := Self; end;

function THKDocument.InsertArray(const Key: string; AArray: THKArray): THKDocument;
begin
  CheckStatus(hk_doc_insert_array(FHandle, PChar(Key), AArray.Handle), 'InsertArray');
  AArray.FHandle := nil; // Handled by Rust ownership
  Result := Self;
end;

function THKDocument.InsertRef(const Key, TargetCol, TargetID: string): THKDocument;
begin hk_doc_insert_reference(FHandle, PChar(Key), PChar(TargetCol), PChar(TargetID)); Result := Self; end;

class function THKDocument.FromJSON(const Obj: TJSONObject): THKDocument;
var 
  I, J: Integer; 
  Key: string; 
  Data: TJSONData;
  SubArr: THKArray;
begin
  Result := THKDocument.Create;
  for I := 0 to Obj.Count - 1 do begin
    Key := Obj.Names[I]; Data := Obj.Items[I];
    case Data.JSONType of
      jtNull: Result.InsertNull(Key);
      jtBoolean: Result.InsertBool(Key, Data.AsBoolean);
      jtNumber: if Pos('.', Data.AsJSON) > 0 then Result.InsertFloat(Key, Data.AsFloat) else Result.InsertInt(Key, Data.AsInt64);
      jtString: Result.InsertStr(Key, Data.AsString);
      jtObject: Result.InsertDoc(Key, THKDocument.FromJSON(TJSONObject(Data)));
      jtArray: begin
        SubArr := THKArray.Create;
        for J := 0 to TJSONArray(Data).Count - 1 do begin
           if TJSONArray(Data).Items[J].JSONType = jtObject then
             SubArr.AppendDoc(THKDocument.FromJSON(TJSONObject(TJSONArray(Data).Items[J])))
           else if TJSONArray(Data).Items[J].JSONType = jtNumber then
             SubArr.AppendInt(TJSONArray(Data).Items[J].AsInt64)
           else
             SubArr.AppendStr(TJSONArray(Data).Items[J].AsString);
        end;
        Result.InsertArray(Key, SubArr);
      end;
    end;
  end;
end;

function THKDocument.ToJSON: string;
begin Result := ConsumeCString(hk_doc_to_json(FHandle)); end;

{ THKBatch }

constructor THKBatch.Create(ADBHandle: PHK_Engine);
begin inherited Create; FDBHandle := ADBHandle; FHandle := hk_batch_new; end;

destructor THKBatch.Destroy;
begin if (FHandle <> nil) and not FCommitted then hk_batch_free(FHandle); inherited; end;

function THKBatch.SetDoc(const Col, ID: string; Doc: THKDocument): THKBatch;
begin CheckStatus(hk_batch_set(FHandle, PChar(Col), PChar(ID), Doc.Handle), 'BatchSet'); Result := Self; end;

function THKBatch.Delete(const Col, ID: string): THKBatch;
begin CheckStatus(hk_batch_delete(FHandle, PChar(Col), PChar(ID)), 'BatchDelete'); Result := Self; end;

procedure THKBatch.Commit;
begin CheckStatus(hk_batch_commit(FDBHandle, FHandle), 'BatchCommit'); FCommitted := True; end;

{ THKTransaction }

constructor THKTransaction.Create(ADBHandle: PHK_Engine);
begin inherited Create; FDBHandle := ADBHandle; FHandle := hk_transaction_begin(FDBHandle); end;

destructor THKTransaction.Destroy;
begin if FHandle <> nil then hk_transaction_free(FHandle); inherited; end;

function THKTransaction.Get(const Col, ID: string): THKDocument;
var H: PHK_Doc;
begin
  H := hk_transaction_get(FDBHandle, FHandle, PChar(Col), PChar(ID));
  if H = nil then Exit(nil);
  Result := THKDocument.CreateFromHandle(H, True);
end;

procedure THKTransaction.SetDoc(const Col, ID: string; Doc: THKDocument);
begin CheckStatus(hk_transaction_set(FHandle, PChar(Col), PChar(ID), Doc.Handle), 'TxSet'); end;

procedure THKTransaction.Commit;
begin CheckStatus(hk_transaction_commit(FDBHandle, FHandle), 'TxCommit'); end;

{ THKQuery }

constructor THKQuery.Create(ADB: THako; const ACollection: string);
begin FDB := ADB; FCollection := ACollection; FSelectFields := TStringList.Create; end;

destructor THKQuery.Destroy;
var I: Integer; begin
  FSelectFields.Free;
  for I := Low(FWhereIn) to High(FWhereIn) do FWhereIn[I].Data.Free;
  for I := Low(FWhereNotIn) to High(FWhereNotIn) do FWhereNotIn[I].Data.Free;
  for I := Low(FWhereArrayContainsAny) to High(FWhereArrayContainsAny) do FWhereArrayContainsAny[I].Data.Free;
  inherited;
end;

function THKQuery.WhereEqStr(const Field, Value: string): THKQuery;
var L: Integer; begin L := Length(FWhereStr); SetLength(FWhereStr, L + 1); FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := '=='; Result := Self; end;

function THKQuery.WhereEqBool(const Field: string; Value: Boolean): THKQuery;
var L: Integer; begin L := Length(FWhereBool); SetLength(FWhereBool, L + 1); FWhereBool[L].Field := Field; FWhereBool[L].Value := Value; Result := Self; end;

function THKQuery.WhereEqInt(const Field: string; Value: Int64): THKQuery;
var L: Integer; begin L := Length(FWhereInt); SetLength(FWhereInt, L + 1); FWhereInt[L].Field := Field; FWhereInt[L].Value := Value; FWhereInt[L].Op := 'eq'; Result := Self; end;

function THKQuery.WhereNeStr(const Field, Value: string): THKQuery;
var L: Integer; begin L := Length(FWhereStr); SetLength(FWhereStr, L + 1); FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := 'ne'; Result := Self; end;

function THKQuery.WhereNeInt(const Field: string; Value: Int64): THKQuery;
var L: Integer; begin L := Length(FWhereInt); SetLength(FWhereInt, L + 1); FWhereInt[L].Field := Field; FWhereInt[L].Value := Value; FWhereInt[L].Op := 'ne'; Result := Self; end;

function THKQuery.WhereGtStr(const Field, Value: string): THKQuery;
var L: Integer; begin L := Length(FWhereStr); SetLength(FWhereStr, L + 1); FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := 'gt'; Result := Self; end;

function THKQuery.WhereGtInt(const Field: string; Value: Int64): THKQuery;
var L: Integer; begin L := Length(FWhereInt); SetLength(FWhereInt, L + 1); FWhereInt[L].Field := Field; FWhereInt[L].Value := Value; FWhereInt[L].Op := 'gt'; Result := Self; end;

function THKQuery.WhereGteStr(const Field, Value: string): THKQuery;
var L: Integer; begin L := Length(FWhereStr); SetLength(FWhereStr, L + 1); FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := 'gte'; Result := Self; end;

function THKQuery.WhereGteInt(const Field: string; Value: Int64): THKQuery;
var L: Integer; begin L := Length(FWhereInt); SetLength(FWhereInt, L + 1); FWhereInt[L].Field := Field; FWhereInt[L].Value := Value; FWhereInt[L].Op := 'gte'; Result := Self; end;

function THKQuery.WhereLtStr(const Field, Value: string): THKQuery;
var L: Integer; begin L := Length(FWhereStr); SetLength(FWhereStr, L + 1); FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := 'lt'; Result := Self; end;

function THKQuery.WhereLtInt(const Field: string; Value: Int64): THKQuery;
var L: Integer; begin L := Length(FWhereInt); SetLength(FWhereInt, L + 1); FWhereInt[L].Field := Field; FWhereInt[L].Value := Value; FWhereInt[L].Op := 'lt'; Result := Self; end;

function THKQuery.WhereLteStr(const Field, Value: string): THKQuery;
var L: Integer; begin L := Length(FWhereStr); SetLength(FWhereStr, L + 1); FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := 'lte'; Result := Self; end;

function THKQuery.WhereLteInt(const Field: string; Value: Int64): THKQuery;
var L: Integer; begin L := Length(FWhereInt); SetLength(FWhereInt, L + 1); FWhereInt[L].Field := Field; FWhereInt[L].Value := Value; FWhereInt[L].Op := 'lte'; Result := Self; end;

function THKQuery.Match(const Field, Value: string): THKQuery;
var L: Integer; begin L := Length(FWhereStr); SetLength(FWhereStr, L + 1); FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := 'match'; Result := Self; end;

function THKQuery.MatchPrefix(const Field, Value: string): THKQuery;
var L: Integer; begin L := Length(FWhereStr); SetLength(FWhereStr, L + 1); FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := 'match_prefix'; Result := Self; end;

function THKQuery.Contains(const Field, Value: string): THKQuery;
var L: Integer; begin L := Length(FWhereStr); SetLength(FWhereStr, L + 1); FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := 'contains'; Result := Self; end;

function THKQuery.StartsWith(const Field, Value: string): THKQuery;
var L: Integer; begin L := Length(FWhereStr); SetLength(FWhereStr, L + 1); FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := 'starts_with'; Result := Self; end;

function THKQuery.WhereIn(const Field: string; const Values: array of const): THKQuery;
var L, I: Integer;
begin
  L := Length(FWhereIn); SetLength(FWhereIn, L + 1);
  FWhereIn[L].Field := Field; FWhereIn[L].Data := TJSONArray.Create;
  for I := Low(Values) to High(Values) do begin
    case Values[I].VType of
      vtInteger: FWhereIn[L].Data.Add(Values[I].VInteger);
      vtInt64: FWhereIn[L].Data.Add(Values[I].VInt64^);
      vtAnsiString: FWhereIn[L].Data.Add(string(Values[I].VAnsiString));
    end;
  end;
  Result := Self;
end;

function THKQuery.WhereNotIn(const Field: string; const Values: array of const): THKQuery;
var L, I: Integer;
begin
  L := Length(FWhereNotIn); SetLength(FWhereNotIn, L + 1);
  FWhereNotIn[L].Field := Field; FWhereNotIn[L].Data := TJSONArray.Create;
  for I := Low(Values) to High(Values) do begin
    case Values[I].VType of
      vtInteger: FWhereNotIn[L].Data.Add(Values[I].VInteger);
      vtInt64: FWhereNotIn[L].Data.Add(Values[I].VInt64^);
      vtAnsiString: FWhereNotIn[L].Data.Add(string(Values[I].VAnsiString));
    end;
  end;
  Result := Self;
end;

function THKQuery.ArrayContains(const Field, Value: string): THKQuery;
var L: Integer;
begin
  L := Length(FWhereStr); SetLength(FWhereStr, L + 1);
  FWhereStr[L].Field := Field; FWhereStr[L].Value := Value; FWhereStr[L].Op := 'array_contains';
  Result := Self;
end;

function THKQuery.ArrayContainsAny(const Field: string; const Values: array of const): THKQuery;
var L, I: Integer;
begin
  L := Length(FWhereArrayContainsAny); SetLength(FWhereArrayContainsAny, L + 1);
  FWhereArrayContainsAny[L].Field := Field; FWhereArrayContainsAny[L].Data := TJSONArray.Create;
  for I := Low(Values) to High(Values) do begin
    case Values[I].VType of
      vtInteger: FWhereArrayContainsAny[L].Data.Add(Values[I].VInteger);
      vtInt64: FWhereArrayContainsAny[L].Data.Add(Values[I].VInt64^);
      vtAnsiString: FWhereArrayContainsAny[L].Data.Add(string(Values[I].VAnsiString));
    end;
  end;
  Result := Self;
end;

function THKQuery.OrderBy(const Field: string; Ascending: Boolean): THKQuery;
begin FOrderByField := Field; FOrderByAsc := Ascending; Result := Self; end;

function THKQuery.Limit(ACount: NativeUInt): THKQuery;
begin FLimit := ACount; FHasLimit := True; Result := Self; end;

function THKQuery.Offset(ACount: NativeUInt): THKQuery;
begin FOffset := ACount; FHasOffset := True; Result := Self; end;

function THKQuery.DeferBlobs(Defer: Boolean): THKQuery;
begin FDeferBlobs := Defer; Result := Self; end;

function THKQuery.StartAt(ASnapshot: THKDocument): THKQuery;
begin
  if ASnapshot <> nil then FStartAt := ASnapshot.Handle;
  Result := Self;
end;

function THKQuery.StartAfter(ASnapshot: THKDocument): THKQuery;
begin
  if ASnapshot <> nil then FStartAfter := ASnapshot.Handle;
  Result := Self;
end;

function THKQuery.EndAt(ASnapshot: THKDocument): THKQuery;
begin
  if ASnapshot <> nil then FEndAt := ASnapshot.Handle;
  Result := Self;
end;

function THKQuery.EndBefore(ASnapshot: THKDocument): THKQuery;
begin
  if ASnapshot <> nil then FEndBefore := ASnapshot.Handle;
  Result := Self;
end;

function THKQuery.Select(const Fields: array of string): THKQuery;
var I: Integer; begin FSelectFields.Clear; for I := Low(Fields) to High(Fields) do FSelectFields.Add(Fields[I]); Result := Self; end;

function THKQuery.BuildNativeQuery: PHK_Query;
var I, J: Integer; TmpArr: PHK_Array;
begin
  Result := hk_query_new(PChar(FCollection));
  try
    for I := Low(FWhereStr) to High(FWhereStr) do begin
      if FWhereStr[I].Op = 'match' then hk_query_where_match(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value))
      else if FWhereStr[I].Op = 'match_prefix' then hk_query_where_match_prefix(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value))
      else if FWhereStr[I].Op = 'contains' then hk_query_where_contains(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value))
      else if FWhereStr[I].Op = 'starts_with' then hk_query_where_starts_with(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value))
      else if FWhereStr[I].Op = 'ne' then hk_query_where_ne_str(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value))
      else if FWhereStr[I].Op = 'gt' then hk_query_where_gt_str(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value))
      else if FWhereStr[I].Op = 'gte' then hk_query_where_gte_str(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value))
      else if FWhereStr[I].Op = 'lt' then hk_query_where_lt_str(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value))
      else if FWhereStr[I].Op = 'lte' then hk_query_where_lte_str(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value))
      else if FWhereStr[I].Op = 'array_contains' then hk_query_where_array_contains(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value))
      else hk_query_where_eq_str(Result, PChar(FWhereStr[I].Field), PChar(FWhereStr[I].Value));
    end;
    for I := Low(FWhereInt) to High(FWhereInt) do begin
      if FWhereInt[I].Op = 'ne' then hk_query_where_ne_int(Result, PChar(FWhereInt[I].Field), FWhereInt[I].Value)
      else if FWhereInt[I].Op = 'gt' then hk_query_where_gt_int(Result, PChar(FWhereInt[I].Field), FWhereInt[I].Value)
      else if FWhereInt[I].Op = 'gte' then hk_query_where_gte_int(Result, PChar(FWhereInt[I].Field), FWhereInt[I].Value)
      else if FWhereInt[I].Op = 'lt' then hk_query_where_lt_int(Result, PChar(FWhereInt[I].Field), FWhereInt[I].Value)
      else if FWhereInt[I].Op = 'lte' then hk_query_where_lte_int(Result, PChar(FWhereInt[I].Field), FWhereInt[I].Value)
      else hk_query_where_eq_int(Result, PChar(FWhereInt[I].Field), FWhereInt[I].Value);
    end;
    for I := Low(FWhereBool) to High(FWhereBool) do begin
      hk_query_where_eq_bool(Result, PChar(FWhereBool[I].Field), FWhereBool[I].Value);
    end;
    for I := Low(FWhereOrStr) to High(FWhereOrStr) do begin
      hk_query_where_or_str(Result, PChar(FWhereOrStr[I].Field), PChar(FWhereOrStr[I].Value));
    end;
    for I := Low(FWhereOrInt) to High(FWhereOrInt) do begin
      hk_query_where_or_int(Result, PChar(FWhereOrInt[I].Field), FWhereOrInt[I].Value);
    end;
    for I := Low(FWhereIn) to High(FWhereIn) do begin
      TmpArr := hk_array_new;
      for J := 0 to FWhereIn[I].Data.Count-1 do
        if FWhereIn[I].Data.Items[J].JSONType = jtNumber then hk_array_append_int(TmpArr, FWhereIn[I].Data.Items[J].AsInt64)
        else hk_array_append_str(TmpArr, PChar(FWhereIn[I].Data.Items[J].AsString));
      hk_query_where_in(Result, PChar(FWhereIn[I].Field), TmpArr);
    end;
    for I := Low(FWhereNotIn) to High(FWhereNotIn) do begin
      TmpArr := hk_array_new;
      for J := 0 to FWhereNotIn[I].Data.Count-1 do
        if FWhereNotIn[I].Data.Items[J].JSONType = jtNumber then hk_array_append_int(TmpArr, FWhereNotIn[I].Data.Items[J].AsInt64)
        else hk_array_append_str(TmpArr, PChar(FWhereNotIn[I].Data.Items[J].AsString));
      hk_query_where_not_in(Result, PChar(FWhereNotIn[I].Field), TmpArr);
    end;
    for I := Low(FWhereArrayContainsAny) to High(FWhereArrayContainsAny) do begin
      TmpArr := hk_array_new;
      for J := 0 to FWhereArrayContainsAny[I].Data.Count-1 do
        if FWhereArrayContainsAny[I].Data.Items[J].JSONType = jtNumber then hk_array_append_int(TmpArr, FWhereArrayContainsAny[I].Data.Items[J].AsInt64)
        else hk_array_append_str(TmpArr, PChar(FWhereArrayContainsAny[I].Data.Items[J].AsString));
      hk_query_where_array_contains_any(Result, PChar(FWhereArrayContainsAny[I].Field), TmpArr);
    end;
    
    if FStartAt <> nil then hk_query_start_at(Result, FStartAt);
    if FStartAfter <> nil then hk_query_start_after(Result, FStartAfter);
    if FStartAfterRaw <> nil then hk_query_start_after_raw(Result, FStartAfterRaw);
    if FEndAt <> nil then hk_query_end_at(Result, FEndAt);
    if FEndBefore <> nil then hk_query_end_before(Result, FEndBefore);

    if FOrderByField <> '' then hk_query_order_by(Result, PChar(FOrderByField), FOrderByAsc);
    if FHasLimit then hk_query_limit(Result, FLimit);
    if FHasOffset then hk_query_offset(Result, FOffset);
    for I := 0 to FSelectFields.Count - 1 do hk_query_select_field(Result, PChar(FSelectFields[I]));
if FDeferBlobs then hk_query_defer_blobs(Result, 1);
  except hk_query_free(Result); raise; end;
end;

function THKQuery.Count: Int64;
var Q: PHK_Query; J: TJSONObject; begin
  Q := BuildNativeQuery; try hk_query_aggregate_count(Q);
  J := TJSONObject(TJSONParser.Create(ConsumeCString(hk_query_execute_aggregation(FDB.Handle, Q))).Parse);
  Result := J.Get('count', 0); J.Free; finally hk_query_free(Q); end;
end;

function THKQuery.Sum(const Field: string): Double;
var Q: PHK_Query; J: TJSONObject; begin
  Q := BuildNativeQuery; try hk_query_aggregate_sum(Q, PChar(Field));
  J := TJSONObject(TJSONParser.Create(ConsumeCString(hk_query_execute_aggregation(FDB.Handle, Q))).Parse);
  Result := J.Get('sum_'+Field, 0.0); J.Free; finally hk_query_free(Q); end;
end;

function THKQuery.Avg(const Field: string): Double;
var Q: PHK_Query; J: TJSONObject; begin
  Q := BuildNativeQuery; try hk_query_aggregate_avg(Q, PChar(Field));
  J := TJSONObject(TJSONParser.Create(ConsumeCString(hk_query_execute_aggregation(FDB.Handle, Q))).Parse);
  Result := J.Get('avg_'+Field, 0.0); J.Free; finally hk_query_free(Q); end;
end;

function THKQuery.GetJSON: string;
var Q: PHK_Query; begin Q := BuildNativeQuery; try Result := ConsumeCString(hk_query_execute(FDB.Handle, Q)); finally hk_query_free(Q); end; end;

{ THKRawDoc }

constructor THKRawDoc.CreateBorrowed(ADB: THako; AHandle: PHK_RawDoc);
begin FDB := ADB; FHandle := AHandle; end;

function THKRawDoc.Id: string;
var P: PChar; L: SizeUInt;
begin
  P := hk_rawdoc_id(FHandle, @L);
  if (P = nil) or (L = 0) then Exit('');
  SetString(Result, P, L);
end;

function THKRawDoc.Bytes: TBytes;
var P: PByte; L: SizeUInt;
begin
  P := hk_rawdoc_bytes(FHandle, @L);
  if P = nil then Exit(nil);
  SetLength(Result, L);
  if L > 0 then Move(P^, Result[0], L);
end;

function THKRawDoc.Resolve(const Collection: string): THKDocument;
var H: PHK_Doc;
begin
  H := hk_rawdoc_to_doc(FDB.Handle, FHandle, PChar(Collection));
  if H = nil then raise EHakoError.Create('hk_rawdoc_to_doc failed: ' + string(hk_last_error));
  Result := THKDocument.CreateFromHandle(H, True);
end;

{ THKRawResultSet }

constructor THKRawResultSet.Create(ADB: THako; AHandle: PHK_RawResultSet);
begin FDB := ADB; FHandle := AHandle; end;

destructor THKRawResultSet.Destroy;
begin Free; inherited; end;

function THKRawResultSet.Count: NativeUInt;
begin Result := hk_rawresult_count(FHandle); end;

function THKRawResultSet.Get(Index: NativeUInt): THKRawDoc;
var H: PHK_RawDoc;
begin
  H := hk_rawresult_get(FHandle, Index);
  if H = nil then raise EHakoError.Create('raw row out of range');
  Result := THKRawDoc.CreateBorrowed(FDB, H);
end;

procedure THKRawResultSet.Free;
begin if FHandle <> nil then begin hk_rawresult_free(FHandle); FHandle := nil; end; end;

function THKQuery.StartAfterRaw(ARaw: THKRawDoc): THKQuery;
begin FStartAfterRaw := ARaw.Handle; Result := Self; end;

function THKQuery.ExecuteRaw: THKRawResultSet;
var Q: PHK_Query; H: PHK_RawResultSet;
begin
  Q := BuildNativeQuery; try
    H := hk_query_execute_raw(FDB.Handle, Q);
    if H = nil then raise EHakoError.Create('hk_query_execute_raw failed: ' + string(hk_last_error));
    Result := THKRawResultSet.Create(FDB, H);
  finally hk_query_free(Q); end;
end;

function THKQuery.Walk(Callback: THK_WalkCallback; UserData: Pointer): Int64;
var Q: PHK_Query;
begin
  Q := BuildNativeQuery; try
    Result := hk_cursor_walk(FDB.Handle, Q, Callback, UserData);
    if Result < 0 then raise EHakoError.Create('hk_cursor_walk failed: ' + string(hk_last_error));
  finally hk_query_free(Q); end;
end;

function THKQuery.WalkView(Callback: THK_ViewWalkCallback; UserData: Pointer): Int64;
var Q: PHK_Query;
begin
  Q := BuildNativeQuery; try
    Result := hk_cursor_walk_view(FDB.Handle, Q, Callback, UserData);
    if Result < 0 then raise EHakoError.Create('hk_cursor_walk_view failed: ' + string(hk_last_error));
  finally hk_query_free(Q); end;
end;

{ THKViewDoc }

constructor THKViewDoc.Create(AHandle: PHK_ViewDoc);
begin FHandle := AHandle; end;

destructor THKViewDoc.Destroy;
begin if FHandle <> nil then hk_view_free(FHandle); inherited; end;

function THKViewDoc.FieldCount: NativeUInt;
begin Result := hk_view_field_count(FHandle); end;

function THKViewDoc.HasField(const Key: string): Boolean;
begin Result := hk_view_has_field(FHandle, PChar(Key)); end;

function THKViewDoc.GetInt(const Key: string; out Value: Int64): Boolean;
var V: Int64;
begin
  Result := hk_view_get_int(FHandle, PChar(Key), @V);
  if Result then Value := V;
end;

function THKViewDoc.GetFloat(const Key: string; out Value: Double): Boolean;
var V: Double;
begin
  Result := hk_view_get_float(FHandle, PChar(Key), @V);
  if Result then Value := V;
end;

function THKViewDoc.GetBool(const Key: string; out Value: Boolean): Boolean;
var R: cint32;
begin
  R := hk_view_get_bool(FHandle, PChar(Key));
  Result := R >= 0;
  if Result then Value := R <> 0;
end;

function THKViewDoc.GetStr(const Key: string): string;
var P: PChar; L: SizeUInt;
begin
  P := hk_view_get_str(FHandle, PChar(Key), @L);
  if (P = nil) or (L = 0) then Exit('');
  SetString(Result, P, L);
end;

function THKViewDoc.GetBytes(const Key: string): TBytes;
var P: PByte; L: SizeUInt;
begin
  P := hk_view_get_bytes(FHandle, PChar(Key), @L);
  if P = nil then Exit(nil);
  SetLength(Result, L);
  if L > 0 then Move(P^, Result[0], L);
end;

function THKViewDoc.ToDoc(const DocID: string): THKDocument;
var H: PHK_Doc;
begin
  H := hk_view_to_doc(FHandle, PChar(DocID));
  if H = nil then raise EHakoError.Create('hk_view_to_doc failed: ' + string(hk_last_error));
  Result := THKDocument.CreateFromHandle(H, True);
end;

function THKQuery.WhereOrStr(const Field, Value: string): THKQuery;
begin
  SetLength(FWhereOrStr, Length(FWhereOrStr) + 1);
  FWhereOrStr[High(FWhereOrStr)].Field := Field;
  FWhereOrStr[High(FWhereOrStr)].Value := Value;
  Result := Self;
end;

function THKQuery.WhereOrInt(const Field: string; Value: Int64): THKQuery;
begin
  SetLength(FWhereOrInt, Length(FWhereOrInt) + 1);
  FWhereOrInt[High(FWhereOrInt)].Field := Field;
  FWhereOrInt[High(FWhereOrInt)].Value := Value;
  Result := Self;
end;

function THKQuery.Delete: Int64;
var Q: PHK_Query;
begin
  Q := BuildNativeQuery; try
    Result := hk_query_delete(FDB.Handle, Q);
  finally hk_query_free(Q); end;
end;

function THKQuery.DeleteLocal: Int64;
var Q: PHK_Query;
begin
  Q := BuildNativeQuery; try
    Result := hk_query_delete_local(FDB.Handle, Q);
  finally hk_query_free(Q); end;
end;

function THKQuery.Patch(Doc: THKDocument): Int64;
var Q: PHK_Query;
begin
  Q := BuildNativeQuery; try
    Result := hk_query_patch(FDB.Handle, Q, Doc.Handle);
  finally hk_query_free(Q); end;
end;

type
  THKPollingThread = class(TThread)
  private
    FQuery: THKQuery;
    FCallback: TOnSnapshotCallback;
    FQueueToMain: Boolean;
    FInterval: Cardinal;
    procedure DoCallback;
  protected
    procedure Execute; override;
  public
    constructor Create(AQuery: THKQuery; ACallback: TOnSnapshotCallback; AQueueToMain: Boolean; AInterval: Cardinal);
  end;

  THKPollingSubscription = class(TInterfacedObject, IFLSubscription)
  private
    FThread: THKPollingThread;
  public
    constructor Create(AThread: THKPollingThread);
    procedure Stop;
    destructor Destroy; override;
  end;

constructor THKPollingThread.Create(AQuery: THKQuery; ACallback: TOnSnapshotCallback; AQueueToMain: Boolean; AInterval: Cardinal);
begin
  inherited Create(False);
  FQuery := AQuery; FCallback := ACallback; FQueueToMain := AQueueToMain; FInterval := AInterval;
  FreeOnTerminate := False;
end;

procedure THKPollingThread.DoCallback;
begin
  FCallback(FQuery.GetJSON);
end;

procedure THKPollingThread.Execute;
begin
  while not Terminated do begin
    try
      if FQueueToMain then
        Queue(@DoCallback)
      else
        DoCallback;
    except end;
    Sleep(FInterval);
  end;
end;

constructor THKPollingSubscription.Create(AThread: THKPollingThread);
begin
  inherited Create;
  FThread := AThread;
end;

procedure THKPollingSubscription.Stop;
begin
  FThread.Terminate;
end;

destructor THKPollingSubscription.Destroy;
begin
  FThread.Terminate;
  FThread.WaitFor;
  FThread.Free;
  inherited;
end;

function THKQuery.OnSnapshot(const Callback: TOnSnapshotCallback; QueueToMainThread: Boolean): IFLSubscription;
begin
  Result := THKPollingSubscription.Create(THKPollingThread.Create(Self, Callback, QueueToMainThread, 1000));
end;

{ THKDocumentRef }

constructor THKDocumentRef.Create(ADB: THako; const ACollection, ADocID: string);
begin
  inherited Create;
  FDB := ADB; FCollection := ACollection; FDocID := ADocID;
end;

procedure THKDocumentRef.SetDoc(const Doc: THKDocument);
begin
  CheckStatus(hk_engine_insert(FDB.Handle, PChar(FCollection), PChar(FDocID), Doc.Handle), 'DocRefSet');
end;

function THKDocumentRef.Get: THKDocument;
var H: PHK_Doc;
begin
  H := hk_engine_get(FDB.Handle, PChar(FCollection), PChar(FDocID));
  if H = nil then Exit(nil);
  Result := THKDocument.CreateFromHandle(H, True);
end;

procedure THKDocumentRef.Delete;
begin
  CheckStatus(hk_engine_delete(FDB.Handle, PChar(FCollection), PChar(FDocID)), 'DocRefDelete');
end;

procedure THKDocumentRef.DeleteLocal;
begin
  CheckStatus(hk_engine_delete_local(FDB.Handle, PChar(FCollection), PChar(FDocID)), 'DocRefDeleteLocal');
end;

{ THKCollection }

constructor THKCollection.Create(ADB: THako; const AName: string); begin inherited Create; FDB := ADB; FName := AName; end;
function THKCollection.Doc(const DocID: string): THKDocumentRef; begin Result := THKDocumentRef.Create(FDB, FName, DocID); end;
function THKCollection.Query: THKQuery; begin Result := THKQuery.Create(FDB, FName); end;
function THKCollection.WhereEqStr(const Field, Value: string): THKQuery; begin Result := Query.WhereEqStr(Field, Value); end;
function THKCollection.WhereEqInt(const Field: string; Value: Int64): THKQuery; begin Result := Query.WhereEqInt(Field, Value); end;
function THKCollection.Match(const Field, Value: string): THKQuery; begin Result := Query.Match(Field, Value); end;
function THKCollection.Limit(ACount: NativeUInt): THKQuery; begin Result := Query.Limit(ACount); end;

{ THKNetSyncer }

constructor THKNetSyncer.Create(ADBHandle: PHK_Engine; const Name, RoomKey: string);
begin
  inherited Create;
  FHandle := hk_net_syncer_new(ADBHandle, PChar(Name), PChar(RoomKey));
  if FHandle = nil then
    raise Exception.Create('CreateNetSyncer failed: ' + string(hk_last_error));
end;

destructor THKNetSyncer.Destroy;
begin
  if FHandle <> nil then hk_net_syncer_free(FHandle);
  inherited;
end;

procedure THKNetSyncer.Start(APort: Word);
begin
  CheckStatus(hk_net_syncer_start(FHandle, APort), 'NetSyncStart');
end;

procedure THKNetSyncer.SetDiscoveryMode(AMode: THKDiscoveryMode);
begin
  CheckStatus(hk_net_syncer_set_discovery(FHandle, Ord(AMode)), 'NetSyncSetDiscovery');
end;

function THKNetSyncer.StatusJSON: string;
begin
  Result := ConsumeCString(hk_net_syncer_status(FHandle));
end;

{ THKCloudSync }

constructor THKCloudSync.Create(ADBHandle: PHK_Engine; Mode: THKCloudSyncMode; const ClientID, RoomName, RoomKey, AuthToken: string);
begin
  inherited Create;
  FHandle := hk_cloud_sync_new(ADBHandle, Ord(Mode), PChar(ClientID), PChar(RoomName), PChar(RoomKey), PChar(AuthToken));
  if FHandle = nil then
    raise Exception.Create('CreateCloudSyncer failed: ' + string(hk_last_error));
end;

constructor THKCloudSync.CreateServer(ADBHandle: PHK_Engine; const ServerID, AuthToken: string);
begin
  inherited Create;
  FHandle := hk_cloud_sync_server_new(ADBHandle, PChar(ServerID), PChar(AuthToken));
  if FHandle = nil then
    raise Exception.Create('CreateCloudServerSyncer failed: ' + string(hk_last_error));
end;

constructor THKCloudSync.CreateClient(ADBHandle: PHK_Engine; const ClientID, RoomName, RoomKey, AuthToken: string);
begin
  inherited Create;
  FHandle := hk_cloud_sync_client_new(ADBHandle, PChar(ClientID), PChar(RoomName), PChar(RoomKey), PChar(AuthToken));
  if FHandle = nil then
    raise Exception.Create('CreateCloudClientSyncer failed: ' + string(hk_last_error));
end;

destructor THKCloudSync.Destroy;
begin
  if FHandle <> nil then hk_cloud_sync_free(FHandle);
  inherited;
end;

procedure THKCloudSync.Start(const Address: string);
begin
  CheckStatus(hk_cloud_sync_start(FHandle, PChar(Address)), 'CloudSyncStart');
end;

function THKCloudSync.StatusJSON: string;
begin
  Result := ConsumeCString(hk_cloud_sync_status(FHandle));
end;

procedure THKCloudSync.Stop;
begin
  hk_cloud_sync_stop(FHandle);
end;
procedure THKCollection.CreateIndex(const Field: string); begin CheckStatus(hk_engine_create_simple_index(FDB.Handle, PChar(FName), PChar(Field)), 'CreateIndex'); end;
procedure THKCollection.CreateFTSIndex(const Field: string); begin CheckStatus(hk_engine_create_fts_index(FDB.Handle, PChar(FName), PChar(Field)), 'CreateFTSIndex'); end;

procedure THKCollection.CreateCompositeIndex(const Fields: array of string);
var I: Integer; S: string;
begin
  S := '[';
  for I := Low(Fields) to High(Fields) do begin
    if I > Low(Fields) then S := S + ',';
    S := S + '{"field":"' + Fields[I] + '","desc":false}';
  end;
  S := S + ']';
  CheckStatus(hk_engine_create_index(FDB.Handle, PChar(FName), PChar(S)), 'CreateCompositeIndex');
end;

function THKCollection.ListIndexes: string;
begin Result := ConsumeCString(hk_engine_list_indexes(FDB.Handle, PChar(FName))); end;

{ THako }

constructor THako.Create(const DBPath: string); begin inherited Create; FHandle := hk_engine_open(PChar(DBPath)); end;
constructor THako.Create(const DBPath: string; AConfig: THKConfig); begin inherited Create; FHandle := hk_engine_open_with_config(PChar(DBPath), AConfig.Handle); AConfig.FHandle := nil; end;
destructor THako.Destroy; begin if FHandle <> nil then hk_engine_free(FHandle); inherited; end;
function THako.Collection(const Name: string): THKCollection; begin Result := THKCollection.Create(Self, Name); end;
function THako.StartBatch: THKBatch; begin Result := THKBatch.Create(FHandle); end;
function THako.StartTransaction: THKTransaction; begin Result := THKTransaction.Create(FHandle); end;
procedure THako.SetCollectionLocal(const ACollection: string; Local: Boolean);
var L: cint32;
begin
  if Local then L := 1 else L := 0;
  CheckStatus(hk_engine_set_collection_local(FHandle, PChar(ACollection), L), 'SetCollectionLocal');
end;
procedure THako.ReplicateKey(const ACollection, ADocID: string);
begin
  CheckStatus(hk_engine_replicate_key(FHandle, PChar(ACollection), PChar(ADocID)), 'ReplicateKey');
end;
procedure THako.ReplicateCollection(const ACollection: string);
begin
  CheckStatus(hk_engine_replicate_collection(FHandle, PChar(ACollection)), 'ReplicateCollection');
end;
function THako.VacuumCollection(const ACollection: string): Integer;
var R: cint32;
begin
  R := hk_engine_vacuum_collection(FHandle, PChar(ACollection));
  if R < 0 then CheckStatus(R, 'VacuumCollection');
  Result := R;
end;
function THako.CreateNetSyncer(const Name, RoomKey: string): THKNetSyncer; begin Result := THKNetSyncer.Create(FHandle, Name, RoomKey); end;
function THako.CreateCloudSyncer(Mode: THKCloudSyncMode; const ClientID, RoomName, RoomKey, AuthToken: string): THKCloudSync; begin Result := THKCloudSync.Create(FHandle, Mode, ClientID, RoomName, RoomKey, AuthToken); end;
function THako.CreateCloudServerSyncer(const ServerID, AuthToken: string): THKCloudSync; begin Result := THKCloudSync.CreateServer(FHandle, ServerID, AuthToken); end;
function THako.CreateCloudClientSyncer(const ClientID, RoomName, RoomKey, AuthToken: string): THKCloudSync; begin Result := THKCloudSync.CreateClient(FHandle, ClientID, RoomName, RoomKey, AuthToken); end;
function THako.Backup(const Path: string): Integer; begin Result := hk_engine_backup(FHandle, PChar(Path)); end;
procedure THako.Compact; begin CheckStatus(hk_engine_compact(FHandle), 'Compact'); end;
function THako.IsIndexesReady: Boolean; begin Result := hk_engine_is_indexes_ready(FHandle); end;

function THako.GetView(const Col, ID: string): THKViewDoc;
var H: PHK_ViewDoc;
begin
  H := hk_view_get(FHandle, PChar(Col), PChar(ID));
  if H = nil then Exit(nil);
  Result := THKViewDoc.Create(H);
end;
procedure THako.SnapshotIndices; begin CheckStatus(hk_engine_snapshot_indices(FHandle), 'SnapshotIndices'); end;
function THako.ListIndexes(const ACollection: string): string; begin Result := ConsumeCString(hk_engine_list_indexes(FHandle, PChar(ACollection))); end;
function THako.GetAuditLog: string; begin Result := ConsumeCString(hk_engine_get_audit_log(FHandle)); end;
function THako.InsertSubDoc(const Col, ID, SubCol, SubID: string; Doc: THKDocument): Integer;
begin Result := hk_engine_insert_subdoc(FHandle, PChar(Col), PChar(ID), PChar(SubCol), PChar(SubID), Doc.Handle); end;
function THako.GetByRef(Doc: THKDocument; const FieldKey: string): THKDocument;
var H: PHK_Doc;
begin
  H := hk_engine_get_by_ref(FHandle, Doc.Handle, PChar(FieldKey));
  if H = nil then Exit(nil);
  Result := THKDocument.CreateFromHandle(H, True);
end;
procedure THako.CreateCompositeIndex(const ACollection: string; const Fields: array of string);
var I: Integer; S: string;
begin
  S := '[';
  for I := Low(Fields) to High(Fields) do begin
    if I > Low(Fields) then S := S + ',';
    S := S + '{"field":"' + Fields[I] + '","desc":false}';
  end;
  S := S + ']';
  CheckStatus(hk_engine_create_index(FHandle, PChar(ACollection), PChar(S)), 'CreateCompositeIndex');
end;
function THako.ListCollections: TStringList; var S: string; P: TJSONParser; A: TJSONArray; I: Integer; begin Result := TStringList.Create; S := ConsumeCString(hk_engine_list_collections(FHandle)); if S = '' then Exit; P := TJSONParser.Create(S); try A := TJSONArray(P.Parse); for I := 0 to A.Count - 1 do Result.Add(A.Strings[I]); finally P.Free; end; end;
function THako.GetStats: string; begin Result := ConsumeCString(hk_engine_get_stats(FHandle)); end;

end.
