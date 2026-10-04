' Home: Continue Watching, then a row for each source that keeps a catalog. Every poster
' here is something a source can play; Search covers the rest of TMDB.

sub init()
    m.rows = m.top.FindNode("rows")
    m.backdrop = m.top.FindNode("backdrop")
    m.heroTitle = m.top.FindNode("heroTitle")
    m.heroMeta = m.top.FindNode("heroMeta")
    m.heroPlot = m.top.FindNode("heroPlot")
    m.status = m.top.FindNode("status")
    m.navKeys = m.top.FindNode("navKeys")
    m.heroTimer = m.top.FindNode("heroTimer")
    m.hero = m.top.FindNode("hero")
    m.heroIn = m.top.FindNode("heroIn")
    m.backdropIn = m.top.FindNode("backdropIn")
    m.backdropFade = m.top.FindNode("backdropFade")
    m.tabHighlight = m.top.FindNode("tabHighlight")
    m.tabSlide = m.top.FindNode("tabSlide")
    m.tabSlidePos = m.top.FindNode("tabSlidePos")
    m.tabSlideWidth = m.top.FindNode("tabSlideWidth")
    m.heroItem = invalid
    m.backdropTarget = 1.0
    m.backdrop.ObserveField("loadStatus", "onBackdropLoaded")

    m.heroTitle.font = MakeFont("Fredoka-SemiBold", 40)
    m.heroMeta.font = MakeFont("Nunito-ExtraBold", 18)
    ' Plots may not be in a Latin script, so they use the system font.
    m.heroPlot.font = "font:SmallSystemFont"
    m.rows.rowLabelFont = MakeFont("Fredoka-Medium", 21)
    m.status.font = MakeFont("Nunito-SemiBold", 20)

    m.tabNames = ["Home", "Search"]
    m.tab = 0
    m.tabCursor = 0
    m.navFocused = true
    m.firstLoad = true
    m.tabPills = BuildPills(m.top.FindNode("tabs"), m.tabNames, 18)
    styleTabs()

    m.catalogRows = invalid
    m.rowsTask = invalid
    m.infoTask = invalid
    m.infoTarget = invalid
    m.focusedItem = invalid
    m.warning = ""

    m.rows.ObserveField("rowItemFocused", "onRowItemFocused")
    m.rows.ObserveField("rowItemSelected", "onRowItemSelected")
    m.heroTimer.ObserveField("fire", "onHeroTimer")

    loadRows()
end sub

' --- Loading -----------------------------------------------------------------

sub loadRows()
    m.status.text = "Loading…"
    m.rowsTask = CreateObject("roSGNode", "TmdbTask")
    m.rowsTask.request = { mode: "rows" }
    m.rowsTask.ObserveField("result", "onRows")
    m.rowsTask.control = "RUN"
end sub

sub onRows(event as Object)
    result = event.GetData()
    m.catalogRows = event.GetRoSGNode().content
    m.rowsTask = invalid
    m.warning = FieldStr(result, "warning")
    showRows()
end sub

' Continue Watching on top, then the catalog rows.
sub showRows()
    root = CreateObject("roSGNode", "ContentNode")
    continueRow = ContinueWatchingRow()
    if continueRow <> invalid then root.AppendChild(continueRow)
    if m.catalogRows <> invalid then
        catalog = []
        for i = 0 to m.catalogRows.GetChildCount() - 1
            catalog.Push(m.catalogRows.GetChild(i))
        end for
        for each row in catalog
            root.AppendChild(row)
        end for
        m.catalogRows = invalid
    end if
    m.rows.content = root
    if root.GetChildCount() = 0 then
        m.status.text = "No source has a catalog to show yet. Search finds titles on TMDB."
        clearHero()
        focusNav()
        return
    end if
    m.status.text = ""
    if m.warning <> "" then showWarning(m.warning)
    if m.firstLoad then
        m.firstLoad = false
        focusRows()
    end if
end sub

' Not fatal (the rows still work), so it goes in the hero instead of over the rows.
sub showWarning(text as String)
    m.heroTitle.text = "Almost there"
    m.heroMeta.text = ""
    m.heroPlot.text = text
end sub

' --- Hero --------------------------------------------------------------------

function focusedItem() as Dynamic
    root = m.rows.content
    if root = invalid then return invalid
    focus = m.rows.rowItemFocused
    if focus = invalid or focus.Count() < 2 or focus[0] < 0 or focus[1] < 0 then return invalid
    row = root.GetChild(focus[0])
    if row = invalid then return invalid
    return row.GetChild(focus[1])
end function

sub onRowItemFocused()
    refreshHero()
end sub

sub refreshHero()
    item = focusedItem()
    if item = invalid then return
    if item.placeholder then return
    m.focusedItem = item
    showHero(item)
    ' Continue Watching only keeps a title and artwork; fetch the rest once focus settles.
    if not item.hasInfo then
        m.heroTimer.control = "stop"
        m.heroTimer.control = "start"
    end if
