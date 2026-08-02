// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: MapFocus.reds
// Author: Spuddeh
// Description: Takes the player to the marker on the world map instead of leaving them to hunt
//              for it, and - optionally - tracks it for them.
//
//              WHY THIS IS POSSIBLE AT ALL. A script cannot mark a mappin player-tracked: the
//              MappinSystem exposes GetManuallyTrackedMappinID and no setter, and the three
//              functions that CAN do it live on WorldMapMenuGameController, which exists only
//              while the map is open. That was recorded as a wall. It is a PRECONDITION - open
//              the map and the functions are in reach:
//
//                ZoomToMappin(BaseWorldMapMappinController)   centre the map on a pin
//                SetSelectedMappin(BaseWorldMapMappinController)
//                TrackMappin(MappinBaseController)            the tracked slot, by controller
//
//              None of the three appears in the six measured workarounds on
//              [[CP2077-Mods/wiki/learnings/a-script-registered-waypoint-cannot-route-itself]].
//              TrackCustomPositionMappin() is a DIFFERENT function and must not be substituted:
//              it creates a new waypoint at the map cursor rather than adopting an existing pin,
//              so on map open it plants one at roughly the world origin.
//
//              THE HANDLE COMES FROM THE ICON HOOK. A mappin controller is not reachable by
//              lookup, but MapMarker.reds already wraps BaseWorldMapMappinController.UpdateIcon
//              to brand the marker - so the controller passes through this mod on every map
//              build, and capturing it there costs nothing.
//
//              TIMING IS THE WHOLE DIFFICULTY. The pin's controller does not exist when the map
//              opens; it is spawned as the map draws its pins. So the request is queued, and a
//              short poll retries until the controller resolves or the attempts run out.
//
//              TRACKING IS OPT-IN AND MUST STAY THAT WAY. There is ONE tracked slot, and taking
//              it silently discards whatever the player was following - a quest, or their own
//              waypoint. Centring the map costs them nothing and is on by default; taking their
//              tracked slot costs them something and is off by default.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh
// ======================================================================================

module NCZoningDistrictGuide.MapFocus

import NCZoningDistrictGuide.Config.*

// How long to keep looking for the marker's controller after the map opens, and how often.
public func NCZDG_FocusRetryDelay() -> Float { return 0.25; }
public func NCZDG_FocusMaxAttempts() -> Int32 { return 12; }

// Holds the request across the guide closing and the map opening - two different UI lifetimes, so
// this cannot live on either of them.
//
// A ScriptableSERVICE, not a System, because the capture point needs it. The controller is handed
// over from BaseWorldMapMappinController.UpdateIcon, and that is an inkLogicController with no
// GetPlayerControlledObject and therefore no GameInstance to look a system up with.
// GetScriptableServiceContainer() takes no GameInstance, so a service is reachable from there.
public class NCZDGMapFocus extends ScriptableService {
  private let m_pending: Bool;
  private let m_ctrl: wref<BaseWorldMapMappinController>;
  private let m_menu: wref<gameuiInGameMenuGameController>;

  public final static func Get() -> ref<NCZDGMapFocus> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NCZoningDistrictGuide.MapFocus.NCZDGMapFocus") as NCZDGMapFocus;
  }

  // Set when the player asks to be shown the marker. Cleared once the map has acted on it, or once
  // the attempts run out - never left standing, or the next unrelated map open would consume it.
  public func Request() -> Void {
    this.m_pending = true;
  }

  public func Consume() -> Bool {
    let was = this.m_pending;
    this.m_pending = false;
    return was;
  }

  public func IsPending() -> Bool {
    return this.m_pending;
  }

  // Captured from MapMarker's icon hook. A wref, deliberately: the controller dies with the map, and
  // a stale strong ref would outlive the widget it points at.
  public func SetController(ctrl: wref<BaseWorldMapMappinController>) -> Void {
    this.m_ctrl = ctrl;
  }

  public func GetController() -> wref<BaseWorldMapMappinController> {
    return this.m_ctrl;
  }

  public func ClearController() -> Void {
    this.m_ctrl = null;
  }

  // The live in-game menu controller, captured on its OnInitialize. A wref, and cleared on
  // OnUninitialize: the controller dies with the HUD, and a stale handle outlives what it points at.
  public func SetMenu(menu: wref<gameuiInGameMenuGameController>) -> Void {
    this.m_menu = menu;
  }

  public func ClearMenu() -> Void {
    this.m_menu = null;
  }

  public func GetMenu() -> wref<gameuiInGameMenuGameController> {
    return this.m_menu;
  }
}

// The poll. Retries because the marker's controller is spawned while the map draws, not when it
// opens, so the first attempt after the map appears will usually miss.
public class NCZDGFocusCallback extends DelayCallback {
  public let gi: GameInstance;
  public let menu: wref<WorldMapMenuGameController>;
  public let attempt: Int32;

  public func Call() -> Void {
    let focus = NCZDGMapFocus.Get();
    if !IsDefined(focus) || !IsDefined(this.menu) {
      return;
    }
    if !focus.IsPending() {
      return;   // cancelled, or already handled
    }

    let ctrl = focus.GetController();
    if !IsDefined(ctrl) {
      if this.attempt < NCZDG_FocusMaxAttempts() {
        NCZDG_ScheduleFocus(this.gi, this.menu, this.attempt + 1);
      } else {
        focus.Consume();
        NCZDGWarn("[MARK] the marker's map controller never appeared - not centring");
      }
      return;
    }

    focus.Consume();
    this.menu.NCZDG_FocusMarker(ctrl);
  }
}

