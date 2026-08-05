// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: translations/Czech.reds
// Author: Spuddeh
// Description: The Czech slot. Empty - every string shows in English until someone
//              fills this in. Filling it in is welcome, and takes no coding.
//
//              TO TRANSLATE - three steps:
//
//                1. Open English.reds. Copy everything between the { } of DefineTexts.
//                2. Paste it below, over the "translations go here" line.
//                3. Translate the SECOND text on each line. Never change the first.
//
//                   this.Text("NCZDG.title",  "NC ZONING BOARD");
//                             ^^^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^
//                             the KEY - never translate THIS
//
//              RULES:
//                - Partial is fine. Anything you leave out falls back to English.
//                - Keep {n}, {area}, {name} and friends exactly as written. They are
//                  replaced at runtime, and you may move them anywhere in the sentence.
//                - Plurals are one key per form. Fill in the forms your language uses
//                  and leave the rest.
//
//              Then it ships as its own mod - one file, no release needed from
//              this end. Full instructions: docs/TRANSLATING.md
//
//              MAINTAINER: empty on purpose - a filled slot would override newer
//              English wording. The path, module and class name are public API,
//              because a translation mod REPLACES this file.
//              [[CP2077-Mods/wiki/concepts/redscript-translation-as-a-separate-mod]]
// Mod Version: 1.0.0
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoningDistrictGuide.Translations

import Codeware.Localization.*

public class NCZDG_Czech extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // Translations go here. See the instructions at the top of this file.
  }
}
