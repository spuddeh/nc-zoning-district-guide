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
//              The hypothesis under test: MappinTargetType has three values - World, Minimap, Map -
//              and the map, on open, asks the mappin system for its Map-target mappins. If the
//              adoption of a CustomPositionVariant mappin happens lazily inside that native call,
//              then simply CALLING GetMappins(Map, ...) from a script is the same trigger, with no
//              menu, no controller and no cursor. It also fits the one observation nothing else
//              explains: that the FIRST map open of a session behaves differently from the rest.
//
//              GetMappins and GetMappinEntries are reads. If the hypothesis is wrong they cost
//              nothing and change nothing.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh
// ======================================================================================

// Logs the tracked state, then pokes each of the three mappin target lists, then logs it again.
// A flip from playerTracked=false to true across the poke is the whole finding.
public func NCZDG_MapWake(gi: GameInstance, pin: NewMappinID, when: String) -> Void {
  let ms = GameInstance.GetMappinSystem(gi);
  if !IsDefined(ms) {
    return;
  }

  NCZDG_MapWakeState(gi, pin, when + " before");

  let world: array<ref<IMappin>>;
  ms.GetMappins(gamemappinsMappinTargetType.World, world);

  let minimap: array<ref<IMappin>>;
  ms.GetMappins(gamemappinsMappinTargetType.Minimap, minimap);

  // The one that matters: the list the world map reads on open.
  let map: array<ref<IMappin>>;
  ms.GetMappins(gamemappinsMappinTargetType.Map, map);

  let entries: array<MappinEntry>;
  ms.GetMappinEntries(gamemappinsMappinTargetType.Map, entries);

  NCZDGLog(s"[WAKE \(when)] GetMappins world=\(ArraySize(world)) minimap=\(ArraySize(minimap)) map=\(ArraySize(map)) mapEntries=\(ArraySize(entries))");

  // A pin absent from the map-target list cannot be adopted by anything downstream of it.
  let i = 0;
  let found = false;
  while i < ArraySize(map) {
    let m = map[i];
    if IsDefined(m) && m.GetNewMappinID().value == pin.value {
      found = true;
      NCZDGLog(s"[WAKE \(when)] our pin IS in the map list: tracked=\(m.IsPlayerTracked()) active=\(m.IsActive()) visible=\(m.IsVisible())");
    }
    i += 1;
  }
  if !found {
    NCZDGLog(s"[WAKE \(when)] our pin is NOT in the map-target list");
  }

  NCZDG_MapWakeState(gi, pin, when + " after");
}

public func NCZDG_MapWakeState(gi: GameInstance, pin: NewMappinID, when: String) -> Void {
  let ms = GameInstance.GetMappinSystem(gi);
  if !IsDefined(ms) {
    return;
  }
  let trackedId = ms.GetManuallyTrackedMappinID();
  let ours = ms.GetMappin(pin);
  let tracked = IsDefined(ours) ? ours.IsPlayerTracked() : false;
  NCZDGLog(s"[WAKE \(when)] ourId=\(pin.value) ourTracked=\(tracked) manuallyTrackedId=\(trackedId.value)");
}

// The map's own adoption happens during a map session, not on the frame it opens, so a one-shot read
// on the same frame as RegisterMappin may simply be too early. This re-reads a beat later.
public class NCZDGMapWakeCallback extends DelayCallback {
  public let gi: GameInstance;
  public let pin: NewMappinID;

  public func Call() -> Void {
    NCZDG_MapWake(this.gi, this.pin, "delayed");
  }
}
