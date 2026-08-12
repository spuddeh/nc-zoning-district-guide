// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: translations/French.reds
// Author: Spuddeh
// Description: The French slot. Empty - every string shows in English until someone
//              fills this in. Filling it in is welcome, and takes no coding.
//
//              TO TRANSLATE - three steps:
//
//                1. Open English.reds and copy ONLY the this.Text(...) lines.
//                   NOT the whole file. Copying the file brings the English
//                   class name with it, and two classes with one name stops
//                   EVERY redscript mod on the player's machine from loading.
//                2. Paste them below, over the "translations go here" line.
//                   Leave everything else in this file exactly as it is.
//                3. Translate the SECOND text on each line. Never change the first.
//
//              this.Text("NCZDG.title",  "NC ZONING BOARD");
//                        ^^^^^^^^^^^^^  the KEY - never change it
//                                        ^^^^^^^^^^^^^^^^^  translate this
//
//              RULES:
//                - Partial is fine. Anything you leave out falls back to English.
//                - Keep {n}, {area}, {name} and friends exactly as written. They are
//                  replaced at runtime, and you may move them anywhere in the sentence.
//                - Plurals are one key per form. Fill in the forms your language uses
//                  and leave the rest.
//
//              Then it ships as its own mod - one file, and nothing has to be
//              released at this end. Full instructions, including how to package
//              and upload it:
//              https://github.com/spuddeh/nc-zoning-district-guide/blob/main/docs/TRANSLATING.md
//
//              MAINTAINER: empty on purpose - a filled slot would override newer
//              English wording. The path, module and class name are public API,
//              because a translation mod REPLACES this file.
// Mod Version: 1.1.1
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoningDistrictGuide.Translations

import Codeware.Localization.*

