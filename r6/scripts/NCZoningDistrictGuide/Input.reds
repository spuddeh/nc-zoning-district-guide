// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Input.reds
// Author: Spuddeh
// Description: The guide's open keybind. Requires Input Loader to register the action
//              (see r6/input/nczdg.xml); Mod Settings optionally makes it rebindable.
//
//              Uses a DEDICATED LISTENER CLASS registered with RegisterInputListener.
//              Do NOT wrap PlayerPuppet.OnAction directly: it corrupts the input system
//              and is incompatible with how the engine chains cb funcs. (Same pattern and
//              warning as fpp_speedometer, and as ImmersiveTimeskip / QuickhackHotkeys.)
//
//              Graceful degradation:
//                - No Input Loader: NCZDG_ToggleGuide never registers, IsAction never
//                  matches, the listener is inert.
//                - No Mod Settings: the key stays on the XML default (' = IK_SingleQuote)
//                  with no modifier.
// Mod Version: 0.1.0 (Pre-release)
// Credits: jackhumbert (Input Loader, Mod Settings)
// ======================================================================================

import NCZoningDistrictGuide.Config.*

public class NCZDGInputListener {
  private let m_player: wref<PlayerPuppet>;

  // Held state of each modifier, maintained from its own input action. Input Loader cannot
  // express a modifier on a mapping, and inkInputEvent.IsShiftDown() is a UI event method
  // that a gameplay ListenerAction callback cannot reach, so the keys are observed directly.
  private let m_shiftHeld: Bool;
  private let m_altHeld: Bool;
  private let m_ctrlHeld: Bool;

  // BUTTON_PRESSED repeats while held; this debounces it to one fire per press.
  private let m_lastFiredAt: Float;

  public func Setup(player: ref<PlayerPuppet>) -> Void {
    this.m_player = player;
  }

  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let actionType = ListenerAction.GetType(action);
    let pressed = Equals(actionType, gameinputActionType.BUTTON_PRESSED);
    let released = Equals(actionType, gameinputActionType.BUTTON_RELEASED);

    // Track the modifiers. These actions do nothing else, so never consume them: other
    // mods and the game itself still need Shift / Alt / Ctrl.
    if ListenerAction.IsAction(action, n"NCZDG_ModShift") {
      if pressed { this.m_shiftHeld = true; } else if released { this.m_shiftHeld = false; }
      return false;
    }
    if ListenerAction.IsAction(action, n"NCZDG_ModAlt") {
      if pressed { this.m_altHeld = true; } else if released { this.m_altHeld = false; }
      return false;
    }
    if ListenerAction.IsAction(action, n"NCZDG_ModCtrl") {
      if pressed { this.m_ctrlHeld = true; } else if released { this.m_ctrlHeld = false; }
      return false;
    }

    if !ListenerAction.IsAction(action, n"NCZDG_ToggleGuide") || !pressed {
      return false;
    }
    let player = this.m_player;
    if !IsDefined(player) {
      return false;
    }
    // Feature toggle lives in RCF's panel; the keybind lives in Mod Settings.
    let cfg = NCZDGConfig.Get();
    if !IsDefined(cfg) || !cfg.enableStandaloneGuide {
      NCZDGLog("guide key: ignored, guide disabled in settings");
      return false;
    }
    let keys = NCZDGKeybind.Get();
    let modifier = IsDefined(keys) ? keys.openGuideModifier : NCZDGModifier.None;
    if !this.ModifierSatisfied(modifier) {
      // Right key, wrong modifier: leave the press for whoever else wants it.
      NCZDGLog(s"guide key: ignored, need \(NCZDG_ModifierName(modifier)), held [\(this.DebugHeldState())]");
      return false;
    }

    // BUTTON_PRESSED repeats while the key is held (observed: 5 fires in one second from a
    // single hold), so debounce. Without this a toggle flickers open/closed on a long press.
    let now = EngineTime.ToFloat(GameInstance.GetSimTime(player.GetGame()));
    if now - this.m_lastFiredAt < 0.35 {
      return false;
    }
    this.m_lastFiredAt = now;

    NCZDG_ToggleGuide(player);
    return true;
  }

  // The chosen modifier must be held, and with None chosen no modifier may be held, so that
  // e.g. Shift+' does not also trigger a plain ' binding.
  private func ModifierSatisfied(required: NCZDGModifier) -> Bool {
    switch required {
      case NCZDGModifier.Shift: return this.m_shiftHeld;
      case NCZDGModifier.Alt: return this.m_altHeld;
      case NCZDGModifier.Ctrl: return this.m_ctrlHeld;
      default: return !this.m_shiftHeld && !this.m_altHeld && !this.m_ctrlHeld;
    }
  }

  // Dev aid: what the listener currently believes is held. Called from the guide-key path so
  // one press reports whether the modifier probes are tracking. Strip with the logging.
  public func DebugHeldState() -> String {
    let s = "";
    if this.m_shiftHeld { s += "Shift "; }
    if this.m_altHeld { s += "Alt "; }
    if this.m_ctrlHeld { s += "Ctrl "; }
    if UnicodeStringEqual(s, "") { return "none"; }
    return s;
  }
}

public func NCZDG_ModifierName(m: NCZDGModifier) -> String {
  switch m {
    case NCZDGModifier.Shift: return "Shift";
    case NCZDGModifier.Alt: return "Alt";
    case NCZDGModifier.Ctrl: return "Ctrl";
    default: return "no modifier";
  }
}

// Kept separate from the listener so the input plumbing and the UI stay independently testable.
public func NCZDG_ToggleGuide(player: ref<PlayerPuppet>) -> Void {
  NCZDGLog("guide key: FIRED");
}

@addField(PlayerPuppet)
public let nczdg_inputListener: ref<NCZDGInputListener>;

// OnGameAttached can fire more than once for a player, and each call would otherwise stack
// another listener. Observed in-game: two listeners answering one keypress with different
// held-modifier state, interleaving "FIRED" and "ignored, need Ctrl, held [none]" in the
// same second, and each keeping its own debounce clock. Register at most one.
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  if IsDefined(this.nczdg_inputListener) {
    return result;
  }
  this.nczdg_inputListener = new NCZDGInputListener();
  this.nczdg_inputListener.Setup(this);
  this.RegisterInputListener(this.nczdg_inputListener, n"");
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  let result: Bool = wrappedMethod();
  if IsDefined(this.nczdg_inputListener) {
    this.UnregisterInputListener(this.nczdg_inputListener, n"");
    this.nczdg_inputListener = null;   // so a later OnGameAttached registers a fresh one
  }
  return result;
}
