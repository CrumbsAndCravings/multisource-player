' Player with custom controls, from ARAN+.
'
' Before playing, it finds the title's copies (ResolveTask) unless the details page
' already did, then plays the best one. If that copy fails, the error screen offers the
' next one; switching on its own comes with the fallback controller in milestone 3.
'
' Controls hidden:  OK pauses and shows them; Up/Down shows them; Left/Right shows the
'                   bar and previews a seek. Play/Pause, rewind, fast-forward and instant
'                   replay work too. Back leaves.
' Controls shown:   three rows. Top: Back. Middle: play/pause with Left/Right seeking.
'                   Bottom: Audio & subtitles, Episodes, Next episode, Next copy, Restart.
'
' playback (set by the details page or a deep link):
'   kind          "movie" | "episode"
'   media         the movie's Media; for episodes the series' TMDB id is media.tmdbId
'   title, poster, backdrop   for the screen and Continue Watching
'   seriesName, queue, index  episodes: the season's episodes and which one to play
'   copies, copyIndex         copies already found and ranked (optional)
'   startAt       seconds, or -1 to resume from Continue Watching
'   needsDetails  true when only the TMDB id is known (a deep link)

sub init()
    m.video = m.top.FindNode("video")
    m.spinner = m.top.FindNode("spinner")
    m.findingLabel = m.top.FindNode("findingLabel")
    m.keys = m.top.FindNode("keys")

    m.controls = m.top.FindNode("controls")
    m.backBg = m.top.FindNode("backBg")
    m.backLabel = m.top.FindNode("backLabel")
    m.titleLabel = m.top.FindNode("titleLabel")
    m.sourceLabel = m.top.FindNode("sourceLabel")
    m.playBg = m.top.FindNode("playBg")
    m.playIcon = m.top.FindNode("playIcon")
    m.elapsed = m.top.FindNode("elapsed")
    m.remaining = m.top.FindNode("remaining")
    m.barFill = m.top.FindNode("barFill")
    m.barPreview = m.top.FindNode("barPreview")
    m.knob = m.top.FindNode("knob")
    m.bubble = m.top.FindNode("bubble")
    m.bubbleLabel = m.top.FindNode("bubbleLabel")
    m.buttonRow = m.top.FindNode("buttonRow")

    m.upNext = m.top.FindNode("upNext")
    m.upNextTitle = m.top.FindNode("upNextTitle")
    m.upNextHint = m.top.FindNode("upNextHint")
    m.errorBox = m.top.FindNode("errorBox")
    m.errorDetail = m.top.FindNode("errorDetail")
    m.errorTitle = m.top.FindNode("errorTitle")
    m.errorHint = m.top.FindNode("errorHint")
    m.tracks = m.top.FindNode("tracks")
    m.audioList = m.top.FindNode("audioList")
    m.subsList = m.top.FindNode("subsList")
    m.tracksNote = m.top.FindNode("tracksNote")
    m.episodes = m.top.FindNode("episodes")
    m.episodeList = m.top.FindNode("episodeList")

    m.countdown = m.top.FindNode("countdown")
    m.hideTimer = m.top.FindNode("hideTimer")
    m.holdTimer = m.top.FindNode("holdTimer")
    m.commitTimer = m.top.FindNode("commitTimer")

    m.backLabel.font = MakeFont("Fredoka-Medium", 18)
    m.titleLabel.font = MakeFont("Fredoka-Medium", 22)
    m.sourceLabel.font = MakeFont("Nunito-SemiBold", 16)
    m.findingLabel.font = MakeFont("Nunito-SemiBold", 20)
    m.elapsed.font = MakeFont("Nunito-ExtraBold", 17)
    m.remaining.font = MakeFont("Nunito-ExtraBold", 17)
    m.bubbleLabel.font = MakeFont("Fredoka-SemiBold", 17)
    m.top.FindNode("upNextEyebrow").font = MakeFont("Nunito-ExtraBold", 14)
    m.upNextTitle.font = MakeFont("Fredoka-Medium", 22)
    m.upNextHint.font = MakeFont("Nunito-SemiBold", 17)
    m.errorTitle.font = MakeFont("Fredoka-SemiBold", 28)
    m.errorDetail.font = MakeFont("Nunito-SemiBold", 18)
    m.errorHint.font = MakeFont("Nunito-ExtraBold", 18)
    m.top.FindNode("tracksTitle").font = MakeFont("Fredoka-SemiBold", 34)
    m.top.FindNode("audioHeading").font = MakeFont("Nunito-ExtraBold", 15)
    m.top.FindNode("subsHeading").font = MakeFont("Nunito-ExtraBold", 15)
    m.tracksNote.font = MakeFont("Nunito-SemiBold", 18)
    m.top.FindNode("episodesTitle").font = MakeFont("Fredoka-SemiBold", 34)
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.spinner.poster.blendColor = "0xC9B8FFFF"
    m.spinner.poster.width = 64
    m.spinner.poster.height = 64

    m.video.notificationInterval = 1
    m.video.ObserveField("state", "onState")
    m.video.ObserveField("position", "onPosition")
    m.video.ObserveField("availableAudioTracks", "onTracksChanged")
    m.video.ObserveField("availableSubtitleTracks", "onTracksChanged")
    m.countdown.ObserveField("fire", "onCountdown")
    m.hideTimer.ObserveField("fire", "onHideTimer")
    m.holdTimer.ObserveField("fire", "onHoldTick")
    m.commitTimer.ObserveField("fire", "commitSeek")
    m.toast = m.top.FindNode("toast")
    m.toastText = m.top.FindNode("toastText")
    m.toastText.font = MakeFont("Nunito-SemiBold", 18)
    m.toastTimer = m.top.FindNode("toastTimer")
    m.toastTimer.ObserveField("fire", "hideToast")

    m.cfg = LoadConfig()
    m.playback = invalid
    m.kind = "movie"
    m.index = 0
    m.startAt = 0
    m.lastSaved = 0
    m.closing = false
    m.secondsLeft = 0
    m.attempt = 0
    m.started = false
    m.failed = false
    m.errors = []
    m.copies = []
    m.blocked = []
    m.sourceReports = []
    m.copyIndex = 0
    m.resolveTask = invalid
    m.tmdbTask = invalid
    m.errorAction = ""
    m.syncClock = invalid

    m.row = "bar"
    m.buttons = []
    m.buttonPills = []
    m.buttonIndex = 0
    m.seeking = false
    m.seekTarget = 0.0
    m.holdKey = ""
    m.holdDirection = 1
    m.holdClock = CreateObject("roTimespan")
    m.introShown = false

    m.panel = ""
    m.audioOptions = []
    m.subOptions = []
    m.trackColumn = 1
    m.audioCursor = 0
    m.subCursor = 0
    m.episodeCursor = 0
    m.audioPrefDone = false
    m.audioChecked = false
    m.subPrefDone = false
