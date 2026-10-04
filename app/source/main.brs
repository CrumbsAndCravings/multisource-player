' Starts the scene and passes deep links to it, both at launch and while the app is
' already open (roInput). A deep link looks like
'   contentId=tmdb:movie:10378&mediaType=movie
' Movies and episodes start playing (that's Roku's rule for deep links); series, or any
' link with open=details, open the details page. The test harness adds mode and
' condition, which the scene keeps for the measurements in a later milestone.
sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("MainScene")
    screen.Show()

    input = CreateObject("roInput")
    input.SetMessagePort(port)
    forwardDeepLink(scene, args)

    while true
        msg = Wait(0, port)
        kind = type(msg)
        if kind = "roSGScreenEvent" and msg.IsScreenClosed() then return
        if kind = "roInputEvent" and msg.IsInput() then forwardDeepLink(scene, msg.GetInfo())
    end while
end sub

sub forwardDeepLink(scene as Object, args as Dynamic)
    if type(args) <> "roAssociativeArray" then return
    contentId = args.contentId
    if contentId = invalid or contentId = "" then return
    link = { contentId: contentId, mediaType: "", open: "", start: "", mode: "", condition: "" }
    for each key in ["mediaType", "open", "start", "mode", "condition"]
        if args[key] <> invalid then link[key] = args[key]
    end for
    scene.deepLink = link
end sub
