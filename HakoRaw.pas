unit HakoRaw;

{$mode objfpc}{$H+}

interface

uses
  ctypes;

type
  PHK_Engine = Pointer;
  PHK_Doc = Pointer;
  PHK_Batch = Pointer;
  PHK_Query = Pointer;
  PHK_Config = Pointer;
  PHK_Watch = Pointer;
  PHK_NetSyncer = Pointer;
  PHK_Array = Pointer;       // Added in v0.5.9
  PHK_Transaction = Pointer; // Added in v0.5.9
  PHK_ResultSet = Pointer;   // Added in v0.6.x
  PHK_CloudSync = Pointer;   // Added in v0.6.65
  PHK_RawDoc = Pointer;      // Added in v0.8.3
  PHK_RawResultSet = Pointer;// Added in v0.8.3
  PHK_ViewDoc = Pointer;     // Added in v0.8.11

  { Callback for real-time snapshots }
  THK_OnSnapshotCallback = procedure(collection: PChar; path: PChar; kind: cint32; user_data: Pointer); cdecl;
  { Raw walk callback (v0.8.6): return True to continue. Borrowed pointers,
    valid for the call only. Must not re-enter the engine. }
  THK_WalkCallback = function(id: PChar; id_len: SizeUInt; bytes: PByte; bytes_len: SizeUInt; user_data: Pointer): cbool; cdecl;
  { View-walk callback (v0.8.11): borrowed id + view handle, valid for the call only. }
  THK_ViewWalkCallback = function(id: PChar; id_len: SizeUInt; view: PHK_ViewDoc; user_data: Pointer): cbool; cdecl;

const
  HK_CHANGE_PUT = 1;
  HK_CHANGE_DELETE = 2;

{$if defined(Windows)}
const HAKO_LIB = 'hakodb.dll';
{$elseif defined(Darwin)}
const HAKO_LIB = 'libhakodb.dylib';
{$else}
const HAKO_LIB = 'libhakodb.so';
{$endif}

{ Engine Management }
function hk_engine_open(path: PChar): PHK_Engine; cdecl; external HAKO_LIB;
function hk_engine_is_indexes_ready(engine: PHK_Engine): cbool; cdecl; external HAKO_LIB;
function hk_engine_open_with_config(path: PChar; config: PHK_Config): PHK_Engine; cdecl; external HAKO_LIB;
procedure hk_engine_free(engine: PHK_Engine); cdecl; external HAKO_LIB;
function hk_engine_backup(engine: PHK_Engine; path: PChar): cint32; cdecl; external HAKO_LIB;
function hk_engine_compact(engine: PHK_Engine): cint32; cdecl; external HAKO_LIB;
function hk_engine_list_collections(engine: PHK_Engine): PChar; cdecl; external HAKO_LIB;
function hk_engine_list_indexes(engine: PHK_Engine; collection: PChar): PChar; cdecl; external HAKO_LIB;
function hk_engine_get_stats(engine: PHK_Engine): PChar; cdecl; external HAKO_LIB;
function hk_engine_get_audit_log(engine: PHK_Engine): PChar; cdecl; external HAKO_LIB;
function hk_engine_snapshot_indices(engine: PHK_Engine): cint32; cdecl; external HAKO_LIB;

{ Configuration Builder }
function hk_config_new: PHK_Config; cdecl; external HAKO_LIB;
procedure hk_config_free(config: PHK_Config); cdecl; external HAKO_LIB;
procedure hk_config_set_durability(config: PHK_Config; mode: cint32); cdecl; external HAKO_LIB;
procedure hk_config_set_encryption_key(config: PHK_Config; key: PChar); cdecl; external HAKO_LIB;
function hk_config_set_encrypted_collections(config: PHK_Config; collections_json: PChar): cint32; cdecl; external HAKO_LIB;
procedure hk_config_set_audit_log(config: PHK_Config; enabled: cbool; path: PChar); cdecl; external HAKO_LIB;
procedure hk_config_set_query_workers(config: PHK_Config; count: SizeUInt); cdecl; external HAKO_LIB;
procedure hk_config_set_memory_limits(config: PHK_Config; mmap_size, max_inlined_bytes: SizeUInt); cdecl; external HAKO_LIB;
procedure hk_config_set_storage_tuning(config: PHK_Config; page_size, compaction_threshold, group_commit_max_ops: SizeUInt); cdecl; external HAKO_LIB;
procedure hk_config_set_blob_threshold(config: PHK_Config; threshold_bytes: SizeUInt); cdecl; external HAKO_LIB;
procedure hk_config_set_wal_reserve_bytes(config: PHK_Config; bytes: QWord); cdecl; external HAKO_LIB;
procedure hk_config_set_compression(config: PHK_Config; enabled: cbool; level: cint32); cdecl; external HAKO_LIB;
{ Hold background maintenance (deterministic benchmarks). Default on. }
procedure hk_config_set_background_maintenance(config: PHK_Config; enabled: cbool); cdecl; external HAKO_LIB;

