sub init()
    m.video = m.top.findNode("video")
    m.hud = m.top.findNode("hud")
    m.titleLabel = m.top.findNode("title")
    m.subLabel = m.top.findNode("sub")
    m.quality = m.top.findNode("quality")
    m.loading = m.top.findNode("loading")
    m.spinner = m.top.findNode("spinner")
    m.error = m.top.findNode("error")
    m.hudTimer = m.top.findNode("hudTimer")
    m.danmaku = m.top.findNode("danmaku")
    m.panel = m.top.findNode("panel")
    m.keywordEditor = m.top.findNode("keywordEditor")
    m.list = m.top.findNode("list")
    m.dmHint = m.top.findNode("dmHint")

    m.titleLabel.font = cjkFont(42)
    m.subLabel.font = cjkFont(28)
    m.quality.font = cjkFont(30)
    m.dmHint.font = cjkFont(30)
    m.dmHint.color = accent()
    m.top.findNode("loadingText").font = cjkFont(28)
    m.error.font = cjkFont(32)
    m.spinner.poster.uri = themed("spinner")
    m.quality.color = accent()
    m.spinner.control = "start"

    m.video.trickPlayBar.filledBarBlendColor = accent()
    m.video.bufferingBar.filledBarBlendColor = accent()
    m.video.retrievingBar.filledBarBlendColor = accent()
    m.video.notificationInterval = 1

    m.video.observeField("state", "onState")
    m.video.observeField("position", "onPosition")
    m.hudTimer.observeField("fire", "hideHud")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.lastSaved = 0
    m.lastReport = 0
    m.stateClock = CreateObject("roTimespan")
    m.shownOnce = false
    m.format = ""
    m.related = []
    m.played = {}
    m.castReleased = false
    m.playSerial = 0
    m.pendingQuality = false
    m.switchingPlayback = false
    m.qualityResumePending = false
    m.pauseAfterStart = false
    m.qualityChoice = loadSetting("vod_quality", "auto")
    m.appliedQualityChoice = m.qualityChoice
    m.suppressQualityChoice = false

    ' play mode and danmaku live in the registry; the panel edits them
    m.danmaku.video = m.video
    m.keywords = storedKeywords()
    m.danmaku.keywords = m.keywords
    m.panel.mode = playMode()
    m.panel.enabled = loadSetting("dm_on", "1") = "1"
    m.panel.alpha = Val(loadSetting("dm_alpha", "0.8"))
    m.panel.area = Val(loadSetting("dm_area", "0.5"))
    m.panel.density = loadSetting("dm_density", "normal")
    m.panel.size = loadSetting("dm_size", "normal")
    m.panel.speed = loadSetting("dm_speed", "normal")
    m.panel.scrollEnabled = loadSetting("dm_scroll", "1") = "1"
    m.panel.topEnabled = loadSetting("dm_top", "1") = "1"
    m.panel.bottomEnabled = loadSetting("dm_bottom", "1") = "1"
    m.panel.keywordCount = m.keywords.Count()
    m.panel.qualityChoice = m.qualityChoice
    applyDanmakuSettings()
    m.panel.observeField("mode", "onPanelSettings")
    m.panel.observeField("enabled", "onPanelSettings")
    m.panel.observeField("alpha", "onPanelSettings")
    m.panel.observeField("area", "onPanelSettings")
    m.panel.observeField("density", "onPanelSettings")
    m.panel.observeField("size", "onPanelSettings")
    m.panel.observeField("speed", "onPanelSettings")
    m.panel.observeField("scrollEnabled", "onPanelSettings")
    m.panel.observeField("topEnabled", "onPanelSettings")
    m.panel.observeField("bottomEnabled", "onPanelSettings")
    m.panel.observeField("keywordRequested", "openKeywordEditor")
    m.panel.observeField("listRequested", "onPanelList")
    m.panel.observeField("qualityChoice", "onQualityChoice")
    m.keywordEditor.observeField("updated", "onKeywordsUpdated")
    m.keywordEditor.observeField("closed", "closeKeywordEditor")
    m.panel.observeField("closed", "closePanel")
    m.list.observeField("chosen", "onListChosen")
    m.list.observeField("closed", "closeList")
    m.danmaku.observeField("count", "onDanmakuCount")
    onDanmakuCount()
end sub

