// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: translations/Russian.reds
// Author: Parasitko
// Description: The source of truth for every player-facing string. Codeware's
//              ModLocalizationPackage; no TweakXL, no locale JSON, no LocKey registration.
//
//              ADDING A LANGUAGE IS ADDITIVE: copy this file, translate the second
//              argument of every Text() call, extend ModLocalizationPackage under a new
//              name, and add one case to Provider.reds. Never translate the KEY.
//
//              PLACEHOLDERS ARE WHY THE SENTENCES ARE WHOLE. {n}, {area}, {total} and
//              friends are substituted at the call site, so a translator can put the
//              number after the noun, or the area before the count, or drop a word
//              entirely. Assembling a sentence by concatenating a count with " locations"
//              cannot do that - it hardcodes English word order into the code, where a
//              translator cannot reach it.
//
//              PLURALS ARE WHOLE STRINGS, one key per form, never a stem plus "S".
//              English has two forms; Polish and Russian have three, Arabic six. A key
//              per form is a key a translator can fill in; a suffix is not.
// Mod Version: 1.0.0
// Credits: psiberx (Codeware), DigitalVixen (RCF, the reference implementation)
// ======================================================================================

module NCZoningDistrictGuide.Translations

import Codeware.Localization.*

public class NCZDG_Russian extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // --- guide chrome ------------------------------------------------------------------
    this.Text("NCZDG.title",           "NC ZONING BOARD");
    this.Text("NCZDG.headerLeft",      "NIGHT CORP // URBAN PLANNING DIVISION");
    this.Text("NCZDG.headerRight",     "NC-ZB-01");
    this.Text("NCZDG.searchHint",      "ПОИСК ПО НАЗВАНИЮ, АВТОРУ, ТЕГУ");

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
    this.Text("NCZDG.countSearch",     "{n} ИЗ {всего} В {области}");
    this.Text("NCZDG.countPaged",      "{от}-{до} из {n} в {область}");
    this.Text("NCZDG.countPlain",      "{n} В {области}");

    // --- nav column --------------------------------------------------------------------
    this.Text("NCZDG.areaAll",         "ВСЕ ЛОКАЦИИ");
    this.Text("NCZDG.navRecent",       "{n} ПОЛЕДНИЕ");

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
    this.Text("NCZDG.panelEmpty",      "В {области} пока нет зарегистрированных локаций");
    this.Text("NCZDG.panelCountOne",   "{n} зарегистрированная локация в {области}");
    this.Text("NCZDG.panelCountMany",  "{n} зарегистрированные локации в {области}");
    this.Text("NCZDG.panelNearest",    "Ближайший: {название}");

    // --- world map panel ---------------------------------------------------------------
    this.Text("NCZDG.mapCaption",      "ЗОНИРОВАНИЕ NC :");
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
    this.Text("NCZDG.tipShowing",      "Какие локации отображаются в справочнике при его открытии. Вы по-прежнему можете переключаться между ними внутри справочника. Требуется Cyber Engine Tweaks, который и определяет установленные у вас моды.");
    this.Text("NCZDG.optOpenArea",     "Откройте информацию о вашем районе");
    this.Text("NCZDG.tipOpenArea",     "Путеводитель открывается с того района, в котором вы находитесь. Отключите эту функцию, чтобы путеводитель открывался со страницы ВСЕ ЛОКАЦИИ. В режиме Вне карты путеводитель всегда открывается со страницы ВСЕ ЛОКАЦИИ.");
    this.Text("NCZDG.optOpenMap",      "Открыть карту в режиме просмотра");
    this.Text("NCZDG.tipOpenMap",      "Функция ПОКАЗАТЬ НА КАРТЕ открывает карту мира и центрирует её на путевой точке. Отключите эту функцию, чтобы установить путевую точку и остаться в режиме навигации.");
    this.Text("NCZDG.optAutoTrack",    "Отслеживать путевую точку");
    this.Text("NCZDG.tipAutoTrack",    "Сразу же проложите маршрут до контрольной точки, вместо того чтобы самостоятельно отслеживать её на карте. Это заменит установленную вами пользовательскую контрольную точку; ваш отслеживаемый квест занимает отдельный слот и останется без изменений.");
    this.Text("NCZDG.noteWaypoint",    "Маршрутизация по путевой точке начинается только после открытия карты мира. Это ограничение игры, а не настройка.");

    this.Text("NCZDG.dropAll",         "Все");
    this.Text("NCZDG.dropInstalled",   "Только установленные");
    this.Text("NCZDG.dropMissing",     "Только пропущенные");

    this.Text("NCZDG.secMap",          "Карта мира");
    this.Text("NCZDG.optMap",          "Показать на карте мира");
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