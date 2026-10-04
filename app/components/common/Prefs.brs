' Preferences kept in the registry: player languages and the last source per title.

' Player preferences, e.g. { audio: "hin", subtitles: "eng" } (language codes, or "off").
' Until you choose in the player, the languages from config.json apply.
function LoadPrefs() as Object
    raw = RegRead("prefs", "player")
    prefs = invalid
    if raw <> invalid then prefs = ParseJson(raw)
    if not IsAA(prefs) then prefs = {}
    cfg = LoadConfig()
    if FieldStr(prefs, "audio") = "" and cfg.audioLanguage <> "" then prefs.audio = cfg.audioLanguage
    if FieldStr(prefs, "subtitles") = "" and cfg.subtitleLanguage <> "" then prefs.subtitles = cfg.subtitleLanguage
    return prefs
end function

sub SavePref(key as String, value as String)
    raw = RegRead("prefs", "player")
    prefs = invalid
    if raw <> invalid then prefs = ParseJson(raw)
    if not IsAA(prefs) then prefs = {}
    prefs[key] = value
    RegWrite("prefs", "player", FormatJson(prefs))
end sub

' Which source each title last played from, so a resume picks the same copy (and the
' same timing) when it can. Stored newest first as [{ k, s }], at most 40.
function LastSourceFor(key as String) as String
    for each saved in lastSources()
        if FieldStr(saved, "k") = key then return FieldStr(saved, "s")
    end for
    return ""
end function

sub SaveLastSource(key as String, sourceId as String)
    list = [{ k: key, s: sourceId }]
    for each saved in lastSources()
        if FieldStr(saved, "k") <> key and list.Count() < 40 then list.Push(saved)
    end for
    RegWrite("prefs", "lastSources", FormatJson(list))
end sub

function lastSources() as Object
    raw = RegRead("prefs", "lastSources")
    list = invalid
    if raw <> invalid then list = ParseJson(raw)
    if not IsArr(list) then list = []
    return list
end function
