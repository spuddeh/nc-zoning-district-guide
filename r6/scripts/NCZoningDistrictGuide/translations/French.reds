// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: translations/French.reds
// Author: Spuddeh
// Description: The French slot. EMPTY ON PURPOSE - every key falls through to English.
//
//              THIS FILE EXISTS SO IT CAN BE REPLACED. A translation ships as a separate
//              mod carrying this same path, this same module and this same class name;
//              the mod manager hides this copy, so redscript compiles one NCZDG_French
//              and there is no duplicate class. A translation cannot add a case to
//              Provider.reds, which is why the slot has to be here before anyone can fill
//              it. [[CP2077-Mods/wiki/concepts/redscript-translation-as-a-separate-mod]]
//
//              IT IS EMPTY RATHER THAN A COPY OF THE ENGLISH. A package fills AFTER the
//              English fallback, so a copied English string that later changes in
//              English.reds would keep overriding it with the older wording. Empty cannot
//              go stale.
//
//              TO TRANSLATE: copy the DefineTexts body out of English.reds, translate the
//              SECOND argument of each Text() call, and leave every key untouched. Partial
//              is fine - anything absent falls back to English.
// Mod Version: 1.0.0
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoningDistrictGuide.Translations

import Codeware.Localization.*

public class NCZDG_French extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {}
}