sub applyDanmakuSettings()
    if m.danmaku.density <> m.panel.density then m.danmaku.density = m.panel.density
    if m.danmaku.size <> m.panel.size then m.danmaku.size = m.panel.size
    if m.danmaku.speed <> m.panel.speed then m.danmaku.speed = m.panel.speed
    if m.danmaku.area <> m.panel.area then m.danmaku.area = m.panel.area
    if m.danmaku.scrollEnabled <> m.panel.scrollEnabled then m.danmaku.scrollEnabled = m.panel.scrollEnabled
    if m.danmaku.topEnabled <> m.panel.topEnabled then m.danmaku.topEnabled = m.panel.topEnabled
    if m.danmaku.bottomEnabled <> m.panel.bottomEnabled then m.danmaku.bottomEnabled = m.panel.bottomEnabled
    if m.danmaku.opacity <> m.panel.alpha then m.danmaku.opacity = m.panel.alpha
    if m.danmaku.enabled <> m.panel.enabled then m.danmaku.enabled = m.panel.enabled
end sub

function storedKeywords() as Object
    words = ParseJson(loadSetting("dm_keywords", "[]"))
    if type(words) <> "roArray" then return []
    result = []
    for each word in words
        if type(word) = "roString" and word <> "" then result.Push(word)
        if result.Count() >= 20 then exit for
    end for
    return result
end function

sub onPanelSettings(event as Object)
    applyDanmakuSettings()
    field = event.getField()
    if field = "mode" then saveSetting("play_mode", m.panel.mode)
    if field = "enabled" then
        value = "0"
        if m.panel.enabled then value = "1"
        saveSetting("dm_on", value)
    end if
    if field = "alpha" then saveSetting("dm_alpha", Str(m.panel.alpha).Trim())
    if field = "area" then saveSetting("dm_area", Str(m.panel.area).Trim())
    if field = "density" then saveSetting("dm_density", m.panel.density)
    if field = "size" then saveSetting("dm_size", m.panel.size)
    if field = "speed" then saveSetting("dm_speed", m.panel.speed)
    if field = "scrollEnabled" then saveSetting("dm_scroll", boolSetting(m.panel.scrollEnabled))
    if field = "topEnabled" then saveSetting("dm_top", boolSetting(m.panel.topEnabled))
    if field = "bottomEnabled" then saveSetting("dm_bottom", boolSetting(m.panel.bottomEnabled))
    onDanmakuCount()
end sub

function boolSetting(value as Boolean) as String
    if value then return "1"
    return "0"
end function

sub onPanelList()
    closePanel()
    openList()
end sub

sub onQualityChoice()
    if m.suppressQualityChoice then return
    choice = m.panel.qualityChoice
    if choice = m.qualityChoice then return
    m.qualityChoice = choice
    saveSetting("vod_quality", choice)
    if m.req = invalid or m.part = invalid then return
    m.pendingQuality = m.video.state = "playing" or m.video.state = "paused"
    if m.pendingQuality then m.qualityFromChoice = m.appliedQualityChoice
    requestStream("auto")
end sub

sub restoreQualityChoice()
    choice = strOf(m.qualityFromChoice)
    if choice = "" then choice = "auto"
    m.qualityChoice = choice
    m.appliedQualityChoice = choice
    saveSetting("vod_quality", choice)
    m.suppressQualityChoice = true
    m.panel.qualityChoice = choice
    m.suppressQualityChoice = false
end sub

sub openKeywordEditor()
    m.keywordWasPlaying = m.video.state = "playing"
    if m.keywordWasPlaying then m.video.control = "pause"
    m.keywordEditor.keywords = m.keywords
    m.keywordEditor.visible = true
    m.keywordEditor.setFocus(true)
end sub

sub onKeywordsUpdated()
    m.keywords = m.keywordEditor.updated
    saveSetting("dm_keywords", FormatJson(m.keywords))
    m.danmaku.keywords = m.keywords
    m.panel.keywordCount = m.keywords.Count()
end sub

sub closeKeywordEditor()
    m.keywordEditor.visible = false
    m.panel.setFocus(true)
    if m.keywordWasPlaying and m.video.state = "paused" then m.video.control = "resume"
end sub

sub onDanmakuCount()
    n = m.danmaku.count
    m.panel.count = n
    keys = "↑ 播放设置    ↓ 选集/推荐"
    if not m.panel.enabled then
        m.dmHint.text = "弹幕 关    " + keys
    else if n > 0 then
        m.dmHint.text = "弹幕 开    " + keys
    else
        m.dmHint.text = "弹幕 开    " + keys
    end if
