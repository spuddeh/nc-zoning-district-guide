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
  private let m_isQuestPin: Bool;      // a journal-owned pin is retired by DeleteScriptedQuest, not UnregisterMappin

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
  // Two pins are possible and they are not equivalent. A journal-owned pin (QuestPinProbe) is the
  // only one that can be TRACKED without the world map being opened, because tracking is a property
  // of an owner and a bare mappin has none. It is tried first; the orphan pin below is the fallback
  // and cannot route until the player opens the map.
  public func SetWaypoint(gi: GameInstance, pos: Vector4, locId: String, title: String) -> Void {
    this.ClearWaypoint(gi);

    let questId = NCZDG_QuestPinSet(gi, pos, title);
    if questId.value != 0ul {
      this.m_mappinId = questId;
      this.m_pinnedId = locId;
      this.m_isQuestPin = true;
      NCZDGLog(s"actions: waypoint set on '\(locId)' via the journal");
      return;
    }

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
    let data: MappinData;
    data.mappinType = t"Mappins.DefaultStaticMappin";
    data.variant = gamedataMappinVariant.CustomPositionVariant;
    data.visibleThroughWalls = true;

    // DEV EXPERIMENT, remove either way. Can the pin carry a CUSTOM ICON without changing the
    // variant? The variant cannot change - CustomPositionVariant is what the map adopts - so the
    // only candidate is scriptData. GameplayMappinController.UpdateIcon prefers m_textureID over the
    // variant-derived icon when it is a valid TweakDBID. Whether the custom-position pin uses that
    // controller at all is the open question. A stash glyph is unmistakable next to a waypoint.
    let icon = new GameplayRoleMappinData();
    icon.m_textureID = t"MappinIcons.PlayerStashMappin";
    icon.m_visibleThroughWalls = true;
    icon.m_showOnMiniMap = true;
    data.scriptData = icon;

    this.m_mappinId = ms.RegisterMappin(data, pos);
    this.m_pinnedId = locId;
    this.m_isQuestPin = false;

    NCZDGLog(s"actions: waypoint set on '\(locId)' as an orphan pin [ICON TEST: MappinIcons.PlayerStashMappin]");
  }

  public func ClearWaypoint(gi: GameInstance) -> Void {
    if !this.HasPin() {
      return;
    }
    if this.m_isQuestPin {
      NCZDG_QuestPinClear(gi);
    } else {
      let ms = GameInstance.GetMappinSystem(gi);
      if IsDefined(ms) {
        ms.UnregisterMappin(this.m_mappinId);
      }
    }
    let empty: NewMappinID;
    this.m_mappinId = empty;
    this.m_pinnedId = "";
    this.m_isQuestPin = false;
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