end sub

sub onPlayback()
    m.global.playing = true
    m.playback = m.top.playback
    m.kind = m.playback.kind
    m.index = ToInt(m.playback.index)
    if not IsArr(m.playback.queue) then m.playback.queue = []
    if ToBool(Field(m.playback, "needsDetails")) then
        fetchDetails()
    else
        startItem(ToInt(m.playback.startAt), true)
    end if
end sub

sub onTakeFocus()
    m.keys.SetFocus(true)
end sub

' The Media for what's playing now: the movie, or the current episode in the queue.
function currentMedia() as Object
    p = m.playback
    if m.kind = "movie" then return MakeMedia(p.media)
    values = { type: "episode", tmdbId: p.media.tmdbId, imdbId: FieldStr(p.media, "imdbId"), title: FieldStr(p, "seriesName") }
    if m.index < p.queue.Count() then
        ep = p.queue[m.index]
        values.season = ep.season
        values.episode = ep.episode
        values.episodeTitle = ep.title
        values.runtimeSec = ToInt(ep.runtimeSec)
    else
        values.season = p.media.season
        values.episode = p.media.episode
    end if
    return MakeMedia(values)
end function

function progressKey() as String
    if m.kind = "movie" then return ProgressKeyFor("movie", m.playback.media.tmdbId)
    return ProgressKeyFor("series", m.playback.media.tmdbId)
end function

function hasNextEpisode() as Boolean
    return m.kind = "episode" and m.index + 1 < m.playback.queue.Count()
end function

function currentCopy() as Dynamic
    if m.copyIndex < m.copies.Count() then return m.copies[m.copyIndex]
    return invalid
end function

' --- Details for deep links --------------------------------------------------------

' A deep link carries only the TMDB id, so get the title (and for an episode, its
' season's episode list) before playing. Without TMDB it plays with what it has.
sub fetchDetails()
    showFinding("Getting details…")
    kind = "movie"
    if m.kind = "episode" then kind = "series"
    runTmdb({ mode: "details", kind: kind, tmdbId: m.playback.media.tmdbId }, "onDetails")
end sub

sub runTmdb(request as Object, callback as String)
    if m.tmdbTask <> invalid then m.tmdbTask.UnobserveField("result")
    m.tmdbTask = CreateObject("roSGNode", "TmdbTask")
    m.tmdbTask.request = request
    m.tmdbTask.ObserveField("result", callback)
    m.tmdbTask.control = "RUN"
end sub

sub onDetails(event as Object)
    result = event.GetData()
    if m.closing then return
    p = m.playback
    media = p.media
    if result.ok then
        info = result.info
        p.poster = info.poster
        p.backdrop = info.backdrop
        media.imdbId = info.imdbId
        media.year = info.year
        if m.kind = "movie" then
            p.title = info.title
            media.title = info.title
            media.runtimeSec = info.durationSecs
        else
            p.seriesName = info.title
        end if
    end if
    p.media = media
    m.playback = p
    if m.kind = "episode" and result.ok then
        runTmdb({ mode: "season", tmdbId: media.tmdbId, season: media.season }, "onSeason")
        return
    end if
    m.playback.needsDetails = false
    startItem(ToInt(p.startAt), true)
end sub

sub onSeason(event as Object)
    result = event.GetData()
    content = event.GetRoSGNode().content
    if m.closing then return
    p = m.playback
    queue = []
    index = 0
    if result.ok and content <> invalid then
        for i = 0 to content.GetChildCount() - 1
            ep = content.GetChild(i)
            if ep.episodeNo = p.media.episode then index = queue.Count()
            queue.Push(EpisodeEntry(ep))
        end for
    end if
    p.queue = queue
    p.needsDetails = false
    m.playback = p
    m.index = index
    startItem(ToInt(p.startAt), true)
end sub

' A queue entry for an episode node from TmdbTask's season mode.
function EpisodeEntry(ep as Object) as Object
    return { season: ep.seasonNo, episode: ep.episodeNo, title: ep.title, code: EpisodeCode(ep.seasonNo, ep.episodeNo), runtimeSec: ep.durationSecs }
