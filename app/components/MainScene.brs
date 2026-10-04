sub init()
    m.top.backgroundUri = ""
    m.top.backgroundColor = "0x151028FF"
    applyDialogPalette()
    m.stack = m.top.FindNode("stack")
    m.screens = []
    m.screenCount = 0
    ' The test mode and condition from the last deep link, for measurements later.
    m.global.AddFields({ playing: false, testMode: "", testCondition: "" })
    resetTo("HomeScreen")
end sub

' Roku's own dialogs and keyboards in the ARAN+ colours.
sub applyDialogPalette()
    if not m.top.HasField("palette") then return
    palette = CreateObject("roSGNode", "RSGPalette")
    palette.colors = {
        DialogBackgroundColor: "0x1E1736FF"
        DialogItemColor: "0xF7F3FFFF"
        DialogTextColor: "0xF7F3FFFF"
        DialogFocusColor: "0xC9B8FFFF"
        DialogFocusItemColor: "0x151028FF"
        DialogSecondaryTextColor: "0xC3B8E6FF"
        DialogSecondaryItemColor: "0xFF9ECFFF"
        DialogInputFieldColor: "0x30275AFF"
        DialogKeyboardColor: "0x241C42FF"
        DialogFootprintColor: "0x43377AFF"
    }
    m.top.palette = palette
end sub

function pushScreen(name as String) as Object
    if m.screens.Count() > 0 then
        current = m.screens.Peek()
        current.visible = false
    end if
    screen = m.stack.CreateChild(name)
    screen.ObserveField("action", "onAction")
    m.screens.Push(screen)
    animateIn(screen)
    return screen
end function

' New screens fade in while floating up a little.
sub animateIn(screen as Object)
    m.screenCount = m.screenCount + 1
    screen.id = "screen" + m.screenCount.ToStr()
    screen.opacity = 0.0
    screen.translation = [0, 18]
    anim = m.top.CreateChild("Animation")
    anim.duration = 0.3
    anim.easeFunction = "outCubic"
    fade = anim.CreateChild("FloatFieldInterpolator")
    fade.key = [0.0, 1.0]
    fade.keyValue = [0.0, 1.0]
    fade.fieldToInterp = screen.id + ".opacity"
    slide = anim.CreateChild("Vector2DFieldInterpolator")
    slide.key = [0.0, 1.0]
    slide.keyValue = [[0, 18], [0, 0]]
    slide.fieldToInterp = screen.id + ".translation"
    anim.ObserveField("state", "onScreenAnimation")
    anim.control = "start"
end sub

' Drops finished transitions and makes sure the screen ends fully shown.
sub onScreenAnimation(event as Object)
    anim = event.GetRoSGNode()
    if anim.state <> "stopped" then return
    for each screen in m.screens
        screen.opacity = 1.0
        screen.translation = [0, 0]
    end for
    anim.UnobserveField("state")
    m.top.RemoveChild(anim)
end sub

sub popScreen()
    if m.screens.Count() <= 1 then return
    top = m.screens.Pop()
    top.UnobserveField("action")
    m.stack.RemoveChild(top)
    previous = m.screens.Peek()
    previous.visible = true
    previous.takeFocus = true
end sub

sub resetTo(name as String)
    for each screen in m.screens
        screen.UnobserveField("action")
    end for
    m.screens = []
    m.screenCount = 0
    m.stack.RemoveChildrenIndex(m.stack.GetChildCount(), 0)
    screen = pushScreen(name)
    screen.takeFocus = true
end sub

sub onAction(event as Object)
    action = event.GetData()
    name = FieldStr(action, "name")
    if name = "openSearch" then
        screen = pushScreen("SearchScreen")
        screen.takeFocus = true
    else if name = "openDetails" then
        screen = pushScreen("DetailsScreen")
        screen.item = action.item
        screen.takeFocus = true
    else if name = "play" then
        screen = pushScreen("PlayerScreen")
        screen.playback = action.playback
        screen.takeFocus = true
    else if name = "close" then
        popScreen()
    end if
end sub

' --- Deep links ----------------------------------------------------------------

sub onDeepLink()
    link = m.top.deepLink
    target = ParseContentId(FieldStr(link, "contentId"))
    if target = invalid then return
    m.global.testMode = FieldStr(link, "mode")
    m.global.testCondition = FieldStr(link, "condition")

    ' Start from Home, so Back from the linked title lands somewhere sensible.
    m.top.dialog = invalid
    resetTo("HomeScreen")
    kind = "movie"
    if target.type <> "movie" then kind = "series"
    if target.type = "series" or FieldStr(link, "open") = "details" then
        item = CreateObject("roSGNode", "ContentNode")
        item.Update(ItemDefaults(), true)
        item.kind = kind
        item.tmdbId = target.tmdbId
        screen = pushScreen("DetailsScreen")
        screen.item = item
        screen.takeFocus = true
        return
    end if

    ' A movie or an episode plays straight away, from where it was left unless the link
    ' says where to start.
    startAt = -1
    if FieldStr(link, "start") <> "" then startAt = ToInt(link.start)
    screen = pushScreen("PlayerScreen")
    screen.playback = {
        kind: target.type
        media: MakeMedia({ type: target.type, tmdbId: target.tmdbId, season: target.season, episode: target.episode })
        startAt: startAt
        needsDetails: true
    }
    screen.takeFocus = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" and m.screens.Count() > 1 then
        popScreen()
        return true
    end if
    return false
end function
