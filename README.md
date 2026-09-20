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
