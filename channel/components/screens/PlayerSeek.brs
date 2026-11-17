' VOD input belongs to the screen, not the native Video trick-play UI.
' Browsing a target never seeks the decoder; OK/Play commits exactly once.
sub initPlaybackInput()
    m.playbackInput = m.top.findNode("playbackInput")
    m.seekLabel = m.top.findNode("seekLabel")
    m.seekTime = m.top.findNode("seekTime")
    m.seekHint = m.top.findNode("seekHint")
    m.seekFill = m.top.findNode("seekFill")
    m.seekMarker = m.top.findNode("seekMarker")
    m.seekHoldTimer = m.top.findNode("seekHoldTimer")
    m.seekHoldTimer.observeField("fire", "onSeekHold")
    m.seekHoldClock = CreateObject("roTimespan")
    m.heldSeekKey = ""
    m.seekLabel.font = cjkFont(30)
    m.seekTime.font = cjkFont(30)
    m.seekHint.font = cjkFont(26)
    m.seekFill.color = accent()
    m.seekMarker.color = accent()
    m.seekActive = false
    m.transportHeld = ""
end sub

function beginSeek() as Boolean
    if m.castReleased then return false
    if m.video.state <> "playing" and m.video.state <> "paused" then return false
    if m.video.duration <= 0 then return false
    m.seekOrigin = m.video.position
    m.seekTarget = m.seekOrigin
    m.seekWasPlaying = m.video.state = "playing"
    m.seekActive = true
    if m.seekWasPlaying then m.video.control = "pause"
    showHud(false)
    paintPlaybackProgress()
    print "[seek] begin position="; m.seekOrigin
    return true
end function

function boundedSeek(position as Float) as Float
    last = m.video.duration * 1.0 - 1.0
    if last < 0 then last = 0.0
    if position < 0 then return 0.0
    if position > last then return last
    return position
end function

sub moveSeek(delta as Integer)
    target = boundedSeek(m.seekTarget + delta)
    if target = m.seekTarget then return
    m.seekTarget = target
    paintPlaybackProgress()
end sub

sub endSeekHold()
    m.heldSeekKey = ""
    if m.seekHoldTimer <> invalid then m.seekHoldTimer.control = "stop"
end sub

sub onSeekHold()
    if m.seekActive <> true or m.castReleased or m.heldSeekKey = "" then
        endSeekHold()
        return
    end if
    if m.seekHoldClock.TotalMilliseconds() < 450 then return
    delta = 10
    if m.heldSeekKey = "rewind" or m.heldSeekKey = "left" then delta = -10
    moveSeek(delta)
end sub

sub commitSeek()
    if m.seekActive <> true then return
    endSeekHold()
    target = m.seekTarget
    origin = m.seekOrigin
    m.seekActive = false
    ' A first press followed by OK just resumes. Do not seek back to a keyframe.
    if Abs(target - origin) >= 0.1 then m.video.seek = target
    m.video.control = "resume"
    showHud(true)
    paintPlaybackProgress()
    print "[seek] commit origin="; origin; " target="; target
end sub

' false is for teardown/replacement or a phone command that takes control.
sub cancelSeek(restorePlayback = true as Boolean)
    if m.seekActive <> true then return
    endSeekHold()
    m.seekActive = false
    if restorePlayback and m.seekWasPlaying then m.video.control = "resume"
    if restorePlayback then
        showHud(m.seekWasPlaying)
        paintPlaybackProgress()
    end if
    print "[seek] cancel position="; m.seekOrigin
end sub

sub paintPlaybackProgress()
    if m.seekLabel = invalid then return
    if not m.hud.visible then return
    position = m.video.position
    duration = m.video.duration
    if m.seekActive then
        position = m.seekTarget
        m.seekLabel.text = "选择播放位置"
        m.seekHint.text = "快退 / 快进或左右调整 · 长按连续移动 · OK / 播放确认 · 返回取消"
    else
        m.seekLabel.text = "播放"
        if m.video.state = "paused" then m.seekLabel.text = "已暂停"
        m.seekHint.text = "快退 / 快进键 选择位置 · OK / 播放键 暂停或继续"
    end if
    m.seekTime.text = fmtTime(Int(position)) + " / " + fmtTime(Int(duration))
    ratio = 0
    if duration > 0 then ratio = position / duration
    if ratio < 0 then ratio = 0
    if ratio > 1 then ratio = 1
    m.seekFill.width = 1728 * ratio
    m.seekMarker.translation = [1728 * ratio - 5, 68]
end sub

function handlePlaybackKey(key as String, press as Boolean) as Boolean
    seekKey = key = "fastforward" or key = "rewind" or key = "left" or key = "right"
    confirmKey = key = "OK" or key = "play"
    if not press then
        if key = m.heldSeekKey then endSeekHold()
        wasHeld = key = m.transportHeld
        if key = m.transportHeld then m.transportHeld = ""
        if seekKey and m.seekActive then print "[seek] preview target="; m.seekTarget
        return wasHeld or seekKey or confirmKey or key = "replay"
    end if
    if m.castReleased then return true
    if key = "back" and m.transportHeld = "back" then return true
    if seekKey then
        ' Some keys/devices repeat keydown; our timer owns repetition so both
        ' real remotes and ECP down/up get one consistent held-key behavior.
        if m.heldSeekKey = key then return true
        wasSeeking = m.seekActive
        if not wasSeeking then
            if not beginSeek() then return true
        end if
        ' Dedicated transport keys first pause/open the picker, as on YouTube.
        ' Direction keys still move immediately.
        if wasSeeking or key = "left" or key = "right" then
            delta = 10
            if key = "rewind" or key = "left" then delta = -10
            moveSeek(delta)
        end if
        m.heldSeekKey = key
        m.seekHoldClock.Mark()
        m.seekHoldTimer.control = "start"
        return true
    else if confirmKey then
        ' Ignore repeat keydowns and consume keyup: one press, one action.
        if m.transportHeld = key then return true
        m.transportHeld = key
        if m.seekActive then
            commitSeek()
        else if m.video.state = "playing" then
            m.video.control = "pause"
        else if m.video.state = "paused" then
            m.video.control = "resume"
        end if
        return true
    else if key = "back" and m.seekActive then
        m.transportHeld = key
        cancelSeek()
        return true
    else if key = "replay" then
        cancelSeek(false)
        if m.video.duration > 0 then
            m.video.seek = boundedSeek(m.video.position - 10)
            m.video.control = "resume"
            showHud(true)
        end if
        return true
    end if
    return false
end function