end function

' --- Starting an item ----------------------------------------------------------------

' startAt -1 resumes from Continue Watching. useGiven plays the copies the details page
' already found, for the item it opened with.
sub startItem(startAt as Integer, useGiven as Boolean)
    if startAt < 0 then startAt = savedPosition()
    m.startAt = startAt
    m.attempt = 0
    m.started = false
    m.failed = false
    m.errors = []
    m.introShown = false
    m.audioPrefDone = false
    m.audioChecked = false
    m.subPrefDone = false
    cancelSeek()
    closePanel(false)
    hideControls()
    m.upNext.visible = false
    m.errorBox.visible = false
    m.sourceLabel.text = ""

    media = currentMedia()
    if m.kind = "movie" then
        title = FirstText([m.playback.title, media.title])
        if title = "" then title = "Movie " + media.tmdbId
        m.titleLabel.text = title
    else
        name = FirstText([m.playback.seriesName, "Series " + media.tmdbId])
        m.titleLabel.text = name + "   ·   " + EpisodeCode(media.season, media.episode) + "  " + media.episodeTitle
    end if

    given = m.playback.copies
    if useGiven and IsArr(given) and given.Count() > 0 then
        m.copies = given
        m.blocked = []
        m.copyIndex = ToInt(m.playback.copyIndex)
        if m.copyIndex >= m.copies.Count() then m.copyIndex = 0
        playCopy()
        return
    end if
    resolveItem()
end sub

' Where Continue Watching says this movie or episode stopped, or 0.
function savedPosition() as Integer
    entry = ProgressFind(progressKey())
    if entry = invalid then return 0
    if m.kind = "episode" then
        media = currentMedia()
        if ToInt(entry.season) <> media.season or ToInt(entry.episode) <> media.episode then return 0
    end if
    return ToInt(entry.pos)
end function

sub showFinding(text as String)
    m.video.visible = false
    m.findingLabel.text = text
    m.findingLabel.visible = true
    m.spinner.visible = true
    m.spinner.control = "start"
    m.keys.SetFocus(true)
end sub

sub resolveItem()
    showFinding("Finding a copy…")
    if m.resolveTask <> invalid then m.resolveTask.UnobserveField("result")
    m.resolveTask = CreateObject("roSGNode", "ResolveTask")
    m.resolveTask.request = { media: currentMedia(), prefs: LoadPrefs(), lastSource: LastSourceFor(progressKey()) }
    m.resolveTask.ObserveField("result", "onResolved")
    m.resolveTask.control = "RUN"
end sub

sub onResolved(event as Object)
    result = event.GetData()
    m.resolveTask = invalid
    if m.closing then return
    ' Moved on to another episode while this one was being looked up.
    if ContentIdFor(MakeMedia(result.request.media)) <> ContentIdFor(currentMedia()) then return
    m.copies = result.copies
    m.blocked = result.blocked
    m.sourceReports = result.sources
    m.copyIndex = 0
    if m.copies.Count() = 0 then
        showNoCopies()
        return
    end if
    playCopy()
end sub

sub playCopy()
    m.attempt = 0
    m.failed = false
    m.errors = []
    m.errorBox.visible = false
    buildButtons()
    loadStream()
end sub

' Attempt 0 tells Roku the copy's format. Attempt 1 leaves it out and lets Roku work it
' out from the stream itself, in case the source got it wrong.
sub loadStream()
    copy = currentCopy()
    if copy = invalid then return
    content = CreateObject("roSGNode", "ContentNode")
    content.url = copy.url
    content.title = m.titleLabel.text
    if m.attempt = 0 and copy.format <> "" then content.streamFormat = copy.format
    headers = []
    for each name in copy.headers
        headers.Push(name + ": " + ToStr(copy.headers[name]))
    end for
    if headers.Count() > 0 then content.HttpHeaders = headers
    ' Sidecar subtitle files; subtitles inside the stream show up by themselves.
    tracks = []
    for each track in copy.subtitles
        if FieldStr(track, "url") <> "" then tracks.Push({ Language: FieldStr(track, "language"), TrackName: FieldStr(track, "url"), Description: FieldStr(track, "label") })
    end for
    if tracks.Count() > 0 then content.subtitleTracks = tracks
    maxKbps = MaxBandwidthFor(copy, ScreenHeight(), m.cfg.tuning.maxBandwidthKbps)
    if maxKbps > 0 then content.MaxBandwidth = maxKbps
    ' Back up a few seconds so the scene picks up where it left off.
    if m.startAt > 10 then content.playStart = m.startAt - 5

    m.sourceLabel.text = copyLine(copy)
    m.lastSaved = m.startAt
    m.findingLabel.visible = false
    m.video.visible = true
    m.video.content = content
    m.video.control = "play"
    m.spinner.visible = true
    m.spinner.control = "start"
    m.keys.SetFocus(true)
end sub

' "Open movies · Mux test stream · HLS · 720p · English   ·   copy 1 of 3"
function copyLine(copy as Object) as String
    text = copy.sourceName + " · " + copy.label
    summary = CopySummary(copy)
    if summary <> "" then text = text + " · " + summary
    if m.copies.Count() > 1 then text = text + "   ·   copy " + (m.copyIndex + 1).ToStr() + " of " + m.copies.Count().ToStr()
    return text
