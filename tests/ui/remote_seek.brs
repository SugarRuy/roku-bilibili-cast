' Production input/state machine; the fake decoder never changes position itself.
sub main()
    m.checks = 0
    resetPlayer()
    check(onKeyEvent("fastforward", true), "dedicated fast forward is handled")
    check(m.seekActive and m.video.control = "pause", "first press pauses and opens picker")
    check(m.seekTarget = 120 and m.video.seek = -1, "first press does not move or seek")
    check(onKeyEvent("fastforward", false) and m.seekActive, "release leaves picker open")
    onKeyEvent("fastforward", true)
    check(m.seekTarget = 130 and m.video.seek = -1, "second press changes only the target by ten seconds")
    onKeyEvent("rewind", true)
    check(m.seekTarget = 120, "opposite key reverses the target")
    for i = 1 to 40
        onKeyEvent("fastforward", true)
        onKeyEvent("fastforward", false)
    end for
    check(m.seekTarget = 249 and m.video.seek = -1, "repeat events clamp to end without decoder seeks")
    onKeyEvent("fastforward", false)
    check(m.video.position = 120, "holding and releasing never changes the real position")
    onKeyEvent("OK", true)
    check(not m.seekActive and m.video.seek = 249 and m.video.control = "resume", "OK commits the target and resumes")
    m.video.control = "untouched"
    onKeyEvent("OK", true)
    check(m.video.control = "untouched", "held OK does not toggle again")
    onKeyEvent("OK", false)
    check(m.video.control = "untouched", "OK release cannot pause after confirming")
    onKeyEvent("OK", true)
    check(m.video.control = "pause", "next separate OK still toggles normal playback")

    resetPlayer()
    onKeyEvent("rewind", true)
    onKeyEvent("rewind", false)
    onKeyEvent("play", true)
    check(m.video.seek = -1 and m.video.control = "resume", "confirming unchanged position avoids needless buffering")
    m.video.control = "untouched"
    onKeyEvent("play", false)
    check(m.video.control = "untouched", "Play release is not a second action")

    resetPlayer()
    onKeyEvent("fastforward", true)
    onKeyEvent("fastforward", false)
    onKeyEvent("fastforward", true)
    onKeyEvent("back", true)
    check(not m.seekActive and m.video.seek = -1 and m.video.control = "resume", "Back cancels without committing and resumes original position")
    onKeyEvent("back", true)
    check(m.exits = 0, "holding cancel cannot leave the player")
    onKeyEvent("back", false)
    onKeyEvent("back", true)
    check(m.exits = 1, "a separate Back still exits normally")

    resetPlayer()
    m.video.state = "paused"
    onKeyEvent("rewind", true)
    onKeyEvent("rewind", false)
    onKeyEvent("rewind", true)
    onKeyEvent("back", true)
    check(m.video.seek = -1 and m.video.control = "untouched", "cancel preserves a preexisting pause")

    resetPlayer()
    onKeyEvent("left", true)
    check(m.seekTarget = 110, "direction left still moves on its first press")
    onKeyEvent("right", true)
    check(m.seekTarget = 120, "direction right adjusts the same picker")
    for i = 1 to 40
        onKeyEvent("rewind", true)
        onKeyEvent("rewind", false)
    end for
    check(m.seekTarget = 0 and m.video.seek = -1, "rewind clamps at zero")
    onKeyEvent("play", true)
    check(m.video.seek = 0 and m.video.control = "resume", "Play confirms rewinding to start")

    resetPlayer()
    m.video.duration = 0
    onKeyEvent("fastforward", true)
    check(not m.seekActive and m.video.control = "untouched", "unknown duration is not seekable")
    m.video.duration = 250
    m.video.state = "buffering"
    onKeyEvent("fastforward", true)
    check(not m.seekActive and m.video.seek = -1, "buffering cannot start a stale seek")
    m.video.state = "playing"
    m.castReleased = true
    onKeyEvent("fastforward", true)
    check(not m.seekActive and m.video.control = "untouched", "retired player ignores transport keys")

    resetPlayer()
    onKeyEvent("fastforward", true)
    onKeyEvent("fastforward", false)
    onKeyEvent("fastforward", true)
    m.video.control = "replacement"
    cancelSeek(false)
    check(not m.seekActive and m.video.seek = -1 and m.video.control = "replacement", "teardown or phone takeover discards preview without resuming")

    resetPlayer()
    onKeyEvent("replay", true)
    check(m.video.seek = 110 and m.video.control = "resume", "instant replay remains an immediate ten-second skip")
    resetPlayer()
    m.comments.visible = true
    onKeyEvent("fastforward", true)
    onKeyEvent("OK", false)
    check(not m.seekActive and m.video.control = "untouched", "comments keep playback keys and releases isolated")

    resetPlayer()
    m.seekLabel = {}
    m.seekTime = {}
    m.seekHint = {}
    m.seekFill = {}
    m.seekMarker = {}
    m.hud = { visible: true }
    onKeyEvent("fastforward", true)
    onKeyEvent("fastforward", false)
    onKeyEvent("fastforward", true)
    check(m.seekTime.text = "2:10 / 4:10", "picker displays target and duration")
    check(m.seekFill.width > 898 and m.seekFill.width < 899, "timeline reflects target instead of decoder position")
    m.video.duration = 0.5
    check(boundedSeek(10) = 0, "subsecond videos have a valid nonnegative bound")

    resetPlayer()
    onKeyEvent("fastforward", true)
    onKeyEvent("fastforward", true)
    check(m.seekTarget = 120, "repeated keydown does not double-count timer movement")
    m.seekHoldClock.elapsed = 400
    onSeekHold()
    check(m.seekTarget = 120, "short hold delay prevents a tap from moving")
    m.seekHoldClock.elapsed = 500
    onSeekHold()
    check(m.seekTarget = 130 and m.video.seek = -1, "held key timer moves only the preview")
    onSeekHold()
    check(m.seekTarget = 140, "holding continuously advances the target")
    onKeyEvent("fastforward", false)
    onSeekHold()
    check(m.seekTarget = 140 and m.seekHoldTimer.control = "stop", "release immediately stops further movement")
    onKeyEvent("rewind", true)
    m.seekHoldClock.elapsed = 500
    onSeekHold()
    check(m.seekTarget = 120, "opposite held key reverses immediately then repeats")
    cancelSeek(false)
    onSeekHold()
    check(m.seekHoldTimer.control = "stop" and m.video.seek = -1, "phone takeover or replacement stops held-key timer")
    print "PASS remote_seek"; m.checks
end sub

sub resetPlayer()
    m.video = { state: "playing", position: 120, duration: 250, seek: -1, control: "untouched" }
    m.castReleased = false
    m.seekActive = false
    m.transportHeld = ""
    m.heldSeekKey = ""
    m.seekHoldTimer = {}
    m.seekHoldClock = { elapsed: 0, Mark: markHold, TotalMilliseconds: holdMillis }
    m.comments = { visible: false }
    m.seekLabel = invalid
    m.exits = 0
end sub

sub markHold()
    m.elapsed = 0
end sub

function holdMillis() as Integer
    return m.elapsed
end function

sub showHud(autoHide as Boolean)
end sub

sub releasePlayback()
    m.exits = m.exits + 1
end sub

sub navigate(action as Object)
end sub

sub openList()
end sub

sub openPanel()
end sub
