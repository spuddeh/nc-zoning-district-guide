// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: ModifierWatch.reds
// Author: Spuddeh
// Description: Tracks whether the configured guide-key MODIFIER is currently held.
//
//              MODIFIER STATE COMES FROM Codeware's n"Input/Key" EVENT, not from dedicated
//              input actions. IsShiftDown() / IsControlDown() live on inkInputEvent and are
//              unreachable from a gameplay ListenerAction callback, but n"Input/Key" delivers
//              a KeyInputEvent, which is not a UI event and carries GetKey(), GetAction(),
//              IsShiftDown(), IsControlDown() and IsAltDown()
//              (_source/cp2077-codeware KeyInputEvent.reds).
//
//              THE RAW KEY IS WATCHED, NOT IsShiftDown(). RCF's modifier row stores an
//              arbitrary EInputKey, so the modifier is ANY key the player picks; the three
//              predicates would only cover three of them.
//
//              This mirrors DVRCF_Hub.RefreshModifierWatch / OnModifierKey exactly. RCF does
//              NOT expose that as a reusable helper: a `localOnly` row is stored and handed
//              back, and resolving it is the consumer's job. This is a reimplementation of
//              that pattern, not a call into it - RCF's version cannot be reused.
// Mod Version: 1.0.0
// Credits: psiberx (Codeware), DigitalVixen (RCF pattern)
// ======================================================================================

module NCZoningDistrictGuide.Input

import NCZoningDistrictGuide.Config.*

public class NCZDGModifierWatch extends ScriptableSystem {
  // The watched key, as an EInputKey cast to Int32. 0 (IK_None) means no modifier is
  // configured, and every check short-circuits to satisfied.
  private let m_modifierKey: Int32;
  private let m_held: Bool;
  private let m_watching: Bool;

  public final static func Get(gi: GameInstance) -> ref<NCZDGModifierWatch> {
    return GameInstance.GetScriptableSystemsContainer(gi)
      .Get(n"NCZoningDistrictGuide.Input.NCZDGModifierWatch") as NCZDGModifierWatch;
  }

  private func OnAttach() -> Void {
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    this.Refresh();
  }

  // Re-read the configured modifier. Called on session ready and again from
  // NCZDGRcfProvider.SetInt, so changing it in the RCF panel takes effect immediately rather
  // than next launch. RCF does the same thing for its own hotkey.
  public func Refresh() -> Void {
    let keys = NCZDGKeybind.Get();
    this.m_modifierKey = IsDefined(keys) ? EnumInt(keys.openGuideModifier) : 0;
    // Held state is meaningless across a change of key, and a stale `true` would leave the
    // guide openable with nothing held.
    this.m_held = false;
    if !this.m_watching {
      // sticky = true: survives the session teardown that would otherwise drop it.
      GameInstance.GetCallbackSystem()
        .RegisterCallback(n"Input/Key", this, n"OnKeyInput", true);
      this.m_watching = true;
    }
  }

  // Fires for every key, mouse button and pad button in the game, so it must stay cheap and
  // must never consume anything - it only observes.
  protected cb func OnKeyInput(event: ref<KeyInputEvent>) -> Void {
    if this.m_modifierKey <= 0 {
      return;
    }
    if NotEquals(EnumInt(event.GetKey()), this.m_modifierKey) {
      return;
    }
    if Equals(event.GetAction(), EInputAction.IACT_Press) {
      this.m_held = true;
    }
    if Equals(event.GetAction(), EInputAction.IACT_Release) {
      this.m_held = false;
    }
  }

  // With no modifier configured this is always true. Note the asymmetry with the old
  // enum-based check, which also required that NO modifier be held: that existed so Shift+'
  // would not also fire a plain ' binding. It cannot be reproduced here, because with an
  // arbitrary modifier key there is no bounded set of "other modifiers" to test against.
  public func Satisfied() -> Bool {
    return this.m_modifierKey <= 0 || this.m_held;
  }

  // Dev aid: what the watcher currently believes. Reported from the guide-key path so one
  // press says whether the watch is live.
  public func DebugState() -> String {
    if this.m_modifierKey <= 0 {
      return "no modifier configured";
    }
    return s"modifier key \(this.m_modifierKey), held=\(this.m_held)";
  }
}