end sub

sub openPanel()
    m.panel.visible = true
    m.panel.setFocus(true)
    showHud(false)
end sub

sub closePanel()
    m.panel.visible = false
    m.video.setFocus(true)
    showHud(true)
end sub

' ---------- the video list drawer ----------

sub openList()
    if m.list.content = invalid then return
    if m.req.pages.Count() > 1 then
        m.list.focusItem = [0, m.index]
    else
        m.list.focusItem = [0, 0]
    end if
    m.list.visible = true
    m.list.setFocus(true)
end sub

sub closeList()
    m.list.visible = false
    m.video.setFocus(true)
end sub

' Rows: the parts of this video (when there are several), then related videos.
sub buildList()
    root = CreateObject("roSGNode", "ContentNode")
    m.listRows = []
    pages = m.req.pages
    if pages.Count() > 1 then
        items = []
        for i = 0 to pages.Count() - 1
            p = pages[i]
            title = "P" + (i + 1).ToStr() + "  " + strOf(p.part)
            if i = m.index then title = "▶ " + title
            items.Push({ bvid: m.req.bvid, title: title, up: "", poster: strOf(m.req.poster), duration: intOf(p.duration), duration_text: fmtTime(intOf(p.duration)), view_text: "", date_text: "", progress: 0 })
        end for
        row = root.createChild("ContentNode")
        row.title = "选集（" + pages.Count().ToStr() + "P）"
        cardsToContent(items, row)
        m.listRows.Push("parts")
    end if
    if m.related.Count() > 0 then
        row = root.createChild("ContentNode")
        row.title = "相关推荐"
        if m.panel.mode = "next" then row.title = "相关推荐  ·  自动连播会接着放第一个没看过的"
        cardsToContent(m.related, row)
        m.listRows.Push("related")
    end if
    if root.getChildCount() > 0 then
        m.list.content = root
    else
        m.list.content = invalid
    end if
end sub

sub onListChosen()
    sel = m.list.chosen
    kind = strOf(m.listRows[sel[0]])
    closeList()
    if kind = "parts" then
        if sel[1] <> m.index then
            save(false, true)
            m.shownOnce = false
            startPart(sel[1], 0, "auto")
        end if
    else if kind = "related" then
        it = m.related[sel[1]]
        if it <> invalid then
            save(false, true)
            openVideo(it)
        end if
    end if
end sub

sub loadRelated(bvid as String)
    m.related = []
    buildList()
    m.relatedTask = api("related", { bvid: bvid }, "onRelatedLoaded")
end sub

sub onRelatedLoaded(event as Object)
    if m.castReleased then return
    res = event.getData()
    if not res.ok or m.req = invalid then return
    m.related = res.data.items
    buildList()
end sub

' ---------- one video, several parts ----------

sub onRequest()
    r = m.top.request
    m.req = r
    m.played[strOf(r.bvid)] = true
    loadRelated(strOf(r.bvid))
    startPart(intOf(r.index), intOf(r.startAt), "auto")
end sub

' Switch to another video (from the drawer, or the next one in 自动连播):
' fetch its parts, then carry on where this TV last left it.
sub openVideo(card as Object)
    m.video.control = "stop"
    m.error.visible = false
    m.loading.visible = true
    m.titleLabel.text = strOf(card.title)
    m.subLabel.text = strOf(card.up)
    showHud(false)
    m.videoTask = api("video", { bvid: strOf(card.bvid) }, "onVideoInfo")
end sub

sub onVideoInfo(event as Object)
    if m.castReleased then return
    res = event.getData()
    if not res.ok then
        showError("视频加载失败：" + res.error)
        return
    end if
    v = res.data
    if v.pages.Count() = 0 then
        showError("这个视频没有可以播放的内容")
        return
    end if
    m.req = { bvid: v.bvid, aid: v.aid, title: v.title, up: v.up, poster: v.poster, pages: v.pages }
    m.played[strOf(v.bvid)] = true
    index = 0
    startAt = 0
    saved = loadProgress(v.bvid)
    if saved <> invalid then
        index = intOf(saved.i)
        startAt = intOf(saved.p)
        if index >= v.pages.Count() then index = 0
    end if
    m.shownOnce = false
    loadRelated(strOf(v.bvid))
    startPart(index, startAt, "auto")
