// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: MapWakeProbe.reds
// Author: Spuddeh
// Description: DEV ONLY. Strip with Logging.reds and InkDebug.reds at M7.
//
//              A script-registered pin has no OWNER, so it is not tracked and draws no route until
//              the world map is opened once. What the map does on open that a script cannot is the
//              open question.
//
//              Measured so far: reading the Map-target mappin list does NOT adopt the pin, so the
//              adoption is not a lazy init behind that read. Two facts came out of it instead:
//
//              1. Registration is DEFERRED. The pin is in none of the three target lists on the
//                 frame RegisterMappin returns; all three grow by one within a second.
//              2. The pin is not findable in the map list BY ID, even after it appears.
//
//              (2) is the live question, and an id match cannot answer it - the id is exactly what
//              is in doubt. This matches by POSITION, which the mappin cannot misreport, and dumps
//              every entry near the pin so the object the map actually holds is named outright.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh
// ======================================================================================

public func NCZDG_MapWakeRadius() -> Float { return 12.0; }

// A handle that resolves and a mappin that is tracked are different facts. Logging them as one
// value is how the previous run said "false" to two opposite questions.
public func NCZDG_MapWakeState(gi: GameInstance, pin: NewMappinID, when: String) -> Void {
  let ms = GameInstance.GetMappinSystem(gi);
  if !IsDefined(ms) {
    return;
  }
  let trackedId = ms.GetManuallyTrackedMappinID();
  let ours = ms.GetMappin(pin);
  if !IsDefined(ours) {
    NCZDGLog(s"[WAKE \(when)] GetMappin(\(pin.value)) -> NULL. The system does not know this id. manuallyTrackedId=\(trackedId.value)");
    return;
  }
  NCZDGLog(s"[WAKE \(when)] GetMappin(\(pin.value)) -> ok tracked=\(ours.IsPlayerTracked()) active=\(ours.IsActive()) visible=\(ours.IsVisible()) variant=\(EnumInt(ours.GetVariant())) pos=\(ours.GetWorldPosition()) manuallyTrackedId=\(trackedId.value)");
}

// Names every mappin the system holds within a few metres of the pin, per target list. Whatever
// object the map is holding for this pin, it is standing at the same coordinate.
public func NCZDG_MapWakeNear(gi: GameInstance, target: gamemappinsMappinTargetType, label: String, pos: Vector4, pin: NewMappinID) -> Void {
  let ms = GameInstance.GetMappinSystem(gi);
  if !IsDefined(ms) {
    return;
  }
  let entries: array<MappinEntry>;
  ms.GetMappinEntries(target, entries);

  let hits = 0;
  let i = 0;
  while i < ArraySize(entries) {
    let e = entries[i];
    if Vector4.Distance(e.worldPosition, pos) < NCZDG_MapWakeRadius() {
      hits += 1;
      let mine = e.id.value == pin.value ? "  <-- OUR ID" : "";
      NCZDGLog(s"[WAKE \(label)]   near: id=\(e.id.value) type=\(e.type) pos=\(e.worldPosition)\(mine)");
    }
    i += 1;
  }
  NCZDGLog(s"[WAKE \(label)] \(ArraySize(entries)) entries, \(hits) within \(NCZDG_MapWakeRadius())m of the pin");
}

public func NCZDG_MapWake(gi: GameInstance, pin: NewMappinID, pos: Vector4, when: String) -> Void {
  NCZDG_MapWakeState(gi, pin, when);
  NCZDG_MapWakeNear(gi, gamemappinsMappinTargetType.World, when + " world", pos, pin);
  NCZDG_MapWakeNear(gi, gamemappinsMappinTargetType.Minimap, when + " minimap", pos, pin);
  NCZDG_MapWakeNear(gi, gamemappinsMappinTargetType.Map, when + " map", pos, pin);
}

// Registration is deferred, so a read on the registering frame sees nothing. This re-reads after the
// system has had a tick to materialise the pin.
public class NCZDGMapWakeCallback extends DelayCallback {
  public let gi: GameInstance;
  public let pin: NewMappinID;
  public let pos: Vector4;

  public func Call() -> Void {
    NCZDG_MapWake(this.gi, this.pin, this.pos, "delayed");
  }
}
