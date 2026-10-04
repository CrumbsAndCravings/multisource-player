sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    req = m.top.request
    mode = FieldStr(req, "mode")
    m.cfg = LoadConfig()
    if mode = "rows" then
        result = runRows()
    else if not HasTmdb(m.cfg) then
        result = { ok: false, error: "Add your TMDB token to config.json to see details and search." }
    else if mode = "details" then
        result = runDetails(FieldStr(req, "kind"), FieldStr(req, "tmdbId"))
    else if mode = "season" then
        result = runSeason(FieldStr(req, "tmdbId"), ToInt(req.season))
    else if mode = "search" then
        result = runSearch(FieldStr(req, "query"))
    else
        result = { ok: false, error: "Unknown request." }
    end if
    result.request = req
    m.top.result = result
end sub

function tmdbGet(path as String, params as Object) as Object
    res = FetchJson(TmdbUrl(path, params, m.cfg), TmdbHeaders(m.cfg), 20000)
    if not res.ok then
        if res.code = 401 then
            res.error = "TMDB turned the token down (" + res.error + ") Check tmdbToken in config.json."
        else
            res.error = "TMDB didn't answer: " + res.error
        end if
    end if
    return res
end function

function runDetails(kind as String, tmdbId as String) as Object
    if kind = "movie" then
        res = tmdbGet("/movie/" + tmdbId, { append_to_response: "credits" })
        if not res.ok then return res
        return { ok: true, info: ParseTmdbMovie(res.data) }
    end if
    res = tmdbGet("/tv/" + tmdbId, { append_to_response: "credits,external_ids" })
    if not res.ok then return res
    return { ok: true, info: ParseTmdbShow(res.data) }
end function

' One season's episodes as a content node for the details screen's episode list.
function runSeason(tmdbId as String, season as Integer) as Object
    res = tmdbGet("/tv/" + tmdbId + "/season/" + season.ToStr(), {})
    if not res.ok then return res
    content = CreateObject("roSGNode", "ContentNode")
    for each ep in ParseTmdbSeason(res.data)
        MakeItem(content, {
            kind: "episode"
            tmdbId: tmdbId
            title: ep.title
            description: ep.description
            HDPosterUrl: ep.still
            seasonNo: ep.seasonNo
            episodeNo: ep.episodeNo
            durationSecs: ep.durationSecs
        })
    end for
    m.top.content = content
    return { ok: true, count: content.GetChildCount() }
end function

' Movies and Series rows. Titles no source has are dimmed (sourceCount 0).
function runSearch(query as String) as Object
    if query.Trim() = "" then return { ok: true, forQuery: query }
    res = tmdbGet("/search/multi", { query: query.Trim(), include_adult: "false" })
    if not res.ok then return res
    found = ParseTmdbSearch(res.data)
    content = CreateObject("roSGNode", "ContentNode")
    for each group in [{ title: "Movies", list: found.movies }, { title: "Series", list: found.series }]
        if group.list.Count() > 0 then
            row = content.CreateChild("ContentNode")
            row.title = group.title
            for each entry in group.list
                count = LocalCopyCount(entry.kind, entry.tmdbId)
                caption = ""
                if count = 0 then caption = "No source"
                MakeItem(row, {
                    kind: entry.kind
                    tmdbId: entry.tmdbId
                    title: entry.title
                    year: entry.year
                    description: entry.description
                    HDPosterUrl: entry.poster
                    backdrop: entry.backdrop
                    score: entry.score
                    sourceCount: count
                    caption: caption
                })
            end for
        end if
    end for
    content.AddFields({ forQuery: query })
    m.top.content = content
    return { ok: true, forQuery: query }
end function

' Home's rows: one per source catalog, each title filled in from TMDB when there's a
' token (posters, backdrops, plots). Without one the titles still show, as name cards.
function runRows() as Object
    content = CreateObject("roSGNode", "ContentNode")
    warning = ""
    if not HasTmdb(m.cfg) then warning = "Add your TMDB token to config.json for posters, details and search."
    for each source in SourceTable()
        info = source.info()
        if info.hasCatalog then
            listing = source.catalog(invalid, 0, "", m.cfg)
            titles = FieldArr(listing, "titles")
            if titles.Count() > 0 then
                row = content.CreateChild("ContentNode")
                row.title = info.rowTitle
                for each title in titles
                    item = MakeItem(row, {
                        kind: FieldStr(title, "type")
                        tmdbId: FieldStr(title, "tmdbId")
                        title: FieldStr(title, "title")
                        year: FieldStr(title, "year")
                        sourceCount: 1
                    })
                    if warning = "" then
                        res = runDetails(item.kind, item.tmdbId)
                        if res.ok then
                            ApplyInfo(item, res.info)
                        else if warning = "" then
                            warning = res.error
                        end if
                    end if
                end for
            end if
        end if
    end for
    m.top.content = content
    return { ok: true, warning: warning }
end function
