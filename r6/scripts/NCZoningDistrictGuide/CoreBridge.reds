// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: CoreBridge.reds
// Author: Spuddeh
// Description: The soft dependency on NCZoningCore. Every top-level item that touches
//              NCZoning.Api is guarded by @if(ModuleExists(...)), so this mod still
//              compiles and loads when the core is absent. At runtime it gates on
//              ApiVersion() and listens for the core's data lifecycle events.
// Mod Version: 0.1.0 (Pre-release)
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
// NCZoning-InstallScanComplete never arrives, which means no CET - a legitimate resting state, not
// a failure. Long enough that a slow CET scan wins the race and reports the real answer.
public func NCZDG_ReadyFallbackDelay() -> Float { return 10.0; }

// --- core presence ---------------------------------------------------------------
// Two compile-time variants: with the core installed this reports the real state; without
// it, the whole mod degrades to "core missing" and every feature stays dormant.

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

// --- installed-mod detection (needs NCZoningCore 0.3.0+) -------------------------
//
// ⚠ THIS RAISES THE MINIMUM CORE VERSION, AND @if CANNOT SOFTEN IT. `ModuleExists` tests for
// a MODULE, not a function, so with NCZoning.Api present but OLDER than 0.3.0 the guarded arm
// still compiles and `IsInstallDetectionAvailable()` is an UNRESOLVED_FN - which fails the
// whole compilation and takes down every redscript mod on that machine, not just this one.
// There is no @if(FunctionExists) to hide behind. NCZoningCore 0.3.0+ is therefore a hard
// floor for this mod and must be stated in its requirements.
//
// AVAILABILITY IS A GATE, NOT A BRANCH. False means the answer is unknowable this session -
// detection needs CET, which this mod does not require - so the filter UI must be HIDDEN
// rather than shown empty. Same rule as NCZDG_CoreUsable() vs NCZDG_HasData().
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_InstallDetection() -> Bool {
  return NCZDG_CoreUsable() && IsInstallDetectionAvailable();
}
@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_InstallDetection() -> Bool { return false; }

// Unknown is a real answer and must render as one. It covers "no CET" and "undetectable in
// principle" (AMM location mods), and showing either as "not installed" would tell the player
// to download something they may already have.
//
// GUARDED ARM ONLY, DELIBERATELY - there is no `!ModuleExists` twin, because both the
// parameter and the return type are core types that do not exist without the core, so a
// fallback arm could not be written at all. Every caller lives inside a guarded class for the
// same reason. Same shape as OnCoreDataReady below.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_InstallStateOf(loc: ref<NCZLocation>) -> NCZInstallState {
  return GetInstallState(loc);
}

// How much data arrived, for the one readiness line. Same guarded-arm rule as everything else
// here: array<ref<NCZLocation>> is a core type, so the fallback returns a bare 0 rather than
// trying to name it.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_TotalLocations() -> Int32 {
  return ArraySize(GetAllLocations());
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

    // Emitted BEFORE the core checks, so it is present even in the dormant case - which is
    // exactly the case where someone is asking why nothing appeared. The per-event "disabled
    // in settings" lines were cut in favour of this one: they said the same thing once per
    // fast travel, and only about the three settings that happened to have a log call.
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

  // The second of the two facts the [READY] line needs, announced rather than waited for. The core
  // dispatches it from NCZInstalledRegistry.EndScan.
  //
  // Unlike IsInstallDetectionAvailable(), this does NOT raise the core version floor: an event name
  // is a string, not a symbol, so subscribing to one an older core never registers simply never
  // fires. The fallback timer covers that case for free.
  @if(ModuleExists("NCZoning.Api"))
  protected cb func OnCoreInstallScanComplete(event: ref<NCZoningDataEvent>) -> Void {
    this.ReportReadyNow();
  }

  // Single funnel for "the registry is usable now".
  //
  // Deliberately does NOT resolve the district here. Verified in-game: Session/Ready (and
  // therefore the core's DataReady) fires roughly ten seconds BEFORE PreventionSystem's
  // DistrictManager is seeded, so GetCurrentDistrict() returns null at this point. Every
  // feature resolves on demand instead: the toast and guide off the district-change hook
  // (DistrictWatcher.reds), the map panel off its own hover callback.
  // ONE READINESS LINE, ONCE. An automated event that always happens says nothing by
  // happening - it is only worth a line if it FAILED to. So the injections, the listener
  // registrations, the RCF handshake and every guide open are silent, and this single line
  // stands for all of them: the dependency version, how much data arrived, and whether
  // install detection is available. What still logs per occurrence is what the PLAYER did -
  // setting a marker, arriving at one, teleporting.
  //
  // Refreshes do not repeat it. A refresh is the same fact arriving again, and a line per
  // refresh is a line per timer tick.
  //
  // IT IS DEFERRED, NECESSARILY. "The registry is usable" is not the same instant as "the
  // registry has finished populating", and install detection settles later still - the CET
  // scan that feeds it lands after Session/Ready. Read at this moment, the line reports
  // locations=0 installDetection=off on a session holding 297 locations with detection
  // working. A readiness line that reports a state nothing has reached yet is worse than no
  // line: it is a wrong answer in the place someone goes for the right one.
  private func OnCoreDataUsable(isRefresh: Bool) -> Void {
    if isRefresh || this.m_announced {
      return;
    }
    this.m_announced = true;
    this.ScheduleReadyFallback();
  }

  // ONE SHOT, NOT A POLL. The [READY] line needs two facts, and both now announce themselves:
  // locations arrive with NCZoning-DataReady, detection with NCZoning-InstallScanComplete. This
  // timer is the third case only - detection that never completes.
  //
  // It cannot be dropped, because "no CET" is a legitimate resting state that produces NO event
  // at all. Waiting on the event alone would mean a CET-less setup never gets a [READY] line, and
  // that is the setup whose bug reports need one most. So: whichever comes first wins, and
  // ReportReadyNow is idempotent.
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