public func NCZDG_ScheduleFocus(gi: GameInstance, menu: wref<WorldMapMenuGameController>, attempt: Int32) -> Void {
  let cb = new NCZDGFocusCallback();
  cb.gi = gi;
  cb.menu = menu;
  cb.attempt = attempt;
  GameInstance.GetDelaySystem(gi).DelayCallback(cb, NCZDG_FocusRetryDelay());
}

// Centres the map on the marker, and takes the tracked slot only if the player asked for that.
//
// SetSelectedMappin before TrackMappin: the map's own key path (TryTrackQuestOrSetWaypoint) reads
// selectedMappin and falls through to creating a cursor waypoint when it is null, so selecting first
// keeps this on the same path the game uses rather than a parallel one.
@addMethod(WorldMapMenuGameController)
public final func NCZDG_FocusMarker(ctrl: wref<BaseWorldMapMappinController>) -> Void {
  if !IsDefined(ctrl) {
    return;
  }
  this.ZoomToMappin(ctrl);
  this.SetSelectedMappin(ctrl);

  let cfg = NCZDGConfig.Get();
  if !IsDefined(cfg) || !cfg.autoTrackMarker {
    NCZDGLog("[MARK] centred the map on the marker");
    return;
  }
  this.TrackMappin(ctrl);
  NCZDGLog("[MARK] centred the map on the marker and took the tracked slot");
}

// ── Opening the world map from script ────────────────────────────────────────────────────────────
//
// SpawnMenuInstanceDataEvent is the only route into the hub menus, and it is PROTECTED - it can be
// called from inside the class that owns it and nowhere else. It is declared on
// gameuiBaseMenuGameController (NOT on inkGameController, which is where an earlier attempt looked
// for it and is why that attempt failed to resolve the method).
//
// The guide is a Codeware InGamePopup, so it is not a menu controller and can never call it. An
// @addMethod on gameuiInGameMenuGameController is, for access purposes, a method OF that class, so
// the protected call is legal there - and that controller inherits the native from its base. What is
// then needed is a live instance, which is what OnInitialize captures.
//
// The body mirrors the game's own OpenShortcutMenu (inGameMenuGameController.swift:501-526) rather
// than inventing a path: same init data, same hardware-disabled guard, same combat restriction, same
// conditional event name.

@wrapMethod(gameuiInGameMenuGameController)
protected cb func OnInitialize() -> Bool {
  let result = wrappedMethod();
  let focus = NCZDGMapFocus.Get();
  if IsDefined(focus) {
    focus.SetMenu(this);
  }
  return result;
}

@wrapMethod(gameuiInGameMenuGameController)
protected cb func OnUninitialize() -> Bool {
  let focus = NCZDGMapFocus.Get();
  if IsDefined(focus) {
    focus.ClearMenu();
  }
  return wrappedMethod();
}

// Opens the world map. Returns false when the game itself would refuse, so the caller can tell the
// difference between "asked" and "did not ask" instead of assuming the map is on its way.
@addMethod(gameuiInGameMenuGameController)
public final func NCZDG_OpenWorldMap() -> Bool {
  let player = this.GetPlayerControlledObject();
  if !IsDefined(player) {
    return false;
  }
  // The game's own guard: with the player's hardware disabled, the hub is unavailable and the event
  // is silently dropped. Bail here so the failure is on record rather than invisible.
  if HubMenuUtility.IsPlayerHardwareDisabled(player) {
    NCZDGWarn("[MARK] cannot open the map - the player's hardware is disabled");
    return false;
  }

  let initData = new HubMenuInitData();
  initData.m_menuName = n"world_map";
  initData.m_combatRestriction =
    this.GetPSMBlackboard(player).GetInt(GetAllBlackboardDefs().PlayerStateMachine.Combat) == 1;

  // The event name is CONDITIONAL, and the wrong one opens nothing at all with no error anywhere.
  let gi = player.GetGame();
  let eventName: CName = GetFact(gi, n"radial_hub_menu_enabled") > 0
    ? n"OnOpenRadialHubMenu_InitData"
    : n"OnOpenHubMenu_InitData";

  this.SpawnMenuInstanceDataEvent(eventName, initData);
  return true;
}

// Called from the guide once it has closed itself. Fails quietly to the old behaviour - the request
// stays pending, so the marker is still centred whenever the player opens the map by hand.
public func NCZDG_TryOpenWorldMap() -> Bool {
  let focus = NCZDGMapFocus.Get();
  if !IsDefined(focus) {
    return false;
  }
  let menu = focus.GetMenu();
  if !IsDefined(menu) {
    NCZDGWarn("[MARK] no in-game menu controller captured - not opening the map");
    return false;
  }
  return menu.NCZDG_OpenWorldMap();
}

// Delayed so the guide's own close lands first. The popup holds UIGameContext.ModalPopup, and the
// hub menu cannot take the UI context while that is still up - the same ordering the teleport path
// uses, at the same 0.15s.
public class NCZDGOpenMapCallback extends DelayCallback {
  public func Call() -> Void {
    NCZDG_TryOpenWorldMap();
  }
}

public func NCZDG_ScheduleOpenMap(gi: GameInstance) -> Void {
  GameInstance.GetDelaySystem(gi).DelayCallback(new NCZDGOpenMapCallback(), 0.15);
}

// Entry point: the map has opened. A pending focus starts the poll for the pin's controller.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
  let result = wrappedMethod();
  let focus = NCZDGMapFocus.Get();
  if IsDefined(focus) {
    focus.ClearController();   // last session's controller is dead; do not act on it
    if focus.IsPending() {
      NCZDG_ScheduleFocus(this.GetPlayerControlledObject().GetGame(), this, 0);
    }
  }
  return result;
}
