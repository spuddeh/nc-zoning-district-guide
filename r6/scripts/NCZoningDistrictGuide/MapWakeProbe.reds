// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: MapWakeProbe.reds
// Author: Spuddeh
// Description: DEV ONLY. Strip with Logging.reds and InkDebug.reds at M7.
//
//              A script-registered pin is not tracked and draws no route until the world map is
//              opened once. The map's own code cannot be read, and the route renderer is invisible
//              to script - gamegpsGPSSystem and gameuiGPSGameController have zero scripted members
//              and zero references anywhere in the decompiled scripts. So the map's work can only be
//              observed by its RESULT.
//
//              This snapshots every mappin the system holds, then diffs across the map session:
//              what was CREATED, what was DESTROYED, and whose tracked/active/variant state MOVED.
//              If the map builds an owner object, it appears here as a new id. If it only flips a
//              flag on the pin already present, that appears here too - and they are different
//              answers with different consequences.
//
//              Established by the earlier runs and not re-litigated here:
//                - RegisterMappin is ASYNC. GetMappin(id) is null on the registering frame.
//                - Once materialised, the pin is present in all three target lists (World, Minimap,
//                  Map), active, visible, variant 21, and untracked. The map is not short of data.
//                - Reading the Map-target list does not adopt it.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh
// ======================================================================================

// The snapshot lives on the system so it survives the map session that is being measured.
public class NCZDGMapDiff extends ScriptableSystem {
  private let m_ids: array<Uint64>;
  private let m_desc: array<String>;
  private let m_taken: Bool;

  // --- instance census (the [INST] probe) --------------------------------------------------
  // One key press invokes TryTrackQuestOrSetWaypoint N times, N growing by one per map open, and all
  // but the last see selectedMappin == null - so each stale one runs TrackCustomPositionMappin() and
  // drops a stray waypoint. The stray then STEALS the tracked slot on the next map open.
  //
  // The method is reached from a GLOBAL INPUT CALLBACK (OnEntityAttached registers OnPressInput,
  // OnEntityDetached unregisters it - balanced in vanilla), so one registration is surviving each map
  // open. Two shapes fit the log and they need different fixes:
  //
  //   A. N leaked CONTROLLER INSTANCES, each still registered  -> the [PRESS] burst carries N ids
  //   B. ONE instance registered N times                       -> the [PRESS] burst repeats ONE id
  //
  // The id is what discriminates them. It is stamped once per object (assigned only when 0), so a
  // REUSED controller keeps its id across map opens and a fresh one gets a new one.
  private let m_instSeq: Int32;
  private let m_liveCtrl: Int32;

  public final func NextInstId() -> Int32 {
    this.m_instSeq += 1;
    return this.m_instSeq;
  }

  // Returns the live count AFTER the change, so attach/detach lines read as a running balance.
  // If DETACH never appears, or live only ever climbs, the registrations are never being removed.
  public final func CtrlAttached() -> Int32 {
    this.m_liveCtrl += 1;
    return this.m_liveCtrl;
  }

  public final func CtrlDetached() -> Int32 {
    this.m_liveCtrl -= 1;
    return this.m_liveCtrl;
  }

  public final func LiveCtrl() -> Int32 {
    return this.m_liveCtrl;
  }

