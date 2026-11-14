' Experimental resumable SSDP + NVA receiver. No account cookies or arbitrary URLs enter this task.
sub init()
    m.top.functionName = "castServe"
end sub

sub castServe()
    m.port = CreateObject("roMessagePort")
    m.clock = CreateObject("roTimespan")
    ' Never pull SceneGraph fields in the network loop while the scene is
    ' suspended. Node events carry copies into task-local caches instead.
    for each field in ["playback", "diagnostics", "signedIn", "shutdown", "suspended"]
        m.top.observeField(field, m.port)
    end for
    m.playbackCache = m.top.playback
    m.pipelineCache = m.top.diagnostics
    m.signedInCache = m.top.signedIn
    m.stopRequested = m.top.shutdown
    m.suspended = m.top.suspended
    m.pendingCommands = []
    m.wakeTransfer = invalid
    m.wakeAttempts = 0
    m.wakeAt = 0
    m.wakeRetryAt = -1
    m.clients = []
    m.events = []
    m.commandId = 0
    m.httpPort = 9958
    m.name = "Roku 小电视 · 投屏测试"
    m.uuid = "3465d391-8c31-4ac9-8caf-c4a3e6e95ba4"
    m.bootId = CreateObject("roDateTime").AsSeconds().ToStr()
    m.udn = "uuid:" + m.uuid
    m.serverAgent = "Linux/3.0.0, UPnP/1.0, Platinum/1.0.5.13"
    m.ip = ""
    addrs = CreateObject("roDeviceInfo").GetIPAddrs()
    if type(addrs) = "roAssociativeArray" then
        for each key in addrs
            ip = castText(addrs[key])
            if Left(ip, 4) <> "127." and Instr(1, ip, ".") > 0 then
                m.ip = ip
                exit for
            end if
        end for
    end if
    if m.ip = "" then
        m.top.status = { ok: false, error: "未找到局域网地址" }
        return
    end if
    addr = CreateObject("roSocketAddress")
    addr.SetHostName(m.ip)
    addr.SetPort(m.httpPort)
    m.listener = CreateObject("roStreamSocket")
    m.listener.SetMessagePort(m.port)
    m.listener.SetReuseAddr(true)
    bound = m.listener.SetAddress(addr)
    if not bound or not m.listener.Listen(8) then
        m.top.status = { ok: false, error: "投屏端口 9958 无法监听" }
        return
    end if
    m.listener.NotifyReadable(true)
    m.location = "http://" + m.ip + ":" + m.httpPort.ToStr() + "/description.xml"
    m.targets = ["upnp:rootdevice", m.udn, "urn:schemas-upnp-org:device:MediaRenderer:1", "urn:schemas-upnp-org:service:AVTransport:1", "urn:app-bilibili-com:service:NirvanaControl:3"]
    m.udp = CreateObject("roDatagramSocket")
    m.udp.SetMessagePort(m.port)
    m.udp.SetReuseAddr(true)
    m.udp.SetMulticastTTL(2)
    udpAddr = CreateObject("roSocketAddress")
    udpAddr.SetPort(1900)
    m.ssdpBound = m.udp.SetAddress(udpAddr)
    m.group = CreateObject("roSocketAddress")
    m.group.SetHostName("239.255.255.250")
    m.group.SetPort(1900)
    m.joined = false
    if m.ssdpBound then m.joined = m.udp.JoinGroup(m.group)
    m.udp.NotifyReadable(true)
    castLog("ready", "ssdpBind=" + m.ssdpBound.ToStr() + " join=" + m.joined.ToStr())
    m.top.status = { ok: true, name: m.name, ip: m.ip, ssdp: m.joined }
    lastAdvert = -10000
    lastStatus = -1000
    while not m.stopRequested
        msg = wait(50, m.port)
        now = m.clock.TotalMilliseconds()
        castTaskEvent(msg)
        castWakeTick(now)
        if m.listener.IsReadable() then castAccept()
        if m.udp.IsReadable() then castDiscovery()
        if now - lastAdvert >= 3000 then
            castAdvertise("ssdp:alive")
            lastAdvert = now
        end if
        for i = m.clients.Count() - 1 to 0 step -1
            c = m.clients[i]
            if c.socket.IsReadable() and not c.closing then
                bytes = CreateObject("roByteArray")
                bytes[8191] = 0
                n = c.socket.Receive(bytes, 0, 8192)
                if n > 0 then
                    c.rx.Append(castSlice(bytes, 0, n))
                    c.lastAt = now
                    if c.rx.Count() > 131072 then
                        c.dead = true
                    else if c.mode = "http" then
                        castHttp(c)
                    else
                        castNva(c)
                    end if
                else if n = 0 then
                    c.dead = true
                end if
            end if
            if c.mode = "nva" and c.rx.Count() > 0 and not c.dead then castNva(c)
            if now - lastStatus >= 1000 and c.mode = "nva" and not c.dead then castProgress(c)
            castFlush(c)
            if c.mode = "http" and now - c.lastAt > 10000 then c.dead = true
            if c.mode = "nva" and now - c.lastAt > 300000 then c.dead = true
            if c.dead then
                c.socket.Close()
                m.clients.Delete(i)
            end if
        end for
        if now - lastStatus >= 1000 then lastStatus = now
    end while
    castAdvertise("ssdp:byebye")
    for each c in m.clients
        c.socket.Close()
    end for
    m.udp.Close()
    m.listener.Close()
