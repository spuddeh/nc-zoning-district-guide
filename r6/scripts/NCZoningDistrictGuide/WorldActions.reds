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
  private let m_pinnedPos: Vector4;    // where the waypoint was put; a mismatch means the map moved it
  private let m_borrowed: Bool;        // true when the mappin is the GAME's, moved rather than registered

  public final static func Get(gi: GameInstance) -> ref<NCZDGWorldActions> {
    return GameInstance.GetScriptableSystemsContainer(gi)
      .Get(n"NCZDGWorldActions") as NCZDGWorldActions;
  }

  // A NewMappinID is a runtime handle: value == 0 means no pin, and it does not survive a save
  // load. The system is per-session and the pin goes with it.
  // A waypoint is SET when a location owns it. The mappin can outlive that - it is kept alive and
  // deactivated across a clear, because only the world map can put one in the tracked slot and a
  // tracked mappin can be repositioned forever.
  public func HasPin() -> Bool {
    this.Reconcile();
    return this.m_mappinId.value != 0ul && !UnicodeStringEqual(this.m_pinnedId, "");
  }

  private func HasMappin() -> Bool {
    return this.m_mappinId.value != 0ul;
  }

  // The waypoint belongs to the GAME, and the map can destroy or move it at any time with no
  // notification. Held state must be re-checked against the mappin system before it is trusted, or it
  // goes stale: a waypoint cleared from the map leaves the guide still offering CLEAR WAYPOINT for it.
  private func Reconcile() -> Void {
    if this.m_mappinId.value == 0ul {
      return;
    }
    let ms = GameInstance.GetMappinSystem(this.GetGameInstance());
    if !IsDefined(ms) {
      return;
    }

    let mappin = ms.GetMappin(this.m_mappinId);
    if !IsDefined(mappin) {
      let empty: NewMappinID;
      this.m_mappinId = empty;
      this.m_pinnedId = "";
      this.m_borrowed = false;
      NCZDGLog("[SYNC] the waypoint was destroyed elsewhere - releasing it");
      return;
    }

    // Moved from the map: the mappin lives on, but it no longer marks the location it was set for.
    if !UnicodeStringEqual(this.m_pinnedId, "")
      && Vector4.Distance(mappin.GetWorldPosition(), this.m_pinnedPos) > 1.0 {
      this.m_pinnedId = "";
      NCZDGLog("[SYNC] the waypoint was moved elsewhere - releasing the location");
    }
  }

  // No tracked waypoint means there is nothing to move, and REGISTERING one is not a fallback:
  // a script-registered variant-21 mappin sits alongside the one the game builds the next time the
  // player sets a waypoint from the map, and two of them corrupt the game's waypoint handling.
  public func CanSetWaypoint(gi: GameInstance) -> Bool {
    let ms = GameInstance.GetMappinSystem(gi);
    if !IsDefined(ms) {
      return false;
    }
    let trackedId = ms.GetManuallyTrackedMappinID();
    if trackedId.value != 0ul && IsDefined(ms.GetMappin(trackedId)) {
      return true;
    }
    return this.HasMappin() && IsDefined(ms.GetMappin(this.m_mappinId));
  }

  public func IsPinned(locId: String) -> Bool {
    return this.HasPin() && UnicodeStringEqual(locId, this.m_pinnedId);
  }

  public func PinId() -> NewMappinID {
    return this.m_mappinId;
  }

  // Reactivate, reposition, and take ownership of an existing mappin. No mappin is created.
  private func Adopt(gi: GameInstance, id: NewMappinID, pos: Vector4, locId: String,
                     borrowed: Bool, what: String) -> Void {
    let ms = GameInstance.GetMappinSystem(gi);
    ms.SetMappinActive(id, true);
    ms.SetMappinPosition(id, pos);

    this.m_mappinId = id;
    this.m_pinnedId = locId;
    this.m_pinnedPos = pos;
    this.m_borrowed = borrowed;

    NCZDGLog(s"[MOVE] reused \(what) id=\(id.value) -> \(pos)");
    let readback = ms.GetMappin(id);
    if IsDefined(readback) {
      NCZDGLog(s"[MOVE] readback: tracked=\(readback.IsPlayerTracked()) active=\(readback.IsActive()) visible=\(readback.IsVisible()) pos=\(readback.GetWorldPosition())");
    }
  }

  // THIS NEVER CREATES A MAPPIN. It moves the one the game already tracks.
  //
  // CustomPositionVariant (21) is a ROLE, not a look: the game assumes exactly one mappin holds it,
  // looks that mappin up, and WRITES to it. A second variant-21 mappin makes it write to the wrong
  // one - measured, it moved a script-registered pin to a coordinate nobody chose and created a third
  // waypoint elsewhere. A script-registered pin also cannot route: nothing in the game tracks a mappin
  // by id, and the C++ slot naming THE custom-position mappin is not writable from script.
  //
  // So registering is not a fallback - it is a decoy that draws no trail and corrupts the player's
  // waypoint state as soon as they set one from the map. With no tracked waypoint there is nothing to
  // move, and the honest answer is to refuse and say why. CanSetWaypoint() reports it.
  //
  // The GPS reads a tracked mappin's position LIVE, so repositioning it redraws the trail with no map
  // open. [[CP2077-Mods/wiki/learnings/a-script-registered-waypoint-cannot-route-itself]]
  public func SetWaypoint(gi: GameInstance, pos: Vector4, locId: String) -> Bool {
    let ms = GameInstance.GetMappinSystem(gi);
    if !IsDefined(ms) {
      return false;
    }

    // A NewMappinID read inline off the call yields a heap pointer, not the id. Bind it first.
    let trackedId = ms.GetManuallyTrackedMappinID();
    if trackedId.value != 0ul && IsDefined(ms.GetMappin(trackedId)) {
      this.Adopt(gi, trackedId, pos, locId, true, "the game's tracked waypoint");
      return true;
    }

    // Deactivated by a clear earlier this session. The tracked slot is scarce - only the world map can
    // fill it - so the mappin is revived rather than abandoned.
    if this.HasMappin() && IsDefined(ms.GetMappin(this.m_mappinId)) {
      this.Adopt(gi, this.m_mappinId, pos, locId, this.m_borrowed, "a dormant waypoint");
      return true;
    }

    NCZDGLog("[MOVE] refused: no waypoint exists to move, and registering one would corrupt the game's");
    return false;
  }

  // Destroying the mappin also empties the tracked slot, and the slot is the scarce thing: only the
  // world map can fill it. A tracked mappin can be repositioned forever, so it is kept alive and
  // merely deactivated - the trail must go with it.
  //
  // PROBE. If an inactive mappin keeps routing, this is a GHOST TRAIL - an invisible waypoint still
  // drawing a line - which is worse than the bug it replaces. Unregister is the fallback.
  public func ClearWaypoint(gi: GameInstance) -> Void {
    if !this.HasPin() {
      return;
    }
    let ms = GameInstance.GetMappinSystem(gi);
    if IsDefined(ms) {
      ms.SetMappinActive(this.m_mappinId, false);

      let readback = ms.GetMappin(this.m_mappinId);
      if IsDefined(readback) {
        NCZDGLog(s"[CLEAR] deactivated id=\(this.m_mappinId.value) active=\(readback.IsActive()) visible=\(readback.IsVisible()) tracked=\(readback.IsPlayerTracked())");
      } else {
        NCZDGLog(s"[CLEAR] deactivated id=\(this.m_mappinId.value) - the mappin no longer resolves");
      }
      let stillTracked = ms.GetManuallyTrackedMappinID();
      NCZDGLog(s"[CLEAR] tracked slot after deactivate: \(stillTracked.value)");
    }
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
