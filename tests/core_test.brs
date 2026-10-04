' Off-device checks for the parts that decide what plays: title IDs, copies, ranking,
' the resolver, the open-movies list, TMDB parsing, preferences and Continue Watching.
' Run with: npm test

sub Main()
    m.failures = 0
    m.count = 0
    ' No config.json in tests: the defaults, with English audio preferred.
    m.appConfig = ConfigWithDefaults({ languages: { audio: "en", subtitles: "off" } })

    testContentIds()
    testCopies()
    testConfig()
    testLanguages()
    testRanking()
    testResolver()
    testOpenMovies()
    testTmdb()
    testPrefs()
    testProgress()

    print ""
    if m.failures = 0 then
        print "ALL PASSED (" + m.count.ToStr() + " checks)"
    else
        print "FAILED: " + m.failures.ToStr() + " of " + m.count.ToStr() + " checks"
    end if
end sub

' --- Title IDs and deep links ------------------------------------------------------

sub testContentIds()
    movie = ParseContentId("tmdb:movie:10378")
    check("movie type", movie.type, "movie")
    check("movie id", movie.tmdbId, "10378")
    ep = ParseContentId("TMDB:TV:1399:S1E2")
    check("episode type", ep.type, "episode")
    checkInt("episode season", ep.season, 1)
    checkInt("episode number", ep.episode, 2)
    check("series type", ParseContentId(" tmdb:tv:1399 ").type, "series")
    check("not tmdb", boolText(ParseContentId("imdb:tt0944947") = invalid), "true")
    check("movie with episode", boolText(ParseContentId("tmdb:movie:1:s1e2") = invalid), "true")
    check("empty id", boolText(ParseContentId("") = invalid), "true")

    check("content id movie", ContentIdFor(MakeMedia({ type: "movie", tmdbId: 10378 })), "tmdb:movie:10378")
    check("content id episode", ContentIdFor(MakeMedia({ type: "episode", tmdbId: "1399", season: "1", episode: 2 })), "tmdb:tv:1399:s1e2")
    check("progress key movie", ProgressKeyFor("movie", "10378"), "tmdb:movie:10378")
    check("progress key series", ProgressKeyFor("series", "1399"), "tmdb:tv:1399")
    media = MakeMedia({ tmdbId: 7, runtimeSec: "600" })
    check("media defaults to movie", media.type, "movie")
    checkInt("media runtime from text", media.runtimeSec, 600)
end sub

' --- Copies --------------------------------------------------------------------

sub testCopies()
    check("format m3u8", FormatForUrl("https://a/b/master.m3u8?token=x"), "hls")
    check("format mpd", FormatForUrl("https://a/b.mpd"), "dash")
    check("format mov", FormatForUrl("https://a/b.MOV"), "mp4")
    check("format mkv", FormatForUrl("https://a/b.mkv"), "mkv")
    check("format avi", FormatForUrl("https://a/b.avi"), "avi")
    check("format unknown", FormatForUrl("https://a/stream"), "")

    copy = MakeCopy({ url: " https://a/b.m3u8 ", height: "720", transcoded: "false" })
    check("copy url trimmed", copy.url, "https://a/b.m3u8")
    check("copy format from url", copy.format, "hls")
    checkInt("copy height from text", copy.height, 720)
    check("copy transcoded text", boolText(copy.transcoded), "false")
    checkInt("copy audio default", copy.audio.Count(), 0)
    check("copy key", MakeCopy({ sourceId: "x", url: "u" }).url, "u")

    full = MakeCopy({ url: "u.mp4", height: 1080, audio: [{ language: "eng" }, { language: "en" }, { language: "spa" }], subtitles: [{ language: "eng" }], transcoded: true })
    check("summary", CopySummary(full), "MP4 · 1080p · English, Spanish · subtitles · converted on the fly")
end sub

sub testConfig()
    cfg = ConfigWithDefaults(invalid)
    checkInt("config budget default", cfg.tuning.resolveBudgetMs, 6000)
    checkInt("config bandwidth default", cfg.tuning.maxBandwidthKbps, 5000)
    check("config no tmdb", boolText(HasTmdb(cfg)), "false")
    cfg = ConfigWithDefaults({ tmdbToken: " abc ", languages: { audio: "EN" }, tuning: { stallSwitchMs: 5000, startWaitMs: 0 } })
    check("config token trimmed", cfg.tmdbToken, "abc")
    check("config has tmdb", boolText(HasTmdb(cfg)), "true")
    check("config audio lowercased", cfg.audioLanguage, "en")
    checkInt("config tuning given", cfg.tuning.stallSwitchMs, 5000)
    checkInt("config tuning zero keeps default", cfg.tuning.startWaitMs, 1500)
