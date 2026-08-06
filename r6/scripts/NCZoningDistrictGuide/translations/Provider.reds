// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: translations/Provider.reds
// Author: Spuddeh
// Description: Resolves a language code to a package. Nothing registers this: it extends
//              ScriptableSystem, and Codeware's OnAttach queues the registration itself.
//
//              EVERY LANGUAGE THE GAME SHIPS HAS A CASE HERE, and all but English resolve
//              to an empty package that falls through to the English fallback. The case
//              has to exist before a translation can be dropped in, because a translation
//              mod replaces a language FILE and cannot reach this switch.
//              https://github.com/spuddeh/nc-zoning-district-guide/blob/main/docs/TRANSLATING.md
//
//              An unlisted language hits default and gets English, so a code the game
//              adds later degrades rather than breaking.
// Mod Version: 1.1.0
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoningDistrictGuide.Translations

import Codeware.Localization.*

public class NCZDG_LocalizationProvider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    switch language {
      case n"en-us":  return new NCZDG_English();
      case n"fr-fr":  return new NCZDG_French();
      case n"de-de":  return new NCZDG_German();
      case n"es-es":  return new NCZDG_Spanish();
      case n"es-mx":  return new NCZDG_SpanishLatam();
      case n"it-it":  return new NCZDG_Italian();
      case n"pt-br":  return new NCZDG_Portuguese();
      case n"pl-pl":  return new NCZDG_Polish();
      case n"ru-ru":  return new NCZDG_Russian();
      case n"ua-ua":  return new NCZDG_Ukrainian();
      case n"cz-cz":  return new NCZDG_Czech();
      case n"hu-hu":  return new NCZDG_Hungarian();
      case n"tr-tr":  return new NCZDG_Turkish();
      case n"th-th":  return new NCZDG_Thai();
      case n"ar-ar":  return new NCZDG_Arabic();
      case n"jp-jp":  return new NCZDG_Japanese();
      case n"kr-kr":  return new NCZDG_Korean();
      case n"zh-cn":  return new NCZDG_ChineseSimplified();
      case n"zh-tw":  return new NCZDG_ChineseTraditional();
      default:       return new NCZDG_English();
    };
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}