end function

' --- Progress ----------------------------------------------------------------

sub onPosition()
    if m.closing or not m.started then return
    position = Int(m.video.position)
    if Abs(position - m.lastSaved) >= 15 then saveProgress()
    if m.controls.visible then renderBar()
end sub

sub saveProgress()
    if m.playback = invalid or not m.started or m.failed then return
    position = Int(m.video.position)
    duration = Int(m.video.duration)
    if position < 10 then return
    m.lastSaved = position
    if duration > 0 and position >= duration * 0.95 then
        markFinished()
        return
    end if
    ProgressPut(entryFor(m.index, position, duration))
end sub

function entryFor(index as Integer, position as Integer, duration as Integer) as Object
    p = m.playback
    src = ""
    copy = currentCopy()
    if copy <> invalid and index = m.index then src = copy.sourceId
    entry = {
        k: progressKey()
        tmdb: p.media.tmdbId
        poster: FieldStr(p, "poster")
        bd: FieldStr(p, "backdrop")
        pos: position
        dur: duration
        src: src
    }
    if m.kind = "movie" then
        entry.kind = "movie"
        entry.name = FirstText([p.title, p.media.title])
        return entry
    end if
    entry.kind = "episode"
    entry.name = FieldStr(p, "seriesName")
    if index < p.queue.Count() then
        ep = p.queue[index]
        entry.season = ep.season
        entry.episode = ep.episode
        entry.etitle = ep.title
    else
        entry.season = p.media.season
        entry.episode = p.media.episode
        entry.etitle = ""
    end if
    return entry
end function

' Movies drop out of Continue Watching; series move on to the next episode.
sub markFinished()
    if m.kind = "movie" then
        ProgressRemove(progressKey())
    else if hasNextEpisode() then
        ProgressPut(entryFor(m.index + 1, 0, 0))
    else
        ProgressRemove(progressKey())
    end if
end sub

' --- Playback state ------------------------------------------------------------

sub onState()
    if m.closing then return
    state = m.video.state
    m.spinner.visible = (state = "buffering")
    if state = "buffering" then
        m.spinner.control = "start"
    else
        m.spinner.control = "stop"
    end if
    renderPlayButton()

    if state = "playing" then
        if not m.started then
            copy = currentCopy()
            if copy <> invalid then SaveLastSource(progressKey(), copy.sourceId)
        end if
        m.started = true
        onTracksChanged()
        if not m.audioChecked then
            m.audioChecked = true
            checkAudioPlayable()
        end if
        ' Show the controls briefly the first time, so the buttons are discoverable.
        if not m.introShown then
            m.introShown = true
            showControls("bar")
        else if m.controls.visible then
            restartHideTimer()
        end if
    else if state = "paused" then
        saveProgress()
        if not m.controls.visible then showControls("bar")
        m.hideTimer.control = "stop"
    else if state = "error" then
        onPlaybackError()
    else if state = "finished" then
        ' Roku can report "finished" right after an error. Only a stream that actually
        ' played counts as watched.
        if m.failed or not m.started then return
        markFinished()
        if hasNextEpisode() then
            showUpNext()
        else
            close()
        end if
    end if
end sub

sub onPlaybackError()
    m.errors.Push(describeRokuError())
    if m.started then m.startAt = Int(m.video.position)
    m.started = false
    if m.attempt = 0 then
        m.attempt = 1
        loadStream()
        return
    end if
    showPlaybackError()
end sub

sub showPlaybackError()
    m.failed = true
    m.countdown.control = "stop"
    m.upNext.visible = false
    m.video.control = "stop"
    m.video.visible = false
    m.spinner.visible = false
    m.findingLabel.visible = false
    hideControls()
    closePanel(false)
    m.errorTitle.text = "This copy didn't play"
    m.errorDetail.text = diagnosis()
    if m.copies.Count() > 1 then
        m.errorAction = "nextCopy"
        m.errorHint.text = "OK to try the next copy   ·   Back to return"
    else
        m.errorAction = "retry"
        m.errorHint.text = "OK to try again   ·   Back to return"
    end if
    m.errorBox.visible = true
end sub

' Nothing to play: says what each source answered and which copies can't play here.
sub showNoCopies()
    m.failed = true
    m.video.visible = false
    m.spinner.visible = false
    m.findingLabel.visible = false
    lines = []
    for each report in m.sourceReports
        lines.Push(report.name + ": " + SourceOutcomeText(report))
    end for
    for each copy in m.blocked
        lines.Push("Found but can't play on this " + DeviceWord() + ": " + copy.sourceName + " · " + copy.label + " (" + copy.problem + ").")
    end for
    if lines.Count() = 0 then lines.Push("No sources are turned on.")
    m.errorTitle.text = "No source has this title"
    m.errorDetail.text = lines.Join(Chr(10))
    m.errorAction = "resolve"
    m.errorHint.text = "OK to look again   ·   Back to return"
    m.errorBox.visible = true
end sub

' One source's answer in words, for the error and details screens.
function SourceOutcomeText(report as Object) as String
    outcome = FieldStr(report, "outcome")
    if outcome = "ok" then
        count = ToInt(report.found)
        if count = 1 then return "1 copy."
        return count.ToStr() + " copies."
    end if
    if outcome = "empty" then return "doesn't have it."
    if outcome = "skipped" then return "doesn't carry this kind of title."
    if outcome = "timeout" then return "didn't answer in time."
    return "couldn't look (" + FieldStr(report, "detail") + ")."
