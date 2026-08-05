// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: CoreBridge.reds
// Author: Spuddeh
// Description: The soft dependency on NCZoningCore. Every top-level item that touches
//              NCZoning.Api is guarded by @if(ModuleExists(...)), so this mod still
//              compiles and loads when the core is absent. At runtime it gates on
//              ApiVersion() and listens for the core's data lifecycle events.
// Mod Version: 1.0.0
// Credits: Spuddeh (NCZoningCore), psiberx (Codeware)
// ======================================================================================

module NCZoningDistrictGuide.Bridge

@if(ModuleExists("NCZoning.Api"))
import NCZoning.Api.*
@if(ModuleExists("NCZoning.Api"))
import NCZoning.Data.*

// The Layer-2 resolver. Guarded to match: its resolve funcs return ref<NCZDistrictName>,
// a type that only exists when the core is installed.
@if(ModuleExists("NCZoning.Api"))
import NCZoningDistrictGuide.District.*
import NCZoningDistrictGuide.Config.*

// The lowest core ApiVersion this mod knows how to talk to.
public func NCZDG_RequiredApiVersion() -> Int32 { return 1; }

// How long to wait for install detection before reporting [READY] without it. Only reached when
// NCZoning-InstallScanComplete never arrives, which means no CET - a normal state, not a failure.
// Long enough that a slow CET scan still wins the race.
public func NCZDG_ReadyFallbackDelay() -> Float { return 10.0; }

// --- core presence ---------------------------------------------------------------
// Two compile-time variants: with the core installed this reports the live state; without it,
// every function answers "core missing" and every feature stays dormant.

@if(ModuleExists("NCZoning.Api"))
public func NCZDG_HasCore() -> Bool { return true; }
@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_HasCore() -> Bool { return false; }

@if(ModuleExists("NCZoning.Api"))
public func NCZDG_CoreUsable() -> Bool {
  return ApiVersion() >= NCZDG_RequiredApiVersion();
}
@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_CoreUsable() -> Bool { return false; }

// "Ready" means THE CORE HAS DATA, not that the core is installed. Do NOT gate a UI surface on
// this: with no data it is false, so the surface that exists to tell the player the data is
// missing gets switched off by the very failure it reports. Gate on NCZDG_CoreUsable() (installed
// and API-compatible) and branch on NCZDG_HasData() (Status.reds) instead.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_CoreReady() -> Bool {
  return NCZDG_CoreUsable() && IsReady();
}
@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_CoreReady() -> Bool { return false; }

@if(ModuleExists("NCZoning.Api"))
public func NCZDG_CoreVersion() -> String { return Version(); }
@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_CoreVersion() -> String { return "absent"; }

// --- installed-mod detection (needs NCZoningCore 1.0.0+) -------------------------
//
// ⚠ THIS RAISES THE MINIMUM CORE VERSION, AND @if CANNOT SOFTEN IT. `ModuleExists` tests for
// a MODULE, not a function, so with NCZoning.Api present but OLDER than 1.0.0 the guarded arm
// still compiles and `IsInstallDetectionAvailable()` is an UNRESOLVED_FN - which fails the
// whole compilation and takes down every redscript mod on that machine, not just this one.
// There is no @if(FunctionExists). NCZoningCore 1.0.0+ is a hard floor for this mod and must
// be stated in its requirements.
//
// AVAILABILITY IS A GATE, NOT A BRANCH. False means the answer is unknowable this session -
// detection needs CET, which this mod does not require - so the filter UI is HIDDEN rather
// than shown empty. Same rule as NCZDG_CoreUsable() vs NCZDG_HasData().
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_InstallDetection() -> Bool {
  return NCZDG_CoreUsable() && IsInstallDetectionAvailable();
}
@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_InstallDetection() -> Bool { return false; }

// Unknown is a real answer and must render as one. It covers "no CET" and "cannot be detected
// at all" (AMM location mods); do not render either as "not installed".
//
// GUARDED ARM ONLY - there is no `!ModuleExists` twin, because both the parameter and the
// return type are core types that do not exist without the core, so a fallback arm cannot be
// written. Every caller lives inside a guarded class for the same reason.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_InstallStateOf(loc: ref<NCZLocation>) -> NCZInstallState {
  return GetInstallState(loc);
}

