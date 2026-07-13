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

  // The game keeps ONE custom waypoint, so setting a second must clear the first.
  public func SetWaypoint(gi: GameInstance, pos: Vector4, locId: String) -> Void {
    this.ClearWaypoint(gi);

    let ms = GameInstance.GetMappinSystem(gi);
    if !IsDefined(ms) {
      return;
    }
    // MappinData is an importonly struct: declare a local, never `new`.
    //
    // The type MUST be Mappins.CustomPositionMappinDefinition. Mappins.DefaultStaticMappin declares
    // possibleVariants = [DefaultVariant], which does not include CustomPositionVariant, so pairing
    // the two is a definition/variant mismatch: the pin draws, but no GPS route is built until the
    // world map opens and runs its own custom-position sync.
    let data: MappinData;
    data.mappinType = t"Mappins.CustomPositionMappinDefinition";
    data.variant = gamedataMappinVariant.CustomPositionVariant;
    data.active = true;
    data.visibleThroughWalls = true;

    this.m_mappinId = ms.RegisterMappin(data, pos);
    this.m_pinnedId = locId;

    let tracked = ms.GetManuallyTrackedMappinID();
    let pin = ms.GetMappin(this.m_mappinId);
    NCZDGLog(s"actions: waypoint set on '\(locId)' id=\(this.m_mappinId.value) trackedId=\(tracked.value) playerTracked=\(IsDefined(pin) ? pin.IsPlayerTracked() : false)");
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

// DEV ONLY. Dumps the tracking state that decides whether a GPS route is drawn.
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
