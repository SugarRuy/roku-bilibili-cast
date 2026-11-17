' Deliver delayed Task results in a chosen order; no HTTP/account operations.
sub main()
    m.checks = 0
    resetPlayer()
    openVideo(videoData("A"))
    first = m.videoTask
    openVideo(videoData("B"))
    second = m.videoTask
    onVideoInfo(response(first, { ok: true, data: videoData("A") }))
    check(m.req.bvid = "original", "old video details cannot start after a newer selection")
    check(first.cancelled and m.videoTask.isSameNode(second), "new selection cancels and retains only its own lookup")
    onVideoInfo(response(second, { ok: true, data: videoData("B") }))
    check(m.req.bvid = "B" and m.videoTask = invalid, "latest video details start and release task")
    check(m.playTask.params.bvid = "B", "stream belongs to selected video")

    resetPlayer()
    loadRelated("A")
    first = m.relatedTask
    loadRelated("B")
    second = m.relatedTask
    onRelatedLoaded(response(first, { ok: true, data: { items: ["old"] } }))
    check(m.related.Count() = 0 and first.cancelled, "old recommendations cannot replace new context")
    onRelatedLoaded(response(second, { ok: true, data: { items: ["new"] } }))
    check(m.related[0] = "new" and m.relatedTask = invalid, "current recommendations accepted once")
    onRelatedLoaded(response(second, { ok: true, data: { items: ["duplicate"] } }))
    check(m.related[0] = "new", "completed lookup cannot publish twice")

    resetPlayer()
    requestStream("auto")
    oldStream = m.playTask
    openVideo(videoData("B"))
    onPlay(response(oldStream, playResult("old-stream")))
    check(m.applied.Count() = 0 and oldStream.cancelled, "late old stream cannot restart playback during video lookup")
    check(not m.pendingQuality and not m.pauseAfterStart, "new video clears old quality and pause recovery")
    m.panel.qualityChoice = "64"
    onQualityChoice()
    check(m.playTask = invalid and m.qualityChoice = "64", "quality preference during lookup never reloads the old video")
    onVideoInfo(response(m.videoTask, { ok: true, data: videoData("B") }))
    check(m.playTask.params.quality = "64", "new video uses updated quality preference")
    current = m.playTask
    onPlay(response(current, playResult("new-stream")))
    check(m.applied.Count() = 1 and m.applied[0] = "new-stream" and m.playTask = invalid, "only current stream applies and releases task")
    onPlay(response(current, playResult("duplicate")))
    check(m.applied.Count() = 1, "duplicate play completion is ignored")

    resetPlayer()
    openVideo(videoData("B"))
    current = m.videoTask
    m.format = "dash"
    m.video.state = "error"
    onState()
    check(m.videoTask.isSameNode(current) and m.playTask = invalid, "old decoder error cannot fall back to the old video during lookup")
    m.video.state = "finished"
    onState()
    check(not m.finished and m.videoTask.isSameNode(current), "old finish notification cannot auto-advance or cancel new selection")
    onVideoInfo(response(current, { ok: false, error: "synthetic lookup failure" }))
    m.panel.qualityChoice = "64"
    onQualityChoice()
    check(m.playTask = invalid and m.error.text <> "", "quality after failed selection cannot resurrect previous video")
    openVideo(videoData("C"))
    onVideoInfo(response(m.videoTask, { ok: true, data: videoData("C") }))
    check(not m.loadingVideo and m.playTask.params.bvid = "C", "new selection recovers after failed lookup")

    resetPlayer()
    refreshInteractions(false)
    first = m.interactionTask
    refreshInteractions(false)
    second = m.interactionTask
    onInteractionStatus(response(first, statusResult()))
    check(not m.interactionMenu.visible and first.cancelled, "older status request cannot open interaction menu")
    onInteractionStatus(response(second, statusResult()))
    check(m.interactionMenu.visible and m.interactionTask = invalid, "current status opens menu")
    m.interactionMenu.visible = false
    refreshInteractions(false)
    first = m.interactionTask
    closePanel()
    onInteractionStatus(response(first, statusResult()))
    check(first.cancelled and not m.interactionMenu.visible, "closing settings cancels lookup and rejects its late menu")

    resetPlayer()
    refreshInteractions(false)
    first = m.interactionTask
    m.panel.visible = false
    onInteractionStatus(response(first, statusResult()))
    check(not m.interactionMenu.visible and m.interactionTask = invalid, "sidebar hidden by another view cannot regain focus from late status")
    resetPlayer()
    submitInteraction("coin", 1)
    action = m.interactionActionTask
    submitInteraction("coin", 1)
    check(m.requests.Count() = 1 and m.interactionActionTask.isSameNode(action), "pending action cannot be submitted twice")
    m.panel.visible = false
    onInteractionAction(response(action, { ok: false, error: "synthetic failure" }))
    check(not m.interactionMenu.visible and m.interactionActionTask = invalid, "failed action does not reopen a closed menu")
    refreshInteractions(true)
    check(m.interactionTask = invalid, "silent refresh does not fetch for a closed sidebar")
    m.castReleased = true
    onVideoInfo(response(action, { ok: true, data: videoData("late") }))
    check(m.req.bvid = "original", "released screen ignores lookup completion")
    issued = m.requests.Count()
    openVideo(videoData("late"))
    loadRelated("late")
    requestStream("auto")
    startPart(0, 0, "auto")
    check(m.requests.Count() = issued, "queued actions cannot start background requests after release")
    print "PASS player_requests"; m.checks