{ Real-time Snapshots }
function hk_engine_watch(engine: PHK_Engine; collection: PChar; callback: THK_OnSnapshotCallback; user_data_ptr: Pointer): PHK_Watch; cdecl; external HAKO_LIB;
procedure hk_watch_free(watch: PHK_Watch); cdecl; external HAKO_LIB;

{ Document Builder }
function hk_doc_new: PHK_Doc; cdecl; external HAKO_LIB;
procedure hk_doc_free(doc: PHK_Doc); cdecl; external HAKO_LIB;
function hk_doc_insert_str(doc: PHK_Doc; key, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_doc_insert_int(doc: PHK_Doc; key: PChar; value: cint64): cint32; cdecl; external HAKO_LIB;
function hk_doc_insert_float(doc: PHK_Doc; key: PChar; value: cdouble): cint32; cdecl; external HAKO_LIB;
function hk_doc_insert_bool(doc: PHK_Doc; key: PChar; value: cbool): cint32; cdecl; external HAKO_LIB;
function hk_doc_insert_null(doc: PHK_Doc; key: PChar): cint32; cdecl; external HAKO_LIB;
function hk_doc_insert_bin(doc: PHK_Doc; key: PChar; data: PByte; len: SizeUInt): cint32; cdecl; external HAKO_LIB;
function hk_doc_insert_timestamp(doc: PHK_Doc; key: PChar; micros: cint64): cint32; cdecl; external HAKO_LIB;
function hk_doc_insert_server_timestamp(doc: PHK_Doc; key: PChar): cint32; cdecl; external HAKO_LIB;
function hk_doc_insert_doc(parent: PHK_Doc; key: PChar; child: PHK_Doc): cint32; cdecl; external HAKO_LIB;
function hk_doc_insert_array(doc: PHK_Doc; key: PChar; arr: PHK_Array): cint32; cdecl; external HAKO_LIB;
function hk_doc_insert_reference(doc: PHK_Doc; key, target_col, target_id: PChar): cint32; cdecl; external HAKO_LIB;
function hk_doc_to_json(doc: PHK_Doc): PChar; cdecl; external HAKO_LIB;

{ Array Builder }
function hk_array_new: PHK_Array; cdecl; external HAKO_LIB;
procedure hk_array_free(arr: PHK_Array); cdecl; external HAKO_LIB;
function hk_array_append_str(arr: PHK_Array; value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_array_append_int(arr: PHK_Array; value: cint64): cint32; cdecl; external HAKO_LIB;
function hk_array_append_doc(arr: PHK_Array; doc: PHK_Doc): cint32; cdecl; external HAKO_LIB;

{ Sharded Operations }
function hk_engine_insert(engine: PHK_Engine; col, doc_id: PChar; doc: PHK_Doc): cint32; cdecl; external HAKO_LIB;
{ Owned-doc insert: consumes the HK_Doc handle (no deep clone). Do not use or free doc afterwards. }
function hk_engine_insert_take(engine: PHK_Engine; col, doc_id: PChar; doc: PHK_Doc): cint32; cdecl; external HAKO_LIB;
{ Resolve deferred blob fields of a query-returned doc in place. }
function hk_doc_resolve_blobs(engine: PHK_Engine; col: PChar; doc: PHK_Doc): cint32; cdecl; external HAKO_LIB;
function hk_engine_get(engine: PHK_Engine; col, doc_id: PChar): PHK_Doc; cdecl; external HAKO_LIB;
function hk_engine_delete(engine: PHK_Engine; col, doc_id: PChar): cint32; cdecl; external HAKO_LIB;
function hk_engine_delete_local(engine: PHK_Engine; col, doc_id: PChar): cint32; cdecl; external HAKO_LIB;
function hk_engine_set_collection_local(engine: PHK_Engine; col: PChar; local: cint32): cint32; cdecl; external HAKO_LIB;
function hk_engine_replicate_key(engine: PHK_Engine; col, doc_id: PChar): cint32; cdecl; external HAKO_LIB;
function hk_engine_replicate_collection(engine: PHK_Engine; col: PChar): cint32; cdecl; external HAKO_LIB;
function hk_engine_vacuum_collection(engine: PHK_Engine; col: PChar): cint32; cdecl; external HAKO_LIB;
{ Archive (v0.12.3+): move docs src -> dst, reporting moved vs missing as
  JSON {"moved":[...],"missing":[...]}. Free the report with hk_string_free. }
function hk_engine_relocate_docs(engine: PHK_Engine; src, dst, ids_json: PChar): PChar; cdecl; external HAKO_LIB;
{ Load a lazy collection now (0 ok); unload it (-1 unless lazy). }
function hk_engine_load_collection(engine: PHK_Engine; col: PChar): cint32; cdecl; external HAKO_LIB;
function hk_engine_unload_collection(engine: PHK_Engine; col: PChar): cint32; cdecl; external HAKO_LIB;
{ Lazy collections currently out of the index, as a JSON array. }
function hk_engine_unloaded_collections(engine: PHK_Engine): PChar; cdecl; external HAKO_LIB;
function hk_engine_patch(engine: PHK_Engine; col, doc_id: PChar; updates: PHK_Doc): cint32; cdecl; external HAKO_LIB;
function hk_engine_get_by_ref(engine: PHK_Engine; doc: PHK_Doc; field_key: PChar): PHK_Doc; cdecl; external HAKO_LIB;
function hk_engine_insert_subdoc(engine: PHK_Engine; col, id, sub_col, sub_id: PChar; doc: PHK_Doc): cint32; cdecl; external HAKO_LIB;

{ Atomic Batches }
function hk_batch_new: PHK_Batch; cdecl; external HAKO_LIB;
procedure hk_batch_free(batch: PHK_Batch); cdecl; external HAKO_LIB;
function hk_batch_set(batch: PHK_Batch; col, doc_id: PChar; doc: PHK_Doc): cint32; cdecl; external HAKO_LIB;
function hk_batch_delete(batch: PHK_Batch; col, doc_id: PChar): cint32; cdecl; external HAKO_LIB;
function hk_batch_commit(engine: PHK_Engine; batch: PHK_Batch): cint32; cdecl; external HAKO_LIB;

{ Serializable Transactions }
function hk_transaction_begin(engine: PHK_Engine): PHK_Transaction; cdecl; external HAKO_LIB;
function hk_transaction_get(engine: PHK_Engine; tx: PHK_Transaction; col, id: PChar): PHK_Doc; cdecl; external HAKO_LIB;
function hk_transaction_set(tx: PHK_Transaction; col, id: PChar; doc: PHK_Doc): cint32; cdecl; external HAKO_LIB;
function hk_transaction_commit(engine: PHK_Engine; tx: PHK_Transaction): cint32; cdecl; external HAKO_LIB;
procedure hk_transaction_free(tx: PHK_Transaction); cdecl; external HAKO_LIB;

{ Queries }
function hk_query_new(collection: PChar): PHK_Query; cdecl; external HAKO_LIB;
procedure hk_query_free(query: PHK_Query); cdecl; external HAKO_LIB;
function hk_query_where_eq_str(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_where_eq_bool(query: PHK_Query; field: PChar; value: cbool): cint32; cdecl; external HAKO_LIB;
function hk_query_where_eq_int(query: PHK_Query; field: PChar; value: cint64): cint32; cdecl; external HAKO_LIB;
function hk_query_where_ne_str(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_where_ne_int(query: PHK_Query; field: PChar; value: cint64): cint32; cdecl; external HAKO_LIB;
function hk_query_where_gt_str(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_where_gt_int(query: PHK_Query; field: PChar; value: cint64): cint32; cdecl; external HAKO_LIB;
function hk_query_where_gte_str(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_where_gte_int(query: PHK_Query; field: PChar; value: cint64): cint32; cdecl; external HAKO_LIB;
function hk_query_where_lt_str(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_where_lt_int(query: PHK_Query; field: PChar; value: cint64): cint32; cdecl; external HAKO_LIB;
function hk_query_where_lte_str(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_where_lte_int(query: PHK_Query; field: PChar; value: cint64): cint32; cdecl; external HAKO_LIB;
function hk_query_where_or_str(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_where_or_int(query: PHK_Query; field: PChar; value: cint64): cint32; cdecl; external HAKO_LIB;
function hk_query_where_in(query: PHK_Query; field: PChar; arr: PHK_Array): cint32; cdecl; external HAKO_LIB;
function hk_query_where_not_in(query: PHK_Query; field: PChar; arr: PHK_Array): cint32; cdecl; external HAKO_LIB;
function hk_query_where_array_contains_any(query: PHK_Query; field: PChar; arr: PHK_Array): cint32; cdecl; external HAKO_LIB;
function hk_query_where_array_contains(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_order_by(query: PHK_Query; field: PChar; ascending: cbool): cint32; cdecl; external HAKO_LIB;
function hk_query_limit(query: PHK_Query; limit: SizeUInt): cint32; cdecl; external HAKO_LIB;
function hk_query_offset(query: PHK_Query; offset: SizeUInt): cint32; cdecl; external HAKO_LIB;
function hk_query_select_field(query: PHK_Query; field: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_defer_blobs(query: PHK_Query; defer: cint32): cint32; cdecl; external HAKO_LIB;
function hk_query_execute(engine: PHK_Engine; query: PHK_Query): PChar; cdecl; external HAKO_LIB;
function hk_query_delete(engine: PHK_Engine; query: PHK_Query): cint32; cdecl; external HAKO_LIB;
function hk_query_delete_local(engine: PHK_Engine; query: PHK_Query): cint32; cdecl; external HAKO_LIB;
function hk_query_patch(engine: PHK_Engine; query: PHK_Query; patch_doc: PHK_Doc): cint32; cdecl; external HAKO_LIB;
function hk_query_execute_to_handles(engine: PHK_Engine; query: PHK_Query): PHK_ResultSet; cdecl; external HAKO_LIB;
function hk_result_set_count(results: PHK_ResultSet): SizeUInt; cdecl; external HAKO_LIB;
function hk_result_set_get_doc(results: PHK_ResultSet; index: SizeUInt): PHK_Doc; cdecl; external HAKO_LIB;
procedure hk_result_set_free(results: PHK_ResultSet); cdecl; external HAKO_LIB;
{ Bulk result-set to JSON: one call, one JSON array string. Free with hk_string_free. }
function hk_result_set_to_json(results: PHK_ResultSet): PChar; cdecl; external HAKO_LIB;
{ Borrowed views (v0.8.11): pinned bytes + lazy typed pulls, no owned
  construction. Strict scalar matches; views never inflate blobs. }
function hk_view_get(engine: PHK_Engine; col, doc_id: PChar): PHK_ViewDoc; cdecl; external HAKO_LIB;
procedure hk_view_free(view: PHK_ViewDoc); cdecl; external HAKO_LIB;
function hk_view_field_count(view: PHK_ViewDoc): SizeUInt; cdecl; external HAKO_LIB;
function hk_view_has_field(view: PHK_ViewDoc; key: PChar): cbool; cdecl; external HAKO_LIB;
function hk_view_get_int(view: PHK_ViewDoc; key: PChar; out_value: PInt64): cbool; cdecl; external HAKO_LIB;
function hk_view_get_float(view: PHK_ViewDoc; key: PChar; out_value: PDouble): cbool; cdecl; external HAKO_LIB;
function hk_view_get_bool(view: PHK_ViewDoc; key: PChar): cint32; cdecl; external HAKO_LIB;
function hk_view_get_str(view: PHK_ViewDoc; key: PChar; len_out: PSizeUInt): PChar; cdecl; external HAKO_LIB;
function hk_view_get_bytes(view: PHK_ViewDoc; key: PChar; len_out: PSizeUInt): PByte; cdecl; external HAKO_LIB;
function hk_view_to_doc(view: PHK_ViewDoc; doc_id: PChar): PHK_Doc; cdecl; external HAKO_LIB;
{ View-walk callback: borrowed id + view handle, valid for the call only. }
{ Lazy view walk (v0.8.11+): one call per scan. Returns rows visited, -1 on error. }
function hk_cursor_walk_view(engine: PHK_Engine; query: PHK_Query; callback: THK_ViewWalkCallback; user_data: Pointer): Int64; cdecl; external HAKO_LIB;
{ Raw result sets (v0.8.3): pinned storage bytes, not decoded docs.
  Borrowed-handle contract mirrors HK_ResultSet. Bytes are opaque. }
function hk_query_execute_raw(engine: PHK_Engine; query: PHK_Query): PHK_RawResultSet; cdecl; external HAKO_LIB;
function hk_rawresult_count(results: PHK_RawResultSet): SizeUInt; cdecl; external HAKO_LIB;
function hk_rawresult_get(results: PHK_RawResultSet; index: SizeUInt): PHK_RawDoc; cdecl; external HAKO_LIB;
procedure hk_rawresult_free(results: PHK_RawResultSet); cdecl; external HAKO_LIB;
function hk_rawdoc_bytes(doc: PHK_RawDoc; len_out: PSizeUInt): PByte; cdecl; external HAKO_LIB;
function hk_rawdoc_id(doc: PHK_RawDoc; len_out: PSizeUInt): PChar; cdecl; external HAKO_LIB;
function hk_query_start_after_raw(query: PHK_Query; anchor: PHK_RawDoc): cint32; cdecl; external HAKO_LIB;
function hk_rawdoc_to_doc(engine: PHK_Engine; raw_doc: PHK_RawDoc; collection: PChar): PHK_Doc; cdecl; external HAKO_LIB;
{ Zero-alloc walk (v0.8.6): one call per scan. Returns rows visited, -1 on error. }
function hk_cursor_walk(engine: PHK_Engine; query: PHK_Query; callback: THK_WalkCallback; user_data: Pointer): Int64; cdecl; external HAKO_LIB;
function hk_query_where_match(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_where_match_prefix(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_where_contains(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_where_starts_with(query: PHK_Query; field, value: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_start_at(query: PHK_Query; anchor: PHK_Doc): cint32; cdecl; external HAKO_LIB;
function hk_query_start_after(query: PHK_Query; anchor: PHK_Doc): cint32; cdecl; external HAKO_LIB;
function hk_query_end_at(query: PHK_Query; anchor: PHK_Doc): cint32; cdecl; external HAKO_LIB;
function hk_query_end_before(query: PHK_Query; anchor: PHK_Doc): cint32; cdecl; external HAKO_LIB;

{ Aggregates }
function hk_query_aggregate_count(query: PHK_Query): cint32; cdecl; external HAKO_LIB;
function hk_query_aggregate_sum(query: PHK_Query; field: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_aggregate_avg(query: PHK_Query; field: PChar): cint32; cdecl; external HAKO_LIB;
function hk_query_execute_aggregation(engine: PHK_Engine; query: PHK_Query): PChar; cdecl; external HAKO_LIB;

{ Manual Indexing }
function hk_engine_create_index(engine: PHK_Engine; col, json_def: PChar): cuint32; cdecl; external HAKO_LIB;
function hk_engine_create_simple_index(engine: PHK_Engine; col, field: PChar): cint32; cdecl; external HAKO_LIB;
function hk_engine_create_fts_index(engine: PHK_Engine; col, field: PChar): cint32; cdecl; external HAKO_LIB;

{ Net Sync }
function hk_net_syncer_new(engine: PHK_Engine; name, room_key: PChar): PHK_NetSyncer; cdecl; external HAKO_LIB;
function hk_net_syncer_start(syncer: PHK_NetSyncer; port: Word): cint32; cdecl; external HAKO_LIB;
function hk_net_syncer_set_discovery(syncer: PHK_NetSyncer; mode: cint32): cint32; cdecl; external HAKO_LIB;
function hk_net_syncer_status(syncer: PHK_NetSyncer): PChar; cdecl; external HAKO_LIB;
procedure hk_net_syncer_free(syncer: PHK_NetSyncer); cdecl; external HAKO_LIB;

{ Cloud Sync }
function hk_cloud_sync_new(engine: PHK_Engine; mode: cint32; client_id, room_name, room_key, auth_token: PChar): PHK_CloudSync; cdecl; external HAKO_LIB;
function hk_cloud_sync_server_new(engine: PHK_Engine; server_id, auth_token: PChar): PHK_CloudSync; cdecl; external HAKO_LIB;
function hk_cloud_sync_client_new(engine: PHK_Engine; client_id, room_name, room_key, auth_token: PChar): PHK_CloudSync; cdecl; external HAKO_LIB;
function hk_cloud_sync_start(cloud_sync: PHK_CloudSync; address: PChar): cint32; cdecl; external HAKO_LIB;
function hk_cloud_sync_status(cloud_sync: PHK_CloudSync): PChar; cdecl; external HAKO_LIB;
procedure hk_cloud_sync_stop(cloud_sync: PHK_CloudSync); cdecl; external HAKO_LIB;
procedure hk_cloud_sync_free(cloud_sync: PHK_CloudSync); cdecl; external HAKO_LIB;

{ Errors and Helpers }
function hk_last_error: PChar; cdecl; external HAKO_LIB;
procedure hk_string_free(value: PChar); cdecl; external HAKO_LIB;

implementation
end.
