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

// The lowest core ApiVersion this mod knows how to talk to.
public func NCZDG_RequiredApiVersion() -> Int32 { return 1; }

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

// --- the bridge system -----------------------------------------------------------
// Subscribes to the core's Codeware CallbackSystem events. A redscript consumer gets
// these directly (unlike CET Lua, which has to Observe the facade).

public class NCZDGCoreBridge extends ScriptableSystem {
  private let m_ready: Bool;

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
  }
  @if(!ModuleExists("NCZoning.Api"))
  private func RegisterCoreCallbacks() -> Void {}

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    let reqs = GameInstance.GetSystemRequestsHandler();
    if IsDefined(reqs) && reqs.IsPreGame() {
      return;
    }
    if !NCZDG_HasCore() {
      NCZDGLog("NCZoningCore not installed; features dormant");
      return;
    }
    if !NCZDG_CoreUsable() {
      NCZDGLog("NCZoningCore ApiVersion too old; features dormant");
      return;
    }
    NCZDGLog(s"bridged to NCZoningCore \(NCZDG_CoreVersion())");

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
    NCZDGLog(s"core reported a fetch error; ready=\(NCZDG_CoreReady())");
  }

  // Single funnel for "the registry is usable now".
  //
  // Deliberately does NOT resolve the district here. Verified in-game: Session/Ready (and
  // therefore the core's DataReady) fires roughly ten seconds BEFORE PreventionSystem's
  // DistrictManager is seeded, so GetCurrentDistrict() returns null at this point. Every
  // feature resolves on demand instead: the toast and guide off the district-change hook
  // (DistrictWatcher.reds), the map panel off its own hover callback.
  private func OnCoreDataUsable(isRefresh: Bool) -> Void {
    NCZDGLog(s"registry usable (refresh=\(isRefresh))");
  }

  public func IsReady() -> Bool {
    return this.m_ready && NCZDG_CoreReady();
  }
}