end sub

sub castLog(kind as String, detail as String)
    print "[cast] ms="; m.clock.TotalMilliseconds(); " "; kind; " "; detail
    m.events.Push({ kind: kind, detail: Left(detail, 120), ms: m.clock.TotalMilliseconds() })
    if m.events.Count() > 30 then m.events.Shift()
end sub

sub castAccept()
    sock = m.listener.Accept()
    if sock = invalid then return
    if m.clients.Count() >= 8 then
        sock.Close()
        return
    end if
    sock.SetMessagePort(m.port)
    sock.NotifyReadable(true)
    m.clients.Push({ socket: sock, mode: "http", rx: CreateObject("roByteArray"), tx: [], offset: 0, closing: false, dead: false, seq: 1, lastState: -1, successGeneration: -1, lastAt: m.clock.TotalMilliseconds() })
end sub

sub castQueue(c as Object, bytes as Object)
    if c.tx.Count() >= 24 then
        c.dead = true
        return
    end if
    c.tx.Push(bytes)
end sub

sub castFlush(c as Object)
    if c.dead then return
    if c.tx.Count() > 0 then
        b = c.tx[0]
        n = c.socket.Send(b, c.offset, b.Count() - c.offset)
        if n > 0 then c.offset = c.offset + n
        if c.offset = b.Count() then
            c.tx.Shift()
            c.offset = 0
        end if
    end if
    if c.closing and c.tx.Count() = 0 then c.dead = true
end sub

sub castAdvertise(nts as String)
    eol = Chr(13) + Chr(10)
    for each target in m.targets
        usn = m.udn
        if target <> m.udn then usn = usn + "::" + target
        text = "NOTIFY * HTTP/1.1" + eol + "HOST: 239.255.255.250:1900" + eol + "CACHE-CONTROL: max-age=45" + eol + "LOCATION: " + m.location + eol + "NT: " + target + eol + "NTS: " + nts + eol + "SERVER: " + m.serverAgent + eol + "USN: " + usn + eol + "BOOTID.UPNP.ORG: " + m.bootId + eol + "CONFIGID.UPNP.ORG: 4" + eol + eol
        m.udp.SetSendToAddress(m.group)
        m.udp.SendStr(text)
    end for
end sub

sub castDiscovery()
    text = m.udp.ReceiveStr(8192)
    if Left(UCase(text), 8) <> "M-SEARCH" then return
    h = castHeaders(text)
    wanted = castText(h.st)
    if wanted = "" then return
    peer = m.udp.GetReceivedFromAddress()
    eol = Chr(13) + Chr(10)
    replied = false
    for each target in m.targets
        if wanted = "ssdp:all" or wanted = target then
            usn = m.udn
            if target <> m.udn then usn = usn + "::" + target
            response = "HTTP/1.1 200 OK" + eol + "CACHE-CONTROL: max-age=45" + eol + "EXT:" + eol + "LOCATION: " + m.location + eol + "SERVER: " + m.serverAgent + eol + "ST: " + target + eol + "USN: " + usn + eol + "BOOTID.UPNP.ORG: " + m.bootId + eol + "CONFIGID.UPNP.ORG: 4" + eol + eol
            m.udp.SetSendToAddress(peer)
            m.udp.SendStr(response)
            replied = true
        end if
    end for
    if replied then castLog("discovery", wanted + " ua=" + Left(castText(h["user-agent"]), 55))
end sub

