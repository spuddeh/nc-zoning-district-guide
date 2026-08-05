// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: MapFocus.reds
// Author: Spuddeh
// Description: Centres the world map on the marker, and - optionally - tracks it for the player.
//
//              THE MAP MUST BE OPEN. A script cannot mark a mappin player-tracked: MappinSystem
//              exposes GetManuallyTrackedMappinID and no setter, and the three functions that can
//              do it live on WorldMapMenuGameController, which exists only while the map is open:
//
//                ZoomToMappin(BaseWorldMapMappinController)   centre the map on a pin
//                SetSelectedMappin(BaseWorldMapMappinController)
//                TrackMappin(BaseMappinBaseController)        the PLAYER-tracked slot, by controller
//
//              TrackCustomPositionMappin() is a DIFFERENT function and must not be substituted:
//              it creates a new waypoint at the map cursor rather than adopting an existing pin,
//              so on map open it plants one at roughly the world origin.
//              [[CP2077-Mods/wiki/learnings/a-script-registered-waypoint-cannot-route-itself]]
//
//              THE HANDLE COMES FROM THE ICON HOOK. A mappin controller is not reachable by
//              lookup, but MapMarker.reds already wraps BaseWorldMapMappinController.UpdateIcon
//              to brand the marker, so the controller passes through this mod on every map build.
//
//              NOTHING WAITS ON A TIMER, AND NOTHING MAY. The pin's controller does not exist when
//              the map opens; it is spawned later, as the map draws its pins. DelaySystem runs on
//              GAME time and an open map dilates that almost to a stop, so a 0.25s callback lands
//              ~9 REAL seconds later, after the player has closed the map. The request is queued,
//              and the marker's own icon hook fires it the moment the controller exists.
//
//              TRACKING IS ON BY DEFAULT. The player-tracked slot and the quest-tracked slot are
//              separate: vanilla's TryTrackQuestOrSetWaypoint branches CanQuestTrackMappin ->
//              TrackQuestMappin against CanPlayerTrackMappin -> TrackMappin, and the player branch
//              clears only UntrackCustomPositionMappin. Taking the player slot costs the player a
//              custom map waypoint, never their quest.
// Mod Version: 1.0.0
// Credits: Spuddeh
// ======================================================================================

module NCZoningDistrictGuide.MapFocus

import NCZoningDistrictGuide.Config.*

// Holds the request across the guide closing and the map opening - two different UI lifetimes, so
// this cannot live on either of them.
//
// A ScriptableSERVICE, not a System, because the capture point needs it. The controller is handed
// over from BaseWorldMapMappinController.UpdateIcon, and that is an inkLogicController with no
// GetPlayerControlledObject and therefore no GameInstance to look a system up with.
// GetScriptableServiceContainer() takes no GameInstance, so a service is reachable from there.
public class NCZDGMapFocus extends ScriptableService {
  private let m_pending: Bool;

  // A STRONG ref, and it has to be: the controller is native-owned, and a wref to it reads back
  // null once parked here across a frame. Kept safe by clearing it, not by weakening it - cleared
  // when the map opens, when it closes, and once a focus request has been consumed.
  private let m_ctrl: ref<BaseWorldMapMappinController>;
  private let m_menu: ref<gameuiInGameMenuGameController>;

  public final static func Get() -> ref<NCZDGMapFocus> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NCZoningDistrictGuide.MapFocus.NCZDGMapFocus") as NCZDGMapFocus;
  }

  // Set when the player asks to be shown the waypoint, and consumed the moment the map acts on it.
  // If the map is closed before its pins draw the request simply stays set, so the next map open
  // honours it rather than dropping it.
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

  // Captured from MapMarker's icon hook, which is the only place a mappin controller is reachable.
  public func SetController(ctrl: ref<BaseWorldMapMappinController>) -> Void {
    this.m_ctrl = ctrl;
  }

  public func GetController() -> ref<BaseWorldMapMappinController> {
    return this.m_ctrl;
  }

  public func ClearController() -> Void {
    this.m_ctrl = null;
  }

  // The live in-game menu controller, captured on its OnInitialize and released on OnUninitialize.
  // A STRONG ref, for the reason given on m_ctrl: a weak ref to a native-owned UI controller does
  // not reliably survive being parked here. Held safely by clearing it, never by weakening it.
  public func SetMenu(menu: ref<gameuiInGameMenuGameController>) -> Void {
    this.m_menu = menu;
  }

  public func ClearMenu() -> Void {
    this.m_menu = null;
  }

  public func GetMenu() -> ref<gameuiInGameMenuGameController> {
    return this.m_menu;
  }

  // The open world map. A STRONG ref for the same reason as m_ctrl, and cleared on map close.
  // Nothing in this flow may hold a weak ref across a frame.
  private let m_mapMenu: ref<WorldMapMenuGameController>;

  public func SetMapMenu(menu: ref<WorldMapMenuGameController>) -> Void {
    this.m_mapMenu = menu;
  }

  public func GetMapMenu() -> ref<WorldMapMenuGameController> {
    return this.m_mapMenu;
  }

  public func ClearMapMenu() -> Void {
    this.m_mapMenu = null;
  }

  // Stored because the trigger point is an inkLogicController: it has no GetPlayerControlledObject
  // and therefore no GameInstance of its own, and DelaySystem needs one.
  private let m_gi: GameInstance;

  public func SetGame(gi: GameInstance) -> Void {
    this.m_gi = gi;
  }

  public func GetGame() -> GameInstance {
    return this.m_gi;
  }
}

