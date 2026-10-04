' Shared helpers, mostly from ARAN+. Everything read from an API goes through the loose
' readers here, so a missing or oddly typed field never crashes a screen.

function IsAA(value as Dynamic) as Boolean
    return type(value) = "roAssociativeArray"
end function

function IsArr(value as Dynamic) as Boolean
    return type(value) = "roArray"
end function

function ToStr(value as Dynamic) as String
    t = type(value)
    if t = "String" or t = "roString" then return value
    if t = "Integer" or t = "roInt" or t = "roInteger" or t = "LongInteger" or t = "roLongInteger" then return value.ToStr()
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return Str(value).Trim()
    if t = "Boolean" or t = "roBoolean" then
        if value then return "true"
        return "false"
    end if
    return ""
end function

function ToInt(value as Dynamic) as Integer
    t = type(value)
    if t = "Integer" or t = "roInt" or t = "roInteger" then return value
    if t = "LongInteger" or t = "roLongInteger" or t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return Int(value)
    if t = "String" or t = "roString" then return value.Trim().ToInt()
    if t = "Boolean" or t = "roBoolean" then
        if value then return 1
    end if
    return 0
end function

function ToFloat(value as Dynamic) as Float
    t = type(value)
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return value
    if t = "Integer" or t = "roInt" or t = "roInteger" or t = "LongInteger" or t = "roLongInteger" then return value * 1.0
    if t = "String" or t = "roString" then return value.Trim().ToFloat()
    return 0.0
end function

function ToBool(value as Dynamic) as Boolean
    t = type(value)
    if t = "Boolean" or t = "roBoolean" then return value
    return LCase(ToStr(value)) = "true" or ToInt(value) <> 0
end function

' Reads aa[key] without crashing when aa is not an associative array.
function Field(aa as Dynamic, key as String) as Dynamic
    if not IsAA(aa) then return invalid
    return aa[key]
end function

function FieldStr(aa as Dynamic, key as String) as String
    return ToStr(Field(aa, key)).Trim()
end function

function FieldArr(aa as Dynamic, key as String) as Object
    value = Field(aa, key)
    if IsArr(value) then return value
    return []
end function

function FirstText(values as Object) as String
    for each value in values
        text = ToStr(value).Trim()
        if text <> "" then return text
    end for
    return ""
end function

' TMDB serves every size from the same path, so ask for one that fits a 720p screen.
function SizedImage(url as String, size as String) as String
    marker = "image.tmdb.org/t/p/"
    found = Instr(1, url, marker)
    if found = 0 then return url
    start = found + Len(marker)
    slash = Instr(start, url, "/")
    if slash = 0 then return url
    return Left(url, start - 1) + size + Mid(url, slash)
end function

function YearOf(dateText as String) as String
    year = Left(dateText.Trim(), 4)
    if Len(year) = 4 and year.ToInt() > 1900 then return year
    return ""
end function

function Pad2(n as Integer) as String
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

' 5234 -> "1:27:14"
function FormatClock(seconds as Integer) as String
    h = seconds \ 3600
    mins = (seconds MOD 3600) \ 60
    secs = seconds MOD 60
    if h > 0 then return h.ToStr() + ":" + Pad2(mins) + ":" + Pad2(secs)
    return mins.ToStr() + ":" + Pad2(secs)
end function

' 5234 -> "1h 27m"
function FormatRuntime(seconds as Integer) as String
    totalMins = (seconds + 30) \ 60
    h = totalMins \ 60
    mins = totalMins MOD 60
    if h > 0 and mins > 0 then return h.ToStr() + "h " + mins.ToStr() + "m"
    if h > 0 then return h.ToStr() + "h"
    return mins.ToStr() + "m"
end function

function MetaLine(item as Object) as String
    parts = []
    if item.year <> "" then parts.Push(item.year)
    if item.durationSecs > 0 then parts.Push(FormatRuntime(item.durationSecs))
    if item.genre <> "" then
        genres = item.genre.Split(",")
        text = genres[0].Trim()
        if genres.Count() > 1 then text = text + ", " + genres[1].Trim()
        parts.Push(text)
    end if
    tenths = Int(item.score.ToFloat() * 10 + 0.5)
    if tenths > 0 then
        whole = tenths \ 10
        fraction = tenths MOD 10
        parts.Push("Rated " + whole.ToStr() + "." + fraction.ToStr())
    end if
    return parts.Join("   ·   ")
end function

' "S1:E2"
function EpisodeCode(seasonNo as Dynamic, episodeNo as Dynamic) as String
    return "S" + ToInt(seasonNo).ToStr() + ":E" + ToInt(episodeNo).ToStr()
end function

' --- HTTP errors ------------------------------------------------------------

' One short line from an error page: scripts, tags and extra spaces removed.
function BriefText(body as String, limit as Integer) as String
    text = CreateObject("roRegex", "<(script|style)[^>]*>.*?</(script|style)>", "is").ReplaceAll(body, " ")
    text = CreateObject("roRegex", "<[^>]*>", "s").ReplaceAll(text, " ")
    text = CreateObject("roRegex", "&nbsp;", "i").ReplaceAll(text, " ")
    text = CreateObject("roRegex", "\s+", "").ReplaceAll(text, " ").Trim()
    if Len(text) > limit then text = Left(text, limit - 1).Trim() + "…"
    return text
end function

