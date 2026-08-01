// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: translations/Provider.reds
// Author: Spuddeh
// Description: Resolves a language code to a package. Nothing registers this: it extends
//              ScriptableSystem, and Codeware's OnAttach queues the registration itself.
//
//              English is both the only package and the fallback, so every other language
//              currently resolves to it. Adding one is two lines here and one new file.
// Mod Version: 0.1.0 (Pre-release)
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoningDistrictGuide.Translations

import Codeware.Localization.*

public class NCZDG_LocalizationProvider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    switch language {
      case n"en-us": return new NCZDG_English();
      default:       return new NCZDG_English();
    };
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}