public class NCZDG_French extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // --- guide chrome ------------------------------------------------------------------
    this.Text("NCZDG.title",           "COMMISSION DE ZONAGE DE NC");
    this.Text("NCZDG.headerLeft",      "NIGHT CORP // DIVISION DE L'URBANISME");
    this.Text("NCZDG.headerRight",     "NC-ZB-01");
    this.Text("NCZDG.searchHint",      "RECHERCHER NOM, TAG, AUTEUR - & | !");

    // --- search syntax, shown by the [ i ] beside the search box ------------------------
    // EACH LINE CARRIES ITS OWN EXAMPLE, because the example words are English and a translator
    // has to be free to swap them for words their reader would actually type. A shared example
    // held in code could not be reached.
    //
    // EVERY EXAMPLE WORD IS IN THE REGISTRY. `watson` is 85 records, `apartment` 156, `pacifica`
    // 14, `corpo` 38 - so each line demonstrates itself when it is typed. An example that returns
    // nothing teaches the reader that the feature is broken.
    //
    // The operators themselves (& | !) are NOT translated. They are what the parser reads.
    this.Text("NCZDG.helpTitle",       "SYNTAXE DE RECHERCHE");
    this.Text("NCZDG.helpAnd",         "watson&apartment   -   les deux doivent correspondre");
    this.Text("NCZDG.helpOr",          "watson|pacifica   -   l'un ou l'autre peut correspondre");
    this.Text("NCZDG.helpNot",         "!corpo   -   tout sauf corpo");
    this.Text("NCZDG.helpNotWith",     "apartment!corpo   -   appartements, sauf tout ce qui est corpo");
    this.Text("NCZDG.helpMix",         "watson|pacifica&apartment   -   l'un ou l'autre district, et un appartement");
    this.Text("NCZDG.helpPhrase",      "night city   -   sans opérateur, toute la ligne est recherchée telle qu'elle est saisie");
    this.Text("NCZDG.helpSpaces",      "Collez les opérateurs aux mots. watson & apartment cherche 'watson ' et ' apartment', espaces inclus.");
    this.Text("NCZDG.helpFields",      "Chaque mot est comparé au nom, à la description, à la catégorie, au district, aux tags et aux auteurs.");

    // --- buttons -----------------------------------------------------------------------
    this.Text("NCZDG.btnClear",        "EFFACER");
    this.Text("NCZDG.btnSetMarker",    "AFFICHER SUR LA CARTE");
    this.Text("NCZDG.btnClearMarker",  "EFFACER LE REPÈRE");
    this.Text("NCZDG.btnTeleport",     "TÉLÉPORTER");
    this.Text("NCZDG.btnExitVehicle",  "QUITTER LE VÉHICULE");
    this.Text("NCZDG.btnPrev",         "< PRÉC");
    this.Text("NCZDG.btnNext",         "SUIV >");

    // --- install filter ----------------------------------------------------------------
    this.Text("NCZDG.filterAll",       "AFFICHAGE : TOUT");
    this.Text("NCZDG.filterInstalled", "AFFICHAGE : INSTALLÉS");
    this.Text("NCZDG.filterMissing",   "AFFICHAGE : MANQUANTS");
    this.Text("NCZDG.filterUnknown",   "AFFICHAGE : INCONNUS");

    // --- the guide's status line -------------------------------------------------------
    // Three forms because the sentence differs, not because the numbers do: a search says
    // how many of the area matched, a paged list says which slice is on screen, and a
    // short list says only the total.
    this.Text("NCZDG.countSearch",     "{n} SUR {total} DANS {area}");
    this.Text("NCZDG.countPaged",      "{from}-{to} SUR {n} DANS {area}");
    this.Text("NCZDG.countPlain",      "{n} DANS {area}");

    // --- nav column --------------------------------------------------------------------
    this.Text("NCZDG.areaAll",         "TOUS LES LIEUX");
    this.Text("NCZDG.navRecent",       "{n} RÉCENTS");

    // --- cards -------------------------------------------------------------------------
    this.Text("NCZDG.badgeRecent",     "MIS À JOUR RÉCEMMENT");
    this.Text("NCZDG.badgeInstalled",  "INSTALLÉ");
    this.Text("NCZDG.noImage",         "AUCUN RELEVÉ PHOTO DANS LE DOSSIER");

    // --- lightbox ----------------------------------------------------------------------
    this.Text("NCZDG.imgLoading",      "CHARGEMENT...");
    this.Text("NCZDG.imgLoadingClose", "CHARGEMENT...   -   CLIQUEZ N'IMPORTE OÙ POUR FERMER");
    this.Text("NCZDG.imgFailed",       "IMAGE INDISPONIBLE   -   CLIQUEZ N'IMPORTE OÙ POUR FERMER");
    this.Text("NCZDG.imgClose",        "CLIQUEZ N'IMPORTE OÙ POUR FERMER");

    // --- categories --------------------------------------------------------------------
    // The card badge and the map breakdown want the same three words in singular and
    // plural. The registry's own values ("new-location", "location-overhaul") are data
    // and are never translated - only their labels are.
    this.Text("NCZDG.catNew",          "NOUVEAU LIEU");
    this.Text("NCZDG.catNewPlural",    "NOUVEAUX LIEUX");
    this.Text("NCZDG.catOverhaul",     "REFONTE");
    this.Text("NCZDG.catOverhaulPlural", "REFONTES");
    this.Text("NCZDG.catOther",        "AUTRE");
    this.Text("NCZDG.catOtherPlural",  "AUTRES");

    // --- district notice + fast-travel panel -------------------------------------------
    this.Text("NCZDG.panelEmpty",      "Aucun lieu enregistré dans {area} pour l'instant");
    this.Text("NCZDG.panelCountOne",   "{n} lieu enregistré dans {area}");
    this.Text("NCZDG.panelCountMany",  "{n} lieux enregistrés dans {area}");
    this.Text("NCZDG.panelNearest",    "Le plus proche : {name}");

    // --- world map panel ---------------------------------------------------------------
    this.Text("NCZDG.mapCaption",      "ZONAGE DE NC :");
    this.Text("NCZDG.mapEmpty",        "AUCUN LIEU ENREGISTRÉ");
    this.Text("NCZDG.mapCountOne",     "{n} LIEU");
    this.Text("NCZDG.mapCountMany",    "{n} LIEUX");
    this.Text("NCZDG.mapRecent",       "{n} MIS À JOUR RÉCEMMENT");

    // --- failure states ----------------------------------------------------------------
    // The long form belongs to NCZoningCore (GetStatusMessage) and is localised there.
    this.Text("NCZDG.noData",          "AUCUNE DONNÉE DE LIEU");

    // --- RCF settings panel ------------------------------------------------------------
    // RCF resolves these itself: DVRCF_HubPopup.LocalizeSchema runs every schema string
    // through LocalizationSystem.GetText, so the adapter passes KEYS, not translated text.
    this.Text("NCZDG.modName",         "Commission de zonage de NC - Guide des districts");
    this.Text("NCZDG.modDesc",         "Quels mods de lieux se trouvent dans le district autour de vous.");

    this.Text("NCZDG.secLocations",    "Lieux");
    this.Text("NCZDG.optSubdistrict",  "Limiter au sous-district");
    this.Text("NCZDG.tipSubdistrict",  "Limite tous les compteurs à votre sous-district lorsque vous vous trouvez dans l'un d'eux, plutôt qu'au district entier. S'applique au guide, au panneau de la carte et à l'avis de district.");

    this.Text("NCZDG.secGuide",        "Guide des districts");
    this.Text("NCZDG.optGuide",        "Activer le guide des districts");
    this.Text("NCZDG.tipGuide",        "Parcourez les mods de lieux de n'importe quel district, avec recherche, repère sur la carte et téléportation.");
    this.Text("NCZDG.optKey",          "Touche d'ouverture du guide");
    this.Text("NCZDG.tipKey",          "Touche qui ouvre le guide des districts. Nécessite Input Loader.");
    this.Text("NCZDG.optModifier",     "Modificateur d'ouverture du guide");
    this.Text("NCZDG.tipModifier",     "Touche facultative à maintenir en même temps que la touche d'ouverture. N'importe quelle touche convient, pas seulement Maj, Alt ou Ctrl. Laissez vide pour ne pas utiliser de modificateur.");
    this.Text("NCZDG.optShowing",      "Affichage à l'ouverture du guide");
    this.Text("NCZDG.tipShowing",      "Détermine quels lieux le guide liste à son ouverture. Vous pouvez toujours basculer entre eux dans le guide.");
    this.Text("NCZDG.optOpenArea",     "Ouvrir sur votre district");
    this.Text("NCZDG.tipOpenArea",     "Le guide s'ouvre sur le district où vous vous trouvez. Désactivez cette option pour l'ouvrir sur TOUS LES LIEUX à la place. Hors carte, il s'ouvre toujours sur TOUS LES LIEUX.");
    this.Text("NCZDG.optOpenMap",      "Ouvrir la carte à l'affichage");
    this.Text("NCZDG.tipOpenMap",      "AFFICHER SUR LA CARTE ouvre la carte du monde et la centre sur le repère. Désactivez cette option pour placer le repère et rester dans le guide.");
    this.Text("NCZDG.optAutoTrack",    "Suivre le repère");
    this.Text("NCZDG.tipAutoTrack",    "Trace immédiatement un itinéraire vers le repère, au lieu de vous laisser le suivre vous-même sur la carte. Cela remplace un repère personnalisé que vous avez placé ; votre quête suivie utilise un emplacement séparé et n'est pas modifiée.");
    this.Text("NCZDG.noteWaypoint",    "Un repère ne commence à tracer un itinéraire qu'une fois la carte du monde ouverte. C'est une limitation du jeu, pas un réglage.");

    this.Text("NCZDG.dropAll",         "Tous");
    this.Text("NCZDG.dropInstalled",   "Installés uniquement");
    this.Text("NCZDG.dropMissing",     "Manquants uniquement");

    this.Text("NCZDG.secMap",          "Carte du monde");
    this.Text("NCZDG.optMap",          "Voir sur la carte");
    this.Text("NCZDG.tipMap",          "Ajoute un compteur de mods de lieux et une répartition par catégorie au panneau d'information du district sur la carte.");

    this.Text("NCZDG.secNotice",       "Avis de district");
    this.Text("NCZDG.optNotice",       "Activer l'avis de district");
    this.Text("NCZDG.tipNotice",       "Lorsque vous entrez dans un district, ajoute un panneau sous la bannière de district du jeu. Ne masque jamais la bannière elle-même.");
    this.Text("NCZDG.optNearest",      "Nommer le lieu le plus proche");
    this.Text("NCZDG.tipNearest",      "Affiche aussi le nom du mod de lieu le plus proche dans la zone. Désactivé, seul le compteur est affiché.");
    this.Text("NCZDG.optFastTravel",   "Afficher après un déplacement rapide");
    this.Text("NCZDG.tipFastTravel",   "Le déplacement rapide ne déclenche aucune bannière de district, l'avis apparaît donc à l'arrivée. Désactivé, le déplacement rapide reste entièrement géré par le jeu.");
  }
}
