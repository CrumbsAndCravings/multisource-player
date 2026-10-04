' TMDB API v3 requests and responses -> plain data. No network here, so tests cover it.
' Endpoints: /movie/{id}, /tv/{id}, /tv/{id}/season/{n} and /search/multi.

function TmdbBase() as String
    return "https://api.themoviedb.org/3"
end function

' The URL for a path like "/movie/10378". A v3 API key goes in the query; the newer
' read access token goes in a header instead (TmdbHeaders).
function TmdbUrl(path as String, params as Object, cfg as Object) as String
    url = TmdbBase() + path
    query = []
    if cfg.tmdbToken = "" and cfg.tmdbApiKey <> "" then query.Push("api_key=" + cfg.tmdbApiKey.EncodeUriComponent())
    keys = params.Keys()
    keys.Sort()
    for each key in keys
        query.Push(key + "=" + ToStr(params[key]).EncodeUriComponent())
    end for
    if query.Count() > 0 then url = url + "?" + query.Join("&")
    return url
end function

function TmdbHeaders(cfg as Object) as Object
    if cfg.tmdbToken <> "" then return { Authorization: "Bearer " + cfg.tmdbToken, Accept: "application/json" }
    return { Accept: "application/json" }
end function

' "/abc.jpg" -> "https://image.tmdb.org/t/p/w185/abc.jpg"; "" stays "".
function TmdbImage(path as Dynamic, size as String) as String
    text = ToStr(path).Trim()
    if text = "" then return ""
    return "https://image.tmdb.org/t/p/" + size + text
end function

' --- Details -------------------------------------------------------------------

' /movie/{id}?append_to_response=credits -> the fields ApplyInfo copies onto an item.
function ParseTmdbMovie(data as Dynamic) as Object
    info = tmdbCommon(data)
    info.kind = "movie"
    info.title = FieldStr(data, "title")
    info.year = YearOf(FieldStr(data, "release_date"))
    info.imdbId = FieldStr(data, "imdb_id")
    info.durationSecs = ToInt(Field(data, "runtime")) * 60
    return info
end function

' /tv/{id}?append_to_response=credits,external_ids -> details plus its seasons,
' [{ number, name, episodes }], numbered seasons first and Specials (season 0) last.
function ParseTmdbShow(data as Dynamic) as Object
    info = tmdbCommon(data)
    info.kind = "series"
    info.title = FieldStr(data, "name")
    info.year = YearOf(FieldStr(data, "first_air_date"))
    info.imdbId = FieldStr(Field(data, "external_ids"), "imdb_id")
    runtimes = FieldArr(data, "episode_run_time")
    if runtimes.Count() > 0 then info.durationSecs = ToInt(runtimes[0]) * 60
    seasons = []
    specials = invalid
    for each season in FieldArr(data, "seasons")
        number = ToInt(Field(season, "season_number"))
        count = ToInt(Field(season, "episode_count"))
        if count > 0 then
            name = FieldStr(season, "name")
            if name = "" then name = "Season " + number.ToStr()
            entry = { number: number, name: name, episodes: count }
            if number = 0 then
                specials = entry
            else
                seasons.Push(entry)
            end if
        end if
    end for
    if specials <> invalid then seasons.Push(specials)
    info.seasons = seasons
    return info
end function

function tmdbCommon(data as Dynamic) as Object
    genres = []
    for each genre in FieldArr(data, "genres")
        name = FieldStr(genre, "name")
        if name <> "" then genres.Push(name)
    end for
    credits = Field(data, "credits")
    cast = []
    for each person in FieldArr(credits, "cast")
        name = FieldStr(person, "name")
        if name <> "" and cast.Count() < 3 then cast.Push(name)
    end for
    directors = []
    for each person in FieldArr(credits, "crew")
        if FieldStr(person, "job") = "Director" and directors.Count() < 2 then directors.Push(FieldStr(person, "name"))
    end for
    score = ""
    vote = ToFloat(Field(data, "vote_average"))
    if vote > 0 and ToInt(Field(data, "vote_count")) >= 5 then score = ToStr(vote)
    return {
        tmdbId: FieldStr(data, "id")
        description: FieldStr(data, "overview")
        genre: genres.Join(", ")
        score: score
        starring: cast.Join(", ")
        directedBy: directors.Join(", ")
        poster: TmdbImage(Field(data, "poster_path"), "w185")
        backdrop: TmdbImage(Field(data, "backdrop_path"), "w780")
        durationSecs: 0
        imdbId: ""
    }
end function

' /tv/{id}/season/{n} -> [{ seasonNo, episodeNo, title, description, still, durationSecs }]
' in episode order. Episodes TMDB lists without a number are left out.
function ParseTmdbSeason(data as Dynamic) as Object
    episodes = []
    for each ep in FieldArr(data, "episodes")
        number = ToInt(Field(ep, "episode_number"))
        if number > 0 then
            title = FieldStr(ep, "name")
            if title = "" then title = "Episode " + number.ToStr()
            episodes.Push({
                seasonNo: ToInt(Field(ep, "season_number"))
                episodeNo: number
                title: title
                description: FieldStr(ep, "overview")
                still: TmdbImage(Field(ep, "still_path"), "w300")
                durationSecs: ToInt(Field(ep, "runtime")) * 60
                order: number
            })
        end if
    end for
    episodes.SortBy("order")
    return episodes
end function

' --- Search --------------------------------------------------------------------

' /search/multi -> { movies: [...], series: [...] }, each entry { kind, tmdbId, title,
' year, poster, backdrop, description, score }. People and adult titles are left out.
function ParseTmdbSearch(data as Dynamic) as Object
    results = { movies: [], series: [] }
    for each entry in FieldArr(data, "results")
        mediaType = FieldStr(entry, "media_type")
        if not ToBool(Field(entry, "adult")) and (mediaType = "movie" or mediaType = "tv") then
            item = {
                tmdbId: FieldStr(entry, "id")
                poster: TmdbImage(Field(entry, "poster_path"), "w185")
                backdrop: TmdbImage(Field(entry, "backdrop_path"), "w780")
                description: FieldStr(entry, "overview")
                score: ""
            }
            vote = ToFloat(Field(entry, "vote_average"))
            if vote > 0 and ToInt(Field(entry, "vote_count")) >= 5 then item.score = ToStr(vote)
            if mediaType = "movie" then
                item.kind = "movie"
                item.title = FieldStr(entry, "title")
                item.year = YearOf(FieldStr(entry, "release_date"))
                results.movies.Push(item)
            else
                item.kind = "series"
                item.title = FieldStr(entry, "name")
                item.year = YearOf(FieldStr(entry, "first_air_date"))
                results.series.Push(item)
            end if
        end if
    end for
    return results
end function
