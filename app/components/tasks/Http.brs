' HTTP for task threads.

' A roUrlTransfer set up for HTTPS with the given headers, on `port` when given.
function NewTransfer(url as String, headers as Dynamic, port as Dynamic) as Object
    http = CreateObject("roUrlTransfer")
    if port <> invalid then http.SetMessagePort(port)
    http.SetUrl(url)
    if IsAA(headers) then
        for each name in headers
            http.AddHeader(name, ToStr(headers[name]))
        end for
    end if
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    http.EnableEncodings(true)
    http.RetainBodyOnError(true)
    return http
end function

' Blocking JSON GET: { ok, data } or { ok: false, code, error }.
function FetchJson(url as String, headers as Dynamic, timeoutMs as Integer) as Object
    port = CreateObject("roMessagePort")
    http = NewTransfer(url, headers, port)
    if not http.AsyncGetToString() then return { ok: false, code: 0, error: "Couldn't start the request." }
    msg = Wait(timeoutMs, port)
    if type(msg) <> "roUrlEvent" then
        http.AsyncCancel()
        return { ok: false, code: 0, error: "No answer in " + (timeoutMs \ 1000).ToStr() + " seconds." }
    end if
    code = msg.GetResponseCode()
    if code < 0 then return { ok: false, code: code, error: "Couldn't connect (" + msg.GetFailureReason() + ")." }
    if code <> 200 then return { ok: false, code: code, error: HttpDetail(code, msg.GetString()) + "." }
    data = ParseJson(msg.GetString())
    if data = invalid then return { ok: false, code: code, error: "The answer wasn't readable JSON." }
    return { ok: true, code: code, data: data }
end function
