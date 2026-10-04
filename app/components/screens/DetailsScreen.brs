' Details for a movie or a series, from TMDB. A movie's copies are looked up as soon as
' its runtime is known (the resolver uses it to spot a different cut), and listed under
' the buttons: OK on one plays that copy instead of the best one.

sub init()
    m.backdrop = m.top.FindNode("backdrop")
    m.body = m.top.FindNode("body")
    m.dim = m.top.FindNode("dim")
    m.title = m.top.FindNode("title")
    m.meta = m.top.FindNode("meta")
    m.plot = m.top.FindNode("plot")
    m.credits = m.top.FindNode("credits")
    m.buttonsGroup = m.top.FindNode("buttons")
    m.status = m.top.FindNode("status")
    m.sourcesPanel = m.top.FindNode("sourcesPanel")
    m.sourceRows = m.top.FindNode("sourceRows")
    m.sourcesNote = m.top.FindNode("sourcesNote")
    m.panel = m.top.FindNode("episodesPanel")
    m.seasonsGroup = m.top.FindNode("seasons")
    m.episodes = m.top.FindNode("episodes")
    m.scroll = m.top.FindNode("scroll")
    m.scrollBody = m.top.FindNode("scrollBody")
    m.scrollDim = m.top.FindNode("scrollDim")
    m.keys = m.top.FindNode("keys")
    m.backdropIn = m.top.FindNode("backdropIn")
    m.backdropFade = m.top.FindNode("backdropFade")
    m.backdropTarget = 1.0
    m.backdrop.ObserveField("loadStatus", "onBackdropLoaded")

    m.title.font = MakeFont("Fredoka-SemiBold", 42)
    m.meta.font = MakeFont("Nunito-ExtraBold", 18)
    m.plot.font = "font:SmallSystemFont"
    m.credits.font = "font:SmallestSystemFont"
    m.status.font = MakeFont("Nunito-SemiBold", 19)
    m.top.FindNode("sourcesHeading").font = MakeFont("Nunito-ExtraBold", 15)
    m.sourcesNote.font = MakeFont("Nunito-SemiBold", 17)

    m.zone = "buttons"
    m.scrolled = false
    m.pills = []
    m.buttonActions = []
    m.buttonIndex = 0
    m.seasons = []
    m.seasonPills = []
    m.seasonIndex = 0
    m.seasonCache = {}
    m.pendingPlay = invalid
    m.entry = invalid
    m.tmdbTask = invalid
    m.resolveTask = invalid
    m.copies = []
    m.blocked = []
    m.reports = []
    m.resolved = false
    m.sourceCursor = 0

    m.episodes.ObserveField("itemSelected", "onEpisodeSelected")
end sub

sub onItem()
    item = m.top.item
    if item = invalid then return
    m.item = item
    m.kind = item.kind
    showInfo()
    if m.kind = "movie" then
        buildMovieButtons()
        if item.hasInfo then
            resolveMovie()
        else
            m.status.text = "Getting details…"
            runTmdb({ mode: "details", kind: "movie", tmdbId: item.tmdbId }, "onMovieInfo")
        end if
    else
        m.status.text = "Loading episodes…"
        runTmdb({ mode: "details", kind: "series", tmdbId: item.tmdbId }, "onShowInfo")
    end if
end sub

sub runTmdb(request as Object, callback as String)
    m.tmdbTask = CreateObject("roSGNode", "TmdbTask")
    m.tmdbTask.request = request
    m.tmdbTask.ObserveField("result", callback)
    m.tmdbTask.control = "RUN"
end sub

sub showInfo()
    item = m.item
    m.title.text = item.title
    m.meta.text = MetaLine(item)
    m.plot.text = item.description
    credits = []
    if item.starring <> "" then credits.Push("Starring " + item.starring)
    if item.directedBy <> "" then credits.Push("Directed by " + item.directedBy)
    m.credits.text = credits.Join("   ·   ")
    m.backdropIn.control = "stop"
    m.backdropTarget = ShowBackdrop(m.backdrop, item.backdrop, item.HDPosterUrl)
end sub

sub onBackdropLoaded()
    if m.backdrop.loadStatus <> "ready" then return
    m.backdropFade.keyValue = [0.0, m.backdropTarget]
    m.backdropIn.control = "start"
end sub

' --- Movies ------------------------------------------------------------------

sub onMovieInfo(event as Object)
    result = event.GetData()
    m.tmdbTask = invalid
    if result.ok then
        ApplyInfo(m.item, result.info)
        showInfo()
    end if
    ' Look for copies anyway: without TMDB the resolver just can't check the runtime.
    resolveMovie()
