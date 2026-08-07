// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: translations/Russian.reds
// Author: Parasitko
// Description: The Russian slot. Empty - every string shows in English until someone
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
// Mod Version: 1.1.0
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoningDistrictGuide.Translations

import Codeware.Localization.*

public class NCZDG_Russian extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // --- guide chrome ------------------------------------------------------------------
    this.Text("NCZDG.title",           "NC ZONING BOARD");
    this.Text("NCZDG.headerLeft",      "NIGHT CORP // URBAN PLANNING DIVISION");
    this.Text("NCZDG.headerRight",     "NC-ZB-01");
    this.Text("NCZDG.searchHint",      "ПОИСК ПО НАЗВАНИЮ, АВТОРУ, ТЕГУ - & | !");

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
    this.Text("NCZDG.helpTitle",       "СИНТАКСИС ПОИСКА");
    this.Text("NCZDG.helpAnd",         "watson&apartment   -   оба слова должны совпадать");
    this.Text("NCZDG.helpOr",          "watson|pacifica   -   может совпадать с любым из них");
    this.Text("NCZDG.helpNot",         "!corpo   -   всё, кроме corpo");
    this.Text("NCZDG.helpNotWith",     "apartment!corpo   -   квартиры, за исключением всего, что связано с корпоративным жильем");
    this.Text("NCZDG.helpMix",         "watson|pacifica&apartment   -   любой район и квартира");
    this.Text("NCZDG.helpPhrase",      "night city   -   если не указано оператор, производится поиск по всей строке в том виде, в каком она введена");
    this.Text("NCZDG.helpSpaces",      "Операторы следует указывать без пробелов. Поисковая система watson & apartment ищет фразы watson  и  apartment с пробелами и всем остальным.");
    this.Text("NCZDG.helpFields",      "Каждое слово сопоставляется с названием, описанием, категорией, районом, тегами и авторами.");

    // --- buttons -----------------------------------------------------------------------
    this.Text("NCZDG.btnClear",        "ОЧИСТИТЬ");
    this.Text("NCZDG.btnSetMarker",    "ПОКАЗАТЬ НА КАРТЕ");
    this.Text("NCZDG.btnClearMarker",  "ОЧИСТИТЬ ПУТЕВУЮ ТОЧКУ");
    this.Text("NCZDG.btnTeleport",     "ТЕЛЕПОРТИРОВАТЬСЯ");
    this.Text("NCZDG.btnExitVehicle",  "ВЫЙТИ ИЗ ТРАНСПОРТНОГО СРЕДСТВА");
    this.Text("NCZDG.btnPrev",         "< ПРЕДЫДУЩИЙ");
    this.Text("NCZDG.btnNext",         "СЛЕДУЮЩИЙ >");

    // --- install filter ----------------------------------------------------------------
    this.Text("NCZDG.filterAll",       "ПОКАЗАТЬ: ВСЕ");
    this.Text("NCZDG.filterInstalled", "ПОКАЗАТЬ: УСТАНОВЛЕННЫЕ");
    this.Text("NCZDG.filterMissing",   "ПОКАЗАТЬ: ПРОПУЩЕННЫЕ");
    this.Text("NCZDG.filterUnknown",   "ПОКАЗАТЬ: НЕИЗВЕСТНЫЕ");

    // --- the guide's status line -------------------------------------------------------
    // Three forms because the sentence differs, not because the numbers do: a search says
    // how many of the area matched, a paged list says which slice is on screen, and a
    // short list says only the total.
    this.Text("NCZDG.countSearch",     "{n} ИЗ {total} В {area}");
    this.Text("NCZDG.countPaged",      "{from}-{to} ИЗ {n} В {area}");
    this.Text("NCZDG.countPlain",      "{n} В {area}");

    // --- nav column --------------------------------------------------------------------
    this.Text("NCZDG.areaAll",         "ВСЕ ЛОКАЦИИ");
    this.Text("NCZDG.navRecent",       "{n} ПОСЛЕДНИЕ");

    // --- cards -------------------------------------------------------------------------
    this.Text("NCZDG.badgeRecent",     "НЕДАВНО ОБНОВЛЕНО");
    this.Text("NCZDG.badgeInstalled",  "УСТАНОВЛЕНО");
    this.Text("NCZDG.noImage",         "ИЗОБРАЖЕНИЕ ИЗ ОПРОСА В ФАЙЛЕ ОТСУТСТВУЕТ");

    // --- lightbox ----------------------------------------------------------------------
    this.Text("NCZDG.imgLoading",      "ЗАГРУЗКА...");
    this.Text("NCZDG.imgLoadingClose", "ЗАГРУЗКА...   -   НАЖМИТЕ В ЛЮБОМ МЕСТЕ ЧТОБ ЗАКРЫТЬ");
    this.Text("NCZDG.imgFailed",       "ИЗОБРАЖЕНИЕ ОТСУТСТВУЕТ   -   НАЖМИТЕ В ЛЮБОМ МЕСТЕ ЧТОБ ЗАКРЫТЬ");
    this.Text("NCZDG.imgClose",        "НАЖМИТЕ В ЛЮБОМ МЕСТЕ ЧТОБ ЗАКРЫТЬ");

    // --- categories --------------------------------------------------------------------
    // The card badge and the map breakdown want the same three words in singular and
    // plural. The registry's own values ("new-location", "location-overhaul") are data
    // and are never translated - only their labels are.
    this.Text("NCZDG.catNew",          "НОВАЯ ЛОКАЦИЯ");
    this.Text("NCZDG.catNewPlural",    "НОВЫЕ ЛОКАЦИИ");
    this.Text("NCZDG.catOverhaul",     "КАПИТАЛЬНЫЙ РЕМОНТ");
    this.Text("NCZDG.catOverhaulPlural", "КАПИТАЛЬНЫЕ РЕМОНТЫ");
    this.Text("NCZDG.catOther",        "ДРУГОЕ");
    this.Text("NCZDG.catOtherPlural",  "ДРУГИЕ");

    // --- district notice + fast-travel panel -------------------------------------------
    this.Text("NCZDG.panelEmpty",      "В {area} пока нет зарегистрированных локаций");
    this.Text("NCZDG.panelCountOne",   "{n} зарегистрированная локация в {area}");
    this.Text("NCZDG.panelCountMany",  "{n} зарегистрированные локации в {area}");
    this.Text("NCZDG.panelNearest",    "Ближайший: {name}");

    // --- world map panel ---------------------------------------------------------------
    this.Text("NCZDG.mapCaption",      "ЗОНИРОВАНИЕ NC:");
    this.Text("NCZDG.mapEmpty",        "НЕТ ЗАРЕГИСТРИРОВАННЫХ ЛОКАЦИЙ");
    this.Text("NCZDG.mapCountOne",     "{n} ЛОКАЦИЯ");
    this.Text("NCZDG.mapCountMany",    "{n} ЛОКАЦИИ");
    this.Text("NCZDG.mapRecent",       "{n} НЕДАВНО ОБНОВЛЕНО");

    // --- failure states ----------------------------------------------------------------
    // The long form belongs to NCZoningCore (GetStatusMessage) and is localised there.
    this.Text("NCZDG.noData",          "ДАННЫЕ О ЛОКАЦИИ ОТСУТСТВУЮТ");

    // --- RCF settings panel ------------------------------------------------------------
    // RCF resolves these itself: DVRCF_HubPopup.LocalizeSchema runs every schema string
    // through LocalizationSystem.GetText, so the adapter passes KEYS, not translated text.
    this.Text("NCZDG.modName",         "NC Zoning Board - Справочник по округу");
    this.Text("NCZDG.modDesc",         "Какие моды локаций есть в районе, расположенном рядом с вами.");

    this.Text("NCZDG.secLocations",    "Локации");
    this.Text("NCZDG.optSubdistrict",  "Сузить поиск до микрорайона");
    this.Text("NCZDG.tipSubdistrict",  "Когда вы находитесь в каком-либо подрайоне, просматривайте данные по каждому подрайону, а не по всему району в целом. Это относится к руководству, панели с картой и уведомлению о районе.");

    this.Text("NCZDG.secGuide",        "Путеводитель по округу");
    this.Text("NCZDG.optGuide",        "Включить справочник по округам");
    this.Text("NCZDG.tipGuide",        "Изучайте моды локаций в любом районе с помощью поиска, ориентира на карте и телепортации.");
    this.Text("NCZDG.optKey",          "Открыть справочник ключей");
    this.Text("NCZDG.tipKey",          "Клавиша, открывающая справочник по районам. Требуется Input Loader.");
    this.Text("NCZDG.optModifier",     "Открыть руководство по модификаторам");
    this.Text("NCZDG.tipModifier",     "Дополнительная клавиша, которую нужно удерживать одновременно с клавишей открытия. Подойдет любая клавиша, не обязательно Shift, Alt или Ctrl. Если не указано, модификатор не используется.");
    this.Text("NCZDG.optShowing",      "Открыть руководство по просмотру");
    this.Text("NCZDG.tipShowing",      "Какие локации отображаются в справочнике при его открытии. Вы по-прежнему можете переключаться между ними внутри справочника.");
    this.Text("NCZDG.optOpenArea",     "Откройте информацию о вашем районе");
    this.Text("NCZDG.tipOpenArea",     "Путеводитель открывается с того района, в котором вы находитесь. Отключите эту функцию, чтобы путеводитель открывался со страницы ВСЕ ЛОКАЦИИ. В режиме Вне карты путеводитель всегда открывается со страницы ВСЕ ЛОКАЦИИ.");
    this.Text("NCZDG.optOpenMap",      "Открыть карту в режиме просмотра");
    this.Text("NCZDG.tipOpenMap",      "Функция ПОКАЗАТЬ НА КАРТЕ открывает карту мира и центрирует её на путевой точке. Отключите эту функцию, чтобы установить путевую точку и остаться в режиме навигации.");
    this.Text("NCZDG.optAutoTrack",    "Отслеживать путевую точку");
    this.Text("NCZDG.tipAutoTrack",    "Сразу же проложите маршрут до контрольной точки, вместо того чтобы самостоятельно отслеживать её на карте. Это заменит установленную вами пользовательскую контрольную точку; ваш отслеживаемый квест занимает отдельный слот и останется без изменений.");
    this.Text("NCZDG.noteWaypoint",    "Маршрутизация по путевой точке начинается только после открытия карты мира. Это ограничение игры, а не настройка.");

    this.Text("NCZDG.dropAll",         "ВСЕ");
    this.Text("NCZDG.dropInstalled",   "ТОЛЬКО УСТАНОВЛЕННЫЕ");
    this.Text("NCZDG.dropMissing",     "ТОЛЬКО ПРОПУЩЕННЫЕ");

    this.Text("NCZDG.secMap",          "КАРТА МИРА");
    this.Text("NCZDG.optMap",          "ПОКАЗАТЬ НА КАРТЕ МИРА");
    this.Text("NCZDG.tipMap",          "Добавить на панели с информацией о районах карты количество модификаций по местоположению и разбивку по категориям.");

    this.Text("NCZDG.secNotice",       "Уведомление округа");
    this.Text("NCZDG.optNotice",       "Включить уведомление округа");
    this.Text("NCZDG.tipNotice",       "При входе в район добавьте панель под баннером этого района в игре. При этом сам баннер никогда не скрывается.");
    this.Text("NCZDG.optNearest",      "Укажите ближайшее местоположение");
    this.Text("NCZDG.tipNearest",      "Также укажите название ближайшего мода локации в этом районе. При отключенном параметре отображается только количество.");
    this.Text("NCZDG.optFastTravel",   "Показать Быстрое перемещение");
    this.Text("NCZDG.tipFastTravel",   "При использовании быстрого перемещения не отображается баннер района, поэтому уведомление появляется только по прибытии. При отключении этой функции быстрое перемещение полностью осуществляется по умолчанию.");
  }
}
