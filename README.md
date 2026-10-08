# hakopascal

> Part of [**HakoDB**](https://github.com/hakodb/hakodb) — embedded Firestore-style NoSQL document DB in Rust. The engine + C ABI (`hakodb.dll` / `libhakodb.so`) live in `hakodb/hakodb`; this repo holds the Lazarus/Free Pascal wrapper.

Lazarus/Free Pascal wrapper for HakoDB with a Firestore-style API
plus design-time components: `HakoRaw.pas` (flat `cdecl` FFI over
`hakodb.dll`), `Hako.pas` (ergonomic layer), `HakoComponent.pas`
/ `HakoPkg{,Reg}` / `HakoDesign` (Lazarus packages).

## Compatibility

| hakopascal | hako core |
|---|---|
| 0.1.1 | `cloud_sync` branch / `v0.8.21`+ release asset |
| 0.1.2 | `hakodb v0.12.3` (archive: RelocateDocs/Load/Unload/UnloadedCollections) |

## Setup — native library

The units link `hakodb.dll` by filename: put it next to your binary,
on `PATH`, or under `./native/` (populated by the sync script):

```powershell
.\sync-native.ps1 -CoreDir C:\Dev\libs\firelite
.\sync-native.ps1 -Tag v0.8.21
```

Binaries under `native/` are git-ignored.

## Usage

- `HakoRaw.pas` — C-ABI translation with opaque handles (`PHK_Engine`,
`PHK_Doc`, `PHK_Batch`, `PHK_Query`, `PHK_ResultSet`, `PHK_CloudSync`, …) and `cdecl` imports for Windows/Linux/macOS.
- `Hako.pas` — object-oriented API: `THako`, `THKCollection`,
`THKDocument`, `THKQuery`, `THKBatch`, `THKTransaction`, `THKCloudSync`.
  - fluent Firestore-like flow (`Collection(...).Doc(...).SetDoc/Get/Delete`, query chaining)
  - deferred blobs (`THKQuery.DeferBlobs`) returning `__blob__` placeholders for list views
  - projection pushdown (`Select([...])`) wired to `hk_query_select_field`
  - advanced filters (`WhereNotIn`, `ArrayContains`, `ArrayContainsAny`, `WhereOr*`) mapped to FFI
  - callback-based `OnSnapshot` via a polling thread with optional main-thread queue dispatch.

```pascal
var
  DB: THako;
  Col: THKCollection;
  Doc: THKDocument;
begin
  DB := THako.Create('./data.hakodb');
  try
    Col := DB.Collection('users');
    Doc := THKDocument.Create.InsertStr('name', 'alice').InsertInt('age', 30);
    try
      Col.Doc('u1').SetDoc(Doc);
    finally
      Doc.Free;
    end;
  finally
    DB.Free;
  end;
end;
```

The wrapper ships as two Lazarus packages (the standard runtime/designtime
split — a single mixed package will not install):

- `HakoPkg.lpk` — **runtime**: `HakoRaw`, `Hako`, `HakoComponent`. Add it via Project Inspector → Add → New Requirement to use the SDK from code.
- `HakoDesign.lpk` — **designtime** (requires `HakoPkg`): `HakoPkgReg` with the `Register` procedure. Open it via `Package > Open Package File (.lpk)`, Compile, then **Install** — a **HakoDB** tab with `THakoComponent` appears on the component palette.
- `HakoComponent.pas` — the drop-on-form component. Sync is opt-in: `NetSyncEnabled` / `CloudSyncEnabled` default to False (`StartNetSync` / `StartCloudSync` raise otherwise).

## Check

```sh
fpc -S2 -Cn HakoRaw.pas
fpc -S2 -Cn Hako.pas
```

Both units compile warning-free apart from four pre-existing
`TStringList.Create` deprecation hints. Full runtime check needs a
64-bit FPC (the bundled toolchain here is i386-only, while the
shipped DLL is x86_64); the Lazarus `.lpk` packages additionally need
`lazbuild`, not present on this machine.

## Examples

- `examples/console/console_demo.lpr` — CRUD, query, batch, sync;
  compiles clean (`fpc -S2 -Fu../..`), run needs the 64-bit DLL.
- `examples/lazarus/` — minimal form demo using `THakoComponent`
  (needs Lazarus/`lazbuild`; compile paths already point at this repo).
