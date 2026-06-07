name = "justjavac/global_hotkey"

version = "0.1.3"

readme = "README.mbt.md"

repository = "https://github.com/justjavac/moonbit-global-hotkey"

license = "MIT"

keywords = [
  "desktop",
  "shortcut",
  "hotkey",
  "native",
  "windows",
  "macos",
  "linux",
]

description = "Cross-platform native global hotkey helpers for MoonBit."

preferred_target = "native"

options(
  source: "src",
  supported_targets: "+native",
)
