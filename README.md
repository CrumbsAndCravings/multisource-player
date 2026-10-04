# ARAN+ Lab

A Roku player that finds every copy of a title across sources you're allowed to use, plays the best one, and (from milestone 3) switches to another copy when one fails. It's built to measure whether asking several sources at once beats asking one. It looks and feels like ARAN+, and reuses its player, track handling and Continue Watching.

Titles are identified by their [TMDB](https://www.themoviedb.org) ID, so the same movie found in different sources is one title.

## What works (milestones 0 and 1)

- **Home:** Continue Watching, then a row for each source that keeps a catalog. Today that's **Open movies**: Big Buck Bunny, Sintel, Tears of Steel and Elephants Dream (Blender Foundation films, Creative Commons), from public test-stream hosts.
- **Search:** all of TMDB, movies and series, as you type. Titles no source has are dimmed.
- **Details:** TMDB details, and for movies a **Sources** list (Down from the buttons) with every copy found, best first, its format, resolution, languages and score. OK on a copy plays that one. Copies that can't play on this TV are listed with the reason. Series show seasons and episodes from TMDB.
- **Player:** ARAN+'s controls, seeking, audio and subtitle panel, resume, progress every 15 seconds and up-next for episodes. The source and copy show under the title. **Next copy** in the button row switches copies at the same spot; if a copy fails, the error screen offers the next one.
- **Deep links:** start a movie or open a title from outside the app (see below).

Coming next, per the plan: Internet Archive, Jellyfin and Xtream sources (M2), automatic fallback and test modes (M3), the measurement Worker and fault lab (M4), the harness (M5) and the overnight runs (M6).

## Set up a build

Needs Node 18+.

1. `npm install`
2. Copy `app/source/config.example.json` to `app/source/config.json` and put your **TMDB API Read Access Token** in `tmdbToken` (themoviedb.org, Settings, API; free). Git ignores `config.json`, so the token never reaches the repo. Without it the app still plays the open movies, but shows no posters, details or search.
3. `npm run build` makes `build/aranplus-lab.zip`.
4. Install it like ARAN+: on a computer on the same Wi-Fi, open `http://<your-roku-ip>`, sign in as `rokudev`, upload the zip and press **Install**. A Roku holds one developer app at a time, so this replaces ARAN+ until you upload ARAN+ again.

Or build and install in one go: `ROKU_HOST=192.168.1.50 ROKU_PASSWORD=yourpass npm run deploy`.

`config.json` can also set your preferred languages (`"languages": { "audio": "en", "subtitles": "off" }`) and the resolver's timings (`tuning`); the example lists every field.

## Deep links

From a computer on the same Wi-Fi as the TV (Roku's External Control Protocol, port 8060):

```sh
# Play Big Buck Bunny (from where you left off)
curl -d '' "http://<roku-ip>:8060/launch/dev?contentId=tmdb%3Amovie%3A10378&mediaType=movie"

# Play Tears of Steel from the start
curl -d '' "http://<roku-ip>:8060/launch/dev?contentId=tmdb%3Amovie%3A133701&mediaType=movie&start=0"

# Open Sintel's details page instead of playing
curl -d '' "http://<roku-ip>:8060/launch/dev?contentId=tmdb%3Amovie%3A45745&mediaType=movie&open=details"
```

`contentId` is `tmdb:movie:<id>`, `tmdb:tv:<id>` (a series: opens its details) or `tmdb:tv:<id>:s<season>e<episode>` (an episode). Movies and episodes play straight away, as Roku expects. If the app is already open, the same request switches to the title. If the TV refuses the request, check **Settings > System > Advanced system settings > Control by mobile apps**.

## Develop

```sh
npm test          # off-device tests: IDs, copies, ranking, resolver, open movies, TMDB parsing, prefs, Continue Watching
npm run lint      # BrighterScript validation of all .brs/.xml
npm run build     # build/aranplus-lab.zip
npm run images    # regenerate icons, splash and gradients (needs Pillow)
```

Every push to `main` and every pull request is validated, tested and packaged by GitHub Actions.

### How a title gets played

1. The details page (or a deep link) knows the title's TMDB ID.
2. `ResolveTask` asks every source at once (`tasks/Resolve.brs`), each with its own timeout, inside an overall budget.
3. `common/Rank.brs` drops copies this TV can't play (AVI, HEVC on the TCL, expired links, a different cut) and scores the rest: source health 0 to 40, resolution 0 to 20 (720p best on a 720p TV), home network 15, your audio language 10, your subtitle language 5, a direct file 5, the source you watched it on before 5.
4. The player plays the best copy. For HLS on a 720p screen it caps bandwidth at 5,000 kbps so it doesn't fetch 1080p variants it can't show.

### Adding a source

A source is one file in `app/components/sources/` with four functions (`Info`, `Start`, `Step`, `Catalog`) and one line in `Sources.brs`. Sources never touch the network: they return requests, the resolver fetches them, and their `Step` reads the answer. That keeps every source testable against recorded responses. `OpenMovies.brs` is the simplest example; the contract is spelled out at the top of `Sources.brs`.

### Layout

```
app/
  manifest                    title, icons, splash, deep links
  source/main.brs             entry point, passes deep links to the scene
  source/config.json          your TMDB token and settings (git-ignored)
  components/
    MainScene.*               screen stack, deep links
    screens/                  HomeScreen, SearchScreen, DetailsScreen, PlayerScreen
    items/                    PosterItem, EpisodeItem
    tasks/                    TmdbTask (TmdbParse.brs), ResolveTask (Resolve.brs), Http.brs
    sources/                  Sources.brs (the table), OpenMovies.brs + open-movies.json
    common/                   Media (IDs, copies), Rank, Progress, Prefs, Tracks, Config, Utils, Pills
  fonts/                      Fredoka and Nunito (SIL Open Font License)
  images/                     generated by tools/make_images.py
tests/                        brs interpreter tests, TMDB-shaped fixtures
```

## Credits

This product uses the TMDB API but is not endorsed or certified by TMDB. The open movies are © Blender Foundation (Creative Commons Attribution), streamed from test hosts run by Mux, THEOplayer, Unified Streaming and the Blender Foundation.
