' Asks every source for copies of a title at the same time. Each source gets its own
' timeout (its info().timeoutMs) and the whole round stops at budgetMs.
'
' Returns { copies, sources }: every copy found, in source order, and one report per
' source { id, name, outcome, ms, found, detail }. outcome is "ok", "empty", "skipped"
' (the source can't have this kind of title), "error" or "timeout".
function ResolveAll(sources as Object, media as Object, cfg as Object, budgetMs as Integer) as Object
    port = CreateObject("roMessagePort")
    clock = CreateObject("roTimespan")
    clock.Mark()
    jobs = []
    for each source in sources
        info = source.info()
        job = { source: source, info: info, state: invalid, http: invalid, transferId: -1, started: clock.TotalMilliseconds(), done: false, outcome: "", detail: "", ms: 0, copies: [] }
        jobs.Push(job)
        resolveHandle(job, source.start(media, cfg), port, clock)
    end for

    while resolvePending(jobs)
        msg = Wait(50, port)
        if type(msg) = "roUrlEvent" then
            job = resolveJobFor(jobs, msg.GetSourceIdentity())
            if job <> invalid then
                job.http = invalid
                out = job.source.step(job.state, msg.GetResponseCode(), msg.GetString(), cfg)
                resolveHandle(job, out, port, clock)
            end if
        end if
        now = clock.TotalMilliseconds()
        for each job in jobs
            if not job.done and (now - job.started > ToInt(job.info.timeoutMs) or now > budgetMs) then
                if job.http <> invalid then job.http.AsyncCancel()
                job.http = invalid
                resolveFinish(job, "timeout", "no answer in " + (now - job.started).ToStr() + " ms", clock)
            end if
        end for
    end while

    copies = []
    reports = []
    for each job in jobs
        copies.Append(job.copies)
        reports.Push({ id: job.info.id, name: job.info.name, outcome: job.outcome, ms: job.ms, found: job.copies.Count(), detail: job.detail })
    end for
    return { copies: copies, sources: reports }
end function

' Acts on what a source's start or step returned: more to fetch, copies, an error, or
' nothing for this kind of title.
sub resolveHandle(job as Object, out as Dynamic, port as Object, clock as Object)
    if out = invalid then
        resolveFinish(job, "skipped", "", clock)
    else if FieldStr(out, "error") <> "" then
        resolveFinish(job, "error", FieldStr(out, "error"), clock)
    else if IsAA(Field(out, "next")) then
        request = out.next
        job.state = Field(request, "state")
        http = NewTransfer(FieldStr(request, "url"), Field(request, "headers"), port)
        if http.AsyncGetToString() then
            job.http = http
            job.transferId = http.GetIdentity()
        else
            resolveFinish(job, "error", "couldn't start the request", clock)
        end if
    else
        copies = FieldArr(out, "copies")
        job.copies = copies
        if copies.Count() > 0 then
            resolveFinish(job, "ok", "", clock)
        else
            resolveFinish(job, "empty", "", clock)
        end if
    end if
end sub

sub resolveFinish(job as Object, outcome as String, detail as String, clock as Object)
    job.done = true
    job.outcome = outcome
    job.detail = detail
    job.ms = clock.TotalMilliseconds() - job.started
end sub

function resolvePending(jobs as Object) as Boolean
    for each job in jobs
        if not job.done then return true
    end for
    return false
end function

function resolveJobFor(jobs as Object, transferId as Integer) as Dynamic
    for each job in jobs
        if not job.done and job.transferId = transferId then return job
    end for
    return invalid
end function