end sub

sub testLanguages()
    check("same en eng", boolText(SameLanguage("en", "eng")), "true")
    check("same case", boolText(SameLanguage("ENG", "en")), "true")
    check("different", boolText(SameLanguage("en", "spa")), "false")
    check("unknown never matches empty", boolText(SameLanguage("", "")), "false")
    options = [{ language: "spa" }, { language: "eng" }]
    checkInt("option by 2-letter code", LanguageOptionIndex(options, "en"), 1)
    checkInt("option missing", LanguageOptionIndex(options, "hi"), -1)
end sub

' --- Filter and rank ----------------------------------------------------------------

sub testRanking()
    media = MakeMedia({ type: "movie", tmdbId: "1", runtimeSec: 600 })
    noHevc = { hevc: false, vp9: false, av1: false }
    ' Small on purpose: the off-device interpreter turns 1800000000 + 60 into a Double
    ' and loses precision; a Roku keeps it an Integer.
    now = 1000000

    check("plays", CopyProblem(MakeCopy({ url: "a.m3u8", videoCodec: "h264" }), media, noHevc, now), "")
    check("avi blocked", CopyProblem(MakeCopy({ url: "a.avi" }), media, noHevc, now), "AVI files")
    check("hevc blocked", CopyProblem(MakeCopy({ url: "a.mkv", videoCodec: "hevc" }), media, noHevc, now), "HEVC (H.265) video")
    check("hevc ok when decodable", CopyProblem(MakeCopy({ url: "a.mkv", videoCodec: "hevc" }), media, { hevc: true }, now), "")
    check("expired", CopyProblem(MakeCopy({ url: "a.mp4", expiresAt: now - 1 }), media, noHevc, now), "an expired link")
    check("not yet expired", CopyProblem(MakeCopy({ url: "a.mp4", expiresAt: now + 60 }), media, noHevc, now), "")
    check("different cut", CopyProblem(MakeCopy({ url: "a.mp4", durationSec: 900 }), media, noHevc, now), "a different cut (15:00 long, TMDB says 10m)")

    ' TMDB rounds to the minute, so short films get 90 seconds of room.
    check("cut: Big Buck Bunny 10:35 vs 10m", boolText(SameCut(635, 600)), "true")
    check("cut: 92 seconds over", boolText(SameCut(692, 600)), "false")
    check("cut: 2h film, 5 min off", boolText(SameCut(7500, 7200)), "true")
    check("cut: 2h film, 7 min off", boolText(SameCut(7620, 7200)), "false")
    check("cut: unknown length", boolText(SameCut(0, 600)), "true")
    check("cut: unknown runtime", boolText(SameCut(900, 0)), "true")

    checkInt("res 720", ResolutionPoints(720), 20)
    checkInt("res 750 wide", ResolutionPoints(750), 20)
    checkInt("res 1080", ResolutionPoints(1080), 15)
    checkInt("res 480", ResolutionPoints(480), 8)
    checkInt("res unknown", ResolutionPoints(0), 5)
    checkInt("res 4k", ResolutionPoints(2160), 0)

    prefs = { audio: "en", subtitles: "es" }
    base = MakeCopy({ sourceId: "a", url: "x.m3u8", height: 720, audio: [{ language: "eng" }] })
    scored = CopyScore(base, prefs, {}, "")
    ' Unknown health 20 + 720p 20 + English audio 10 + direct file 5.
    checkInt("score base", scored.score, 55)
    check("score reasons", scored.why.Join(", "), "health 20, resolution 20, audio language 10, direct file 5")
    checkInt("score healthy source", CopyScore(base, prefs, { a: 1.0 }, "").score, 75)
    checkInt("score failing source", CopyScore(base, prefs, { a: 0.0 }, "").score, 35)
    checkInt("score watched there", CopyScore(base, prefs, {}, "a").score, 60)
    lan = MakeCopy({ sourceId: "j", network: "lan", url: "x.mp4", height: 1080, subtitles: [{ language: "spa" }], transcoded: true })
    ' 20 + 15 + home 15 + Spanish subtitles 5, no direct-file points.
    checkInt("score lan transcode", CopyScore(lan, prefs, {}, "").score, 55)
    checkInt("score subtitles off", CopyScore(lan, { subtitles: "off" }, {}, "").score, 50)

    copies = [
        MakeCopy({ sourceId: "b", label: "1080 only", url: "1.m3u8", height: 1080 })
        MakeCopy({ sourceId: "a", label: "avi", url: "2.avi" })
        MakeCopy({ sourceId: "a", label: "720 second", url: "3.m3u8", height: 720 })
        MakeCopy({ sourceId: "b", label: "720 tie", url: "4.m3u8", height: 720 })
        MakeCopy({ sourceId: "a", label: "720 first", url: "5.m3u8", height: 720 })
    ]
    ranked = RankCopies(copies, media, noHevc, {}, {}, "", ["a", "b"], now)
    checkInt("ranked playable", ranked.playable.Count(), 4)
    checkInt("ranked blocked", ranked.blocked.Count(), 1)
    check("blocked problem", ranked.blocked[0].problem, "AVI files")
    ' Equal scores: source priority (a before b), then the order the source gave them.
    check("rank 1", ranked.playable[0].label, "720 second")
    check("rank 2", ranked.playable[1].label, "720 first")
    check("rank 3", ranked.playable[2].label, "720 tie")
    check("rank 4", ranked.playable[3].label, "1080 only")
    ranked = RankCopies(copies, media, noHevc, {}, { b: 1.0 }, "", ["a", "b"], now)
    check("healthy source wins", ranked.playable[0].label, "720 tie")

    hls720 = MakeCopy({ url: "a.m3u8", height: 720 })
    checkInt("bandwidth cap on 720p TV", MaxBandwidthFor(hls720, 720, 5000), 5000)
    checkInt("no cap on 1080p TV", MaxBandwidthFor(hls720, 1080, 5000), 0)
    checkInt("no cap when only 1080p", MaxBandwidthFor(MakeCopy({ url: "a.m3u8", height: 1080 }), 720, 5000), 0)
    checkInt("no cap for mp4", MaxBandwidthFor(MakeCopy({ url: "a.mp4", height: 720 }), 720, 5000), 0)
