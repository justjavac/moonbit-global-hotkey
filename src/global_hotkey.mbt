///|
/// Owns the native backend and keeps the normalized registration index in sync.
pub struct GlobalHotkeyManager {
  state : GlobalHotkeyState
  store : RegistrationStore
}

///|
/// Resolves the backend state unless the manager has already been destroyed.
fn GlobalHotkeyManager::resolve_state(
  self : GlobalHotkeyManager,
) -> Result[GlobalHotkeyState, String] {
  if self.store.destroyed {
    Err(destroyed_error_message())
  } else if state_is_null_ffi(self.state) {
    Err(create_error_message())
  } else {
    Ok(self.state)
  }
}

///|
/// Converts the support probe into the package's public result shape.
fn ensure_supported_result(
  supported : Bool,
  error_message : Bytes,
) -> Result[Unit, String] {
  if supported {
    Ok(())
  } else {
    Err(decode_error_message(error_message, unsupported_error_message()))
  }
}

///|
/// Converts a native create failure into the package's public result shape.
fn create_status_result(
  is_null : Bool,
  error_message : Bytes,
) -> Result[Unit, String] {
  if is_null {
    Err(decode_error_message(error_message, create_error_message()))
  } else {
    Ok(())
  }
}

///|
/// Converts a native register status code into the package's public result shape.
fn register_status_result(
  status : Int,
  error_message : Bytes,
  accelerator : String,
) -> Result[Bool, String] {
  if status == 0 {
    Ok(true)
  } else {
    Err(decode_error_message(error_message, register_error_message(accelerator)))
  }
}

///|
/// Converts a native unregister status code into the package's public result shape.
fn unregister_status_result(
  status : Int,
  error_message : Bytes,
  accelerator : String,
) -> Result[Bool, String] {
  if status == 0 {
    Ok(true)
  } else {
    Err(decode_error_message(error_message, unregister_error_message(accelerator)))
  }
}

///|
/// Drains repeated trigger reads into one array.
fn drain_with(take : () -> String?) -> Array[String] {
  let accelerators : Array[String] = []
  while true {
    match take() {
      Some(accelerator) => accelerators.push(accelerator)
      None => break
    }
  }
  accelerators
}

///|
/// Returns `true` when the current native target exposes a usable global hotkey backend.
///
/// This is a lightweight capability probe. On Linux it checks for an X11
/// session and an X11 backend that can be opened at runtime. On macOS the
/// native backend may still require Input Monitoring permission when a manager
/// is created.
///
/// ```mbt check
/// test "support detection can be queried" {
///   ignore(@global_hotkey.is_supported())
/// }
/// ```
pub fn is_supported() -> Bool {
  platform_supported_ffi()
}

///|
/// Verifies that the current native target has a backend this package can use.
///
/// This is useful for fast-fail checks before building a polling loop. When the
/// probe can provide a concrete reason, the returned `Err(String)` contains it;
/// otherwise a generic compatibility message is used.
///
/// ```mbt check
/// test "support can be checked without registering anything" {
///   ignore(@global_hotkey.ensure_supported())
/// }
/// ```
pub fn ensure_supported() -> Result[Unit, String] {
  ensure_supported_result(is_supported(), last_error_message_ffi())
}

///|
/// Creates a manager that can register, unregister, and poll global hotkeys.
///
/// The returned manager owns native resources and should be released with
/// `destroy()` when you are done. On macOS the backend may fail here if the
/// process has not been granted Input Monitoring permission yet.
///
/// ```mbt check
/// test "manager creation can be attempted safely" {
///   match @global_hotkey.create() {
///     Ok(manager) => manager.destroy()
///     Err(_) => ()
///   }
/// }
/// ```
pub fn create() -> Result[GlobalHotkeyManager, String] {
  let state = create_state_ffi()
  match create_status_result(state_is_null_ffi(state), last_error_message_ffi()) {
    Err(error) => Err(error)
    Ok(_) =>
      Ok(
        GlobalHotkeyManager::{
          state,
          store: new_registration_store(),
        },
      )
  }
}

