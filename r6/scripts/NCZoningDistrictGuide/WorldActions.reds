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
  public func SetWaypoint(gi: GameInstance, pos: Vector4, locId: String) -> Void {
    this.ClearWaypoint(gi);

    let ms = GameInstance.GetMappinSystem(gi);
    if !IsDefined(ms) {
      return;
    }
    // MappinData is an importonly struct: declare a local, never `new`.
    //
    // Mappins.DefaultStaticMappin, NOT Mappins.CustomPositionMappinDefinition. On paper the second
    // is the right record - DefaultStaticMappin declares possibleVariants = [DefaultVariant], which
    // does not include CustomPositionVariant, so this pairing is a mismatch. In game the mismatched
    // pairing is the one that behaves: with DefaultStaticMappin a map open/close builds the route,
    // and with CustomPositionMappinDefinition nothing does. Measured, not reasoned; do not "correct"
    // this back without re-testing the trail.
    //
    // CustomPositionVariant is correct HERE, because this pin IS the player's waypoint. It is wrong
    // for a point-of-interest pin, which is a separate bug in the checklist mods
    // (spuddeh/perk-shard-checklist#2).
    let data: MappinData;
    data.mappinType = t"Mappins.DefaultStaticMappin";
    data.variant = gamedataMappinVariant.CustomPositionVariant;
    data.active = true;
    data.visibleThroughWalls = true;

    this.m_mappinId = ms.RegisterMappin(data, pos);
    this.m_pinnedId = locId;

    let tracked = ms.GetManuallyTrackedMappinID();
    let pin = ms.GetMappin(this.m_mappinId);
    NCZDGLog(s"actions: waypoint set on '\(locId)' id=\(this.m_mappinId.value) trackedId=\(tracked.value) playerTracked=\(IsDefined(pin) ? pin.IsPlayerTracked() : false)");

    // The route is wired by whatever consumes the map's open/close state. Ask for it here rather
    // than making the player open the map.
    NCZDG_AnnounceMapCycle(gi);
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

// Announce a world-map open/close on the UI_Map blackboard, without opening the map.
//
// The map's OnInitialize / OnUninitialize write exactly this, and nothing in SCRIPT ever reads
// currentState - so whatever consumes it is native, and that is the same layer that wires a custom
// waypoint into the GPS route. Replaying the two writes asks that layer to do its work while the
// player stays in the world.
//
// The two writes must land on separate frames: a system that reacts to the transition needs to see
// "Initialized" before it sees "Uninitialized".
public func NCZDG_AnnounceMapCycle(gi: GameInstance) -> Void {
  let bb = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().UI_Map);
  if !IsDefined(bb) {
    return;
  }
  bb.SetString(GetAllBlackboardDefs().UI_Map.currentState, "Initialized", true);

  let close = new NCZDGMapCycleClose();
  close.gi = gi;
  GameInstance.GetDelaySystem(gi).DelayCallback(close, 0.1);
  NCZDGLog("[PIN] announced map Initialized; Uninitialized queued");
}

public class NCZDGMapCycleClose extends DelayCallback {
  public let gi: GameInstance;

  public func Call() -> Void {
    let bb = GameInstance.GetBlackboardSystem(this.gi).Get(GetAllBlackboardDefs().UI_Map);
    if !IsDefined(bb) {
      return;
    }
    bb.SetString(GetAllBlackboardDefs().UI_Map.currentState, "Uninitialized", true);
    NCZDG_LogMappinState(this.gi, "after-announced-map-close");
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
