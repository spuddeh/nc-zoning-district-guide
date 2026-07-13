// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: WorldActions.reds
// Author: Spuddeh
// Description: The two things the guide can DO with a location: mark it, or go there.
//
//              Unguarded: it only ever sees Vector4 / Float / String, never an NCZLocation, so it
//              needs no @if(ModuleExists) and holds whatever the core's state.
//
//              THE MARKER IS NOT A WAYPOINT, and that distinction is the whole design.
//
//              CustomPositionVariant (21) is a ROLE, not a look: the game assumes exactly one mappin
//              holds it, looks that mappin up, and WRITES to it. Registering a second one makes the
//              game write to the wrong mappin - measured, it moved a script-registered pin to a
//              coordinate nobody chose and spawned a third waypoint. It is the cause of the "random
//              waypoints" reports against the checklist mods (spuddeh/perk-shard-checklist#2).
//
//              So this registers an ordinary POI marker instead, on a variant the waypoint logic does
//              not own. The player's own waypoint is never touched, and two markers can never
//              collide with it.
//
//              Routing then comes for free, because of two measured facts:
//                1. ANY non-quest mappin can be player-tracked from the world map
//                   (CanPlayerTrackMappin = !CanQuestTrackMappin, and a quest-trackable mappin needs
//                   a journal entry in a Quest group - a POI marker has neither).
//                2. The GPS reads a tracked mappin's position LIVE. Move the mappin in the tracked
//                   slot and the breadcrumb trail redraws immediately, with no map open.
//
//              So the player tracks the marker once, from the map, as a normal game action against an
//              ordinary POI pin. From then on the guide repositions it and the trail follows. A clear
//              DEACTIVATES the marker rather than destroying it, because the tracked slot is the
//              scarce thing - only the world map can fill it - and a marker that survives a clear
//              never needs re-tracking.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (SimpleLocationManager, the CET original)
// ======================================================================================

// IMappin.GetDisplayName() returns the debugCaption, so a tag written into it identifies the marker
// from any controller hook without a side table mapping ids to mods.
public func NCZDG_MarkerTag() -> String { return "NCZDG"; }

public func NCZDG_MarkerCaption(title: String) -> String {
  return NCZDG_MarkerTag() + "|" + title;
}

// Owns the single marker. A ScriptableSystem so it outlives the popup: a marker set from the guide
// must survive the guide closing.
public class NCZDGWorldActions extends ScriptableSystem {
  private let m_mappinId: NewMappinID;
  private let m_pinnedId: String;      // the NCZLocation.Id() the marker belongs to; "" = none
  private let m_pinnedPos: Vector4;
  private let m_confirmed: Bool;       // the mappin has resolved at least once; registration is async

  public final static func Get(gi: GameInstance) -> ref<NCZDGWorldActions> {
    return GameInstance.GetScriptableSystemsContainer(gi)
      .Get(n"NCZDGWorldActions") as NCZDGWorldActions;
  }

  // A marker is SET when a location owns it. The mappin outlives that: it is deactivated on a clear,
  // not destroyed, so the tracked slot it may be sitting in survives.
  public func HasPin() -> Bool {
    this.Reconcile();
    return this.m_mappinId.value != 0ul && !UnicodeStringEqual(this.m_pinnedId, "");
  }

  public func IsPinned(locId: String) -> Bool {
    return this.HasPin() && UnicodeStringEqual(locId, this.m_pinnedId);
  }

  private func HasMappin() -> Bool {
    return this.m_mappinId.value != 0ul;
  }

  // True once the player has tracked the marker from the map. Until then the marker draws but does
  // not route, and only the player can change that - there is no script-side way to fill the slot.
  public func IsRouting(gi: GameInstance) -> Bool {
    if !this.HasMappin() {
      return false;
    }
    let ms = GameInstance.GetMappinSystem(gi);
    if !IsDefined(ms) {
      return false;
    }
    let trackedId = ms.GetManuallyTrackedMappinID();
    return trackedId.value == this.m_mappinId.value;
  }

  // The map can destroy the marker with no notification, so held state is re-checked before it is
  // trusted.
  //
  // RegisterMappin is ASYNC: GetMappin(id) returns null for the first frames after registering, even
  // though the id is real. A reconcile that treats null as "destroyed" therefore deletes the marker it
  // just created. Nothing is released until the mappin has been seen alive at least once.
  private func Reconcile() -> Void {
    if this.m_mappinId.value == 0ul {
      return;
    }
    let ms = GameInstance.GetMappinSystem(this.GetGameInstance());
    if !IsDefined(ms) {
      return;
    }
    if IsDefined(ms.GetMappin(this.m_mappinId)) {
      this.m_confirmed = true;
      return;
    }
    if !this.m_confirmed {
      return;
    }
    let empty: NewMappinID;
    this.m_mappinId = empty;
    this.m_pinnedId = "";
    this.m_confirmed = false;
    NCZDGLog("[SYNC] the marker was destroyed elsewhere - releasing it");
  }

  // Never creates a second mappin. One marker exists per session and moves between locations.
  //
  // A NewMappinID read inline off the call (GetNewMappinID().value) yields a heap pointer, not the
  // id. Bind the struct to a local first, always.
  public func SetWaypoint(gi: GameInstance, pos: Vector4, locId: String, title: String) -> Bool {
    let ms = GameInstance.GetMappinSystem(gi);
    if !IsDefined(ms) {
      return false;
    }

    if this.HasMappin() && IsDefined(ms.GetMappin(this.m_mappinId)) {
      ms.SetMappinActive(this.m_mappinId, true);
      ms.SetMappinPosition(this.m_mappinId, pos);
      ms.SetMappinDebugCaption(this.m_mappinId, NCZDG_MarkerCaption(title));
      this.m_pinnedId = locId;
      this.m_pinnedPos = pos;

      NCZDGLog(s"[MARK] moved the marker to '\(title)' \(pos) routing=\(this.IsRouting(gi))");
      return true;
    }

    // MappinData is an importonly struct: declare a local, never `new`.
    //
    // ApartmentVariant is any ordinary POI variant - what matters is only that it is NOT
    // CustomPositionVariant and NOT quest-grouped, so the waypoint logic does not own it and the
    // player is allowed to track it. The icon is overridden on the controller, so the variant's own
    // look does not survive to the screen.
    let data: MappinData;
    data.mappinType = t"Mappins.DefaultStaticMappin";
    data.variant = gamedataMappinVariant.ApartmentVariant;
    data.visibleThroughWalls = true;
    data.debugCaption = NCZDG_MarkerCaption(title);

    this.m_mappinId = ms.RegisterMappin(data, pos);
    this.m_pinnedId = locId;
    this.m_pinnedPos = pos;

    NCZDGLog(s"[MARK] registered the marker on '\(title)' \(pos) id=\(this.m_mappinId.value)");
    return true;
  }

  // Deactivate, never unregister: destroying the mappin would empty the tracked slot, and only the
  // world map can fill it again.
  public func ClearWaypoint(gi: GameInstance) -> Void {
    if !this.HasPin() {
      return;
    }
    let ms = GameInstance.GetMappinSystem(gi);
    if IsDefined(ms) {
      ms.SetMappinActive(this.m_mappinId, false);
    }
    this.m_pinnedId = "";
    NCZDGLog("[MARK] marker cleared (deactivated, still tracked)");
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
