' Asks this Roku what it can decode. Answers are cached per component, since many
' copies share the same codecs.

' What this device can decode, for ranking copies: { hevc, vp9, av1 } (H.264 always plays).
function DeviceCaps() as Object
    return {
        hevc: canDecode("video", "hevc", "")
        vp9: canDecode("video", "vp9", "")
        av1: canDecode("video", "av1", "")
    }
end function

function canDecode(kind as String, codec as String, profile as String) as Boolean
    if m.decodeCache = invalid then m.decodeCache = {}
    key = kind + "|" + codec + "|" + profile
    cached = m.decodeCache[key]
    if cached <> invalid then return cached
    device = CreateObject("roDeviceInfo")
    query = { Codec: codec }
    if profile <> "" then query.Profile = profile
    if kind = "video" then
        answer = device.CanDecodeVideo(query)
    else
        answer = device.CanDecodeAudio(query)
    end if
    ok = true
    if IsAA(answer) and ToStr(answer.result) = "false" then ok = false
    m.decodeCache[key] = ok
    return ok
end function

' The screen's height in lines (720 on the TCL), for picking how much bandwidth to allow.
function ScreenHeight() as Integer
    size = CreateObject("roDeviceInfo").GetDisplaySize()
    return ToInt(Field(size, "h"))
end function