sub castHttp(c as Object)
    text = c.rx.ToAsciiString()
    eol = Chr(13) + Chr(10)
    split = Instr(1, text, eol + eol)
    if split = 0 then
        if c.rx.Count() > 16384 then c.dead = true
        return
    end if
    head = Left(text, split - 1)
    lines = head.Split(eol)
    request = lines[0].Split(" ")
    if request.Count() < 2 then
        c.dead = true
        return
    end if
    method = UCase(request[0])
    path = request[1].Split("?")[0]
    headers = castHeaders(head)
    bodyAt = castBytes(head + eol + eol).Count()
    size = castNumber(headers["content-length"])
    if size < 0 or size > 65536 then
        c.dead = true
        return
    end if
    if c.rx.Count() < bodyAt + size then return
    body = castSlice(c.rx, bodyAt, size).ToAsciiString()
    if path <> "/status" then castLog("http", method + " " + Left(path, 55) + " ua=" + Left(castText(headers["user-agent"]), 55))
    if (method = "SETUP" or method = "RESTORE" or method = "STARTRESTORE") and path = "/projection" and headers.session <> invalid then
        session = castText(headers.session).Replace(Chr(13), "").Replace(Chr(10), "")
        response = "NVA 200 OK" + eol + "Session: " + Left(session, 128) + eol + "NvaVersion: 1" + eol + "Connection: Keep-Alive" + eol + "UUID: " + m.uuid + eol + "User-Agent: " + m.serverAgent + eol + eol
        castQueue(c, castBytes(response))
        c.mode = "nva"
        c.rx = castSlice(c.rx, bodyAt + size, c.rx.Count() - bodyAt - size)
        castLog("connected", "NVA")
        castNva(c)
    else if method = "GET" and path = "/description.xml" then
        castHttpReply(c, "200 OK", "text/xml; charset=utf-8", castDescription())
    else if method = "GET" and path = "/dlna/NirvanaControl.xml" then
        castHttpReply(c, "200 OK", "text/xml", ReadAsciiFile("pkg:/resources/cast/NirvanaControl.xml"))
    else if method = "GET" and path = "/dlna/AVTransport.xml" then
        castHttpReply(c, "200 OK", "text/xml", ReadAsciiFile("pkg:/resources/cast/AVTransport.xml"))
    else if method = "GET" and path = "/status" then
        ' Deliberately excludes URLs, cookies, video titles and received message bodies.
        castHttpReply(c, "200 OK", "application/json", FormatJson({ name: m.name, ssdpBound: m.ssdpBound, multicastJoined: m.joined, clients: m.clients.Count(), events: m.events, playback: castPlayback(), pipeline: m.pipelineCache, suspended: m.suspended, pending: m.pendingCommands.Count() }))
    else if method = "POST" and path = "/AVTransport/action" then
        castSoap(c, headers, body)
    else if method = "POST" and path = "/NirvanaControl/action" then
        castSoap(c, headers, body, "urn:app-bilibili-com:service:NirvanaControl:3")
    else if method = "SUBSCRIBE" and path = "/AVTransport/event" then
        castHttpReply(c, "200 OK", "text/plain", "", "SID: uuid:" + m.uuid + eol + "TIMEOUT: Second-1800" + eol)
    else
        castHttpReply(c, "404 Not Found", "text/plain", "Not found")
    end if
end sub

sub castHttpReply(c as Object, status as String, mime as String, text as String, extra = "" as String)
    body = castBytes(text)
    eol = Chr(13) + Chr(10)
    head = "HTTP/1.1 " + status + eol + "Content-Type: " + mime + eol + "Content-Length: " + body.Count().ToStr() + eol + extra + "Connection: close" + eol + eol
    bytes = castBytes(head)
    bytes.Append(body)
    castQueue(c, bytes)
    c.closing = true
    c.rx.Clear()
end sub

function castDescription() as String
    text = ReadAsciiFile("pkg:/resources/cast/description.xml")
    return text.Replace("{{UUID}}", m.uuid).Replace("{{NAME}}", castXml(m.name))
end function

sub castNva(c as Object)
    for budget = 0 to 7
        frame = castFrame(c.rx)
        if frame = invalid then return
        if frame.bad = true then
            castLog("reject", "malformed NVA frame")
            c.dead = true
            return
        end if
        c.rx = castSlice(c.rx, frame.size, c.rx.Count() - frame.size)
        if frame.kind = &he0 and frame.action <> "" then castAction(c, frame)
        if frame.kind = &he4 then
            pong = castReply(frame.seq, invalid)
            castQueue(c, pong)
        end if
    end for
end sub