end sub

' --- Resolver ------------------------------------------------------------------

sub testResolver()
    sources = [
        { info: fakeInfoA, start: fakeStartCopies, step: fakeStep, catalog: fakeStep }
        { info: fakeInfoB, start: fakeStartNothing, step: fakeStep, catalog: fakeStep }
        { info: fakeInfoC, start: fakeStartError, step: fakeStep, catalog: fakeStep }
        { info: fakeInfoD, start: fakeStartEmpty, step: fakeStep, catalog: fakeStep }
    ]
    found = ResolveAll(sources, MakeMedia({ type: "movie", tmdbId: "1" }), {}, 6000)
    checkInt("resolver copies", found.copies.Count(), 2)
    check("resolver copy order", found.copies[1].label, "two")
    checkInt("resolver reports", found.sources.Count(), 4)
    check("report ok", found.sources[0].outcome, "ok")
    checkInt("report found", found.sources[0].found, 2)
    check("report skipped", found.sources[1].outcome, "skipped")
    check("report error", found.sources[2].outcome, "error")
    check("report error detail", found.sources[2].detail, "server said no")
    check("report empty", found.sources[3].outcome, "empty")
    check("report name", found.sources[3].name, "Fake D")
end sub

function fakeInfoA() as Object
    return { id: "a", name: "Fake A", network: "lan", timeoutMs: 1000, hasCatalog: false }
end function

function fakeInfoB() as Object
    return { id: "b", name: "Fake B", network: "internet", timeoutMs: 1000, hasCatalog: false }
end function

function fakeInfoC() as Object
    return { id: "c", name: "Fake C", network: "internet", timeoutMs: 1000, hasCatalog: false }
end function

function fakeInfoD() as Object
    return { id: "d", name: "Fake D", network: "internet", timeoutMs: 1000, hasCatalog: false }
end function

function fakeStartCopies(media as Object, cfg as Object) as Dynamic
    return { copies: [MakeCopy({ sourceId: "a", label: "one", url: "1.m3u8" }), MakeCopy({ sourceId: "a", label: "two", url: "2.m3u8" })] }
end function

function fakeStartNothing(media as Object, cfg as Object) as Dynamic
    return invalid
end function

function fakeStartError(media as Object, cfg as Object) as Dynamic
    return { error: "server said no" }
end function

function fakeStartEmpty(media as Object, cfg as Object) as Dynamic
    return { copies: [] }
end function

function fakeStep(state as Dynamic, status as Integer, body as String, cfg as Object) as Object
    return { copies: [] }
end function

' --- Open movies --------------------------------------------------------------------

