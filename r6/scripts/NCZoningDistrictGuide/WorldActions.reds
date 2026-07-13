// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: WorldActions.reds
// Author: Spuddeh
// Description: The two things the guide can DO with a location: put a waypoint on it, or go there.
//
//              Unguarded: it only ever sees Vector4 / Float / String, never an NCZLocation, so it
//              needs no @if(ModuleExists) and holds whatever the core's state.
//
//              The CET equivalents, for anyone porting between the two:
//                Game.GetMappinSystem()          -> GameInstance.GetMappinSystem(gi)
//                Game.GetTeleportationFacility() -> GameInstance.GetTeleportationFacility(gi)
//                MappinData.new()                -> a plain `let data: MappinData;`
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (SimpleLocationManager, the CET original)
// ======================================================================================

// Owns the single waypoint. A ScriptableSystem so it outlives the popup: a pin set from the guide
// must survive the guide closing.
public class NCZDGWorldActions extends ScriptableSystem {
  private let m_mappinId: NewMappinID;
  private let m_pinnedId: String;      // the NCZLocation.Id() the pin belongs to; "" = none

  public final static func Get(gi: GameInstance) -> ref<NCZDGWorldActions> {
    return GameInstance.GetScriptableSystemsContainer(gi)
      .Get(n"NCZDGWorldActions") as NCZDGWorldActions;
  }

  // A NewMappinID is a runtime handle: value == 0 means no pin, and it does not survive a save
  // load. The system is per-session and the pin goes with it.
  public func HasPin() -> Bool {
    return this.m_mappinId.value != 0ul;
  }

  public func IsPinned(locId: String) -> Bool {
    return this.HasPin() && UnicodeStringEqual(locId, this.m_pinnedId);
  }

  public func PinId() -> NewMappinID {
    return this.m_mappinId;
  }

  // The game keeps ONE custom waypoint, so setting a second must clear the first.
  //
  // This pin CANNOT route itself: no breadcrumb trail appears until the player opens the world map
  // once. Nothing in the game tracks a mappin by id - tracking is a property of an OWNER, and the
  // only two owners are a world-map mappin controller (alive only while the map runs) and a journal
  // entry (buildable only through the scripted-quest API, which is stubbed to return false in the
  // shipped build). A pin registered from a script has no owner, so it cannot be nominated. Say so
  // in the UI; do not try to work around it in script.
  // [[CP2077-Mods/wiki/learnings/a-script-registered-waypoint-cannot-route-itself]]
  public func SetWaypoint(gi: GameInstance, pos: Vector4, locId: String) -> Void {
    this.ClearWaypoint(gi);

    let ms = GameInstance.GetMappinSystem(gi);
    if !IsDefined(ms) {
      return;
    }
    // MappinData is an importonly struct: declare a local, never `new`.
    //
    // TYPE = DefaultStaticMappin. On paper CustomPositionMappinDefinition is the right record and
    //   this pairing is a mismatch (DefaultStaticMappin declares possibleVariants = [DefaultVariant]).
    //   In game only this pairing has ever produced a route.
    //
    // VARIANT = CustomPositionVariant, because this pin IS the player's waypoint. It is the WRONG
    //   variant for a point-of-interest pin, which is a separate bug in the checklist mods
    //   (spuddeh/perk-shard-checklist#2): the game adopts any such mappin as the player's waypoint,
    //   so registering many of them produces waypoints the player never asked for.
    //
    // DO NOT set `active`. It changes nothing - the game sets it on the mappin regardless of what is
    //   passed here (measured: a pin registered with active = false comes back active = true).
    //
    // The ICON is overridable: GameplayRoleMappinData.m_textureID on scriptData beats the variant's
    //   own icon (measured - a PlayerStashMappin glyph rendered in place of the waypoint arrow). A
    //   branded pin therefore needs only a MappinIcons TweakDB record, which means a TweakXL
    //   dependency this mod does not currently carry.
    let data: MappinData;
    data.mappinType = t"Mappins.DefaultStaticMappin";
    data.variant = gamedataMappinVariant.CustomPositionVariant;
    data.visibleThroughWalls = true;

    this.m_mappinId = ms.RegisterMappin(data, pos);
    this.m_pinnedId = locId;

    NCZDGLog(s"actions: waypoint set on '\(locId)'");

    NCZDG_MapWake(gi, this.m_mappinId, "immediate");

    let wake = new NCZDGMapWakeCallback();
    wake.gi = gi;
    wake.pin = this.m_mappinId;
    GameInstance.GetDelaySystem(gi).DelayCallback(wake, 1.0);
  }