end function

function describeRokuError() as String
    text = m.video.errorMsg
    if text = "" then text = "unknown error"
    text = text + " (code " + ToStr(m.video.errorCode) + ")"
    detail = ""
    info = m.video.errorInfo
    if IsAA(info) then detail = FieldStr(info, "dbgmsg")
    if detail = "" then detail = ToStr(m.video.errorStr)
    if detail <> "" and detail <> m.video.errorMsg then
        if Len(detail) > 110 then detail = Left(detail, 110) + "…"
        text = text + ": " + detail
    end if
    return text
end function

' What went wrong and which copy it was.
function diagnosis() as String
    copy = currentCopy()
    lines = []
    lines.Push("Roku says: " + m.errors.Peek())
    if m.errors.Count() > 1 then lines.Push("Tried twice: with the copy's format, then letting Roku work it out.")
    detected = []
    if ToStr(m.video.videoFormat) <> "" then detected.Push("video " + m.video.videoFormat)
    if ToStr(m.video.audioFormat) <> "" then detected.Push("audio " + m.video.audioFormat)
    if detected.Count() > 0 then lines.Push("Roku detected: " + detected.Join(", "))
    if copy <> invalid then
        lines.Push("Copy: " + copyLine(copy))
        lines.Push("Address: " + copy.url)
    end if
    return lines.Join(Chr(10))
end function

sub onErrorOk()
    if m.errorAction = "resolve" then
        resolveItem()
        m.errorBox.visible = false
    else if m.errorAction = "nextCopy" then
        switchCopy(m.copyIndex + 1)
    else
        playCopy()
    end if
end sub

' Plays another copy from the same spot (the start, if this one never played).
sub switchCopy(index as Integer)
    if m.copies.Count() = 0 then return
    if m.started then
        saveProgress()
        m.startAt = Int(m.video.position)
    end if
    m.copyIndex = index MOD m.copies.Count()
    m.started = false
    m.video.control = "stop"
    m.audioPrefDone = false
    m.audioChecked = false
    m.subPrefDone = false
    playCopy()
    showToast("Playing copy " + (m.copyIndex + 1).ToStr() + " of " + m.copies.Count().ToStr() + ": " + currentCopy().sourceName + " · " + currentCopy().label)
end sub

' --- Controls ------------------------------------------------------------------

sub buildButtons()
    m.buttons = [{ label: "Audio & subtitles", action: "tracks" }]
    if m.kind = "episode" then
        m.buttons.Push({ label: "Episodes", action: "episodes" })
        if hasNextEpisode() then m.buttons.Push({ label: "Next episode", action: "next" })
    end if
    if m.copies.Count() > 1 then m.buttons.Push({ label: "Next copy", action: "nextCopy" })
    m.buttons.Push({ label: "Restart", action: "restart" })
    labels = []
    for each button in m.buttons
        labels.Push(button.label)
    end for
    m.buttonPills = BuildPills(m.buttonRow, labels, 17)
    m.buttonIndex = 0
end sub

sub showControls(row as String)
    m.controls.visible = true
    m.row = row
    renderControls()
    restartHideTimer()
end sub

sub hideControls()
    m.controls.visible = false
    m.hideTimer.control = "stop"
end sub

sub restartHideTimer()
    m.hideTimer.control = "stop"
    if m.video.state <> "paused" then m.hideTimer.control = "start"
end sub

sub onHideTimer()
    if m.seeking or m.panel <> "" or m.video.state = "paused" then return
    hideControls()
end sub

sub renderControls()
    if m.row = "top" then
        m.backBg.blendColor = "0xC9B8FFFF"
        m.backBg.opacity = 1.0
        m.backLabel.color = "0x151028FF"
    else
        m.backBg.blendColor = "0x151028FF"
        m.backBg.opacity = 0.6
        m.backLabel.color = "0xF7F3FFFF"
    end if
    buttonFocus = -1
    if m.row = "buttons" then buttonFocus = m.buttonIndex
    StylePills(m.buttonPills, buttonFocus, -1)
    renderPlayButton()
    renderBar()
end sub

sub renderPlayButton()
    if m.video.state = "paused" then
        m.playIcon.uri = "pkg:/images/icon_play.png"
    else
        m.playIcon.uri = "pkg:/images/icon_pause.png"
    end if
    if m.row = "bar" then
        m.playBg.blendColor = "0xC9B8FFFF"
        m.playBg.opacity = 1.0
        m.playIcon.blendColor = "0x151028FF"
    else
        m.playBg.blendColor = "0xF7F3FFFF"
        m.playBg.opacity = 0.2
        m.playIcon.blendColor = "0xF7F3FFFF"
    end if
end sub

