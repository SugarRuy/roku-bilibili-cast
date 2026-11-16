' The real player integration runs against inert nodes: no decoder or TV commands.
sub main()
    m.checks = 0
    m.top = fakeNode()
    m.video = fakeNode()
    m.playbackInput = fakeNode()
    m.seekActive = false
    m.video.state = "playing"
    m.video.position = 125
    m.video.content = { id: "keep-this-stream" }
    m.video.control = "unchanged"
    m.danmaku = { enabled: true }
    m.panel = { visible: true, enabled: true, density: "normal", size: "normal", speed: "normal", area: 0.5, scrollEnabled: true, topEnabled: true, bottomEnabled: true, alpha: 0.8 }
    m.comments = fakeNode()
    m.comments.visible = false
    m.list = { visible: false }
    m.hud = { visible: true }
    m.hudTimer = {}
    m.spinner = {}
    m.error = {}
    m.req = { aid: "170001" }
    openComments()
    check(m.comments.visible and not m.panel.visible, "comments replace settings drawer")
    check(m.video.width = 1360 and m.video.height = 765, "video fits left side at 16:9")
    check(m.video.content.id = "keep-this-stream" and m.video.control = "unchanged" and m.video.position = 125, "opening never replaces or restarts the stream")
    check(not m.danmaku.enabled and m.panel.enabled, "temporary suppression keeps user preference")
    check(not m.hud.visible and m.hudTimer.control = "stop", "fullscreen HUD hidden")
    showHud(false)
    check(not m.hud.visible, "state changes cannot cover comments with HUD")
    closeComments()
    check(m.video.width = 1920 and m.video.height = 1080 and not m.comments.visible, "closing restores full video")
    check(m.danmaku.enabled and m.panel.enabled, "closing restores original danmaku on")
    m.panel.enabled = false
    m.video.state = "paused"
    openComments()
    closeComments()
    check(not m.danmaku.enabled and not m.panel.enabled, "original danmaku off stays off")
    check(m.video.state = "paused" and m.video.control = "unchanged", "opening and closing does not resume paused video")
    openComments()
    m.panel.enabled = true
    applyDanmakuSettings()
    check(not m.danmaku.enabled, "phone enable cannot show danmaku over comments")
    closeComments()
    check(m.danmaku.enabled, "closing applies latest user/phone preference")
    toggleCommentPlayback()
    check(m.video.control = "resume", "Play key resumes paused video")
    m.video.state = "playing"
    toggleCommentPlayback()
    check(m.video.control = "pause", "Play key pauses playing video")
    print "PASS comments_player"; m.checks
end sub
