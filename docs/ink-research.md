# Ink research: the native surfaces this mod injects into

M1 deliverable. Every fact below is read from the decompiled game scripts
(`_source/cyberpunk-decompiled-scripts`, redscript in `.swift` files) and the NativeDB dump
(`_resources/cp2077_dump_json/json`), then cross-checked against Codeware's own addons.

**No WolvenKit export was needed.** The decompiled scripts answer every question the wkit ink
export would have (controller names, widget refs, wrap points, how the game sets the text), and
they answer the one wkit could not: which classes and methods are scripted, and therefore
wrappable. A wkit project remains useful only if we later want to match exact fonts and atlas
parts by eye; it is gitignored (`Wkit/`) and is not a build input.

## Summary of targets

| Milestone | Class | Wrap point | Scripted? |
| --- | --- | --- | --- |
| M4 district-enter banner | `NewLocationNotification` | `SetNotificationData` | Yes, plain scripted class |
| M6 map district panel | `WorldMapMenuGameController` | `OnUpdateHoveredDistricts` (+ `OnInitialize`) | Class is `native`, these methods are scripted |
| M5 standalone guide | n/a, our own widgets | built programmatically | n/a |

## M4: the district-enter banner is `NewLocationNotification`

`_source/cyberpunk-decompiled-scripts/cyberpunk/UI/fullscreen/notification/journalNotification.swift:706`

```swift
public class NewLocationNotification extends JournalNotification {
  private edit let districtName: inkTextRef;
  private edit let districtIcon: inkImageRef;
  private edit let districtFluffIcon: inkImageRef;

  public func SetNotificationData(notificationData: ref<GenericNotificationViewData>) -> Void {
    ...
    inkTextRef.SetText(this.districtName, this.m_questNotificationData.title);
    ...
  }
}
```

- Plain scripted class, so `@wrapMethod(NewLocationNotification)` on `SetNotificationData` works.
- **The parameter type is `ref<GenericNotificationViewData>`**, NOT the dump's spelling
  `gameuiGenericNotificationViewData`. Wrapping with the dump name will not compile. The dump
  reports engine names; the decompiled scripts report the redscript names. Trust the scripts.
- Likewise `districtName` is an `inkTextRef` (dump says `inkTextWidgetReference`), written with
  `inkTextRef.SetText(...)`.
- The title arrives as a **LocKey** (Westbrook is special-cased to `LocKey#94398`), so the
  banner already knows its district identity, but as a localized string, not a TweakDBID.
- The fields are `private`, so a `@wrapMethod` in our own file cannot read `this.districtName`
  directly. Append our own text widget under `GetRootWidget()` instead (the RAMpocalypse
  `HUD.reds` pattern), or resolve the district ourselves via Layer 2 and inject a sibling.

### Related event (better source of truth than the banner's LocKey)

`gamemappinsDistrictEnteredEvent` (dump) carries what we actually want:

| Field | Type | Meaning |
| --- | --- | --- |
| `district` | `TweakDBID` | the district entered, keys `NCZDistrictMap.Lookup` directly |
| `entered` | `Bool` | enter vs leave |
| `sendNewLocationNotification` | `Bool` | whether the game will show the banner |

`DistrictManager` consumes it: `ManageDistrictStack`, `PushDistrict`, `PopDistrict`, `Update`,
all taking `handle:gamemappinsDistrictEnteredEvent`. `worldLocationAreaNotifier` carries the
matching `districtID` + `sendNewLocationNotification`. So district change is observable without
polling. Prefer this over a `Cron`-style timer.

## M6: the map DOES have a district panel (and it is not the mappin tooltip)

`_source/cyberpunk-decompiled-scripts/cyberpunk/UI/fullscreen/map/worldMap.swift:2`

```swift
public native class WorldMapMenuGameController extends MappinsContainerController {
  private edit let m_districtIconImageContainer: inkWidgetRef;   // :30
  private edit let m_districtIconImage: inkImageRef;             // :32
  private edit let m_districtNameText: inkTextRef;               // :34
  private edit let m_subdistrictNameText: inkTextRef;            // :36
  private edit let m_locationAndGangsContainer: inkWidgetRef;    // :38
  private edit let m_gangsInfoContainer: inkWidgetRef;           // :40
  private edit let m_gangsList: inkCompoundRef;                  // :42
```

The live update, `worldMap.swift:600`:

