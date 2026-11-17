sub main()
    m.checks = 0
    m.top = {}
    m.castReleased = false
    m.req = { castGeneration: 12 }
    m.saved = 0
    m.comments = { visible: true }
    m.hudTimer = { control: "start" }
    m.danmaku = { enabled: true, video: {}, cid: "42" }
    m.video = testVideo("player")
    m.video.state = "playing"
    m.video.listeners = { state: "onState", position: "onPosition" }
    m.playTask = { cancelled: false }
    m.videoTask = { cancelled: false }
    m.relatedTask = { cancelled: false }
    releasePlayback()
    check(m.castReleased and m.saved = 1, "release marks player inactive and saves once")
    check(not m.comments.visible and m.hudTimer.control = "stop", "release closes comments and HUD timer")
    check(not m.danmaku.enabled and m.danmaku.video = invalid and m.danmaku.cid = "", "release severs danmaku bindings")
    check(m.video.listeners.Count() = 0 and m.video.control = "stop", "release removes video listeners and stops decoder")
    check(m.playTask.cancelled and m.videoTask.cancelled and m.relatedTask.cancelled, "release cancels outstanding lookups")
    check(m.top.castState.state = 7 and m.top.castState.generation = 12, "released cast state is stopped before decoder callback")
    releasePlayback()
    check(m.saved = 1, "duplicate cleanup does not save again")
    m.top.castCommand = { action: "resume" }
    onPlayerCastCommand()
    check(m.video.control = "stop", "late command cannot restart released player")
    m.castReleased = false
    releasePlayback(false)
    check(m.saved = 1, "completion cleanup preserves already-finalized progress")
    m.castReleased = false
    m.switchingPlayback = false
    m.video.duration = 250
    m.video.position = 120
    m.video.seek = -1
    m.seekActive = true
    m.seekOrigin = 120
    m.seekTarget = 200
    m.seekWasPlaying = true
    m.top.castCommand = { action: "pause" }
    onPlayerCastCommand()
    check(not m.seekActive and m.video.control = "pause" and m.video.seek = -1, "phone pause cancels the local preview without committing it")
    m.seekActive = true
    m.top.castCommand = { action: "seek", position: 55 }
    onPlayerCastCommand()
    check(not m.seekActive and m.video.seek = 55, "phone seek overrides the preview target")
    m.seekActive = true
    m.video.state = "paused"
    m.top.castCommand = { action: "resume" }
    onPlayerCastCommand()
    check(not m.seekActive and m.video.control = "resume", "phone resume dismisses the preview")
    print "PASS playback_release"; m.checks
end sub

sub save(done as Boolean, leaving as Boolean)
    m.saved = m.saved + 1
end sub

sub navigate(action as Object)
end sub
