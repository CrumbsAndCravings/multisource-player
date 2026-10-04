' The sources the resolver asks, in priority order. Each entry points at one source
' file's functions (see sources/OpenMovies.brs for the contract), so adding a source is
' one new file and one line here.
'
'   info()                        -> { id, name, rowTitle, network, timeoutMs, hasCatalog }
'   start(media, cfg)             -> invalid (can't have it), { next: request } or { copies }
'   step(state, status, body, cfg) -> { next: request } or { copies }  (empty = not found)
'   catalog(state, status, body, cfg) -> { next: request } or { titles }; state is invalid
'                                       on the first call
'
' A request is { url, headers, state }; the resolver fetches it and hands the answer to
' step along with that state. Sources never touch the network themselves.

function SourceTable() as Object
    return [
        { info: OpenMovies_Info, start: OpenMovies_Start, step: OpenMovies_Step, catalog: OpenMovies_Catalog }
    ]
end function

' How many copies the sources that keep a local list know of, without asking anyone:
' 0 when none of them has it, -1 when only a source that has to be asked could say
' (series, for now).
function LocalCopyCount(kind as String, tmdbId as String) as Integer
    if kind <> "movie" then return -1
    return OpenMoviesCopies(OpenMoviesData(), MakeMedia({ type: "movie", tmdbId: tmdbId })).Count()
end function
