' Decides which copies can play on this device and in what order to try them. Pure, so
' tests cover every rule. The numbers are the plan doc's (Resolver, Filter and Rank).
'
' caps        what this device decodes: { hevc, vp9, av1 } (DeviceCaps on a Roku)
' prefs       { audio, subtitles }: language codes, subtitles may be "off"
' health      { <sourceId>: 0.0 to 1.0 }, the share of a source's recent plays that worked;
'             a source with no history yet gets the middle score
' lastSource  the source this title last played from, or ""
' order       source ids in priority order, for ties

' Why a copy can't play here, or "" when it can. `now` is Unix seconds.
function CopyProblem(copy as Object, media as Object, caps as Object, now as Integer) as String
    if IsUnsupportedContainer(copy.format) then return UCase(copy.format) + " files"
    codec = copy.videoCodec
    if (codec = "hevc" or codec = "h265") and not ToBool(Field(caps, "hevc")) then return "HEVC (H.265) video"
    if codec = "vp9" and not ToBool(Field(caps, "vp9")) then return "VP9 video"
    if codec = "av1" and not ToBool(Field(caps, "av1")) then return "AV1 video"
    if copy.expiresAt > 0 and copy.expiresAt <= now then return "an expired link"
    if not SameCut(copy.durationSec, media.runtimeSec) then return "a different cut (" + FormatClock(copy.durationSec) + " long, TMDB says " + FormatRuntime(media.runtimeSec) + ")"
    return ""
end function

' True when a copy's length fits the TMDB runtime: within 5%, or 90 seconds for short
' films, since TMDB rounds runtimes to the minute. Unknown lengths always fit.
function SameCut(copySec as Integer, runtimeSec as Integer) as Boolean
    if copySec <= 0 or runtimeSec <= 0 then return true
    allowed = runtimeSec * 0.05
    if allowed < 90 then allowed = 90
    return Abs(copySec - runtimeSec) <= allowed
end function

' Splits copies into { playable, blocked }. playable is best first, each copy with its
' score and the reasons for it; blocked copies carry their problem.
function RankCopies(copies as Object, media as Object, caps as Object, prefs as Object, health as Object, lastSource as String, order as Object, now as Integer) as Object
    playable = []
    blocked = []
    index = 0
    for each copy in copies
        problem = CopyProblem(copy, media, caps, now)
        if problem <> "" then
            copy.problem = problem
            blocked.Push(copy)
        else
            scored = CopyScore(copy, prefs, health, lastSource)
            copy.score = scored.score
            copy.why = scored.why
            priority = sourcePriority(order, copy.sourceId)
            ' Higher score first, then source priority, then the order sources listed them.
            copy.rankKey = (100 - scored.score) * 100000 + priority * 1000 + index
            playable.Push(copy)
        end if
        index = index + 1
    end for
    playable.SortBy("rankKey")
    return { playable: playable, blocked: blocked }
end function

' { score (out of 100), why: ["health 20", ...] } for one copy.
function CopyScore(copy as Object, prefs as Object, health as Object, lastSource as String) as Object
    why = []
    score = 0

    known = Field(health, copy.sourceId)
    points = 20
    if known <> invalid then points = Int(ToFloat(known) * 40 + 0.5)
    score = score + points
    why.Push("health " + points.ToStr())

    points = ResolutionPoints(copy.height)
    score = score + points
    why.Push("resolution " + points.ToStr())

    if copy.network = "lan" then
        score = score + 15
        why.Push("home network 15")
    end if

    audio = FieldStr(prefs, "audio")
    if audio <> "" and hasLanguage(copy.audio, audio) then
        score = score + 10
        why.Push("audio language 10")
    end if

    subtitles = FieldStr(prefs, "subtitles")
    if subtitles <> "" and subtitles <> "off" and hasLanguage(copy.subtitles, subtitles) then
        score = score + 5
        why.Push("subtitle language 5")
    end if

    if not copy.transcoded then
        score = score + 5
        why.Push("direct file 5")
    end if

    if lastSource <> "" and copy.sourceId = lastSource then
        score = score + 5
        why.Push("watched here before 5")
    end if
    return { score: score, why: why }
end function

' The TV is 720p: 720p gets the most, 1080p a little less (it uses more bandwidth for
' nothing), 480p less again, unknown 5, and 2160p nothing.
function ResolutionPoints(height as Integer) as Integer
    if height <= 0 then return 5
    if height >= 1800 then return 0
    if height >= 900 then return 15
    if height >= 650 then return 20
    if height >= 400 then return 8
    return 3
end function

function hasLanguage(tracks as Object, language as String) as Boolean
    for each track in tracks
        if SameLanguage(FieldStr(track, "language"), language) then return true
    end for
    return false
end function

function sourcePriority(order as Object, sourceId as String) as Integer
    for i = 0 to order.Count() - 1
        if order[i] = sourceId then return i
    end for
    return order.Count()
end function

' How much bandwidth the player may use for a copy, in kbps, or 0 for no limit. Only an
' HLS copy with a picture this screen can show in full gets the cap, so it skips
' variants bigger than the screen; a copy whose only variant is bigger plays as is.
function MaxBandwidthFor(copy as Object, screenLines as Integer, capKbps as Integer) as Integer
    if copy.format <> "hls" or screenLines <= 0 or screenLines > 720 then return 0
    if copy.height <= 0 or copy.height > 720 then return 0
    return capKbps
end function