///|
/// Registers one global accelerator like `Ctrl+Shift+K` or `Meta+Space`.
///
/// Supported modifier aliases include `Ctrl` / `Control`, `Alt` / `Option`,
/// and `Meta` / `Cmd` / `Command` / `Win` / `Super`. The accelerator is
/// normalized before registration, so `ctrl + shift + k` is stored as
/// `Ctrl+Shift+K`.
///
/// Returns `Ok(true)` when the native backend accepted the registration.
/// Duplicate registrations, invalid accelerators, and backend failures are
/// returned as `Err(String)`.
pub fn GlobalHotkeyManager::register(
  self : GlobalHotkeyManager,
  accelerator : String,
) -> Result[Bool, String] {
  match self.resolve_state() {
    Err(error) => Err(error)
    Ok(state) =>
      match self.store.plan_register(accelerator) {
        Err(error) => Err(error)
        Ok(plan) => {
          match register_status_result(
            register_hotkey_ffi(
              state,
              plan.id,
              plan.parsed.modifiers,
              @utf8.encode(plan.parsed.key_name),
            ),
            last_error_message_ffi(),
            plan.parsed.normalized,
          ) {
            Err(error) => Err(error)
            Ok(result) => {
              self.store.commit_register(plan)
              Ok(result)
            }
          }
        }
      }
  }
}

///|
/// Unregisters one previously registered accelerator.
///
/// The accelerator string is normalized with the same rules as `register()`.
/// Returns `Ok(true)` when a registration existed and was removed, `Ok(false)`
/// when nothing matched, and `Err(String)` for invalid input or backend
/// failures.
pub fn GlobalHotkeyManager::unregister(
  self : GlobalHotkeyManager,
  accelerator : String,
) -> Result[Bool, String] {
  match self.resolve_state() {
    Err(error) => Err(error)
    Ok(state) =>
      match self.store.plan_unregister(accelerator) {
        Err(error) => Err(error)
        Ok(None) => Ok(false)
        Ok(Some(plan)) => {
          match unregister_status_result(
            unregister_hotkey_ffi(state, plan.id),
            last_error_message_ffi(),
            plan.normalized,
          ) {
            Err(error) => Err(error)
            Ok(result) => {
              self.store.commit_unregister(plan)
              Ok(result)
            }
          }
        }
      }
  }
}

///|
/// Returns every currently registered accelerator in normalized form.
///
/// This is purely the MoonBit-side view of the manager and does not block on
/// the native backend.
pub fn GlobalHotkeyManager::list(self : GlobalHotkeyManager) -> Array[String] {
  self.store.list()
}

///|
/// Pops the next triggered accelerator from the native queue, if any.
///
/// The manager never blocks here. Poll this method from your application's main
/// loop when you want to react to global shortcuts.
pub fn GlobalHotkeyManager::take_triggered(
  self : GlobalHotkeyManager,
) -> String? {
  match self.resolve_state() {
    Err(_) => None
    Ok(state) => self.store.lookup_trigger(take_triggered_id_ffi(state))
  }
}

///|
/// Drains every currently queued trigger in the order reported by the backend.
///
/// This is a convenience wrapper over repeated `take_triggered()` calls and is
/// useful when you poll infrequently.
pub fn GlobalHotkeyManager::drain_triggered(
  self : GlobalHotkeyManager,
) -> Array[String] {
  drain_with(fn() { self.take_triggered() })
}

///|
/// Releases every native resource owned by this manager and clears its registry.
///
/// Calling `destroy()` more than once is harmless. After destruction,
/// registration methods return `Err(String)` and trigger polling returns `None`.
pub fn GlobalHotkeyManager::destroy(self : GlobalHotkeyManager) -> Unit {
  if !self.store.destroyed {
    destroy_state_ffi(self.state)
    self.store.destroy()
  }
}
