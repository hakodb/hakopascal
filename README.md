# firelite-pascal

Lazarus/Free Pascal wrapper for
[FireLite](https://github.com/rizaptk/firelite) with a Firestore-style API
plus design-time components: `FireLiteRaw.pas` (flat `cdecl` FFI over
`firelite.dll`), `FireLite.pas` (ergonomic layer), `FireLiteComponent.pas`
/ `FireLitePkg{,Reg}` / `FireLiteDesign` (Lazarus packages).

## Compatibility

| firelite-pascal | firelite core |
|---|---|
| 0.1.1 | `cloud_sync` branch / `v0.8.20`+ release asset |

## Setup — native library

The units link `firelite.dll` by filename: put it next to your binary,
on `PATH`, or under `./native/` (populated by the sync script):

```powershell
.\sync-native.ps1 -CoreDir C:\Dev\libs\firelite
.\sync-native.ps1 -Tag v0.8.20
```

Binaries under `native/` are git-ignored. The old committed
`libimpFireLiteRaw.a` was dropped: unreferenced by any source and
regenerable per toolchain.

## Usage

- `FireLiteRaw.pas` — C-ABI translation with opaque handles (`PFL_Engine`, `PFL_Doc`, `PFL_Batch`, `PFL_Query`, `PFL_ResultSet`, `PFL_CloudSync`, …) and `cdecl` imports for Windows/Linux/macOS.
- `FireLite.pas` — object-oriented API: `TFireLite`, `TFLCollection`, `TFLDocument`, `TFLQuery`, `TFLBatch`, `TFLTransaction`, `TFLCloudSync`.
  - fluent Firestore-like flow (`Collection(...).Doc(...).SetDoc/Get/Delete`, query chaining)
  - deferred blobs (`TFLQuery.DeferBlobs`) returning `__blob__` placeholders for list views
  - projection pushdown (`Select([...])`) wired to `fl_query_select_field`
  - advanced filters (`WhereNotIn`, `ArrayContains`, `ArrayContainsAny`, `WhereOr*`) mapped to FFI
  - callback-based `OnSnapshot` via a polling thread with optional main-thread queue dispatch.

```pascal
var
  DB: TFireLite;
  Col: TFLCollection;
  Doc: TFLDocument;
begin
  DB := TFireLite.Create('./data.firelite');
  try
    Col := DB.Collection('users');
    Doc := TFLDocument.Create.InsertStr('name', 'alice').InsertInt('age', 30);
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

- `FireLitePkg.lpk` — **runtime**: `FireLiteRaw`, `FireLite`, `FireLiteComponent`. Add it via Project Inspector → Add → New Requirement to use the SDK from code.
- `FireLiteDesign.lpk` — **designtime** (requires `FireLitePkg`): `FireLitePkgReg` with the `Register` procedure. Open it via `Package > Open Package File (.lpk)`, Compile, then **Install** — a **FireLite** tab with `TFireLiteComponent` appears on the component palette.
- `FireLiteComponent.pas` — the drop-on-form component. Sync is opt-in: `NetSyncEnabled` / `CloudSyncEnabled` default to False (`StartNetSync` / `StartCloudSync` raise otherwise).

## Check

```sh
fpc -S2 -Cn FireLiteRaw.pas
fpc -S2 -Cn FireLite.pas
```

Both units compile warning-free apart from four pre-existing
`TStringList.Create` deprecation hints. Full runtime check needs a
64-bit FPC (the bundled toolchain here is i386-only, while the
shipped DLL is x86_64); the Lazarus `.lpk` packages additionally need
`lazbuild`, not present on this machine.

## Examples

- `examples/console/console_demo.lpr` — CRUD, query, batch, sync;
  compiles clean (`fpc -S2 -Fu../..`), run needs the 64-bit DLL.
- `examples/lazarus/` — minimal form demo using `TFireLiteComponent`
  (needs Lazarus/`lazbuild`; compile paths already point at this repo).
