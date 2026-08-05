// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Loc.reds
// Author: Spuddeh
// Description: How every surface reads a string. NCZDG_T is global scope, no module, so any
//              file can call it with no import - the same shape as Logging.reds, for the
//              same reason.
//
//              READS GO THROUGH Codeware's LocalizationSystem.GetText, NOT the global
//              GetLocalizedText. GetLocalizedText resolves the BASE GAME's text table and
//              returns "" for an NCZDG.* key, which renders every string in the mod as its
//              own key. Codeware's native service does merge provider entries into the
//              game's on-screen table, but that merge is not what the global resolver reads.
//
//              GetText NEEDS A GameInstance, and most of this mod's string sites have none
//              - Brand.reds, GuideModel.reds and Status.reds are free functions. Rather
//              than thread a GameInstance through every caller to reach them, the system is
//              resolved once and cached on a ScriptableService, because
//              GameInstance.GetScriptableServiceContainer() is a static that takes no
//              GameInstance. NCZDGCoreBridge binds it at Session/Ready.
//
//              A MISSING KEY RENDERS AS THE KEY. Returning "" would draw an empty widget,
//              which reads as a layout bug; "NCZDG.btnTeleport" on a button names the fault.
// Mod Version: 1.0.0
// Credits: psiberx (Codeware)
// ======================================================================================

import Codeware.Localization.*

// Holds the LocalizationSystem so a free function can reach it. Global scope, so the service
// name is the bare class name.
public class NCZDGLocCache extends ScriptableService {
  private let m_loc: ref<LocalizationSystem>;

  public final static func Get() -> ref<NCZDGLocCache> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"NCZDGLocCache") as NCZDGLocCache;
  }

  // Called from NCZDGCoreBridge.OnSessionReady, which is a ScriptableSystem and therefore has
  // a GameInstance to give. Re-binding on a later session is harmless and keeps this correct
  // across a load.
  public func Bind(gi: GameInstance) -> Void {
    this.m_loc = LocalizationSystem.GetInstance(gi);
    // Unbound means every string in the mod renders as its key, on every surface at once. The
    // screen shows that plainly but not why, so name the cause here.
    if !IsDefined(this.m_loc) {
      NCZDGError("Codeware LocalizationSystem not found - every string will render as its key");
    }
  }

  public func Text(key: String) -> String {
    if !IsDefined(this.m_loc) {
      return key;
    }
    let s = this.m_loc.GetText(key);
    return StrLen(s) > 0 ? s : key;
  }
}

public func NCZDG_T(key: String) -> String {
  let cache = NCZDGLocCache.Get();
  if !IsDefined(cache) {
    return key;
  }
  return cache.Text(key);
}

// Substitutes one placeholder. The sentences live whole in the translation file so a
// translator controls word order; these put the numbers back in.
public func NCZDG_T1(key: String, token: String, value: String) -> String {
  return StrReplace(NCZDG_T(key), token, value);
}

public func NCZDG_T2(key: String, t1: String, v1: String, t2: String, v2: String) -> String {
  return StrReplace(StrReplace(NCZDG_T(key), t1, v1), t2, v2);
}

public func NCZDG_T3(key: String, t1: String, v1: String, t2: String, v2: String, t3: String, v3: String) -> String {
  return StrReplace(StrReplace(StrReplace(NCZDG_T(key), t1, v1), t2, v2), t3, v3);
}

// The first argument is a KEY at every arity, never a nested lookup's result. Nesting appears to
// work only because a failed lookup echoes its input, so a real translation for that text would
// silently replace the sentence.
public func NCZDG_T4(key: String, t1: String, v1: String, t2: String, v2: String, t3: String, v3: String, t4: String, v4: String) -> String {
  return StrReplace(StrReplace(StrReplace(StrReplace(NCZDG_T(key), t1, v1), t2, v2), t3, v3), t4, v4);
}