sub testOpenMovies()
    data = OpenMoviesData()
    titles = OpenMoviesTitles(data)
    checkInt("open movies titles", titles.Count(), 4)
    check("open movies first", titles[0].title, "Big Buck Bunny")
    check("open movies type", titles[0].type, "movie")

    ' Every copy in the list must be usable as written.
    seen = {}
    for each title in FieldArr(data, "titles")
        id = FieldStr(title, "tmdbId")
        check("unique id " + id, boolText(seen.DoesExist(id)), "false")
        seen[id] = true
        for each copy in OpenMoviesCopies(data, MakeMedia({ type: "movie", tmdbId: id }))
            name = FieldStr(title, "title") + " / " + copy.label
            check("https " + name, Left(copy.url, 8), "https://")
            check("known format " + name, boolText(copy.format = "hls" or copy.format = "mp4" or copy.format = "mkv"), "true")
            check("h264 " + name, copy.videoCodec, "h264")
            check("source id " + name, copy.sourceId, "openmovies")
            check("has length " + name, boolText(copy.durationSec > 0), "true")
            for each track in copy.subtitles
                check("subtitle language " + name, boolText(LanguageName(FieldStr(track, "language")) <> ""), "true")
            end for
        end for
    end for

    steel = OpenMoviesCopies(data, MakeMedia({ type: "movie", tmdbId: "133701" }))
    checkInt("tears of steel copies", steel.Count(), 3)
    check("sidecar subtitles", steel[1].subtitles[0].url, "https://download.blender.org/demo/movies/ToS/subtitles/TOS-en.srt")
    checkInt("not in list", OpenMoviesCopies(data, MakeMedia({ type: "movie", tmdbId: "999" })).Count(), 0)
    check("episodes skipped", boolText(OpenMovies_Start(MakeMedia({ type: "episode", tmdbId: "10378" }), {}) = invalid), "true")
    checkInt("local count movie", LocalCopyCount("movie", "45745"), 2)
    checkInt("local count none", LocalCopyCount("movie", "999"), 0)
    checkInt("local count series unknown", LocalCopyCount("series", "1399"), -1)

    ' The open movies, ranked for a 720p TV without HEVC, from TMDB's runtimes.
    ranked = RankCopies(steel, MakeMedia({ type: "movie", tmdbId: "133701", runtimeSec: 720 }), { hevc: false }, { audio: "en", subtitles: "off" }, {}, "", ["openmovies"], 1800000000)
    checkInt("steel all playable", ranked.playable.Count(), 3)
    check("steel best", ranked.playable[0].label, "Unified Streaming demo")
    check("steel 1080p last", ranked.playable[2].label, "Mux test stream (1080p)")
    bunny = OpenMoviesCopies(data, MakeMedia({ type: "movie", tmdbId: "10378" }))
    ranked = RankCopies(bunny, MakeMedia({ type: "movie", tmdbId: "10378", runtimeSec: 600 }), { hevc: false }, {}, {}, "", ["openmovies"], 1800000000)
    checkInt("bunny plays despite TMDB's 10m", ranked.playable.Count(), 1)
end sub

' --- TMDB ------------------------------------------------------------------------

sub testTmdb()
    cfg = ConfigWithDefaults({ tmdbToken: "tok" })
    check("url with token", TmdbUrl("/search/multi", { query: "tears of steel", include_adult: "false" }, cfg), "https://api.themoviedb.org/3/search/multi?include_adult=false&query=tears%20of%20steel")
    check("header with token", TmdbHeaders(cfg).Authorization, "Bearer tok")
    keyCfg = ConfigWithDefaults({ tmdbApiKey: "k1" })
    check("url with api key", TmdbUrl("/movie/1", {}, keyCfg), "https://api.themoviedb.org/3/movie/1?api_key=k1")
    check("no auth header with api key", boolText(TmdbHeaders(keyCfg).Authorization = invalid), "true")
    check("image", TmdbImage("/a.jpg", "w185"), "https://image.tmdb.org/t/p/w185/a.jpg")
    check("image missing", TmdbImage(invalid, "w185"), "")

    movie = ParseTmdbMovie(fixture("tmdb_movie.json"))
    check("movie title", movie.title, "Tears of Steel")
    check("movie id", movie.tmdbId, "133701")
    check("movie year", movie.year, "2012")
    check("movie imdb", movie.imdbId, "tt2285752")
    checkInt("movie runtime seconds", movie.durationSecs, 720)
    check("movie genres", movie.genre, "Science Fiction, Action, Animation")
    check("movie cast top three", movie.starring, "Derek de Lint, Sergio Hasselbaink, Rogier Schippers")
    check("movie director", movie.directedBy, "Ian Hubert")
    check("movie score", movie.score, "6.3")
    check("movie poster", movie.poster, "https://image.tmdb.org/t/p/w185/tears.jpg")
    check("movie backdrop", movie.backdrop, "https://image.tmdb.org/t/p/w780/steel.jpg")

    show = ParseTmdbShow(fixture("tmdb_show.json"))
    check("show title", show.title, "Example Show")
    check("show kind", show.kind, "series")
    check("show imdb", show.imdbId, "tt0944947")
    checkInt("show episode runtime", show.durationSecs, 3480)
    check("show score needs votes", show.score, "")
    check("show no backdrop", show.backdrop, "")
    checkInt("show seasons kept", show.seasons.Count(), 3)
    checkInt("show first season", show.seasons[0].number, 1)
    check("show unnamed season", show.seasons[1].name, "Season 2")
    check("show specials last", show.seasons[2].name, "Specials")

    episodes = ParseTmdbSeason(fixture("tmdb_season.json"))
    checkInt("season episodes", episodes.Count(), 2)
    checkInt("season sorted", episodes[0].episodeNo, 1)
    check("season untitled episode", episodes[0].title, "Episode 1")
    check("season no still", episodes[0].still, "")
    checkInt("season runtime", episodes[1].durationSecs, 3360)
    check("season still", episodes[1].still, "https://image.tmdb.org/t/p/w300/e2.jpg")

    found = ParseTmdbSearch(fixture("tmdb_search.json"))
    checkInt("search movies", found.movies.Count(), 1)
    checkInt("search series", found.series.Count(), 1)
    check("search movie", found.movies[0].title, "Tears of Steel")
    check("search series name", found.series[0].title, "Steel Show")
    check("search series no year", found.series[0].year, "")
    check("search series no poster", found.series[0].poster, "")