// THERE IS NO CALLBACK AND NO TIMER HERE, AND ONE MUST NOT BE ADDED.
//
// The focus fires synchronously from MapMarker's icon hook, at the moment the marker's controller
// exists. A delay here has no correct duration: DelaySystem runs on GAME time, and an open world
// map dilates that almost to a stop, so a 0.25s delay lands ~9 REAL seconds later - after the
// player has closed the map.

// Centres the map on the waypoint, and takes the PLAYER-tracked slot unless the player opted out.
//
// SetSelectedMappin before TrackMappin: the map's own key path (TryTrackQuestOrSetWaypoint) reads
// selectedMappin and falls through to creating a cursor waypoint when it is null, so selecting first
// keeps this on the same path the game uses rather than a parallel one.
@addMethod(WorldMapMenuGameController)
public final func NCZDG_FocusMarker(ctrl: ref<BaseWorldMapMappinController>) -> Void {
  if !IsDefined(ctrl) {
    return;
  }
  this.ZoomToMappin(ctrl);
  this.SetSelectedMappin(ctrl);

  let cfg = NCZDGConfig.Get();
  if !IsDefined(cfg) || !cfg.autoTrackMarker {
    NCZDGLog("[MARK] centred the map on the waypoint");
    return;
  }
  this.TrackMappin(ctrl);
  NCZDGLog("[MARK] centred the map on the waypoint and tracked it");
}

// ── Opening the world map from script ────────────────────────────────────────────────────────────
//
// SpawnMenuInstanceDataEvent is the only route into the hub menus, and it is PROTECTED - it can be
// called from inside the class that owns it and nowhere else. It is declared on
// gameuiBaseMenuGameController - NOT on inkGameController, where it does not resolve.
//
// The guide is a Codeware InGamePopup, so it is not a menu controller and can never call it. An
// @addMethod on gameuiInGameMenuGameController is, for access purposes, a method OF that class, so
// the protected call is legal there - and that controller inherits the native from its base. What is
// then needed is a live instance, which is what OnInitialize captures.
//
// The body mirrors the game's own OpenShortcutMenu (inGameMenuGameController.swift:501-526): same
// init data, same hardware-disabled guard, same combat restriction, same conditional event name.

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

// Called from the guide once it has closed itself. Fails quietly - the request stays pending, so
// the marker is still centred whenever the player opens the map by hand.
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

// NO TIMER HERE. The map open is called from NCZDGGuidePopup.OnHidden, because what it waits for is
// the ModalPopup context being popped - an event, not a duration. Scheduling it a fixed delay after
// Close() races the popup's teardown and soft-locks the game.

// The map is gone, so the controller it owned must not be held past it. This is what makes the
// strong ref safe.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnUninitialize() -> Bool {
  let focus = NCZDGMapFocus.Get();
  if IsDefined(focus) {
    focus.ClearController();
    focus.ClearMapMenu();
  }
  return wrappedMethod();
}

// Entry point: the map has opened.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
  let result = wrappedMethod();
  let focus = NCZDGMapFocus.Get();
  if IsDefined(focus) {
    focus.ClearController();   // last session's controller is dead; do not act on it
    // The map itself is captured here and held until it closes. Nothing is scheduled: the focus is
    // fired by the marker's controller appearing, which happens later as the map draws its pins.
    focus.SetMapMenu(this);
    let player = this.GetPlayerControlledObject();
    if IsDefined(player) {
      focus.SetGame(player.GetGame());
    }
  }
  return result;
}
