# justjavac/global_hotkey

Cross-platform native global hotkey helpers for MoonBit.

This package targets `native` and supports Windows, macOS, and Linux X11 sessions.

## Install

```bash
moon add justjavac/global_hotkey
```

## Example

```mbt check
test "global_hotkey can be probed safely" {
  ignore(@global_hotkey.is_supported())
  match @global_hotkey.create() {
    Ok(manager) => manager.destroy()
    Err(_) => ()
  }
}
```

Full platform notes, coverage badges, and usage guidance live in [README.md](README.md).