  public final static func Get(gi: GameInstance) -> ref<NCZDGMapDiff> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"NCZDGMapDiff") as NCZDGMapDiff;
  }

  // The census covers every mappin, not just the registered pin. An owner object the map creates is
  // a mappin that appeared from nowhere, and only a full census can recognise it as new.
  private func Census(gi: GameInstance, out ids: array<Uint64>, out desc: array<String>) -> Void {
    let ms = GameInstance.GetMappinSystem(gi);
    if !IsDefined(ms) {
      return;
    }
    let all: array<ref<IMappin>>;
    ms.GetMappins(gamemappinsMappinTargetType.Map, all);

    let i = 0;
    while i < ArraySize(all) {
      let m = all[i];
      if IsDefined(m) {
        let mid = m.GetNewMappinID();
        ArrayPush(ids, mid.value);
        ArrayPush(desc, s"\(m.GetClassName()) variant=\(EnumInt(m.GetVariant())) tracked=\(m.IsPlayerTracked()) active=\(m.IsActive()) visible=\(m.IsVisible()) pos=\(m.GetWorldPosition())");
      }
      i += 1;
    }
  }

  private func IndexOf(ids: array<Uint64>, id: Uint64) -> Int32 {
    let i = 0;
    while i < ArraySize(ids) {
      if ids[i] == id {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  // GetManuallyTrackedMappinID() and IMappin.IsPlayerTracked() name the SAME mappin - there is one
  // tracking slot, not two. They only appeared to disagree because a NewMappinID read inline off the
  // call (`GetNewMappinID().value`) yields a heap pointer, not the id. Bind the struct to a local
  // first. Every id in this file is read that way, and any that is not will silently lie.
  //
  // The trail follows IsPlayerTracked: the HUD's MappinsContainerController renders it into
  // gpsPlayerTrackedPathWidget, separate from gpsQuestPathWidget, gpsDelamainPathWidget and
  // autodrivePathWidget.
  public func TrackedCensus(gi: GameInstance, when: String) -> Void {
    let ms = GameInstance.GetMappinSystem(gi);
    if !IsDefined(ms) {
      return;
    }

    let manualId = ms.GetManuallyTrackedMappinID();
    let manual = ms.GetMappin(manualId);
    if IsDefined(manual) {
      NCZDGLog(s"[TRACK \(when)] manuallyTracked id=\(manualId.value) \(manual.GetClassName()) variant=\(EnumInt(manual.GetVariant())) playerTracked=\(manual.IsPlayerTracked()) quest=\(manual.IsQuestMappin()) name='\(manual.GetDisplayName())' pos=\(manual.GetWorldPosition())");
    } else {
      NCZDGLog(s"[TRACK \(when)] manuallyTracked id=\(manualId.value) -> resolves to NOTHING");
    }

    let taxiId = ms.GetDelamainTrackedMappinID();
    NCZDGLog(s"[TRACK \(when)] delamainTracked id=\(taxiId.value)");

    // Every mappin the game currently considers player-tracked. More than one would mean the flag is
    // not a single slot at all.
    let all: array<ref<IMappin>>;
    ms.GetMappins(gamemappinsMappinTargetType.Map, all);
    let hits = 0;
    let i = 0;
    while i < ArraySize(all) {
      let m = all[i];
      if IsDefined(m) && m.IsPlayerTracked() {
        hits += 1;
        let pid = m.GetNewMappinID();
        NCZDGLog(s"[TRACK \(when)] playerTracked: id=\(pid.value) \(m.GetClassName()) variant=\(EnumInt(m.GetVariant())) quest=\(m.IsQuestMappin()) name='\(m.GetDisplayName())' pos=\(m.GetWorldPosition())");
      }
      i += 1;
    }
    NCZDGLog(s"[TRACK \(when)] \(hits) player-tracked mappin(s) out of \(ArraySize(all))");
  }

  public func HasBaseline() -> Bool {
    return this.m_taken;
  }

  public func Snapshot(gi: GameInstance, label: String) -> Void {
    ArrayClear(this.m_ids);
    ArrayClear(this.m_desc);
    this.Census(gi, this.m_ids, this.m_desc);
    this.m_taken = true;
    this.TrackedCensus(gi, label);

    let ms = GameInstance.GetMappinSystem(gi);
    let manual = ms.GetManuallyTrackedMappinID();
    let trackedId = manual.value;
    NCZDGLog(s"[DIFF] snapshot '\(label)': \(ArraySize(this.m_ids)) map mappins, manuallyTrackedId=\(trackedId)");
  }

  public func Diff(gi: GameInstance, label: String) -> Void {
    if !this.m_taken {
      return;
    }
    let ids: array<Uint64>;
    let desc: array<String>;
    this.Census(gi, ids, desc);

    let ms = GameInstance.GetMappinSystem(gi);
    let manual = ms.GetManuallyTrackedMappinID();
    let trackedId = manual.value;
    NCZDGLog(s"[DIFF] === \(label): \(ArraySize(this.m_ids)) -> \(ArraySize(ids)) map mappins, manuallyTrackedId=\(trackedId) ===");
    this.TrackedCensus(gi, label);

    let i = 0;
    while i < ArraySize(ids) {
      let was = this.IndexOf(this.m_ids, ids[i]);
      if was < 0 {
        NCZDGLog(s"[DIFF] CREATED id=\(ids[i]) \(desc[i])");
      } else {
        if !UnicodeStringEqual(this.m_desc[was], desc[i]) {
          NCZDGLog(s"[DIFF] CHANGED id=\(ids[i])");
          NCZDGLog(s"[DIFF]    was: \(this.m_desc[was])");
          NCZDGLog(s"[DIFF]    now: \(desc[i])");
        }
      }
      i += 1;
    }

    i = 0;
    while i < ArraySize(this.m_ids) {
      if this.IndexOf(ids, this.m_ids[i]) < 0 {
        NCZDGLog(s"[DIFF] DESTROYED id=\(this.m_ids[i]) \(this.m_desc[i])");
      }
      i += 1;
    }

    ArrayClear(this.m_ids);
    ArrayClear(this.m_desc);
    this.m_ids = ids;
    this.m_desc = desc;
  }
}

// Read-only. wrappedMethod() runs first and unconditionally: the map must behave exactly as it would
// without this mod present.
// A run that sets only a NATIVE map pin never calls SetWaypoint, so it would have no baseline to diff
// against. Taking one on first open makes the game's own waypoint measurable on its own terms - the
// control this whole investigation has been missing.
// Stamped once per controller OBJECT, never reassigned. Int32 defaults to 0, and 0 means "not yet
// stamped" - so a controller the game REUSES across map opens keeps its id, and a fresh one gets a new
// one. That is the whole discriminator: same id twice in a [PRESS] burst = duplicate registrations on
// one object; different ids = leaked objects.
@addField(WorldMapMenuGameController)
let nczdg_instId: Int32;

@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
  let r = wrappedMethod();
  let gi = this.GetPlayerControlledObject().GetGame();
  let diff = NCZDGMapDiff.Get(gi);
  if IsDefined(diff) {
    if this.nczdg_instId == 0 {
      this.nczdg_instId = diff.NextInstId();
    }
    NCZDGLog(s"[INST] INIT     inst=\(this.nczdg_instId) live=\(diff.LiveCtrl())");
    if diff.HasBaseline() {
      diff.Diff(gi, "MAP OPENED");
    } else {
      diff.Snapshot(gi, "MAP OPENED (no pin set, baseline only)");
    }
  }
  return r;
}

// OnEntityAttached is where vanilla calls RegisterToGlobalInputCallback(n"OnPostOnPress", this,
// n"OnPressInput") - worldMap.swift:483. Every attach that is not matched by a detach is one more
// invocation of TryTrackQuestOrSetWaypoint per key press, forever.
//
// wrappedMethod() runs FIRST and UNCONDITIONALLY. It must: a probe that throws before vanilla's
// register/unregister would MANUFACTURE the leak it is here to measure.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnEntityAttached() -> Bool {
  let r = wrappedMethod();
  let player = this.GetPlayerControlledObject();
  if IsDefined(player) {
    let diff = NCZDGMapDiff.Get(player.GetGame());
    if IsDefined(diff) {
      if this.nczdg_instId == 0 {
        this.nczdg_instId = diff.NextInstId();   // an attach with no preceding OnInitialize still gets an id
      }
      NCZDGLog(s"[INST] ATTACH   inst=\(this.nczdg_instId) live=\(diff.CtrlAttached())  <- registered OnPressInput");
    }
  }
  return r;
}

