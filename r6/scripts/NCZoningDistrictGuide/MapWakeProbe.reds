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
        ArrayPush(ids, m.GetNewMappinID().value);
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

  // GetManuallyTrackedMappinID() and IMappin.IsPlayerTracked() are NOT the same slot: a pin can come
  // back player-tracked while the manually-tracked id names a different mappin entirely, and the
  // manually-tracked id can be non-zero before anything is pinned. The trail follows IsPlayerTracked
  // - the HUD's MappinsContainerController renders it into gpsPlayerTrackedPathWidget, separate from
  // gpsQuestPathWidget, gpsDelamainPathWidget and autodrivePathWidget. Naming what sits in each slot
  // is the point of this census.
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
        NCZDGLog(s"[TRACK \(when)] playerTracked: id=\(m.GetNewMappinID().value) \(m.GetClassName()) variant=\(EnumInt(m.GetVariant())) quest=\(m.IsQuestMappin()) name='\(m.GetDisplayName())' pos=\(m.GetWorldPosition())");
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
    let trackedId = IsDefined(ms) ? ms.GetManuallyTrackedMappinID().value : 0ul;
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
    let trackedId = IsDefined(ms) ? ms.GetManuallyTrackedMappinID().value : 0ul;
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
@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
  let r = wrappedMethod();
  let gi = this.GetPlayerControlledObject().GetGame();
  let diff = NCZDGMapDiff.Get(gi);
  if IsDefined(diff) {
    if diff.HasBaseline() {
      diff.Diff(gi, "MAP OPENED");
    } else {
      diff.Snapshot(gi, "MAP OPENED (no pin set, baseline only)");
    }
  }
  return r;
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
