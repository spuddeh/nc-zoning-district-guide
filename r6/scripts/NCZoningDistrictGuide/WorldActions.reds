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
  // A waypoint is SET when a location owns it. The mappin can outlive that - it is kept alive and
  // deactivated across a clear, because only the world map can put one in the tracked slot and a
  // tracked mappin can be repositioned forever.
  public func HasPin() -> Bool {
    return this.m_mappinId.value != 0ul && !UnicodeStringEqual(this.m_pinnedId, "");
  }

  private func HasMappin() -> Bool {
    return this.m_mappinId.value != 0ul;
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
    this.m_borrowed = borrowed;

    NCZDGLog(s"[MOVE] reused \(what) id=\(id.value) -> \(pos)");
    let readback = ms.GetMappin(id);
    if IsDefined(readback) {
      NCZDGLog(s"[MOVE] readback: tracked=\(readback.IsPlayerTracked()) active=\(readback.IsActive()) visible=\(readback.IsVisible()) pos=\(readback.GetWorldPosition())");
    }
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

    // BEST CASE: a waypoint is tracked. Move it. The GPS reads a tracked mappin's position live, so
    // the trail redraws with no map open - measured.
    if trackedId.value != 0ul && IsDefined(ms.GetMappin(trackedId)) {
      // A pin this system registered earlier must not survive alongside the tracked one.
      if this.HasMappin() && this.m_mappinId.value != trackedId.value && !this.m_borrowed {
        ms.UnregisterMappin(this.m_mappinId);
      }
      this.Adopt(gi, trackedId, pos, locId, true, "the game's tracked waypoint");
      return;
    }

    // A mappin from earlier this session, deactivated by a clear. Reuse it rather than registering a
    // second one, which is what corrupts the game's waypoint state.
    if this.HasMappin() && IsDefined(ms.GetMappin(this.m_mappinId)) {
      this.Adopt(gi, this.m_mappinId, pos, locId, this.m_borrowed, "a dormant mappin");
      return;
    }

    NCZDGLog("[MOVE] nothing to reposition - registering a new pin");
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