end sub

function movieMedia() as Object
    item = m.item
    return MakeMedia({ type: "movie", tmdbId: item.tmdbId, imdbId: item.imdbId, title: item.title, year: item.year, runtimeSec: item.durationSecs })
end function

function progressKey() as String
    return ProgressKeyFor(m.kind, m.item.tmdbId)
end function

sub resolveMovie()
    m.status.text = "Finding copies…"
    m.resolveTask = CreateObject("roSGNode", "ResolveTask")
    m.resolveTask.request = { media: movieMedia(), prefs: LoadPrefs(), lastSource: LastSourceFor(progressKey()) }
    m.resolveTask.ObserveField("result", "onResolved")
    m.resolveTask.control = "RUN"
end sub

sub onResolved(event as Object)
    result = event.GetData()
    m.resolveTask = invalid
    m.copies = result.copies
    m.blocked = result.blocked
    m.reports = result.sources
    m.resolved = true
    m.sourceCursor = 0
    renderSources()
    m.status.text = SourcesSummary(m.copies, m.blocked, m.reports)
end sub

' One line under the buttons: how many copies, and the one Play will use.
function SourcesSummary(copies as Object, blocked as Object, reports as Object) as String
    if copies.Count() = 0 then
        lines = []
        for each report in reports
            lines.Push(report.name + " " + outcomeWords(report))
        end for
        text = "No source has this title"
        if lines.Count() > 0 then text = text + " (" + lines.Join(", ") + ")"
        if blocked.Count() > 0 then text = text + ". " + blocked.Count().ToStr() + " found can't play on this " + DeviceWord()
        return text + "."
    end if
    sourceCount = 0
    for each report in reports
        if report.outcome = "ok" then sourceCount = sourceCount + 1
    end for
    copyWord = " copies"
    if copies.Count() = 1 then copyWord = " copy"
    sourceWord = " sources"
    if sourceCount = 1 then sourceWord = " source"
    best = copies[0]
    return copies.Count().ToStr() + copyWord + " from " + sourceCount.ToStr() + sourceWord + "   ·   Play uses " + best.sourceName + " · " + best.label + "   ·   Down to see them all"
end function

function outcomeWords(report as Object) as String
    outcome = FieldStr(report, "outcome")
    if outcome = "empty" then return "doesn't have it"
    if outcome = "skipped" then return "doesn't carry this kind of title"
    if outcome = "timeout" then return "didn't answer"
    if outcome = "error" then return "couldn't look"
    return "found " + ToInt(report.found).ToStr()
end function

' Every copy, best first, then the ones that can't play here. Two lines each; a window
' of six around the cursor.
sub renderSources()
    m.sourceRows.RemoveChildrenIndex(m.sourceRows.GetChildCount(), 0)
    rows = sourceEntries()
    m.sourcesPanel.visible = rows.Count() > 0 and m.kind = "movie"
    if rows.Count() = 0 then return
    visible = 6
    first = m.sourceCursor - (visible \ 2)
    if first > rows.Count() - visible then first = rows.Count() - visible
    if first < 0 then first = 0
    last = first + visible - 1
    if last > rows.Count() - 1 then last = rows.Count() - 1
    focused = (m.zone = "sources")
    y = 0
    for i = first to last
        entry = rows[i]
        row = m.sourceRows.CreateChild("Group")
        row.translation = [0, y]
        bg = row.CreateChild("Poster")
        bg.uri = "pkg:/images/pill.9.png"
        bg.width = 1184
        bg.height = 62
        name = row.CreateChild("Label")
        name.translation = [20, 6]
        name.width = 1140
        name.font = MakeFont("Nunito-ExtraBold", 19)
        name.text = entry.title
        detail = row.CreateChild("Label")
        detail.translation = [20, 34]
        detail.width = 1140
        detail.font = MakeFont("Nunito-SemiBold", 16)
        detail.text = entry.detail
        if focused and i = m.sourceCursor then
            bg.blendColor = "0xC9B8FFFF"
            bg.opacity = 1.0
            name.color = "0x151028FF"
            detail.color = "0x30275AFF"
        else
            bg.blendColor = "0x241C42FF"
            bg.opacity = 0.9
            name.color = "0xF7F3FFFF"
            detail.color = "0xA195CCFF"
            if entry.blocked then
                name.color = "0x8579B0FF"
                detail.color = "0xFFD98AFF"
            end if
        end if
        y = y + 70
    end for
    m.sourcesNote.text = "OK plays the copy you pick. Score: source health 0 to 40, resolution 0 to 20, home network 15, your languages 10 and 5, direct file 5, watched there before 5."
