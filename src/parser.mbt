///|
/// Stores the normalized shortcut data passed into the native backend.
struct ParsedGlobalHotkey {
  normalized : String
  modifiers : Int
  key_name : String
} derive(Show, Eq)

///|
/// Normalizes a single modifier or key token for case-insensitive matching.
fn normalize_keyword(raw : String) -> String {
  raw.trim().to_string().to_lower()
}

///|
/// Converts modifier booleans into the backend's logical modifier bitset.
fn modifier_mask(control : Bool, shift : Bool, alt : Bool, meta : Bool) -> Int {
  let mut mask = 0
  if alt {
    mask += 0x0001
  }
  if control {
    mask += 0x0002
  }
  if shift {
    mask += 0x0004
  }
  if meta {
    mask += 0x0008
  }
  mask
}

///|
/// Renders a normalized accelerator string in a stable modifier order.
fn normalize_accelerator_name(
  control : Bool,
  shift : Bool,
  alt : Bool,
  meta : Bool,
  key_name : String,
) -> String {
  let builder = StringBuilder::new()
  let mut wrote_modifier = false
  if control {
    builder.write_string("Ctrl")
    wrote_modifier = true
  }
  if shift {
    if wrote_modifier {
      builder.write_char('+')
    }
    builder.write_string("Shift")
    wrote_modifier = true
  }
  if alt {
    if wrote_modifier {
      builder.write_char('+')
    }
    builder.write_string("Alt")
    wrote_modifier = true
  }
  if meta {
    if wrote_modifier {
      builder.write_char('+')
    }
    builder.write_string("Meta")
    wrote_modifier = true
  }
  if wrote_modifier {
    builder.write_char('+')
  }
  builder.write_string(key_name)
  builder.to_string()
}

///|
/// Decodes a key token into the canonical key name used by all backends.
fn decode_key_name(raw : String) -> Result[String, String] {
  let token = raw.trim().to_string()
  let upper = token.to_upper()
  if upper.length() == 1 {
    match upper.get_char(0) {
      Some(ch) =>
        if (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') {
          Ok(upper)
        } else {
          match ch {
            '-' => Ok("Minus")
            '=' => Ok("Equal")
            ',' => Ok("Comma")
            '.' => Ok("Period")
            '/' => Ok("Slash")
            '\\' => Ok("Backslash")
            ';' => Ok("Semicolon")
            '\'' => Ok("Quote")
            '`' => Ok("Backquote")
            '[' => Ok("LeftBracket")
            ']' => Ok("RightBracket")
            _ => Err("unsupported global_hotkey key: " + raw)
          }
        }
      None => Err("unsupported global_hotkey key: " + raw)
    }
  } else {
    match normalize_keyword(token) {
      "space" => Ok("Space")
      "tab" => Ok("Tab")
      "enter" => Ok("Enter")
      "return" => Ok("Enter")
      "escape" => Ok("Escape")
      "esc" => Ok("Escape")
      "backspace" => Ok("Backspace")
      "delete" => Ok("Delete")
      "del" => Ok("Delete")
      "insert" => Ok("Insert")
      "ins" => Ok("Insert")
      "home" => Ok("Home")
      "end" => Ok("End")
      "pageup" => Ok("PageUp")
      "page-up" => Ok("PageUp")
      "pgup" => Ok("PageUp")
      "pagedown" => Ok("PageDown")
      "page-down" => Ok("PageDown")
      "pgdown" => Ok("PageDown")
      "left" => Ok("Left")
      "right" => Ok("Right")
      "up" => Ok("Up")
      "down" => Ok("Down")
      "minus" => Ok("Minus")
      "hyphen" => Ok("Minus")
      "equal" => Ok("Equal")
      "equals" => Ok("Equal")
      "plus" => Ok("Plus")
      "comma" => Ok("Comma")
      "period" => Ok("Period")
      "dot" => Ok("Period")
      "slash" => Ok("Slash")
      "backslash" => Ok("Backslash")
      "semicolon" => Ok("Semicolon")
      "quote" => Ok("Quote")
      "apostrophe" => Ok("Quote")
      "backquote" => Ok("Backquote")
      "grave" => Ok("Backquote")
      "tilde" => Ok("Backquote")
      "leftbracket" => Ok("LeftBracket")
      "lbracket" => Ok("LeftBracket")
      "bracketleft" => Ok("LeftBracket")
      "rightbracket" => Ok("RightBracket")
      "rbracket" => Ok("RightBracket")
      "bracketright" => Ok("RightBracket")
      "f1" => Ok("F1")
      "f2" => Ok("F2")
      "f3" => Ok("F3")
      "f4" => Ok("F4")
      "f5" => Ok("F5")
      "f6" => Ok("F6")
      "f7" => Ok("F7")
      "f8" => Ok("F8")
      "f9" => Ok("F9")
      "f10" => Ok("F10")
      "f11" => Ok("F11")
      "f12" => Ok("F12")
      "f13" => Ok("F13")
      "f14" => Ok("F14")
      "f15" => Ok("F15")
      "f16" => Ok("F16")
      "f17" => Ok("F17")
      "f18" => Ok("F18")
      "f19" => Ok("F19")
      "f20" => Ok("F20")
      "f21" => Ok("F21")
      "f22" => Ok("F22")
      "f23" => Ok("F23")
      "f24" => Ok("F24")
      _ => Err("unsupported global_hotkey key: " + raw)
    }
  }
}