end sub

' 自动连播: the first related video not yet played in this sitting.
function nextVideo() as Dynamic
    for each it in m.related
        if not m.played.DoesExist(strOf(it.bvid)) then return it
    end for
    return invalid
end function

sub startPart(index as Integer, startAt as Integer, fmt as String)
    m.index = index
    m.startAt = startAt
    m.fmt = fmt
    m.pendingQuality = false
    m.switchingPlayback = false
    m.qualityResumePending = false
    m.lastPlayData = invalid
    m.part = m.req.pages[index]
    m.lastSaved = startAt
    m.video.control = "stop"
    m.error.visible = false
    m.loading.visible = true
    m.titleLabel.text = m.req.title
    line = strOf(m.req.up)
    if m.req.pages.Count() > 1 then line = "P" + (index + 1).ToStr() + "  " + strOf(m.part.part) + "    " + line
    m.subLabel.text = line
    m.danmaku.cid = strOf(m.part.cid)
    if m.req.pages.Count() > 1 then buildList()   ' moves the ▶ marker
    requestStream(fmt)
end sub

sub requestStream(fmt as String)
    if m.playTask <> invalid then m.playTask.cancelled = true
    m.playSerial = m.playSerial + 1
    m.playTask = api("play", { bvid: m.req.bvid, cid: strOf(m.part.cid), fmt: fmt, quality: m.qualityChoice }, "onPlay", m.playSerial.ToStr())
end sub

sub onPlay(event as Object)
    if m.castReleased then return
    if event.getRoSGNode().tag <> m.playSerial.ToStr() then return
    res = event.getData()
    if not res.ok then
        if m.pendingQuality then
            m.pendingQuality = false
            restoreQualityChoice()
            navigate({ action: "toast", text: "画质切换失败：" + res.error })
            return
        end if
        showError("无法获取播放地址：" + res.error)
        return
    end if
    d = res.data
    if m.pendingQuality then
        m.pendingQuality = false
        m.qualityBackup = m.lastPlayData
        m.pauseAfterStart = m.video.state = "paused"
        m.startAt = Int(m.video.position)
        m.switchingPlayback = true
        m.qualityResumePending = m.startAt > 2
    end if
    applyPlayData(d, m.startAt)
    m.lastPlayData = d
    m.panel.qualities = d.qualities
    m.panel.actualQuality = strOf(d.quality_name)
    m.appliedQualityChoice = m.qualityChoice
    if m.qualityChoice <> "auto" and intOf(m.qualityChoice) <> intOf(d.quality) then
        navigate({ action: "toast", text: "此视频使用 " + strOf(d.quality_name) })
    end if
end sub

sub applyPlayData(d as Object, startAt as Integer)
    m.format = strOf(d.format)
    m.quality.text = strOf(d.quality_name)
    if m.qualityChoice = "auto" and m.format = "dash" then m.quality.text = "自动 · 最高 " + strOf(d.quality_name)
    if m.format = "dash" then
        ' the loopback server hands this manifest to the player
        m.global.mpd = d.mpd
        m.global.mpdId = d.sid
    end if
    c = CreateObject("roSGNode", "ContentNode")
    c.url = strOf(d.url)
    c.streamFormat = m.format
    c.HttpHeaders = d.headers
    if startAt > 0 then c.PlayStart = startAt
    m.video.content = c
    m.video.control = "play"
    if not m.list.visible and not m.panel.visible then m.video.setFocus(true)
end sub

sub onState()
    if m.castReleased then return
    publishCastState()
    m.stateClock.Mark()
    s = m.video.state
    if s = "playing" then
        m.loading.visible = false
        if m.pauseAfterStart then
            m.pauseAfterStart = false
            m.video.control = "pause"
        end if
        if m.switchingPlayback and not m.qualityResumePending then
            m.switchingPlayback = false
            m.qualityBackup = invalid
        end if
        if not m.shownOnce then
            m.shownOnce = true
            showHud(true)
        end if
    else if s = "paused" then
        showHud(false)
    else if s = "error" then
        secs = Int(m.video.position)
        if m.switchingPlayback and m.qualityBackup <> invalid then
            m.switchingPlayback = false
            m.qualityResumePending = false
            backup = m.qualityBackup
            m.qualityBackup = invalid
            restoreQualityChoice()
            applyPlayData(backup, m.startAt)
            m.lastPlayData = backup
            m.panel.qualities = backup.qualities
            m.panel.actualQuality = strOf(backup.quality_name)
            navigate({ action: "toast", text: "新画质播放失败，已恢复原画质" })
            return
        end if
        ' DASH is the 1080P path; if this TV chokes on it, the progressive MP4 still plays
        if m.format = "dash" then
            print "[player] dash failed ("; m.video.errorCode; ") "; m.video.errorMsg; " -> retry mp4"
            if secs > m.startAt then m.startAt = secs
            startPart(m.index, m.startAt, "mp4")
        else
            showError("播放出错：" + strOf(m.video.errorMsg) + " (" + strOf(m.video.errorCode) + ")")
        end if
    else if s = "finished" then
        onFinished()
    end if