sub renderBar()
    barX = 228
    barWidth = 896
    duration = m.video.duration
    position = m.video.position
    shown = position
    if m.seeking then shown = m.seekTarget

    m.elapsed.text = FormatClock(Int(shown))
    if duration > 0 then
        timeLeft = duration - shown
        if timeLeft < 0 then timeLeft = 0
        m.remaining.text = "-" + FormatClock(Int(timeLeft))
    else
        m.remaining.text = ""
    end if

    playedFraction = BarFraction(position, duration)
    shownFraction = BarFraction(shown, duration)
    m.barFill.width = barWidth * playedFraction
    if m.seeking and duration > 0 then
        low = playedFraction
        high = shownFraction
        if high < low then
            low = shownFraction
            high = playedFraction
        end if
        m.barPreview.translation = [barX + barWidth * low, 584]
        m.barPreview.width = barWidth * (high - low)
        m.barPreview.visible = true
    else
        m.barPreview.visible = false
    end if

    knobX = barX + barWidth * shownFraction
    m.knob.translation = [knobX - 9, 577.5]
    m.knob.visible = (m.row = "bar")

    m.bubble.visible = m.seeking
    if m.seeking then
        m.bubbleLabel.text = FormatClock(Int(shown))
        bubbleX = knobX - 52
        if bubbleX < barX - 40 then bubbleX = barX - 40
        if bubbleX > 1232 - 104 then bubbleX = 1232 - 104
        m.bubble.translation = [bubbleX, 530]
    end if
end sub

sub setRow(row as String)
    m.row = row
    renderControls()
    restartHideTimer()
end sub

sub togglePause()
    if m.video.state = "paused" then
        m.video.control = "resume"
    else
        m.video.control = "pause"
        showControls(m.row)
    end if
end sub

sub runButton()
    if m.buttonIndex >= m.buttons.Count() then return
    action = m.buttons[m.buttonIndex].action
    if action = "tracks" then
        openTracks()
    else if action = "episodes" then
        openEpisodes()
    else if action = "next" then
        goToEpisode(m.index + 1)
    else if action = "nextCopy" then
        switchCopy(m.copyIndex + 1)
    else if action = "restart" then
        cancelSeek()
        m.video.seek = 0
        m.lastSaved = 0
        if m.video.state = "paused" then m.video.control = "resume"
        setRow("bar")
    end if
end sub

' Jumps to another episode in the queue; Continue Watching follows.
sub goToEpisode(index as Integer)
    saveProgress()
    ProgressPut(entryFor(index, 0, 0))
    m.index = index
    m.video.control = "stop"
    startItem(0, false)
end sub

sub leave()
    if not m.failed then saveProgress()
    close()
end sub

' --- Seeking -------------------------------------------------------------------

sub beginHold(key as String, direction as Integer)
    ' Already held: the hold timer does the stepping (guards against key repeats).
    if m.holdKey = key then return
    m.commitTimer.control = "stop"
    if not m.seeking then
        m.seeking = true
        m.seekTarget = m.video.position
    end if
    m.holdKey = key
    m.holdDirection = direction
    m.holdClock.Mark()
    stepSeek(10)
    m.holdTimer.control = "start"
end sub

sub onHoldTick()
    if m.holdKey = "" then
        m.holdTimer.control = "stop"
        return
    end if
    held = m.holdClock.TotalMilliseconds()
    ' A missed key release shouldn't leave the target running away.
    if held > 20000 then
        endHold()
        return
    end if
    ' Taps shorter than half a second are a single step.
    if held >= 500 then stepSeek(HoldStep(held))
end sub

sub stepSeek(seconds as Integer)
    m.seekTarget = ClampSeek(m.seekTarget + seconds * m.holdDirection, m.video.duration)
    if not m.controls.visible then showControls("bar")
    renderBar()
    restartHideTimer()
end sub

sub endHold()
    m.holdKey = ""
    m.holdTimer.control = "stop"
    if m.seeking then m.commitTimer.control = "start"
end sub

sub commitSeek()
    m.commitTimer.control = "stop"
    if not m.seeking then return
    m.seeking = false
    m.video.seek = m.seekTarget
    m.lastSaved = Int(m.seekTarget)
    renderBar()
    restartHideTimer()
end sub

sub cancelSeek()
    m.holdKey = ""
    m.holdTimer.control = "stop"
    m.commitTimer.control = "stop"
    m.seeking = false
end sub

sub jumpBy(seconds as Integer)
    cancelSeek()
    target = ClampSeek(m.video.position + seconds, m.video.duration)
    m.video.seek = target
    m.lastSaved = Int(target)
    showControls("bar")
end sub

' --- Keys ----------------------------------------------------------------------

function directionOf(key as String) as Integer
    if key = "left" or key = "rewind" then return -1
    return 1
end function

function isSeekKey(key as String) as Boolean
    return key = "left" or key = "right" or key = "rewind" or key = "fastforward"
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    ' Releases only matter for ending a held Left/Right.
    if not press then
        if key = m.holdKey then endHold()
        return true
    end if

    if m.panel = "tracks" then return onTrackKey(key)
    if m.panel = "episodes" then return onEpisodeKey(key)

    if m.errorBox.visible then
        if key = "OK" then
            onErrorOk()
        else if key = "back" then
            close()
        end if
        return true
    end if

    ' Still finding a copy or getting details: only Back does anything.
    if m.findingLabel.visible then
        if key = "back" then close()
        return true
    end if

    if m.upNext.visible then
        if key = "OK" or key = "play" then
            playNext()
        else if key = "back" then
            close()
        end if
        return true
    end if

    ' Back cancels a seek preview, then hides the controls, then leaves.
    if key = "back" then
        if m.seeking then
            cancelSeek()
            renderBar()
        else if m.controls.visible then
            hideControls()
        else
            leave()
        end if
        return true
    else if key = "play" then
        togglePause()
        return true
    else if key = "replay" then
        jumpBy(-10)
        return true
    else if key = "options" then
        openTracks()
        return true
    end if

    if not m.controls.visible then
        if key = "OK" then
            if m.video.state <> "paused" then m.video.control = "pause"
            showControls("bar")
        else if key = "up" or key = "down" then
            showControls("bar")
        else if isSeekKey(key) then
            showControls("bar")
            beginHold(key, directionOf(key))
        end if
        return true
    end if

    restartHideTimer()
    if m.row = "bar" then
        if key = "OK" then
            if m.seeking then
                commitSeek()
            else
                togglePause()
            end if
        else if isSeekKey(key) then
            beginHold(key, directionOf(key))
        else if key = "up" then
            setRow("top")
        else if key = "down" then
            setRow("buttons")
        end if
    else if m.row = "top" then
        if key = "OK" then
            leave()
        else if key = "down" then
            setRow("bar")
        end if
    else if m.row = "buttons" then
        if key = "left" and m.buttonIndex > 0 then
            m.buttonIndex = m.buttonIndex - 1
            renderControls()
        else if key = "right" and m.buttonIndex < m.buttons.Count() - 1 then
            m.buttonIndex = m.buttonIndex + 1
            renderControls()
        else if key = "OK" then
            runButton()
        else if key = "up" then
            setRow("bar")
        end if
    end if
    return true