end sub

sub showHero(item as Object)
    m.heroTitle.text = item.title
    meta = MetaLine(item)
    if item.caption <> "" then meta = "Resume  " + item.caption
    if continueItem() <> invalid then meta = meta + "   ·   * to remove"
    m.heroMeta.color = "0xC3B8E6FF"
    m.heroMeta.text = meta
    m.heroPlot.text = item.description
    ' A new title floats in; a refresh of the same title (details arriving) doesn't.
    isNew = true
    if m.heroItem <> invalid then isNew = not m.heroItem.IsSameNode(item)
    m.heroItem = item
    if isNew then
        m.heroIn.control = "stop"
        m.hero.opacity = 0.0
        m.heroIn.control = "start"
    end if
    m.backdropIn.control = "stop"
    m.backdropTarget = ShowBackdrop(m.backdrop, item.backdrop, item.HDPosterUrl)
end sub

sub onBackdropLoaded()
    if m.backdrop.loadStatus <> "ready" then return
    m.backdropFade.keyValue = [0.0, m.backdropTarget]
    m.backdropIn.control = "start"
end sub

sub clearHero()
    m.heroTitle.text = ""
    m.heroMeta.text = ""
    m.heroPlot.text = ""
    m.backdrop.uri = ""
end sub

sub onHeroTimer()
    item = m.focusedItem
    if item = invalid or item.hasInfo or item.tmdbId = "" then return
    item.hasInfo = true
    m.infoTarget = item
    m.infoTask = CreateObject("roSGNode", "TmdbTask")
    m.infoTask.request = { mode: "details", kind: item.kind, tmdbId: item.tmdbId }
    m.infoTask.ObserveField("result", "onHeroInfo")
    m.infoTask.control = "RUN"
end sub

sub onHeroInfo(event as Object)
    result = event.GetData()
    item = m.infoTarget
    m.infoTask = invalid
    m.infoTarget = invalid
    if item = invalid or not result.ok then return
    ' Continue Watching's own title and caption stay as they are.
    caption = item.caption
    ApplyInfo(item, result.info)
    item.caption = caption
    if m.focusedItem <> invalid and m.focusedItem.IsSameNode(item) then showHero(item)
end sub

' --- Selection & focus -------------------------------------------------------

sub onRowItemSelected()
    if m.navFocused then return
    root = m.rows.content
    selected = m.rows.rowItemSelected
    if root = invalid or selected = invalid or selected.Count() < 2 then return
    row = root.GetChild(selected[0])
    if row = invalid then return
    item = row.GetChild(selected[1])
    if item = invalid or item.placeholder then return
    m.top.action = { name: "openDetails", item: item }
end sub

sub onTakeFocus()
    if m.rows.content <> invalid then refreshContinueWatching()
    restoreFocus()
end sub

sub restoreFocus()
    if m.navFocused then
        focusNav()
    else
        focusRows()
    end if
end sub

sub refreshContinueWatching()
    root = m.rows.content
    continueRow = ContinueWatchingRow()
    hasRow = false
    if root.GetChildCount() > 0 then hasRow = root.GetChild(0).HasField("isContinue")
    if continueRow <> invalid and hasRow then
        root.ReplaceChild(continueRow, 0)
    else if continueRow <> invalid then
        root.InsertChild(continueRow, 0)
    else if hasRow then
        root.RemoveChildIndex(0)
    end if
    focus = m.rows.rowItemFocused
    if root.GetChildCount() > 0 and focus <> invalid and focus.Count() > 0 and focus[0] = 0 then m.rows.jumpToRowItem = [0, 0]
    refreshHero()
end sub

sub focusRows()
    root = m.rows.content
    if root = invalid or root.GetChildCount() = 0 then
        focusNav()
        return
    end if
    m.navFocused = false
    m.rows.SetFocus(true)
    styleTabs()
end sub

' Focus goes to navKeys, an empty sibling of the rows, rather than to this screen, so
' the RowList can't keep taking keys while the tab bar is active.
sub focusNav()
    m.navFocused = true
    m.tabCursor = m.tab
    m.navKeys.SetFocus(true)
    styleTabs()
end sub

sub activateTab()
    if m.tabNames[m.tabCursor] = "Search" then
        m.tabCursor = m.tab
        styleTabs()
        m.top.action = { name: "openSearch" }
        return
    end if
    focusRows()
end sub