end sub

' What happens at the end follows the play mode: 单集循环 repeats this part,
' the others go on to the next part; after the last part 自动连播 moves to a
' related video and 播完停止 goes back.
sub onFinished()
    save(true)
    mode = m.panel.mode
    m.shownOnce = false
    if mode = "loop" then
        startPart(m.index, 0, "auto")
    else if m.index + 1 < m.req.pages.Count() then
        startPart(m.index + 1, 0, "auto")
    else if mode = "next" and nextVideo() <> invalid then
        openVideo(nextVideo())
    else
        navigate({ action: "back" })
    end if
end sub

sub onPosition()
    if m.castReleased then return
    if m.qualityResumePending then
        ' Roku may seek to the preceding DASH keyframe. Only hide the transient
        ' zero position; waiting for an exact timestamp could stall cast status.
        if m.video.position < 1 then
            publishCastState()
            return
        end if
        m.qualityResumePending = false
        m.switchingPlayback = false
        m.qualityBackup = invalid
        print "[quality] resumed target="; m.startAt; " actual="; m.video.position
    end if
    publishCastState()
    secs = Int(m.video.position)
    if Abs(secs - m.lastSaved) >= 15 then save(false)
end sub

sub save(done as Boolean, leaving = false as Boolean)
    secs = Int(m.video.position)
    dur = Int(m.video.duration)
    if done then secs = dur
    m.lastSaved = secs
    if dur <= 0 then return
    report(secs, done or leaving)
    ' finishing the last part clears the bookmark; finishing an earlier one points at the next
    if done and m.index + 1 < m.req.pages.Count() then
        saveProgress(m.req.bvid, m.index + 1, 0, 0)
        return
    end if
    saveProgress(m.req.bvid, m.index, secs, dur)
end sub

' Mirror the position into the account's history so the phone sees it too.
' Throttled to one call per 30s; finishing or leaving always reports.
sub report(secs as Integer, force as Boolean)
    if not m.global.loggedIn or strOf(m.req.aid) = "" then return
    now = CreateObject("roDateTime").AsSeconds()
    if not force and now - m.lastReport < 30 then return
    m.lastReport = now
    navigate({ action: "report", params: { aid: strOf(m.req.aid), cid: strOf(m.part.cid), progress: secs } })
end sub

sub showHud(autoHide as Boolean)
    m.hud.visible = true
    m.hudTimer.control = "stop"
    if autoHide then m.hudTimer.control = "start"
end sub

sub hideHud()
    if m.video.state <> "paused" and not m.panel.visible then m.hud.visible = false
end sub

sub showError(text as String)
    m.loading.visible = false
    m.error.text = text + Chr(10) + Chr(10) + "按返回键退出"
    m.error.visible = true
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.video.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    ' The Video node swallows the OK press (it uses it for its own bar), so the
    ' centre button toggles pause on release -- unless the press itself just moved
    ' the video (confirming a seek), which would make this a double toggle.
    if key = "OK" and not press then
        if m.stateClock.TotalMilliseconds() < 700 then return true
        if m.video.state = "playing" then
            m.video.control = "pause"
        else if m.video.state = "paused" then
            m.video.control = "resume"
        end if
        return true
    end if
    if not press then return false
    if key = "back" then
        if m.video.state = "playing" or m.video.state = "paused" or m.video.state = "buffering" then save(false, true)
        m.video.control = "stop"
        navigate({ action: "back" })
        return true
    ' Roku TVs keep * for their own picture menu during playback, so the panels live on up/down
    else if key = "down" then
        openList()
        return true
    else if key = "up" or key = "options" or key = "info" then
        openPanel()
        return true
    end if
    return false
end function