end sub

' [{ title, detail, blocked, copyIndex }] for the sources list.
function sourceEntries() as Object
    entries = []
    for i = 0 to m.copies.Count() - 1
        copy = m.copies[i]
        detail = CopySummary(copy)
        if detail <> "" then detail = detail + "   ·   "
        detail = detail + "score " + ToInt(copy.score).ToStr()
        entries.Push({ title: (i + 1).ToStr() + ".  " + copy.sourceName + " · " + copy.label, detail: detail, blocked: false, copyIndex: i })
    end for
    for each copy in m.blocked
        entries.Push({ title: copy.sourceName + " · " + copy.label, detail: "Won't play on this " + DeviceWord() + ": " + copy.problem, blocked: true, copyIndex: -1 })
    end for
    return entries
end function

sub buildMovieButtons()
    m.entry = ProgressFind(progressKey())
    if m.entry <> invalid and ToInt(m.entry.pos) > 0 then
        setButtons(["Resume from " + FormatClock(ToInt(m.entry.pos)), "Play from start", "Remove from Continue Watching"], ["resume", "restart", "forget"])
    else
        setButtons(["Play"], ["play"])
    end if
end sub

' Plays the best copy, or the one picked in the sources list (copyIndex).
sub playMovie(startAt as Integer, copyIndex as Integer)
    item = m.item
    playback = {
        kind: "movie"
        media: movieMedia()
        title: item.title
        poster: item.HDPosterUrl
        backdrop: item.backdrop
        startAt: startAt
    }
    if m.resolved and m.copies.Count() > 0 then
        playback.copies = m.copies
        playback.copyIndex = copyIndex
    end if
    m.top.action = { name: "play", playback: playback }
end sub

' --- Series ------------------------------------------------------------------

sub onShowInfo(event as Object)
    result = event.GetData()
    m.tmdbTask = invalid
    if not result.ok then
        m.status.text = result.error
        return
    end if
    ApplyInfo(m.item, result.info)
    showInfo()
    m.seasons = result.info.seasons
    if m.seasons.Count() = 0 then
        m.status.text = "TMDB doesn't list any episodes for this show."
        return
    end if
    m.status.text = ""
    names = []
    for each season in m.seasons
        names.Push(season.name)
    end for
    m.seasonPills = BuildPills(m.seasonsGroup, names, 18)
    m.panel.visible = true
    ' Open on the season Continue Watching is in.
    m.entry = ProgressFind(progressKey())
    start = 0
    if m.entry <> invalid then
        for i = 0 to m.seasons.Count() - 1
            if m.seasons[i].number = ToInt(m.entry.season) then start = i
        end for
    end if
    showSeason(start)
end sub

sub showSeason(index as Integer)
    if index < 0 or index >= m.seasons.Count() then return
    m.seasonIndex = index
    styleSeasons()
    number = m.seasons[index].number
    cached = m.seasonCache[number.ToStr()]
    if cached <> invalid then
        m.episodes.content = cached
        refreshSeriesProgress()
        return
    end if
    m.episodes.content = invalid
    m.status.text = "Loading " + m.seasons[index].name + "…"
    runTmdb({ mode: "season", tmdbId: m.item.tmdbId, season: number }, "onSeason")
end sub

sub onSeason(event as Object)
    result = event.GetData()
    content = event.GetRoSGNode().content
    m.tmdbTask = invalid
    number = ToInt(result.request.season)
    if not result.ok or content = invalid then
        m.status.text = FieldStr(result, "error")
        return
    end if
    m.status.text = ""
    m.seasonCache[number.ToStr()] = content
    if m.seasons[m.seasonIndex].number <> number then return
    m.episodes.content = content
    refreshSeriesProgress()
    if m.pendingPlay <> invalid then
        pending = m.pendingPlay
        m.pendingPlay = invalid
        playEpisodeNumber(pending.episode, pending.startAt)
    end if
end sub

