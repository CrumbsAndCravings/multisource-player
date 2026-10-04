' Settings for a personal build, read from app/source/config.json (git ignores it, so
' keys never reach the repo). app/source/config.example.json shows every field.

function LoadConfig() as Object
    if m.appConfig = invalid then m.appConfig = ConfigWithDefaults(ParseJson(ReadAsciiFile("pkg:/source/config.json")))
    return m.appConfig
end function

' Fills in defaults for anything config.json leaves out. Tuning numbers are the ones
' the plan doc lists; a value of 0 or less keeps the default.
function ConfigWithDefaults(raw as Dynamic) as Object
    tuning = {
        resolveBudgetMs: 6000
        startWaitMs: 1500
        stallSwitchMs: 8000
        maxBandwidthKbps: 5000
    }
    given = Field(raw, "tuning")
    if IsAA(given) then
        for each key in tuning
            if ToInt(given[key]) > 0 then tuning[key] = ToInt(given[key])
        end for
    end if
    langs = Field(raw, "languages")
    return {
        tmdbToken: FieldStr(raw, "tmdbToken")
        tmdbApiKey: FieldStr(raw, "tmdbApiKey")
        household: FieldStr(raw, "household")
        audioLanguage: LCase(FieldStr(langs, "audio"))
        subtitleLanguage: LCase(FieldStr(langs, "subtitles"))
        tuning: tuning
    }
end function

function HasTmdb(cfg as Object) as Boolean
    return cfg.tmdbToken <> "" or cfg.tmdbApiKey <> ""
end function
