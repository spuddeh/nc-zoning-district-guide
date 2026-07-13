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
  private let m_borrowed: Bool;        // true when the pin is the GAME's waypoint, moved rather than registered

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

  // CustomPositionVariant (21) is a ROLE, not a look. The game's own waypoint is a RuntimeMappin with
  // variant 21 - structurally identical to what RegisterMappin produces - and the game's waypoint
  // handling misbehaves when a SECOND variant-21 mappin exists: measured, it moved a registered pin to
  // a coordinate nobody chose and created a third waypoint elsewhere. Registering one while the player
  // already has a waypoint corrupts their waypoint state. TWO MUST NEVER COEXIST.
  //
  // So the two paths below are exclusive by construction:
  //   waypoint already set -> REPOSITION it. It is already tracked, so no new mappin is created.
  //   no waypoint          -> register one. It is then the only variant-21 mappin in the world.
  //
  // The registered pin still cannot route itself: nothing in the game tracks a mappin by id, and the
  // C++ slot naming THE custom-position mappin is not writable from script. It draws no trail until
  // the map is opened once.
  // [[CP2077-Mods/wiki/learnings/a-script-registered-waypoint-cannot-route-itself]]
  public func SetWaypoint(gi: GameInstance, pos: Vector4, locId: String) -> Void {
    let ms = GameInstance.GetMappinSystem(gi);
    if !IsDefined(ms) {
      return;
    }

    // A NewMappinID read inline off the call yields a heap pointer, not the id. Bind it first.
    let trackedId = ms.GetManuallyTrackedMappinID();
    if trackedId.value != 0ul {
      let tracked = ms.GetMappin(trackedId);
      if IsDefined(tracked) {
        // Only a pin this system REGISTERED may be unregistered here. A borrowed one is the mappin
        // about to be repositioned, and destroying it first would leave a dead id.
        if this.HasPin() && !this.m_borrowed {
          this.ClearWaypoint(gi);
        }
        ms.SetMappinPosition(trackedId, pos);
        this.m_mappinId = trackedId;
        this.m_pinnedId = locId;
        this.m_borrowed = true;

        let readback = ms.GetMappin(trackedId);
        NCZDGLog(s"[MOVE] repositioned the game's own waypoint id=\(trackedId.value) to \(pos)");
        if IsDefined(readback) {
          NCZDGLog(s"[MOVE] readback: tracked=\(readback.IsPlayerTracked()) pos=\(readback.GetWorldPosition())");
        }
        return;
      }
    }

    this.ClearWaypoint(gi);
    NCZDGLog("[MOVE] no waypoint to reposition - registering a new pin");
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

    // RegisterMappin is async - the pin does not exist on this frame - so the baseline census that
    // the map session is diffed against has to wait for it.
    let snap = new NCZDGMapDiffCallback();
    snap.gi = gi;
    GameInstance.GetDelaySystem(gi).DelayCallback(snap, 2.0);
  }

  // A borrowed waypoint belongs to the game, so clearing it must do what the map does when the player
  // clears a waypoint: destroy the mappin. It must NOT be left behind untracked, or it becomes a
  // second variant-21 mappin the moment another is set.
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
    this.m_borrowed = false;
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
