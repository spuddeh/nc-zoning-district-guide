// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Loc.reds
// Author: Spuddeh
// Description: How every surface reads a string. Global scope, no module, so any file can
//              call it with no import - the same shape as Logging.reds, for the same
//              reason.
//
//              WHY GetLocalizedText AND NOT LocalizationSystem.GetText: Codeware's native
//              LocalizationService hooks the game's own text load and MERGES every
//              provider's entries into the base game's on-screen table, hashed by key
//              (src/App/Localization/LocalizationService.cpp). An NCZDG.* key is therefore
//              a real LocKey, and the global resolver reaches it - so nothing has to thread
//              a GameInstance through Brand.reds, GuideModel.reds or a static helper.
//              LocalizationSystem.GetText is the route to take if this mod ever needs
//              gender-sensitive strings, which it does not.
//
//              A MISSING KEY RENDERS AS THE KEY, deliberately. Returning "" would draw an
//              empty widget, which looks exactly like a layout bug and sends you to the
//              wrong file; "NCZDG.btnTeleport" on a button says what is wrong and where.
// Mod Version: 0.1.0 (Pre-release)
// Credits: psiberx (Codeware)
// ======================================================================================

public func NCZDG_T(key: String) -> String {
  let s = GetLocalizedText(key);
  return StrLen(s) > 0 ? s : key;
}

// Substitutes one placeholder. The sentences live whole in the translation file so a
// translator controls word order; these put the numbers back in.
public func NCZDG_T1(key: String, token: String, value: String) -> String {
  return StrReplace(NCZDG_T(key), token, value);
}

public func NCZDG_T2(key: String, t1: String, v1: String, t2: String, v2: String) -> String {
  return StrReplace(StrReplace(NCZDG_T(key), t1, v1), t2, v2);
}

public func NCZDG_T3(key: String, t1: String, v1: String, t2: String, v2: String, t3: String, v3: String) -> String {
  return StrReplace(StrReplace(StrReplace(NCZDG_T(key), t1, v1), t2, v2), t3, v3);
}

// The first argument stays a KEY at every arity. Nesting one of these inside another almost
// works - the inner call returns text, the outer looks it up, misses, and returns what it was
// given - but it only works because a failed lookup echoes its input, so a real translation
// for that text would silently replace the sentence.
public func NCZDG_T4(key: String, t1: String, v1: String, t2: String, v2: String, t3: String, v3: String, t4: String, v4: String) -> String {
  return StrReplace(StrReplace(StrReplace(StrReplace(NCZDG_T(key), t1, v1), t2, v2), t3, v3), t4, v4);
}
