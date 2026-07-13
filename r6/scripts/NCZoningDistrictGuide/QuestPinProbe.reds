// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: QuestPinProbe.reds
// Author: Spuddeh
// Description: DEV ONLY. Strip with Logging.reds and InkDebug.reds at M7.
//
//              Nothing in the game tracks a mappin by id. The RTTI has no TrackMappin(id) on
//              MappinSystem - only UntrackMappin(). The two functions that can WRITE tracking state
//              take an OWNER, never a pin:
//
//                gameuiWorldMapMenuGameController.TrackMappin(controller: MappinBaseController)
//                gameJournalManager.TrackEntry(entry: JournalEntry)
//
//              So a bare RegisterMappin pin is an orphan: no owner, nothing to nominate, no route
//              until the world map spawns a controller for it and adopts it.
//
//              The map's owner is unreachable from a background script - the controller only exists
//              while the map runs. The journal's owner is not: vanilla's GameplayQuestSystem builds
//              one from the base-game template "generic_gameplay_quest" (used by deviceBase for
//              device objectives), so no archive and no cooked asset are needed.
//
//              MappinData carries NO position, so vanilla binds a quest mappin to an entity
//              (SetScriptedQuestMappinEntityID). A registry location is a bare coordinate with no
//              entity, so the mappin the journal creates is repositioned onto it afterwards with
//              MappinSystem.SetMappinPosition.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh
// ======================================================================================

public func NCZDG_QuestPinQuestId() -> String { return "generic_gameplay_quest"; }
public func NCZDG_QuestPinUniqueId() -> String { return "nczdg_waypoint"; }
public func NCZDG_QuestPinObjPath() -> String { return "generic_gameplay_phase/generic_gameplay_objective"; }
public func NCZDG_QuestPinMappinPath() -> String { return "generic_gameplay_phase/generic_gameplay_objective/generic_gameplay_mappin"; }

// Returns the journal-owned mappin's id, or a zero id if any step of the chain refuses. Every step
// logs, because a failure at step 1 and a failure at step 5 mean completely different things:
// step 1 false means the template door is welded shut and there is nothing further to try; a tracked
// entry that owns no mappin means the journal wants an entity after all.
public func NCZDG_QuestPinSet(gi: GameInstance, pos: Vector4, title: String) -> NewMappinID {
  let empty: NewMappinID;

  let journal = GameInstance.GetJournalManager(gi);
  let ms = GameInstance.GetMappinSystem(gi);
  if !IsDefined(journal) || !IsDefined(ms) {
    NCZDGLog("[QPIN] no JournalManager or no MappinSystem");
    return empty;
  }

  // A second Create on a live uniqueId is not defined behaviour, so retire the previous one first.
  NCZDG_QuestPinClear(gi);

  let created = journal.CreateScriptedQuestFromTemplate(
    NCZDG_QuestPinQuestId(), NCZDG_QuestPinUniqueId(), title);
  NCZDGLog(s"[QPIN] 1 CreateScriptedQuestFromTemplate -> \(created)");
  if !created {
    return empty;
  }

  let described = journal.SetScriptedQuestObjectiveDescription(
    NCZDG_QuestPinQuestId(), NCZDG_QuestPinUniqueId(), NCZDG_QuestPinObjPath(), title);
  NCZDGLog(s"[QPIN] 2 SetScriptedQuestObjectiveDescription -> \(described)");

  // The pairing vanilla's own CreateObjective uses, verbatim. The entity binding it does next is the
  // step deliberately skipped here - that is the variable under test.
  let data: MappinData;
  data.mappinType = t"Mappins.QuestStaticMappinDefinition";
  data.variant = gamedataMappinVariant.DefaultQuestVariant;
  data.visibleThroughWalls = true;

  let bound = journal.SetScriptedQuestMappinData(
    NCZDG_QuestPinQuestId(), NCZDG_QuestPinUniqueId(), NCZDG_QuestPinMappinPath(), data);
  NCZDGLog(s"[QPIN] 3 SetScriptedQuestMappinData -> \(bound)");

  // The tracking write. track = true is what TrackEntry does internally, through the journal's door.
  journal.SetScriptedQuestEntryState(
    NCZDG_QuestPinQuestId(), NCZDG_QuestPinUniqueId(), NCZDG_QuestPinObjPath(),
    gameJournalEntryState.Active, JournalNotifyOption.Notify, true);
  NCZDGLog("[QPIN] 4 SetScriptedQuestEntryState(Active, track = true)");

  let tracked = journal.GetTrackedEntry();
  if !IsDefined(tracked) {
    NCZDGLog("[QPIN] 5 GetTrackedEntry -> null: the journal did not adopt the objective");
    return empty;
  }
  NCZDGLog(s"[QPIN] 5 GetTrackedEntry -> \(tracked.GetClassName()) hash=\(journal.GetEntryHash(tracked))");

  let pin = ms.GetMappinFromQuest(tracked);
  if !IsDefined(pin) {
    NCZDGLog("[QPIN] 6 GetMappinFromQuest -> null: tracked, but the entry owns no mappin");
    NCZDG_QuestPinDumpWorldMappins(gi);
    return empty;
  }

  let id = pin.GetNewMappinID();
  NCZDGLog(s"[QPIN] 6 mappin id=\(id.value) playerTracked=\(pin.IsPlayerTracked()) pos=\(pin.GetWorldPosition())");

  ms.SetMappinPosition(id, pos);
  NCZDGLog(s"[QPIN] 7 SetMappinPosition -> \(pos); readback=\(pin.GetWorldPosition())");

  return id;
}

public func NCZDG_QuestPinClear(gi: GameInstance) -> Void {
  let journal = GameInstance.GetJournalManager(gi);
  if !IsDefined(journal) {
    return;
  }
  let deleted = journal.DeleteScriptedQuest(NCZDG_QuestPinQuestId(), NCZDG_QuestPinUniqueId());
  NCZDGLog(s"[QPIN] DeleteScriptedQuest -> \(deleted)");
}

// Only reached when the chain breaks: names every world mappin so a journal-created pin that
// GetMappinFromQuest cannot see is still visible in the log.
public func NCZDG_QuestPinDumpWorldMappins(gi: GameInstance) -> Void {
  let ms = GameInstance.GetMappinSystem(gi);
  if !IsDefined(ms) {
    return;
  }
  let all: array<ref<IMappin>>;
  ms.GetMappins(gamemappinsMappinTargetType.World, all);
  NCZDGLog(s"[QPIN] world mappins: \(ArraySize(all))");

  let i = 0;
  while i < ArraySize(all) {
    let m = all[i];
    if IsDefined(m) && (m.IsQuestMappin() || m.IsPlayerTracked()) {
      NCZDGLog(s"[QPIN]   id=\(m.GetNewMappinID().value) quest=\(m.IsQuestMappin()) tracked=\(m.IsPlayerTracked()) variant=\(EnumInt(m.GetVariant())) pos=\(m.GetWorldPosition())");
    }
    i += 1;
  }
}