// How much data arrived, for the readiness line. array<ref<NCZLocation>> is a core type, so the
// fallback returns a bare 0 rather than naming it.
//
// BIND THE ARRAY TO A LOCAL FIRST. ArraySize() applied straight to a call that returns an array
// measures an rvalue temporary and answers 0, which reads as "the registry is empty" on a session
// holding every record.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_TotalLocations() -> Int32 {
  let all = GetAllLocations();
  return ArraySize(all);
}
@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_TotalLocations() -> Int32 { return 0; }

// --- the bridge system -----------------------------------------------------------
// Subscribes to the core's Codeware CallbackSystem events. A redscript consumer gets
// these directly (unlike CET Lua, which has to Observe the facade).

public class NCZDGCoreBridge extends ScriptableSystem {
  private let m_ready: Bool;
  private let m_announced: Bool;   // the [READY] line is once per session, not once per refresh
  private let m_reported: Bool;    // the line has been written; the event and the fallback race for it

  private func OnAttach() -> Void {
    let cs = GameInstance.GetCallbackSystem();
    cs.RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
    this.RegisterCoreCallbacks();
  }

  // Guarded: the event payload type ref<NCZoningDataEvent> only exists with the core.
  @if(ModuleExists("NCZoning.Api"))
  private func RegisterCoreCallbacks() -> Void {
    let cs = GameInstance.GetCallbackSystem();
    cs.RegisterCallback(n"NCZoning-DataReady", this, n"OnCoreDataReady")
      .SetLifetime(CallbackLifetime.Forever);
    cs.RegisterCallback(n"NCZoning-DataRefreshed", this, n"OnCoreDataRefreshed")
      .SetLifetime(CallbackLifetime.Forever);
    cs.RegisterCallback(n"NCZoning-DataError", this, n"OnCoreDataError")
      .SetLifetime(CallbackLifetime.Forever);
    cs.RegisterCallback(n"NCZoning-InstallScanComplete", this, n"OnCoreInstallScanComplete")
      .SetLifetime(CallbackLifetime.Forever);
  }
  @if(!ModuleExists("NCZoning.Api"))
  private func RegisterCoreCallbacks() -> Void {}

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    let reqs = GameInstance.GetSystemRequestsHandler();
    if IsDefined(reqs) && reqs.IsPreGame() {
      return;
    }
    // FIRST, and unconditionally. Every player-facing string in the mod is read through
    // NCZDG_T, which cannot reach Codeware's LocalizationSystem without a GameInstance - and
    // this is a ScriptableSystem, so it is one of the few places that has one to give. Bound
    // before the core checks because the UI is localised whether or not the core is present.
    let loc = NCZDGLocCache.Get();
    if IsDefined(loc) {
      loc.Bind(this.GetGameInstance());
    } else {
      NCZDGError("localization cache service is missing - every string will render as its key");
    }

    // Emitted BEFORE the core checks, so the settings are on record even when the mod is
    // dormant - the state a "nothing appeared" report usually describes.
    NCZDG_LogConfig();

    if !NCZDG_HasCore() {
      NCZDGWarn("NCZoningCore not installed; features dormant");
      return;
    }
    if !NCZDG_CoreUsable() {
      NCZDGWarn("NCZoningCore ApiVersion too old; features dormant");
      return;
    }

