// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Input.reds
// Author: Spuddeh
// Description: The guide's open keybind. Requires Input Loader to register the action
//              (see r6/input/nczdg.xml); RCF makes it rebindable.
//
//              Uses a DEDICATED LISTENER CLASS registered with RegisterInputListener.
//              Do NOT wrap PlayerPuppet.OnAction directly: it corrupts the input system
//              and is incompatible with how the engine chains cb funcs. (Same pattern and
//              warning as fpp_speedometer, and as ImmersiveTimeskip / QuickhackHotkeys.)
//
//              THE LISTENER NEVER READS openGuideKey. It matches the ACTION name
//              n"NCZDG_ToggleGuide"; which physical key raises that action is decided by
//              nczdg.xml and then overridden by RCF's DVRCFInput plugin. So a wrong key in
//              settings is not something this file can detect or report.
//
//              Modifier state moved OUT of this file. It used to be tracked here from three
//              dedicated input actions; it now lives in NCZDGModifierWatch on Codeware's
//              n"Input/Key" event. See ModifierWatch.reds for why that workaround existed
//              and why it was wrong.
//
//              Graceful degradation:
//                - No Input Loader: NCZDG_ToggleGuide never registers, IsAction never
//                  matches, the listener is inert.
//                - No RCF: the key stays on the XML default (' = IK_SingleQuote) with no
//                  modifier, and cannot be rebound.
// Mod Version: 0.1.0 (Pre-release)
// Credits: jackhumbert (Input Loader), psiberx (Codeware), DigitalVixen (RCF)
// ======================================================================================

import NCZoningDistrictGuide.Config.*
import NCZoningDistrictGuide.Guide.*
import NCZoningDistrictGuide.Input.*

public class NCZDGInputListener {
  private let m_player: wref<PlayerPuppet>;

  // BUTTON_PRESSED repeats while held; this debounces it to one fire per press.
  private let m_lastFiredAt: Float;

  public func Setup(player: ref<PlayerPuppet>) -> Void {
    this.m_player = player;
  }

  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let actionType = ListenerAction.GetType(action);
    let pressed = Equals(actionType, gameinputActionType.BUTTON_PRESSED);

    if !ListenerAction.IsAction(action, n"NCZDG_ToggleGuide") || !pressed {
      return false;
    }
    let player = this.m_player;
    if !IsDefined(player) {
      return false;
    }
    // Every setting, the keybind included, lives in RCF's panel.
    let cfg = NCZDGConfig.Get();
    if !IsDefined(cfg) || !cfg.enableStandaloneGuide {
      return false;
    }
    // A missing watcher means no modifier can be confirmed held. Treat that as satisfied
    // rather than blocking: an unopenable guide is a worse failure than a modifier that
    // stops being required, and the log line says which happened.
    let watch = NCZDGModifierWatch.Get(player.GetGame());
    if !IsDefined(watch) {
      NCZDGWarn("guide key: modifier watcher missing, opening without a modifier check");
    } else if !watch.Satisfied() {
      // Right key, wrong modifier: leave the press for whoever else wants it. Not logged - it
      // fires on every press of a key someone else has bound, which is most of them.
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

}

// Kept separate from the listener so the input plumbing and the UI stay independently testable.
public func NCZDG_ToggleGuide(player: ref<PlayerPuppet>) -> Void {
  if !IsDefined(player) {
    return;
  }
  NCZDG_OpenGuide(player.GetGame());
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
