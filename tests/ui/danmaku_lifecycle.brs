sub main()
    m.checks = 0
    m.top = fakeNode()
    m.top.enabled = false
    m.top.area = 0.5
    m.top.density = "normal"
    m.top.size = "normal"
    m.top.speed = "normal"
    init()
    video = testVideo("first")
    m.top.video = video
    onVideo()
    check(video.listeners.Count() = 0, "disabled layer does not observe video")
    m.top.enabled = true
    onVideo()
    check(video.listeners.Count() = 2, "enabled layer observes state and position")
    check(m.basePos = 4 and not m.playing, "binding samples current paused position")
    video.position = "forbidden readback"
    video.state = "forbidden readback"
    onPosition(testEvent(video, 10.25, {}))
    check(m.basePos = 10.25, "position callback consumes event without reading decoder")
    onState(testEvent(video, "playing", { position: 10.5 }))
    check(m.playing and m.basePos = 10.5, "state callback uses event context position")
    onState(testEvent(video, "paused", { position: 10.6 }))
    check(not m.playing and m.tick.control = "stop", "pause stops clock and timer")
    replacement = testVideo("second")
    replacement.position = 30
    m.top.video = replacement
    onVideo()
    check(video.listeners.Count() = 0 and replacement.listeners.Count() = 2, "rebinding detaches only old layer listeners")
    check(video.otherObserver, "other components' observer remains")
    onPosition(testEvent(video, 99, {}))
    check(m.basePos = 30, "late event from old video is ignored")
    m.top.enabled = false
    onEnabled()
    check(replacement.listeners.Count() = 0 and m.boundVideo = invalid, "turning off detaches listeners")
    check(not m.top.visible and not m.playing, "disabled layer is hidden and clock stopped")
    onPosition(testEvent(replacement, 88, {}))
    check(m.basePos = 30, "disabled layer ignores queued position")
    replacement.position = 60
    replacement.state = "playing"
    m.top.enabled = true
    onEnabled()
    check(m.basePos = 60 and m.playing and m.top.visible, "reenabling resyncs current playback")
    m.top.video = invalid
    onVideo()
    check(m.boundVideo = invalid and replacement.listeners.Count() = 0, "release detaches video")
    check(m.tick.control = "stop" and not m.playing, "release stops animation clock")
    pending = { cancelled: false }
    m.task = pending
    m.top.cid = ""
    onCid()
    check(pending.cancelled and m.task = invalid and m.items.Count() = 0, "release cancels danmaku download")
    print "PASS danmaku_lifecycle"; m.checks
end sub

function testVideo(id as String) as Object
    return { id: id, position: 4.0, state: "paused", listeners: {}, otherObserver: true, observeFieldScoped: observeVideo, unobserveFieldScoped: unobserveVideo, isSameNode: sameVideo }
end function

sub observeVideo(field as String, callback as String, info = invalid as Dynamic)
    m.listeners[field] = callback
end sub

sub unobserveVideo(field as String)
    m.listeners.Delete(field)
end sub

function sameVideo(other as Object) as Boolean
    return m.id = other.id
end function

function testEvent(node as Object, value as Dynamic, info as Object) as Object
    return { node: node, value: value, info: info, getData: eventValue, getInfo: eventInfo, getRoSGNode: eventVideo }
end function

function eventValue() as Dynamic
    return m.value
end function

function eventInfo() as Object
    return m.info
end function

function eventVideo() as Object
    return m.node
end function