' Sums up a failed response, like: HTTP 401: "Invalid API key". TMDB answers errors as
' JSON with a status_message.
function HttpDetail(code as Integer, body as String) as String
    detail = "HTTP " + code.ToStr()
    trimmed = body.Trim()
    said = ""
    if Left(trimmed, 1) = "{" then
        data = ParseJson(trimmed)
        said = FirstText([Field(data, "status_message"), Field(data, "message"), Field(data, "error")])
    end if
    if said = "" then said = trimmed
    said = BriefText(said, 70)
    if said = "" then return detail + ", no reason given"
    return detail + ": " + Chr(34) + said + Chr(34)
end function

' The HTTP status inside Roku's playback error text, like "response code:(403)", or 0.
function HttpCodeIn(text as String) as Integer
    found = CreateObject("roRegex", "(?:response code|http)[^0-9]{0,12}([45]\d\d)\b", "i").Match(text)
    if found.Count() > 1 then return found[1].ToInt()
    return 0
end function

' --- Content nodes -------------------------------------------------------------

' Custom fields every item node gets, so screens never read a missing field (which
' would come back invalid and crash string comparisons).
' Names must not match ContentNode's built-in metadata fields: a built-in keeps its own
' type and silently drops our value (EpisodeNumber, for one, is a string; id is the
' node's own id).
function ItemDefaults() as Object
    return {
        kind: ""
        tmdbId: ""
        imdbId: ""
        backdrop: ""
        year: ""
        genre: ""
        score: ""
        starring: ""
        directedBy: ""
        durationSecs: 0
        seasonNo: 0
        episodeNo: 0
        problem: ""
        hasInfo: false
        placeholder: false
        progress: 0.0
        caption: ""
        sourceCount: -1
    }
end function

function MakeItem(parent as Object, values as Object) as Object
    fields = ItemDefaults()
    fields.Append(values)
    node = parent.CreateChild("ContentNode")
    node.Update(fields, true)
    return node
end function

' Copies TMDB details (from TmdbParse) onto an item node.
sub ApplyInfo(item as Object, info as Dynamic)
    if not IsAA(info) then return
    for each key in ["title", "description", "year", "genre", "score", "starring", "directedBy", "backdrop", "imdbId"]
        value = FieldStr(info, key)
        if value <> "" then item.SetField(key, value)
    end for
    poster = FieldStr(info, "poster")
    if poster <> "" then item.HDPosterUrl = poster
    duration = ToInt(info.durationSecs)
    if duration > 0 then item.durationSecs = duration
    item.hasInfo = true
end sub

' Codec name (ffprobe style) -> "HEVC (H.265)"
function CodecLabel(codec as String) as String
    names = { h264: "H.264", avc: "H.264", hevc: "HEVC (H.265)", h265: "HEVC (H.265)", mpeg4: "MPEG-4 (DivX/Xvid)", mpeg2video: "MPEG-2", vp9: "VP9", av1: "AV1", wmv3: "Windows Media", vc1: "VC-1", aac: "AAC", ac3: "Dolby AC-3", eac3: "Dolby E-AC-3", dts: "DTS", mp3: "MP3", truehd: "Dolby TrueHD", opus: "Opus", flac: "FLAC", vorbis: "Vorbis" }
    label = names[LCase(codec)]
    if label = invalid then return UCase(codec)
    return label
end function

' Containers no Roku device plays, whatever codecs are inside.
function IsUnsupportedContainer(ext as String) as Boolean
    e = LCase(ext)
    for each bad in ["avi", "divx", "wmv", "asf", "flv", "rm", "rmvb"]
        if e = bad then return true
    end for
    return false
end function

' "TV" on a Roku TV, "Roku" on a streaming stick or box, for messages.
function DeviceWord() as String
    if m.deviceWord = invalid then
        m.deviceWord = "Roku"
        if CreateObject("roDeviceInfo").GetModelType() = "TV" then m.deviceWord = "TV"
    end if
    return m.deviceWord
end function

' Maps codec names to the names roDeviceInfo.CanDecodeVideo/Audio expects.
function RokuVideoCodec(videoCodec as String) as String
    c = LCase(videoCodec)
    if c = "h264" or c = "avc" then return "mpeg4 avc"
    if c = "h265" then return "hevc"
    if c = "mpeg2video" then return "mpeg2"
    if c = "mpeg4" then return "mpeg4 2"
    return c
end function

' Points `target` at the backdrop, or at a dimmed, zoomed poster when there is none, and
' returns the opacity it should end at. A new picture starts hidden so the screen can
' fade it in once it has loaded.
function ShowBackdrop(target as Object, backdrop as String, poster as String) as Float
    opacity = 1.0
    uri = ""
    if backdrop <> "" then
        uri = backdrop
    else if poster <> "" then
        uri = SizedImage(poster, "w342")
        opacity = 0.35
    end if
    if target.uri <> uri then
        target.opacity = 0.0
        target.uri = uri
    else
        target.opacity = opacity
    end if
    return opacity
end function

function MakeFont(name as String, size as Integer) as Object
    f = CreateObject("roSGNode", "Font")
    f.uri = "pkg:/fonts/" + name + ".ttf"
    f.size = size
    return f
end function

function NowSeconds() as Integer
    return CreateObject("roDateTime").AsSeconds()
end function

' The app's version from the manifest, like "0.1.1".
function AppVersion() as String
    info = CreateObject("roAppInfo")
    return info.GetVersion()
end function