' Re-reads Continue Watching and updates the buttons and episode progress bars.
sub refreshSeriesProgress()
    m.entry = ProgressFind(progressKey())
    content = m.episodes.content
    if content <> invalid then
        fraction = ProgressFraction(m.entry)
        for e = 0 to content.GetChildCount() - 1
            ep = content.GetChild(e)
            ep.progress = 0.0
            if m.entry <> invalid and ep.seasonNo = ToInt(m.entry.season) and ep.episodeNo = ToInt(m.entry.episode) then ep.progress = fraction
        end for
    end if
    if m.entry <> invalid then
        code = EpisodeCode(Field(m.entry, "season"), Field(m.entry, "episode"))
        ' After an episode finishes, the entry points at the next one with no progress yet.
        verb = "Play "
        if ToInt(m.entry.pos) > 0 then verb = "Resume "
        setButtons([verb + code, "Episodes", "Remove from Continue Watching"], ["resumeEpisode", "episodes", "forget"])
    else if content <> invalid and content.GetChildCount() > 0 then
        first = content.GetChild(0)
        setButtons(["Play " + EpisodeCode(first.seasonNo, first.episodeNo), "Episodes"], ["playFirst", "episodes"])
    else
        setButtons(["Episodes"], ["episodes"])
    end if
end sub

' Plays an episode of the season on screen, with the rest of the season queued after it.
sub playEpisode(index as Integer, startAt as Integer)
    content = m.episodes.content
    if content = invalid or index >= content.GetChildCount() then return
    queue = []
    for e = 0 to content.GetChildCount() - 1
        ep = content.GetChild(e)
        queue.Push({ season: ep.seasonNo, episode: ep.episodeNo, title: ep.title, code: EpisodeCode(ep.seasonNo, ep.episodeNo), runtimeSec: ep.durationSecs })
    end for
    current = queue[index]
    item = m.item
    m.top.action = {
        name: "play"
        playback: {
            kind: "episode"
            media: MakeMedia({ type: "episode", tmdbId: item.tmdbId, imdbId: item.imdbId, title: item.title, year: item.year, season: current.season, episode: current.episode })
            seriesName: item.title
            poster: item.HDPosterUrl
            backdrop: item.backdrop
            queue: queue
            index: index
            startAt: startAt
        }
    }
end sub

sub playEpisodeNumber(episode as Integer, startAt as Integer)
    content = m.episodes.content
    if content = invalid then return
    for e = 0 to content.GetChildCount() - 1
        if content.GetChild(e).episodeNo = episode then
            playEpisode(e, startAt)
            return
        end if
    end for
    playEpisode(0, 0)
end sub

sub onEpisodeSelected()
    content = m.episodes.content
    if content = invalid then return
    ep = content.GetChild(m.episodes.itemSelected)
    if ep = invalid then return
    startAt = 0
    if m.entry <> invalid and ep.seasonNo = ToInt(m.entry.season) and ep.episodeNo = ToInt(m.entry.episode) then startAt = ToInt(m.entry.pos)
    playEpisode(m.episodes.itemSelected, startAt)
end sub

' Resume goes to Continue Watching's episode, loading its season first if needed.
sub resumeEpisode()
    season = ToInt(m.entry.season)
    episode = ToInt(m.entry.episode)
    startAt = ToInt(m.entry.pos)
    if m.seasons[m.seasonIndex].number = season and m.episodes.content <> invalid then
        playEpisodeNumber(episode, startAt)
        return
    end if
    for i = 0 to m.seasons.Count() - 1
        if m.seasons[i].number = season then
            m.pendingPlay = { episode: episode, startAt: startAt }
            showSeason(i)
            if m.pendingPlay <> invalid and m.episodes.content <> invalid then
                m.pendingPlay = invalid
                playEpisodeNumber(episode, startAt)
            end if
            return
        end if
    end for
end sub

' --- Buttons -----------------------------------------------------------------

sub setButtons(labels as Object, actions as Object)
    m.pills = BuildPills(m.buttonsGroup, labels, 20)
    m.buttonActions = actions
    if m.buttonIndex >= labels.Count() then m.buttonIndex = 0
    styleButtons()
end sub

sub styleButtons()
    focus = -1
    if m.zone = "buttons" then focus = m.buttonIndex
    StylePills(m.pills, focus, -1)
end sub

sub styleSeasons()
    focus = -1
    if m.zone = "seasons" then focus = m.seasonIndex
    StylePills(m.seasonPills, focus, m.seasonIndex)
    ' Keep the chosen season on screen when there are more than fit.
    if m.seasonPills.Count() > 0 then
        pill = m.seasonPills[m.seasonIndex]
        position = pill.translation
        bg = pill.GetChild(0)
        right = position[0] + bg.width
        offset = 0
        if right > 1160 then offset = right - 1160
        m.seasonsGroup.translation = [-offset, 0]
    end if
end sub