// OnEntityDetached is the ONLY place in the entire map that calls UnregisterFromGlobalInputCallback
// (worldMap.swift:519-522). OnUninitialize (:252) does NOT touch the input callbacks - it saves filters,
// clears time dilation and god mode, and unhooks OnBack. So the input registration outlives the menu
// unless this callback fires.
//
// The log line must NOT depend on the player object. OnEntityDetached fires while the entity is
// detaching, so GetPlayerControlledObject() can be null on the very call this probe exists to observe -
// and a detach that DID fire would then log nothing, looking exactly like one that never fired at all.
// The first line therefore carries no dependencies; the live count is best-effort after it.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnEntityDetached() -> Bool {
  let r = wrappedMethod();
  NCZDGLog(s"[INST] DETACH   inst=\(this.nczdg_instId)  <- vanilla unregisters OnPressInput HERE and only here");

  let player = this.GetPlayerControlledObject();
  if IsDefined(player) {
    let diff = NCZDGMapDiff.Get(player.GetGame());
    if IsDefined(diff) {
      NCZDGLog(s"[INST] DETACH   inst=\(this.nczdg_instId) live=\(diff.CtrlDetached())");
    }
  } else {
    NCZDGLog(s"[INST] DETACH   inst=\(this.nczdg_instId) - player is NULL here, live count not decremented");
  }
  return r;
}

