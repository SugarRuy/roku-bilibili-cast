' Player adapter. All wire protocol logic lives in CastReceiver/CastProtocol.
sub startCastReceiver()
    m.cast = CreateObject("roSGNode", "CastReceiver")
    m.cast.observeField("command", "onCastCommand")
    m.cast.observeField("status", "onCastStatus")
    m.cast.playback = { state: 7, position: 0, duration: 0 }
    m.cast.signedIn = m.global.loggedIn
    m.cast.control = "RUN"
    m.castRequest = invalid
    m.castTask = invalid
    m.castGeneration = 0
    m.castClock = CreateObject("roTimespan")
    m.castStartedAt = 0
    m.castStage = "idle"
    m.cast.diagnostics = { generation: 0, stage: "idle", elapsedMs: 0 }
    m.castTimer = m.top.findNode("castTimer")
    m.castTimer.observeField("fire", "onCastTick")
    m.castTimer.control = "start"
end sub

sub onCastStatus(event as Object)
    status = event.getData()
    if status.ok then
        showToast("手机 B 站投屏 → " + status.name)
    else
        showToast("投屏服务：" + strOf(status.error))
    end if
end sub

sub onCastCommand(event as Object)
    command = event.getData()
    action = strOf(command.action)
    print "[cast-ui] "; action
    if action = "play" then
        m.castGeneration = m.castGeneration + 1
        m.castRequest = command
        m.castStartedAt = m.castClock.TotalMilliseconds()
        m.cast.playback = { state: 3, position: 0, duration: 0 }
        castTrace("queued")
        if m.castTask <> invalid then
            ' Keep one in-flight lookup alive until its cancellation callback.
            ' Rapid requests replace only m.castRequest; the latest one wins.
            m.castTask.cancelled = true
        else
            startCastLookup()
        end if
        showToast("正在接收手机投屏…")
        return
    end if
    if action = "stop" then
        m.castGeneration = m.castGeneration + 1
        if m.castTask <> invalid then m.castTask.cancelled = true
        m.castRequest = invalid
        castTrace("stopped")
    end if
    if m.stack.Count() = 0 then return
    screen = m.stack.Peek()
    if screen.Subtype() = "PlayerScreen" then
        screen.castCommand = command
    end if
end sub

sub startCastLookup()
    if m.castTask <> invalid or m.castRequest = invalid then return
    command = m.castRequest
    castTrace("lookup")
    m.castTask = api("video", { bvid: strOf(command.bvid), aid: strOf(command.aid) }, "onCastVideo", m.castGeneration.ToStr())
end sub

sub castTrace(stage as String)
    m.castStage = stage
    elapsed = m.castClock.TotalMilliseconds() - m.castStartedAt
    print "[cast-ui] generation="; m.castGeneration; " stage="; stage; " ms="; elapsed
    m.cast.diagnostics = { generation: m.castGeneration, stage: stage, elapsedMs: elapsed }
end sub

sub onCastVideo(event as Object)
    task = event.getRoSGNode()
    if m.castTask = invalid then return
    if not m.castTask.isSameNode(task) then return
    m.castTask = invalid
    if task.tag <> m.castGeneration.ToStr() then
        print "[cast-ui] discarded generation="; task.tag
        startCastLookup()
        return
    end if
    if m.castRequest = invalid then return
    res = event.getData()
    if not res.ok then
        castTrace("lookup-error")
        print "[cast-ui] lookup failed: "; Left(strOf(res.error), 160)
        m.cast.playback = { state: 7, position: 0, duration: 0 }
        showToast("投屏视频加载失败：" + strOf(res.error))
        m.castRequest = invalid
        return
    end if
    v = res.data
    if v.pages.Count() = 0 then
        castTrace("no-parts")
        m.cast.playback = { state: 7, position: 0, duration: 0 }
        showToast("投屏视频没有可播放的分 P")
        m.castRequest = invalid
        return
    end if
    castTrace("details-ready")
    index = 0
    requestedCid = strOf(m.castRequest.cid)
    for i = 0 to v.pages.Count() - 1
        if strOf(v.pages[i].cid) = requestedCid then index = i
    end for
    startAt = intOf(m.castRequest.position)
    dur = intOf(v.pages[index].duration)
    if dur > 0 and startAt >= dur then startAt = 0
    while m.stack.Count() > 1
        current = m.stack.Peek()
        if current.Subtype() = "PlayerScreen" then current.castCommand = { action: "release" }
        pop()
    end while
    screen = CreateObject("roSGNode", "PlayerScreen")
    push(screen)
    screen.request = { bvid: v.bvid, aid: v.aid, title: v.title, up: v.up, poster: v.poster, pages: v.pages, index: index, startAt: startAt, castGeneration: m.castGeneration }
    castTrace("player-loading")
    m.castRequest = invalid
end sub

sub onCastTick()
    if m.cast = invalid then return
    m.cast.signedIn = m.global.loggedIn
    if m.castRequest <> invalid then
        if m.castClock.TotalMilliseconds() - m.castStartedAt > 30000 then
            m.castGeneration = m.castGeneration + 1
            m.castRequest = invalid
            if m.castTask <> invalid then m.castTask.cancelled = true
            castTrace("lookup-timeout")
            showToast("投屏请求超时，请重试")
        else
            return
        end if
    end if
    state = { state: 7, position: 0, duration: 0 }
    if m.stack.Count() > 0 then
        screen = m.stack.Peek()
        if screen.Subtype() = "PlayerScreen" and screen.castState <> invalid then state = screen.castState
    end if
    m.cast.playback = state
    if intOf(state.generation) = m.castGeneration and state.state = 4 and m.castStage = "player-loading" then castTrace("playing")
end sub