end sub

function fixture(name as String) as Dynamic
    return ParseJson(ReadAsciiFile("pkg:/fixtures/" + name))
end function

' --- Preferences ----------------------------------------------------------------------

sub testPrefs()
    prefs = LoadPrefs()
    check("prefs audio from config", prefs.audio, "en")
    check("prefs subtitles from config", prefs.subtitles, "off")
    SavePref("audio", "spa")
    check("prefs saved beats config", LoadPrefs().audio, "spa")

    check("no last source", LastSourceFor("tmdb:movie:1"), "")
    SaveLastSource("tmdb:movie:1", "openmovies")
    SaveLastSource("tmdb:movie:2", "jellyfin")
    SaveLastSource("tmdb:movie:1", "jellyfin")
    check("last source updated", LastSourceFor("tmdb:movie:1"), "jellyfin")
    check("last source other", LastSourceFor("tmdb:movie:2"), "jellyfin")
    for i = 3 to 50
        SaveLastSource("tmdb:movie:" + i.ToStr(), "openmovies")
    end for
    check("last sources capped", LastSourceFor("tmdb:movie:2"), "")
    check("newest kept", LastSourceFor("tmdb:movie:50"), "openmovies")
end sub

' --- Continue Watching ------------------------------------------------------------------

sub testProgress()
    ProgressPut({ k: ProgressKeyFor("movie", "10378"), kind: "movie", tmdb: "10378", name: "Big Buck Bunny", poster: "p", bd: "b", pos: 120, dur: 635, src: "openmovies" })
    ProgressPut({ k: ProgressKeyFor("series", "1399"), kind: "episode", tmdb: "1399", name: "Example Show", season: 1, episode: 2, etitle: "The Second", pos: 30, dur: 3000, src: "" })
    entry = ProgressFind("tmdb:movie:10378")
    checkInt("progress saved", ToInt(entry.pos), 120)
    row = ContinueWatchingRow()
    checkInt("row items", row.GetChildCount(), 2)
    newest = row.GetChild(0)
    check("row newest first", newest.title, "Example Show")
    check("row series kind", newest.kind, "series")
    check("row tmdb id", newest.tmdbId, "1399")
    check("row caption", newest.caption, "S1:E2")
    check("row movie", row.GetChild(1).kind, "movie")
    ProgressRemove("tmdb:movie:10378")
    check("progress removed", boolText(ProgressFind("tmdb:movie:10378") = invalid), "true")
    checkInt("removal remembered", ProgressRemovedList().Count(), 1)
end sub

' --- Helpers -------------------------------------------------------------------

function boolText(value as Boolean) as String
    if value then return "true"
    return "false"
end function

sub check(name as String, actual as String, expected as String)
    m.count = m.count + 1
    if actual <> expected then
        m.failures = m.failures + 1
        print "FAIL " + name + ": expected [" + expected + "] got [" + actual + "]"
    end if
end sub

sub checkInt(name as String, actual as Integer, expected as Integer)
    check(name, actual.ToStr(), expected.ToStr())
end sub