sub castAction(c as Object, frame as Object)
    action = frame.action
    castLog("nva", action)
    data = castJson(frame.body)
    reply = invalid
    command = invalid
    if action = "Play" or action = "PlayUrl" then
        command = castContent(data)
        if command = invalid then castLog("unsupported", "play without supported video identifier")
    else if action = "Pause" then
        command = { action: "pause" }
    else if action = "Resume" then
        command = { action: "resume" }
    else if action = "Stop" then
        command = { action: "stop" }
    else if action = "Seek" and type(data) = "roAssociativeArray" then
        seconds = castNumber(data.seekTs)
        if seconds >= 0 and seconds < 604800 then command = { action: "seek", position: seconds }
    else if action = "SwitchDanmaku" and type(data) = "roAssociativeArray" then
        enabled = data.open = true or LCase(castText(data.open)) = "true" or castNumber(data.open) = 1
        command = { action: "danmaku", enabled: enabled }
    else if action = "GetVolume" then
        reply = { volume: 30 }
    else if action = "GetPlayState" then
        reply = { "playState": castPlayback().state }
    else if action = "GetProgress" then
        state = castPlayback()
        reply = { duration: state.duration, position: state.position }
    end if
    if command <> invalid then castDispatch(command)
    castQueue(c, castReply(frame.seq, reply))
end sub

sub castDispatch(command as Object)
    if m.suspended then
        ' Discovery, GetAppInfo and NVA SETUP never wake the screen. Only an
        ' actual video request starts a wake; follow-up controls stay ordered.
        if command.action = "play" then
            m.pendingCommands = [command]
            if m.wakeTransfer = invalid and m.wakeRetryAt < 0 then
                m.wakeAttempts = 0
                m.wakeAt = m.clock.TotalMilliseconds()
                castStartWake()
            end if
        else if m.pendingCommands.Count() > 0 and m.pendingCommands.Count() < 16 then
            m.pendingCommands.Push(command)
        end if
        return
    end if
    m.commandId = m.commandId + 1
    command.id = m.commandId
    m.top.command = command
end sub

function castPlayback() as Object
    state = m.playbackCache
    if type(state) <> "roAssociativeArray" then return { state: 7, position: 0, duration: 0 }
    return state
end function

sub castProgress(c as Object)
    c.seq = c.seq + 1
    ping = castReply(c.seq, invalid)
    ping[0] = &he4
    castQueue(c, ping)
    state = castPlayback()
    if c.lastState <> state.state then
        c.seq = c.seq + 1
        castQueue(c, castNotice(c.seq, "OnPlayState", { "playState": state.state }))
        c.lastState = state.state
    end if
    generation = castNumber(state.generation)
    if state.state = 4 and generation <> c.successGeneration then
        c.seq = c.seq + 1
        castQueue(c, castNotice(c.seq, "PLAY_SUCCESS"))
        c.successGeneration = generation
    end if
    if state.state = 4 or state.state = 5 then
        c.seq = c.seq + 1
        castQueue(c, castNotice(c.seq, "OnProgress", { duration: state.duration, position: state.position }))
    end if
end sub