  public func ClearWaypoint(gi: GameInstance) -> Void {
    if !this.HasPin() {
      return;
    }
    let ms = GameInstance.GetMappinSystem(gi);
    if IsDefined(ms) {
      ms.UnregisterMappin(this.m_mappinId);
    }
    let empty: NewMappinID;
    this.m_mappinId = empty;
    this.m_pinnedId = "";
    NCZDGLog("actions: waypoint cleared");
  }
}

// DEV ONLY. Dumps the tracking state that decides whether a route is drawn.
//
// Autodrive (2.3) is the useful witness here. Its destination type enum is None / PlayerTracked /
// Quest, so PlayerTracked means the game already derives a ROUTABLE ROAD DESTINATION from a
// player-tracked mappin. If GetAutodriveDestinationMappinID() ever comes back as the registered
// pin's id, the game considers it a real destination and the route machinery is reachable.
public func NCZDG_LogMappinState(gi: GameInstance, when: String) -> Void {
  let ms = GameInstance.GetMappinSystem(gi);
  if !IsDefined(ms) {
    return;
  }
  let trackedId = ms.GetManuallyTrackedMappinID();
  let tracked = ms.GetMappin(trackedId);
  if IsDefined(tracked) {
    NCZDGLog(s"[PIN \(when)] trackedId=\(trackedId.value) variant=\(EnumInt(tracked.GetVariant())) playerTracked=\(tracked.IsPlayerTracked()) active=\(tracked.IsActive()) visible=\(tracked.IsVisible()) pos=\(tracked.GetWorldPosition())");
  } else {
    NCZDGLog(s"[PIN \(when)] trackedId=\(trackedId.value) - NO manually-tracked mappin");
  }

  let ad = GameInstance.GetScriptableSystemsContainer(gi).Get(n"AutoDriveSystem") as AutoDriveSystem;
  if IsDefined(ad) {
    NCZDGLog(s"[AUTODRIVE \(when)] destType=\(EnumInt(ad.GetAutodriveDestinationType())) destMappin=\(ad.GetAutodriveDestinationMappinID().value) dest=\(ad.GetAutodriveDestination()) enabled=\(ad.GetAutodriveEnabled())");
  } else {
    NCZDGLog(s"[AUTODRIVE \(when)] system not found");
  }
}

// False while mounted. The game models a vehicle teleport by moving the VEHICLE and letting the
// mount carry the player; moving a mounted player alone is unmodelled.
public func NCZDG_CanTeleport(gi: GameInstance) -> Bool {
  let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
  if !IsDefined(player) {
    return false;
  }
  return !VehicleComponent.IsMountedToVehicle(gi, player);
}

public func NCZDG_TeleportTo(gi: GameInstance, pos: Vector4, yaw: Float) -> Void {
  let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
  if !IsDefined(player) {
    return;
  }
  // EulerAngles is importonly too: declare, do not `new`. Order is (roll, pitch, yaw).
  let angles: EulerAngles;
  angles.Roll = 0.0;
  angles.Pitch = 0.0;
  angles.Yaw = yaw;

  GameInstance.GetTeleportationFacility(gi).Teleport(player, pos, angles);
  NCZDGLog(s"actions: teleported to (\(pos.X), \(pos.Y), \(pos.Z)) yaw \(yaw)");
}

// Runs after the popup has closed. The popup holds UIGameContext.ModalPopup and pins time dilation
// at ~1e-6, and a long-distance teleport triggers world streaming, which needs a running clock and
// no modal. Vanilla's DEBUG_Teleport closes the world map before teleporting for the same reason.
public class NCZDGTeleportCallback extends DelayCallback {
  public let gi: GameInstance;
  public let pos: Vector4;
  public let yaw: Float;

  public func Call() -> Void {
    NCZDG_TeleportTo(this.gi, this.pos, this.yaw);
  }
}