    // The core may have fired DataReady from its offline cache before this system
    // attached, so never wait on the event alone.
    if NCZDG_CoreReady() {
      this.m_ready = true;
      this.OnCoreDataUsable(false);
    }
  }

  @if(ModuleExists("NCZoning.Api"))
  protected cb func OnCoreDataReady(event: ref<NCZoningDataEvent>) -> Void {
    this.m_ready = true;
    this.OnCoreDataUsable(false);
  }

  @if(ModuleExists("NCZoning.Api"))
  protected cb func OnCoreDataRefreshed(event: ref<NCZoningDataEvent>) -> Void {
    this.m_ready = true;
    this.OnCoreDataUsable(true);
  }

  @if(ModuleExists("NCZoning.Api"))
  protected cb func OnCoreDataError(event: ref<NCZoningDataEvent>) -> Void {
    // IsReady() may still be true when the offline cache is serving.
    NCZDGError(s"core reported a fetch error; ready=\(NCZDG_CoreReady())");
  }

  // The second of the two facts the [READY] line needs. The core dispatches it from
  // NCZInstalledRegistry.EndScan.
  //
  // Unlike IsInstallDetectionAvailable(), this does NOT raise the core version floor: an event name
  // is a string, not a symbol, so subscribing to one an older core never registers simply never
  // fires, and the fallback timer covers that case.
  @if(ModuleExists("NCZoning.Api"))
  protected cb func OnCoreInstallScanComplete(event: ref<NCZoningDataEvent>) -> Void {
    this.ReportReadyNow();
  }

  // Single funnel for "the registry is usable now".
  //
  // DO NOT RESOLVE THE DISTRICT HERE. Session/Ready (and therefore the core's DataReady) fires
  // roughly ten seconds BEFORE PreventionSystem's DistrictManager is seeded, so
  // GetCurrentDistrict() returns null at this point. Every feature resolves on demand instead:
  // the toast and guide off the district-change hook (DistrictWatcher.reds), the map panel off
  // its own hover callback.
  //
  // ONE READINESS LINE, ONCE PER SESSION. The injections, the listener registrations, the RCF
  // handshake and every guide open are silent; this line carries the dependency version, how
  // much data arrived, and whether install detection is available. What still logs per
  // occurrence is what the PLAYER did - setting a marker, arriving at one, teleporting.
  //
  // A refresh does not repeat it: it is the same fact arriving again.
  //
  // THE LINE IS DEFERRED, AND HAS TO BE. "The registry is usable" is not the same instant as
  // "the registry has finished populating", and install detection settles later still, since
  // the CET scan that feeds it lands after Session/Ready. Written at this moment it would
  // report locations=0 installDetection=off on a session holding 297 locations with detection
  // working.
  private func OnCoreDataUsable(isRefresh: Bool) -> Void {
    if isRefresh || this.m_announced {
      return;
    }
    this.m_announced = true;
    this.ScheduleReadyFallback();
  }

  // ONE SHOT, NOT A POLL. The [READY] line needs two facts, and both announce themselves:
  // locations with NCZoning-DataReady, detection with NCZoning-InstallScanComplete. This timer
  // covers the third case - detection that never completes, because "no CET" produces no event
  // at all. Whichever arrives first wins; ReportReadyNow is idempotent.
  private func ScheduleReadyFallback() -> Void {
    let cb = new NCZDGReadyCallback();
    cb.gi = this.GetGameInstance();
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, NCZDG_ReadyFallbackDelay());
  }

  // Idempotent: the event and the fallback race, and the loser must do nothing.
  public func ReportReadyNow() -> Void {
    if this.m_reported {
      return;
    }
    this.m_reported = true;
    let locations = NCZDG_TotalLocations();
    let detection = NCZDG_InstallDetection();
    NCZDGLog(s"[READY] core=\(NCZDG_CoreVersion()) locations=\(locations) installDetection=\(detection ? "on" : "off")");
  }

  public func IsReady() -> Bool {
    return this.m_ready && NCZDG_CoreReady();
  }
}

// The fallback for a session where install detection never completes - no CET, so no scan and no
// NCZoning-InstallScanComplete to wait for. Fires once and carries no retry state.
public class NCZDGReadyCallback extends DelayCallback {
  public let gi: GameInstance;

  public func Call() -> Void {
    let bridge = GameInstance.GetScriptableSystemsContainer(this.gi).Get(n"NCZoningDistrictGuide.Bridge.NCZDGCoreBridge") as NCZDGCoreBridge;
    if IsDefined(bridge) {
      bridge.ReportReadyNow();
    }
  }
}
