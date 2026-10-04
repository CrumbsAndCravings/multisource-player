sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    req = m.top.request
    cfg = LoadConfig()
    media = MakeMedia(req.media)
    found = ResolveAll(SourceTable(), media, cfg, cfg.tuning.resolveBudgetMs)
    order = []
    for each report in found.sources
        order.Push(report.id)
    end for
    prefs = Field(req, "prefs")
    if not IsAA(prefs) then prefs = {}
    ranked = RankCopies(found.copies, media, DeviceCaps(), prefs, {}, FieldStr(req, "lastSource"), order, NowSeconds())
    m.top.result = { ok: true, copies: ranked.playable, blocked: ranked.blocked, sources: found.sources, request: req }
end sub