end sub

sub resetPlayer()
    m.top = {}
    m.global = { loggedIn: true }
    m.castReleased = false
    m.loadingVideo = false
    m.finished = false
    m.requests = []
    m.applied = []
    m.toasts = []
    m.video = { control: "", state: "paused", position: 123, duration: 300 }
    m.comments = { aid: "", visible: false }
    m.panel = fakeNode()
    m.panel.qualityChoice = "auto"
    m.interactionMenu = fakeNode()
    m.interactionMenu.visible = false
    m.coinMenu = fakeNode()
    m.coinMenu.visible = false
    m.playbackInput = fakeNode()
    m.danmaku = {}
    m.error = {}
    m.loading = {}
    m.titleLabel = {}
    m.subLabel = {}
    m.req = videoData("original")
    m.part = m.req.pages[0]
    m.played = {}
    m.related = []
    m.playSerial = 1
    m.pendingQuality = true
    m.pauseAfterStart = true
    m.switchingPlayback = true
    m.qualityResumePending = true
    m.qualityChoice = "auto"
    m.suppressQualityChoice = false
    m.playTask = invalid
    m.videoTask = invalid
    m.relatedTask = invalid
    m.interactionTask = invalid
    m.interactionActionTask = invalid
    m.interactionStatus = { folder: "folder" }
end sub

function videoData(id as String) as Object
    return { bvid: id, aid: id, title: id, up: "author", poster: "", pages: [{ cid: "cid-" + id, part: "P1" }] }
end function

function playResult(marker as String) as Object
    return { ok: true, data: { marker: marker, qualities: [], quality: 64, quality_name: "720P" } }
end function

function statusResult() as Object
    return { ok: true, data: { liked: 0, favorite: 0, later: 0, coins: 0, folder: "folder" } }
end function

function api(op as String, params as Dynamic, callback as String, tag = "" as String) as Object
    task = { id: m.requests.Count(), op: op, params: params, tag: tag, cancelled: false, isSameNode: sameRequest }
    m.requests.Push(task)
    return task
end function

function sameRequest(other as Object) as Boolean
    return m.id = other.id
end function

function response(task as Object, result as Object) as Object
    return { task: task, result: result, getRoSGNode: responseTask, getData: responseData }
end function

function responseTask() as Object
    return m.task
end function

function responseData() as Object
    return m.result
end function

sub applyPlayData(data as Object, startAt as Integer)
    m.applied.Push(data.marker)
end sub

sub buildList()
end sub

sub showHud(autoHide as Boolean)
end sub

sub cancelSeek(restore = true as Boolean)
end sub

function loadProgress(bvid as String) as Dynamic
    return invalid
end function

sub saveSetting(key as String, value as String)
end sub

sub navigate(action as Object)
    m.toasts.Push(action)
end sub

sub showError(message as String)
    m.error.text = message
end sub

sub publishCastState()
end sub

sub paintPlaybackProgress()
end sub

sub onFinished()
    m.finished = true
end sub
