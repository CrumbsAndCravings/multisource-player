' Titles are identified by TMDB ID, so the same movie found in several sources is one
' title. Two shapes travel between the screens, the resolver and the sources:
'
' Media, what the app asks for (MakeMedia):
'   type        "movie" or "episode"
'   tmdbId      TMDB ID of the movie, or of the series for an episode
'   imdbId      IMDb ID with the "tt" prefix, when TMDB has one
'   title       movie title, or series name for an episode
'   year        release year (first air year for a series)
'   season, episode   set for episodes, 0 for movies
'   episodeTitle      the episode's own title
'   runtimeSec  TMDB runtime, used to check that a copy is the same cut
'
' Copy, one playable file a source found (MakeCopy): see CopyDefaults.

function MakeMedia(values as Object) as Object
    media = { type: "movie", tmdbId: "", imdbId: "", title: "", year: "", season: 0, episode: 0, episodeTitle: "", runtimeSec: 0 }
    for each key in values
        media[key] = values[key]
    end for
    media.type = ToStr(media.type)
    media.tmdbId = ToStr(media.tmdbId)
    media.imdbId = ToStr(media.imdbId)
    media.title = ToStr(media.title)
    media.year = ToStr(media.year)
    media.season = ToInt(media.season)
    media.episode = ToInt(media.episode)
    media.episodeTitle = ToStr(media.episodeTitle)
    media.runtimeSec = ToInt(media.runtimeSec)
    return media
end function

' The Continue Watching key: one entry per movie, one per series (it moves along the
' episodes). "tmdb:movie:10378", "tmdb:tv:1399".
function ProgressKeyFor(kind as String, tmdbId as String) as String
    if kind = "movie" then return "tmdb:movie:" + tmdbId
    return "tmdb:tv:" + tmdbId
end function

' A deep link's contentId for a title: "tmdb:movie:10378", "tmdb:tv:1399" (a series) or
' "tmdb:tv:1399:s1e2" (an episode).
function ContentIdFor(media as Object) as String
    if media.type = "movie" then return "tmdb:movie:" + media.tmdbId
    if media.type = "episode" then return "tmdb:tv:" + media.tmdbId + ":s" + media.season.ToStr() + "e" + media.episode.ToStr()
    return "tmdb:tv:" + media.tmdbId
end function

' Reads a deep link's contentId (see ContentIdFor). Returns { type, tmdbId, season,
' episode } with type "movie", "series" or "episode", or invalid when it isn't one.
function ParseContentId(text as String) as Dynamic
    found = CreateObject("roRegex", "^tmdb:(movie|tv):(\d+)(?::s(\d+)e(\d+))?$", "i").Match(LCase(text.Trim()))
    if found.Count() < 3 then return invalid
    kind = found[1]
    result = { type: "movie", tmdbId: found[2], season: 0, episode: 0 }
    if kind = "tv" then
        result.type = "series"
        if found.Count() > 4 and found[3] <> "" then
            result.type = "episode"
            result.season = found[3].ToInt()
            result.episode = found[4].ToInt()
        end if
    else if found.Count() > 3 and found[3] <> "" then
        ' A movie has no episodes.
        return invalid
    end if
    return result
end function

' --- Copies --------------------------------------------------------------------

' Every field a copy has. headers only ever carry the login for your own server (a
' Jellyfin token, later); public files have none.
function CopyDefaults() as Object
    return {
        sourceId: ""
        sourceName: ""
        network: "internet"
        label: ""
        url: ""
        format: ""
        height: 0
        bitrateKbps: 0
        videoCodec: ""
        durationSec: 0
        audio: []
        subtitles: []
        headers: {}
        transcoded: false
        expiresAt: 0
    }
end function

function MakeCopy(values as Object) as Object
    copy = CopyDefaults()
    for each key in values
        copy[key] = values[key]
    end for
    copy.url = ToStr(copy.url).Trim()
    copy.format = LCase(ToStr(copy.format))
    if copy.format = "" then copy.format = FormatForUrl(copy.url)
    copy.height = ToInt(copy.height)
    copy.bitrateKbps = ToInt(copy.bitrateKbps)
    copy.videoCodec = LCase(ToStr(copy.videoCodec))
    copy.durationSec = ToInt(copy.durationSec)
    copy.expiresAt = ToInt(copy.expiresAt)
    copy.transcoded = ToBool(copy.transcoded)
    if not IsArr(copy.audio) then copy.audio = []
    if not IsArr(copy.subtitles) then copy.subtitles = []
    if not IsAA(copy.headers) then copy.headers = {}
    return copy
end function

function CopyKey(copy as Object) as String
    return copy.sourceId + "|" + copy.url
end function

' The stream format Roku's Video node expects, from a URL's extension.
function FormatForUrl(url as String) as String
    path = LCase(url)
    question = Instr(1, path, "?")
    if question > 0 then path = Left(path, question - 1)
    ext = ""
    dot = path.Split(".")
    if dot.Count() > 1 then ext = dot.Peek()
    if ext = "m3u8" then return "hls"
    if ext = "mpd" then return "dash"
    if ext = "mp4" or ext = "m4v" or ext = "mov" then return "mp4"
    if ext = "mkv" then return "mkv"
    if IsUnsupportedContainer(ext) then return ext
    return ""
end function

' "HLS · 720p · English, Spanish · subtitles", for the sources list.
function CopySummary(copy as Object) as String
    parts = []
    if copy.format <> "" then parts.Push(UCase(copy.format))
    if copy.height > 0 then parts.Push(copy.height.ToStr() + "p")
    languages = []
    for each track in copy.audio
        name = LanguageName(FieldStr(track, "language"))
        if name <> "" and not arrayHas(languages, name) then languages.Push(name)
    end for
    if languages.Count() > 0 then parts.Push(languages.Join(", "))
    if copy.subtitles.Count() > 0 then parts.Push("subtitles")
    if copy.transcoded then parts.Push("converted on the fly")
    return parts.Join(" · ")
end function

function arrayHas(list as Object, value as String) as Boolean
    for each entry in list
        if entry = value then return true
    end for
    return false
end function
