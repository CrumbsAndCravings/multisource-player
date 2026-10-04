' Open movies: Blender Foundation films (Creative Commons) on public test-stream hosts,
' listed in open-movies.json and keyed by TMDB ID. The list ships with the app, so
' there's nothing to look up over the network and Start answers straight away.

function OpenMovies_Info() as Object
    return { id: "openmovies", name: "Open movies", rowTitle: "Open movies", network: "internet", timeoutMs: 1000, hasCatalog: true }
end function

function OpenMovies_Start(media as Object, cfg as Object) as Dynamic
    if media.type <> "movie" then return invalid
    return { copies: OpenMoviesCopies(OpenMoviesData(), media) }
end function

function OpenMovies_Step(state as Dynamic, status as Integer, body as String, cfg as Object) as Object
    return { copies: [] }
end function

function OpenMovies_Catalog(state as Dynamic, status as Integer, body as String, cfg as Object) as Object
    return { titles: OpenMoviesTitles(OpenMoviesData()) }
end function

' The parsed list, read once per thread.
function OpenMoviesData() as Dynamic
    if m.openMoviesData = invalid then m.openMoviesData = ParseJson(ReadAsciiFile("pkg:/components/sources/open-movies.json"))
    return m.openMoviesData
end function

' Every copy the list has of a movie, in the list's order.
function OpenMoviesCopies(data as Dynamic, media as Object) as Object
    info = OpenMovies_Info()
    copies = []
    for each title in FieldArr(data, "titles")
        if FieldStr(title, "tmdbId") = media.tmdbId then
            for each entry in FieldArr(title, "copies")
                if FieldStr(entry, "url") <> "" then
                    values = {}
                    for each key in entry
                        values[key] = entry[key]
                    end for
                    values.sourceId = info.id
                    values.sourceName = info.name
                    values.network = info.network
                    copies.Push(MakeCopy(values))
                end if
            end for
        end if
    end for
    return copies
end function

' Home's row: [{ type, tmdbId, title, year }].
function OpenMoviesTitles(data as Dynamic) as Object
    titles = []
    for each title in FieldArr(data, "titles")
        if FieldStr(title, "tmdbId") <> "" then titles.Push({ type: "movie", tmdbId: FieldStr(title, "tmdbId"), title: FieldStr(title, "title"), year: FieldStr(title, "year") })
    end for
    return titles
end function