```swift
protected cb func OnUpdateHoveredDistricts(district: gamedataDistrict, subdistrict: gamedataDistrict) -> Bool {
  let districtRecord: wref<District_Record> = MappinUtils.GetDistrictRecord(district);
  let subdistrictRecord: wref<District_Record> = MappinUtils.GetDistrictRecord(subdistrict);
  inkTextRef.SetLocalizedTextString(this.m_districtNameText, districtRecord.LocalizedName());
  ...
  this.ShowGangsInfo(district, subdistrict);
}
```

- The class is `native`, but `OnUpdateHoveredDistricts`, `OnInitialize`, `OnDistrictViewChanged`,
  and `ShowGangsInfo` are **scripted bodies**, so `@wrapMethod` applies to them. The native
  `func`s (`GetCurrentZoom`, `ZoomToMappin`, ...) are engine-implemented and are not wrappable.
- `@addField` on this native class is supported. Codeware already does it:
  `_source/cp2077-codeware/scripts/Base/Addons/WorldMapMenuGameController.reds`. Codeware's
  fields are `public native let` because it is re-exposing real engine fields; our own
  script-side state uses a plain `@addField` with no `native`.
- The widget refs are `private`, so build and reparent our own container off `GetRootWidget()`
  rather than reaching for `m_locationAndGangsContainer`.
- `OnUpdateHoveredDistricts` fires on **every hover**. Construct widgets once (wrapped
  `OnInitialize`), and only set text/visibility in the hover wrap.

### The enum to TweakDBID bridge (this is the important one)

`OnUpdateHoveredDistricts` hands us a `gamedataDistrict` **enum**, but `NCZDistrictMap.Lookup`
keys on a **path-form TweakDBID**. The core's docs warn that path and enum name differ in
105/132 records, so the enum name cannot be string-built into a path. The bridge:

```swift
let record: wref<District_Record> = MappinUtils.GetDistrictRecord(district);  // native, mappinUtils.swift:6
let id: TweakDBID = record.GetRecordID();   // gamedataTweakDBRecord.GetRecordID() -> TweakDBID
let name = NCZDistrictMap.Lookup(id);       // path form, exactly what the map keys on
```

`GetRecordID()` (and `GetID()`) are on `gamedataTweakDBRecord`, inherited by every record, and
used throughout the shipped scripts (e.g. `aiComponent.swift:459`).

**Consequence: M6 needs no Layer 2.** The map hands us the hovered district directly. The
`DistrictManager` walk (Layer 2) is only needed for M4 and M5, which care about where the player
physically is.

### `District_Record` API (verified, `classes/gamedataDistrict_Record.json`)

`LocalizedName() -> String` (a LocKey), `UiIcon() -> CName` (atlas part), `Type() -> gamedataDistrict`,
`ParentDistrict() -> whandle:gamedataDistrict_Record` (null for top-level, so this is how you tell
a district from a subdistrict), `Gangs(...)`, `GetGangsCount()`, `IsQuestDistrict() -> Bool`.

## Dead end, recorded so nobody re-walks it

`WorldMapTooltipController` / `WorldMapTooltipBaseController` (`worldMapTooltips.swift:116,169`)
are scripted and have an inviting `SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>)`.
But `WorldMapTooltipData` (`orphans.swift:53413`) holds only `controller`, `mappin`,
`journalEntry`, `fastTravelEnabled`, `delamainTaxiEnabled`, `travelCost`, `playerMoney`,
`readJournal`, `moreInfo`, `isCollection`. **No district.** It is the per-mappin hover tooltip
(fast travel, gigs, fixers), not the district panel. Do not inject district info here.

## Widget construction pattern

`MyMods/RAMpocalypse2077/source/resources/r6/scripts/RAMpocalypse/HUD.reds` is the working
in-repo precedent for programmatic ink on a native controller:

```swift
@addField(healthbarWidgetGameController) let ramifyContainer: ref<inkVerticalPanel>;

@wrapMethod(healthbarWidgetGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  this.Ramify_CreateWidget();
  return result;
}
```

then `new inkVerticalPanel()` / `new inkText()`, `SetName`, `SetAnchor`, `SetMargin`,
`SetFitToContent(true)`, `Reparent(anchor)`. Font family used there:
`base\gameplay\gui\fonts\raj\raj.inkfontfamily`.

## Open questions for in-game verification

- Does `OnUpdateHoveredDistricts` fire when the map first opens, or only on a hover change? If
  only on change, seed the panel from a wrapped `OnInitialize` too.
- Does the district banner (`NewLocationNotification`) fire for subdistricts, or only top-level
  districts? `sendNewLocationNotification` on the notifier suggests it is authored per area.
- Confirm `@wrapMethod` on a `protected cb func` of a native class compiles. Nothing found
  contradicts it, but it is the one construct with no in-repo precedent.