sub activateButton()
    if m.buttonIndex >= m.buttonActions.Count() then return
    action = m.buttonActions[m.buttonIndex]
    if action = "play" or action = "restart" then
        playMovie(0, 0)
    else if action = "resume" then
        playMovie(ToInt(m.entry.pos), 0)
    else if action = "playFirst" then
        playEpisode(0, 0)
    else if action = "resumeEpisode" then
        resumeEpisode()
    else if action = "episodes" then
        if m.episodes.content <> invalid and m.episodes.content.GetChildCount() > 0 then enterZone("episodes")
    else if action = "forget" then
        forgetProgress()
    end if
end sub

' Takes this title off Continue Watching, and the buttons back to a plain Play.
sub forgetProgress()
    m.buttonIndex = 0
    ProgressRemove(progressKey())
    if m.kind = "movie" then
        buildMovieButtons()
    else
        refreshSeriesProgress()
    end if
    styleButtons()
end sub

' --- Focus -------------------------------------------------------------------

sub enterZone(zone as String)
    m.zone = zone
    if zone = "buttons" then
        setScrolled(false)
        m.keys.SetFocus(true)
    else if zone = "seasons" or zone = "sources" then
        setScrolled(true)
        m.keys.SetFocus(true)
    else if zone = "episodes" then
        setScrolled(true)
        m.episodes.SetFocus(true)
    end if
    styleButtons()
    styleSeasons()
    if m.kind = "movie" then renderSources()
end sub

sub setScrolled(scrolled as Boolean)
    if scrolled = m.scrolled then return
    m.scrolled = scrolled
    target = [0, 0]
    dimTo = 0.0
    if scrolled then
        target = [0, -392]
        dimTo = 0.6
    end if
    m.scrollBody.keyValue = [m.body.translation, target]
    m.scrollDim.keyValue = [m.dim.opacity, dimTo]
    m.scroll.control = "start"
end sub

sub onTakeFocus()
    if m.kind = "movie" then
        buildMovieButtons()
    else if m.seasons.Count() > 0 then
        refreshSeriesProgress()
    end if
    enterZone(m.zone)
end sub

function hasEpisodes() as Boolean
    return m.seasonPills.Count() > 0
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.zone = "sources" then return onSourceKey(key)

    if m.zone = "episodes" then
        ' Keys the episode list didn't use. Left and Right switch seasons without going
        ' back up to the season bar.
        if key = "left" or key = "right" then
            delta = 1
            if key = "left" then delta = -1
            target = m.seasonIndex + delta
            if target >= 0 and target < m.seasonPills.Count() then
                showSeason(target)
                m.episodes.jumpToItem = 0
            end if
            return true
        else if key = "up" then
            enterZone("seasons")
            return true
        else if key = "back" then
            enterZone("buttons")
            return true
        end if
        return key <> "back"
    end if

    if m.zone = "seasons" then
        if key = "left" and m.seasonIndex > 0 then
            showSeason(m.seasonIndex - 1)
        else if key = "right" and m.seasonIndex < m.seasonPills.Count() - 1 then
            showSeason(m.seasonIndex + 1)
        else if key = "down" or key = "OK" then
            if m.episodes.content <> invalid and m.episodes.content.GetChildCount() > 0 then enterZone("episodes")
        else if key = "up" or key = "back" then
            enterZone("buttons")
        end if
        return true
    end if

    ' Buttons
    if key = "left" and m.buttonIndex > 0 then
        m.buttonIndex = m.buttonIndex - 1
        styleButtons()
    else if key = "right" and m.buttonIndex < m.pills.Count() - 1 then
        m.buttonIndex = m.buttonIndex + 1
        styleButtons()
    else if key = "OK" then
        activateButton()
    else if key = "play" then
        m.buttonIndex = 0
        styleButtons()
        activateButton()
    else if key = "down" then
        if m.kind = "movie" and sourceEntries().Count() > 0 then
            enterZone("sources")
        else if hasEpisodes() then
            enterZone("seasons")
        end if
    else if key = "back" then
        return false
    end if
    return true
end function

function onSourceKey(key as String) as Boolean
    rows = sourceEntries()
    if key = "up" then
        if m.sourceCursor > 0 then
            m.sourceCursor = m.sourceCursor - 1
            renderSources()
        else
            enterZone("buttons")
        end if
    else if key = "down" then
        if m.sourceCursor < rows.Count() - 1 then
            m.sourceCursor = m.sourceCursor + 1
            renderSources()
        end if
    else if key = "OK" or key = "play" then
        if m.sourceCursor < rows.Count() and rows[m.sourceCursor].copyIndex >= 0 then
            startAt = 0
            if m.entry <> invalid then startAt = ToInt(m.entry.pos)
            playMovie(startAt, rows[m.sourceCursor].copyIndex)
        end if
    else if key = "back" then
        enterZone("buttons")
    end if
    return true
end function