sub castSoap(c as Object, headers as Object, body as String, service = "urn:schemas-upnp-org:service:AVTransport:1" as String)
    action = castText(headers.soapaction).Replace(Chr(34), "").Split("#").Peek()
    if not CreateObject("roRegex", "^[A-Za-z][A-Za-z0-9]{0,50}$", "").IsMatch(action) then
        castHttpReply(c, "400 Bad Request", "text/plain", "Invalid SOAP action")
        return
    end if
    castLog("soap", action)
    root = CreateObject("roXMLElement")
    if not root.Parse(body) then
        castHttpReply(c, "400 Bad Request", "text/plain", "Invalid XML")
        return
    end if
    args = {}
    nodes = root.GetChildElements()
    if nodes <> invalid then
        for each outer in nodes
            children = outer.GetChildElements()
            if children <> invalid then
                for each operation in children
                    values = operation.GetChildElements()
                    if values <> invalid then
                        for each arg in values
                            args[arg.GetName().Split(":").Peek()] = arg.GetText()
                        end for
                    end if
                end for
            end if
        end for
    end if
    command = invalid
    fields = {}
    state = castPlayback()
    if action = "GetAppInfo" then
        signedIn = "0"
        if m.signedInCache then signedIn = "1"
        fields = { "PackageName": "com.xiaodianshi.tv.yst", "AppKey": "0000000000000000", "Signature": "0000000000000000", "CurrentSignedIn": signedIn }
    else if action = "SetDanmakuSwitch" then
        command = { action: "danmaku", enabled: castText(args.DesiredSwitch) = "1" or castText(args.DesiredSwitch) = "true" }
    else if action = "SetAVTransportURI" then
        command = castContent({ url: castText(args.CurrentURI) })
        if command = invalid then castLog("unsupported", "DLNA URI has no video identifier")
    else if action = "Play" then
        command = { action: "resume" }
    else if action = "Pause" then
        command = { action: "pause" }
    else if action = "Stop" then
        command = { action: "stop" }
    else if action = "Seek" then
        seconds = 0
        for each part in castText(args.Target).Split(":")
            seconds = seconds * 60 + castNumber(part)
        end for
        if seconds >= 0 and seconds < 604800 then command = { action: "seek", position: seconds }
    else if action = "GetTransportInfo" then
        transport = "STOPPED"
        if state.state = 3 then transport = "TRANSITIONING"
        if state.state = 4 then transport = "PLAYING"
        if state.state = 5 then transport = "PAUSED_PLAYBACK"
        fields = { "CurrentTransportState": transport, "CurrentTransportStatus": "OK", "CurrentSpeed": "1" }
    else if action = "GetPositionInfo" then
        fields = { "Track": "1", "TrackDuration": castHms(state.duration), "TrackMetaData": "", "TrackURI": "", "RelTime": castHms(state.position), "AbsTime": castHms(state.position), "RelCount": "0", "AbsCount": "0" }
    else if action = "GetCurrentTransportActions" then
        fields = { "Actions": "Play,Pause,Stop,Seek" }
    end if
    if command <> invalid then castDispatch(command)
    xml = "<s:Envelope xmlns:s=""http://schemas.xmlsoap.org/soap/envelope/"" s:encodingStyle=""http://schemas.xmlsoap.org/soap/encoding/""><s:Body><u:" + action + "Response xmlns:u=""" + service + """>"
    for each key in fields
        xml = xml + "<" + key + ">" + castXml(castText(fields[key])) + "</" + key + ">"
    end for
    xml = xml + "</u:" + action + "Response></s:Body></s:Envelope>"
    castHttpReply(c, "200 OK", "text/xml; charset=utf-8", xml)
end sub

function castHms(seconds as Integer) as String
    return (seconds \ 3600).ToStr() + ":" + Right("0" + ((seconds \ 60) mod 60).ToStr(), 2) + ":" + Right("0" + (seconds mod 60).ToStr(), 2)
end function

sub castTaskEvent(event as Dynamic)
    if type(event) = "roSGNodeEvent" then
        field = LCase(event.GetField())
        data = event.GetData()
        if field = "playback" then
            m.playbackCache = data
        else if field = "diagnostics" then
            m.pipelineCache = data
        else if field = "signedin" then
            m.signedInCache = data
        else if field = "shutdown" then
            m.stopRequested = data
        else if field = "suspended" then
            m.suspended = data
            castLog("lifecycle", "suspended=" + m.suspended.ToStr())
            if not m.suspended then
                m.wakeRetryAt = -1
                queued = m.pendingCommands
                m.pendingCommands = []
                for each command in queued
                    castDispatch(command)
                end for
            end if
        end if
    else if type(event) = "roUrlEvent" and m.wakeTransfer <> invalid then
        if event.GetSourceIdentity() <> m.wakeTransfer.GetIdentity() then return
        code = event.GetResponseCode()
        castLog("self-wake", "DIAL status=" + code.ToStr())
        m.wakeTransfer = invalid
        if code = 503 and m.wakeAttempts < 3 and m.suspended then
            m.wakeRetryAt = m.clock.TotalMilliseconds() + 1000
        else if code <> 200 and code <> 201 then
            m.pendingCommands = []
        end if
    end if
end sub

sub castStartWake()
    m.wakeRetryAt = -1
    m.wakeAttempts += 1
    m.wakeTransfer = CreateObject("roUrlTransfer")
    m.wakeTransfer.SetMessagePort(m.port)
    m.wakeTransfer.SetUrl("http://127.0.0.1:8060/dial/RokuBiliCast")
    m.wakeTransfer.AddHeader("Content-Type", "text/plain; charset=utf-8")
    if not m.wakeTransfer.AsyncPostFromString("wake=cast") then
        castLog("self-wake", "could not start DIAL request")
        m.wakeTransfer = invalid
        m.pendingCommands = []
    end if
end sub

sub castWakeTick(now as Integer)
    if m.wakeRetryAt >= 0 and now >= m.wakeRetryAt then castStartWake()
    if m.pendingCommands.Count() > 0 and now - m.wakeAt > 10000 then
        if m.wakeTransfer <> invalid then m.wakeTransfer.AsyncCancel()
        m.wakeTransfer = invalid
        m.wakeRetryAt = -1
        m.pendingCommands = []
        castLog("self-wake", "resume timed out; discarded queued commands")
    end if
end sub