' Tab labels sit on one shared highlight that glides between them: lavender while the
' tab bar has focus, a quiet plum on the current tab otherwise.
sub styleTabs()
    target = m.tab
    if m.navFocused then target = m.tabCursor
    for i = 0 to m.tabPills.Count() - 1
        pill = m.tabPills[i]
        pillBg = pill.GetChild(0)
        pillBg.opacity = 0.0
        label = pill.GetChild(1)
        if m.navFocused and i = m.tabCursor then
            label.color = "0x151028FF"
        else if i = m.tab then
            label.color = "0xF7F3FFFF"
        else
            label.color = "0xA195CCFF"
        end if
    end for

    pill = m.tabPills[target]
    bg = pill.GetChild(0)
    position = pill.translation
    toPosition = [232 + position[0], 26]
    if m.navFocused then
        m.tabHighlight.blendColor = "0xC9B8FFFF"
    else
        m.tabHighlight.blendColor = "0x30275AFF"
    end if
    m.tabHighlight.height = bg.height
    if m.tabHighlight.width = 0 then
        m.tabHighlight.translation = toPosition
        m.tabHighlight.width = bg.width
        return
    end if
    m.tabSlide.control = "stop"
    m.tabSlidePos.keyValue = [m.tabHighlight.translation, toPosition]
    m.tabSlideWidth.keyValue = [m.tabHighlight.width, bg.width]
    m.tabSlide.control = "start"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if m.navFocused then return onNavKey(key, press)
    if not press then return false
    if key = "options" then
        ' On a Continue Watching poster, * offers to remove it; elsewhere it's About.
        item = continueItem()
        if item <> invalid then
            showContinueMenu(item)
        else
            showAbout()
        end if
        return true
    end if

    ' The rows didn't use this key: Up on the first row, or Left on a row's first poster.
    if key = "up" or key = "left" then
        focusNav()
        return true
    else if key = "back" then
        focus = m.rows.rowItemFocused
        if focus <> invalid and focus.Count() > 0 and focus[0] > 0 then
            m.rows.jumpToRowItem = [0, 0]
        else
            focusNav()
        end if
        return true
    end if
    return false
end function

function onNavKey(key as String, press as Boolean) as Boolean
    ' OK acts on release, so the release can't land on the rows once they have focus.
    if key = "OK" then
        if not press then activateTab()
        return true
    end if
    if not press then return key <> "back"
    if key = "left" then
        if m.tabCursor > 0 then m.tabCursor = m.tabCursor - 1
        styleTabs()
    else if key = "right" then
        if m.tabCursor < m.tabNames.Count() - 1 then m.tabCursor = m.tabCursor + 1
        styleTabs()
    else if key = "down" then
        activateTab()
    else if key = "options" then
        showAbout()
    else if key = "back" then
        return false
    end if
    return true
end function

' --- Continue Watching ---------------------------------------------------------------

' The focused poster when it's in the Continue Watching row, else invalid.
function continueItem() as Dynamic
    root = m.rows.content
    focus = m.rows.rowItemFocused
    if root = invalid or focus = invalid or focus.Count() < 2 or focus[0] <> 0 then return invalid
    row = root.GetChild(0)
    if row = invalid or not row.HasField("isContinue") then return invalid
    return row.GetChild(focus[1])
end function

sub showContinueMenu(item as Object)
    m.continueTarget = item
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = item.title
    dialog.message = ["Remove it from Continue Watching? Where you stopped is forgotten."]
    dialog.buttons = ["Remove from Continue Watching", "Keep it"]
    dialog.ObserveField("buttonSelected", "onContinueButton")
    dialog.ObserveField("wasClosed", "onDialogClosed")
    m.top.GetScene().dialog = dialog
end sub

sub onContinueButton()
    dialog = m.top.GetScene().dialog
    if dialog = invalid then return
    choice = dialog.buttonSelected
    dialog.close = true
    item = m.continueTarget
    m.continueTarget = invalid
    if choice <> 0 or item = invalid then return
    ProgressRemove(ProgressKeyFor(item.kind, item.tmdbId))
    refreshContinueWatching()
end sub

' --- About -------------------------------------------------------------------

' Version, what's set up, and TMDB's required credit.
sub showAbout()
    cfg = LoadConfig()
    tmdb = "TMDB: connected with your token."
    if not HasTmdb(cfg) then tmdb = "TMDB: no token yet. Add tmdbToken to app/source/config.json and rebuild."
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "ARAN+ Lab " + AppVersion()
    dialog.message = [
        "Finds every copy of a title across your sources and plays the best one."
        tmdb
        "Sources: Open movies (Blender Foundation films, Creative Commons)."
        "This product uses the TMDB API but is not endorsed or certified by TMDB."
    ]
    dialog.buttons = ["Close"]
    dialog.ObserveField("buttonSelected", "onAboutButton")
    dialog.ObserveField("wasClosed", "onDialogClosed")
    m.top.GetScene().dialog = dialog
end sub

sub onAboutButton()
    dialog = m.top.GetScene().dialog
    if dialog <> invalid then dialog.close = true
end sub

sub onDialogClosed()
    restoreFocus()
end sub
