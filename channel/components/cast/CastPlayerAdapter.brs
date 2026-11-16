sub onPlayerCastCommand()
    command = m.top.castCommand
    action = strOf(command.action)
    if action = "stop" or action = "release" then
        releasePlayback()
        if action = "stop" then navigate({ action: "back" })
        return
    end if
    if m.castReleased then return
    if action = "pause" or action = "resume" or action = "seek" then cancelSeek(false)
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
    end if
    paintPlaybackProgress()
    publishCastState()
end sub

' Shared by Back, deep links, cast replacement and Home. Safe to call twice.
sub releasePlayback(savePosition = true as Boolean)
    if m.castReleased then return
    cancelSeek(false)
    m.castReleased = true
    if savePosition and m.req <> invalid then save(false, true)
    m.comments.visible = false
    m.hudTimer.control = "stop"
    m.danmaku.enabled = false
    m.danmaku.video = invalid
    m.danmaku.cid = ""
    for each task in [m.playTask, m.videoTask, m.relatedTask, m.interactionTask, m.interactionActionTask]
        if task <> invalid then task.cancelled = true
    end for
    m.video.unobserveFieldScoped("position")
    m.video.unobserveFieldScoped("state")
    m.video.control = "stop"
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
    if m.castReleased then
        m.top.castState = { state: 7, position: 0, duration: 0, generation: generation }
        return
    end if
    position = Int(m.video.position)
    if m.switchingPlayback and m.qualityResumePending and position < 1 then
        state = 3
        position = m.startAt
    end if
    m.top.castState = { state: state, position: position, duration: Int(m.video.duration), generation: generation }
end sub
