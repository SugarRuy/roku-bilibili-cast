sub onPlayerCastCommand()
    command = m.top.castCommand
    action = strOf(command.action)
    if action = "pause" then
        m.video.control = "pause"
    else if action = "resume" then
        if m.video.state = "paused" then m.video.control = "resume"
    else if action = "seek" then
        seconds = intOf(command.position)
        if seconds >= 0 and (m.video.duration <= 0 or seconds < m.video.duration) then m.video.seek = seconds
    else if action = "danmaku" then
        m.panel.enabled = command.enabled
        applyDanmakuSettings()
    else if action = "stop" or action = "release" then
        m.castReleased = true
        if m.playTask <> invalid then m.playTask.cancelled = true
        if m.videoTask <> invalid then m.videoTask.cancelled = true
        if m.relatedTask <> invalid then m.relatedTask.cancelled = true
        if m.req <> invalid then save(false, true)
        m.video.control = "stop"
        if action = "stop" then navigate({ action: "back" })
    end if
    publishCastState()
end sub

sub publishCastState()
    state = 7
    if m.video.state = "buffering" then state = 3
    if m.video.state = "playing" then state = 4
    if m.video.state = "paused" then state = 5
    if m.video.state = "finished" then state = 6
    generation = 0
    if m.req <> invalid then generation = intOf(m.req.castGeneration)
    position = Int(m.video.position)
    if m.switchingPlayback and m.qualityResumePending and position < 1 then
        state = 3
        position = m.startAt
    end if
    m.top.castState = { state: state, position: position, duration: Int(m.video.duration), generation: generation }
end sub