end function

' --- Up next -------------------------------------------------------------------

sub showUpNext()
    upcoming = m.playback.queue[m.index + 1]
    m.upNextTitle.text = upcoming.code + "  " + upcoming.title
    m.secondsLeft = 8
    updateCountdown()
    hideControls()
    closePanel(false)
    m.upNext.visible = true
    m.countdown.control = "start"
end sub

sub onCountdown()
    m.secondsLeft = m.secondsLeft - 1
    if m.secondsLeft <= 0 then
        playNext()
    else
        updateCountdown()
    end if
end sub

sub updateCountdown()
    m.upNextHint.text = "Starts in " + m.secondsLeft.ToStr() + "   ·   OK to play now"
end sub

sub playNext()
    m.countdown.control = "stop"
    m.index = m.index + 1
    startItem(0, false)
end sub

sub close()
    m.closing = true
    m.global.playing = false
    if m.resolveTask <> invalid then m.resolveTask.UnobserveField("result")
    if m.tmdbTask <> invalid then m.tmdbTask.UnobserveField("result")
    cancelSeek()
    m.countdown.control = "stop"
    m.hideTimer.control = "stop"
    m.video.control = "stop"
    m.toastTimer.control = "stop"
    m.top.action = { name: "close" }
end sub

' --- Panels (audio & subtitles, episodes) ---------------------------------------

sub closePanel(backToControls as Boolean)
    m.panel = ""
    m.tracks.visible = false
    m.episodes.visible = false
    if backToControls then showControls("buttons")
end sub

' Applies the audio and subtitle languages chosen earlier (or set in config.json), once
' per stream, as soon as Roku has listed the tracks.
sub onTracksChanged()
    if not m.started then return
    prefs = LoadPrefs()
    if not m.audioPrefDone then
        options = AudioOptions(m.video.availableAudioTracks)
        if options.Count() > 0 then
            m.audioPrefDone = true
            index = LanguageOptionIndex(options, FieldStr(prefs, "audio"))
            if index >= 0 and options[index].id <> ToStr(m.video.audioTrack) then m.video.audioTrack = options[index].id
        end if
    end if
    if not m.subPrefDone then
        options = SubtitleOptions(m.video.availableSubtitleTracks)
        if options.Count() > 1 then
            m.subPrefDone = true
            wanted = FieldStr(prefs, "subtitles")
            if wanted <> "" and wanted <> "off" then
                index = LanguageOptionIndex(options, wanted)
                if index > 0 then
                    m.video.subtitleTrack = options[index].id
                    m.video.globalCaptionMode = "On"
                end if
            end if
        end if
    end if
end sub

' Some files' audio is in a format this Roku can't play through the TV (DTS is the usual
' one), which plays the picture in silence. Switch to a track it can play, or say why.
sub checkAudioPlayable()
    options = AudioOptions(m.video.availableAudioTracks)
    current = OptionIndex(options, "id", ToStr(m.video.audioTrack))
    format = ""
    if current >= 0 then format = options[current].format
    if format = "" then format = LCase(ToStr(m.video.audioFormat))
    if format = "" or canDecode("audio", format, "") then return
    for each option in options
        if option.format <> "" and canDecode("audio", option.format, "") then
            m.video.audioTrack = option.id
            showToast("Switched to " + option.label + ", because this " + DeviceWord() + " can't play " + CodecLabel(format) + " audio.")
            return
        end if
    end for
    showToast("No sound? This copy's audio is " + CodecLabel(format) + ", which this " + DeviceWord() + " can't play. Another copy may have audio it can.")
end sub

sub showToast(text as String)
    m.toastText.text = text
    m.toast.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.visible = false
end sub

sub openTracks()
    cancelSeek()
    m.audioOptions = AudioOptions(m.video.availableAudioTracks)
    m.subOptions = SubtitleOptions(m.video.availableSubtitleTracks)
    m.audioCursor = activeAudioIndex()
    if m.audioCursor < 0 then m.audioCursor = 0
    m.subCursor = activeSubtitleIndex()
    if m.subCursor < 0 then m.subCursor = 0
    m.trackColumn = 1
    updateTracksNote()
    hideControls()
    m.panel = "tracks"
    m.tracks.visible = true
    renderTracks()
end sub