// OnUninitialize DOES fire on every map close (the [DIFF] MAP CLOSED lines prove it). Logging it next to
// DETACH is what separates "the menu closed" from "the controller was torn down" - they are not the same
// event, and only the second one removes the input registration.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnUninitialize() -> Bool {
  NCZDGLog(s"[INST] UNINIT   inst=\(this.nczdg_instId)  <- menu closed (input callbacks NOT touched here)");
  return wrappedMethod();
}

// OnPressInput is UPSTREAM of the m_readyToZoom gate (worldMap.swift:1150), and every leaked controller
// still registered to n"OnPostOnPress" receives it. TryTrackQuestOrSetWaypoint is DOWNSTREAM of the gate,
// so a probe there is blind to every ghost that m_readyToZoom silences - it can only ever see the ones
// that already got through. This is the line that shows the leak at full size.
//
// m_readyToZoom is what arms a ghost, and it is a ONE-WAY LATCH: worldMap.swift:465 is the only write to
// it in the whole file, it writes true, and nothing ever writes false. It is set from OnRemovePreloader -
// so a map session closed BEFORE the preloader finishes leaves a ghost that is leaked but harmless, and a
// session left open a few seconds longer leaves one that is armed forever. Dwell time on the map is the
// hidden variable behind "the strays are random".
@wrapMethod(WorldMapMenuGameController)
protected cb func OnPressInput(e: ref<inkPointerEvent>) -> Bool {
  NCZDGLog(s"[GATE] inst=\(this.nczdg_instId) readyToZoom=\(this.m_readyToZoom) action=\(e.GetActionName())");
  return wrappedMethod(e);
}

@wrapMethod(WorldMapMenuGameController)
protected cb func OnUninitialize() -> Bool {
  let diff = NCZDGMapDiff.Get(this.GetPlayerControlledObject().GetGame());
  if IsDefined(diff) {
    diff.Diff(this.GetPlayerControlledObject().GetGame(), "MAP CLOSED");
  }
  return wrappedMethod();
}

// The pin is registered asynchronously, so the baseline census must wait for it to materialise.
public class NCZDGMapDiffCallback extends DelayCallback {
  public let gi: GameInstance;

  public func Call() -> Void {
    let diff = NCZDGMapDiff.Get(this.gi);
    if IsDefined(diff) {
      diff.Snapshot(this.gi, "pin registered, map never opened");
    }
  }
}