///|
/// Parses a user-facing accelerator string into canonical backend data.
fn parse_accelerator(raw : String) -> Result[ParsedGlobalHotkey, String] {
  let parts = raw.split("+").to_array()
  let mut control = false
  let mut shift = false
  let mut alt = false
  let mut meta = false
  let mut key_name : String? = None

  for part in parts {
    let token = part.to_string().trim().to_string()
    if token.is_empty() {
      return Err("global_hotkey accelerator contains an empty segment")
    }
    match normalize_keyword(token) {
      "ctrl" =>
        if control {
          return Err("global_hotkey accelerator repeats Ctrl")
        } else {
          control = true
        }
      "control" =>
        if control {
          return Err("global_hotkey accelerator repeats Ctrl")
        } else {
          control = true
        }
      "ctl" =>
        if control {
          return Err("global_hotkey accelerator repeats Ctrl")
        } else {
          control = true
        }
      "shift" =>
        if shift {
          return Err("global_hotkey accelerator repeats Shift")
        } else {
          shift = true
        }
      "alt" =>
        if alt {
          return Err("global_hotkey accelerator repeats Alt")
        } else {
          alt = true
        }
      "option" =>
        if alt {
          return Err("global_hotkey accelerator repeats Alt")
        } else {
          alt = true
        }
      "meta" =>
        if meta {
          return Err("global_hotkey accelerator repeats Meta")
        } else {
          meta = true
        }
      "cmd" =>
        if meta {
          return Err("global_hotkey accelerator repeats Meta")
        } else {
          meta = true
        }
      "command" =>
        if meta {
          return Err("global_hotkey accelerator repeats Meta")
        } else {
          meta = true
        }
      "super" =>
        if meta {
          return Err("global_hotkey accelerator repeats Meta")
        } else {
          meta = true
        }
      "win" =>
        if meta {
          return Err("global_hotkey accelerator repeats Meta")
        } else {
          meta = true
        }
      "windows" =>
        if meta {
          return Err("global_hotkey accelerator repeats Meta")
        } else {
          meta = true
        }
      _ =>
        match key_name {
          Some(_) =>
            return Err("global_hotkey accelerator must contain exactly one key")
          None =>
            match decode_key_name(token) {
              Ok(name) => key_name = Some(name)
              Err(error) => return Err(error)
            }
        }
    }
  }

  match key_name {
    Some(key_name) => {
      let normalized = normalize_accelerator_name(
        control, shift, alt, meta, key_name,
      )
      Ok(ParsedGlobalHotkey::{
        normalized,
        modifiers: modifier_mask(control, shift, alt, meta),
        key_name,
      })
    }
    None => Err("global_hotkey accelerator must include a key")
  }
}