sub updateTracksNote()
    notes = []
    playing = LCase(ToStr(m.video.audioFormat))
    if playing <> "" then notes.Push("Audio now: " + CodecLabel(playing) + ".")
    if m.subOptions.Count() <= 1 then notes.Push("This copy has no subtitles. Another copy may.")
    m.tracksNote.text = notes.Join(" ")
end sub

function activeAudioIndex() as Integer
    return OptionIndex(m.audioOptions, "id", ToStr(m.video.audioTrack))
end function

function activeSubtitleIndex() as Integer
    if ToStr(m.video.globalCaptionMode) <> "On" then return 0
    return OptionIndex(m.subOptions, "id", ToStr(m.video.subtitleTrack))
end function

sub renderTracks()
    renderOptions(m.audioList, m.audioOptions, activeAudioIndex(), m.audioCursor, m.trackColumn = 0, 440, 8)
    renderOptions(m.subsList, m.subOptions, activeSubtitleIndex(), m.subCursor, m.trackColumn = 1, 440, 8)
end sub

sub chooseTrack()
    if m.trackColumn = 0 then
        if m.audioOptions.Count() = 0 then return
        option = m.audioOptions[m.audioCursor]
        m.video.audioTrack = option.id
        if option.language <> "" then SavePref("audio", option.language)
    else
        option = m.subOptions[m.subCursor]
        if option.id = "" then
            m.video.globalCaptionMode = "Off"
            SavePref("subtitles", "off")
        else
            m.video.subtitleTrack = option.id
            m.video.globalCaptionMode = "On"
            if option.language <> "" then SavePref("subtitles", option.language)
        end if
    end if
    renderTracks()
end sub

function onTrackKey(key as String) as Boolean
    if key = "back" or key = "options" then
        closePanel(true)
        return true
    else if key = "left" and m.audioOptions.Count() > 0 then
        m.trackColumn = 0
    else if key = "right" then
        m.trackColumn = 1
    else if key = "up" then
        if m.trackColumn = 0 and m.audioCursor > 0 then m.audioCursor = m.audioCursor - 1
        if m.trackColumn = 1 and m.subCursor > 0 then m.subCursor = m.subCursor - 1
    else if key = "down" then
        if m.trackColumn = 0 and m.audioCursor < m.audioOptions.Count() - 1 then m.audioCursor = m.audioCursor + 1
        if m.trackColumn = 1 and m.subCursor < m.subOptions.Count() - 1 then m.subCursor = m.subCursor + 1
    else if key = "OK" then
        chooseTrack()
        return true
    end if
    renderTracks()
    return true
end function

sub openEpisodes()
    cancelSeek()
    m.episodeCursor = m.index
    hideControls()
    m.panel = "episodes"
    m.episodes.visible = true
    renderEpisodes()
end sub

sub renderEpisodes()
    options = []
    for each ep in m.playback.queue
        options.Push({ id: ep.code, label: ep.code + "   " + ep.title })
    end for
    renderOptions(m.episodeList, options, m.index, m.episodeCursor, true, 1040, 9)
end sub

function onEpisodeKey(key as String) as Boolean
    if key = "back" then
        closePanel(true)
    else if key = "up" and m.episodeCursor > 0 then
        m.episodeCursor = m.episodeCursor - 1
        renderEpisodes()
    else if key = "down" and m.episodeCursor < m.playback.queue.Count() - 1 then
        m.episodeCursor = m.episodeCursor + 1
        renderEpisodes()
    else if key = "OK" then
        if m.episodeCursor = m.index then
            closePanel(true)
        else
            goToEpisode(m.episodeCursor)
        end if
    end if
    return true
end function

' Draws a window of options around the cursor. The active one gets a pink dot.
sub renderOptions(group as Object, options as Object, activeIndex as Integer, cursor as Integer, focused as Boolean, width as Integer, visibleCount as Integer)
    group.RemoveChildrenIndex(group.GetChildCount(), 0)
    if options.Count() = 0 then
        empty = group.CreateChild("Label")
        empty.font = MakeFont("Nunito-SemiBold", 20)
        empty.color = "0x8579B0FF"
        empty.text = "Default"
        return
    end if
    first = cursor - (visibleCount \ 2)
    if first > options.Count() - visibleCount then first = options.Count() - visibleCount
    if first < 0 then first = 0
    last = first + visibleCount - 1
    if last > options.Count() - 1 then last = options.Count() - 1
    y = 0
    for i = first to last
        row = group.CreateChild("Group")
        row.translation = [0, y]
        bg = row.CreateChild("Poster")
        bg.uri = "pkg:/images/pill.9.png"
        bg.width = width
        bg.height = 44
        dot = row.CreateChild("Rectangle")
        dot.translation = [20, 18]
        dot.width = 8
        dot.height = 8
        dot.visible = (i = activeIndex)
        label = row.CreateChild("Label")
        label.translation = [44, 0]
        label.width = width - 60
        label.height = 44
        label.vertAlign = "center"
        label.font = MakeFont("Nunito-ExtraBold", 20)
        label.text = options[i].label
        if focused and i = cursor then
            bg.blendColor = "0xC9B8FFFF"
            bg.opacity = 1.0
            label.color = "0x151028FF"
            dot.color = "0x151028FF"
        else
            bg.opacity = 0.0
            dot.color = "0xFF9ECFFF"
            label.color = "0xA195CCFF"
            if i = activeIndex then label.color = "0xF7F3FFFF"
        end if
        y = y + 50
    end for
end sub
