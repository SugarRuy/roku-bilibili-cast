' Deliberately never accesses scene fields inside the loop. This distinguishes
' OS suspension from a task blocking on a rendezvous with the render thread.
sub init()
    m.top.functionName = "serve"
end sub

sub serve()
    port = CreateObject("roMessagePort")
    timer = CreateObject("roTimespan")
    info = CreateObject("roDeviceInfo")
    instance = info.GetRandomUUID()
    lan = ""
    addresses = info.GetIPAddrs()
    for each key in addresses
        candidate = addresses[key]
        if Left(candidate, 4) <> "127." and Instr(1, candidate, ".") > 0 then lan = candidate
    end for
    address = CreateObject("roSocketAddress")
    address.SetPort(9959)
    tcp = CreateObject("roStreamSocket")
    tcp.SetMessagePort(port)
    tcp.SetReuseAddr(true)
    if not tcp.SetAddress(address) then return
    if not tcp.Listen(8) then return
    tcp.NotifyReadable(true)
    udp = CreateObject("roDatagramSocket")
    udp.SetMessagePort(port)
    udp.SetReuseAddr(true)
    if not udp.SetAddress(address) then return
    udp.NotifyReadable(true)
    clients = []
    ticks = 0
    print "[lifecycle] TCP/UDP 9959 ready"
    while true
        event = wait(25, port)
        ticks++
        if tcp.IsReadable() then
            socket = tcp.Accept()
            if socket <> invalid then
                if clients.Count() < 8 then
                    socket.SetMessagePort(port)
                    socket.NotifyReadable(true)
                    clients.Push({ socket: socket, rx: "", tx: invalid, offset: 0, at: timer.TotalMilliseconds() })
                else
                    socket.Close()
                end if
            end if
        end if
        if udp.IsReadable() then
            token = udp.ReceiveStr(128)
            peer = udp.GetReceivedFromAddress()
            if Left(token, 15) = "ROKU-LIFECYCLE " then
                udp.SetSendToAddress(peer)
                udp.SendStr(FormatJson({ token: token, ticks: ticks, ms: timer.TotalMilliseconds(), instance: instance }))
            end if
        end if
        for i = clients.Count() - 1 to 0 step -1
            client = clients[i]
            if client.tx = invalid and client.socket.IsReadable() then
                chunk = client.socket.ReceiveStr(2048)
                client.rx += chunk
                if Instr(1, client.rx, Chr(13) + Chr(10) + Chr(13) + Chr(10)) > 0 then
                    line = client.rx.Split(Chr(13))[0]
                    result = { token: line, ticks: ticks, ms: timer.TotalMilliseconds(), instance: instance }
                    if line = "POST /self-wake/loopback HTTP/1.1" then
                        result.wake = selfWake("127.0.0.1")
                    else if line = "POST /self-wake/lan HTTP/1.1" and lan <> "" then
                        result.wake = selfWake(lan)
                    end if
                    body = FormatJson(result)
                    eol = Chr(13) + Chr(10)
                    text = "HTTP/1.1 200 OK" + eol + "Content-Type: application/json" + eol
                    text += "Content-Length: " + Len(body).ToStr() + eol + "Connection: close" + eol + eol + body
                    client.tx = CreateObject("roByteArray")
                    client.tx.FromAsciiString(text)
                end if
            end if
            done = false
            if client.tx <> invalid then
                sent = client.socket.Send(client.tx, client.offset, client.tx.Count() - client.offset)
                if sent > 0 then client.offset += sent
                done = client.offset = client.tx.Count()
            end if
            if done or client.rx.Len() > 4096 or timer.TotalMilliseconds() - client.at > 2000 then
                client.socket.Close()
                clients.Delete(i)
            end if
        end for
    end while
end sub

' A request arriving at the TV asks the TV task itself to launch its own DIAL
' endpoint. The computer never sends the DIAL launch in this experiment.
function selfWake(host as String) as Object
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(port)
    transfer.SetUrl("http://" + host + ":8060/dial/RokuLifecycleProbe")
    transfer.AddHeader("Content-Type", "text/plain; charset=utf-8")
    if not transfer.AsyncPostFromString("probe=1") then return { started: false }
    event = wait(4000, port)
    if type(event) = "roUrlEvent" then
        return { started: true, code: event.GetResponseCode(), reason: event.GetFailureReason() }
    end if
    transfer.AsyncCancel()
    return { started: true, timeout: true }
end function
