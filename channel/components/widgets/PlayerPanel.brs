sub init()
    m.alphas = [0.2, 0.4, 0.6, 0.8, 1.0]
    m.areas = danmakuAreas()
    m.modes = playModes()
    m.page = "main"
    m.sel = 0
    m.heading = m.top.findNode("heading")
    m.heading.font = cjkFont(44)
    m.countLabel = m.top.findNode("countLabel")
    m.countLabel.font = cjkFont(26)
    m.hint = m.top.findNode("hint")
    m.hint.font = cjkFont(24)
    m.rows = []
    group = m.top.findNode("rows")
    for i = 0 to 8
        g = group.createChild("Group")
        chip = g.createChild("Poster")
        chip.uri = themed("chip")
        chip.width = 480
        chip.height = 72
        name = g.createChild("Label")
        name.font = cjkFont(30)
        name.translation = [24, 0]
        name.height = 72
        name.vertAlign = "center"
        value = g.createChild("Label")
        value.font = cjkFont(29)
        value.translation = [225, 0]
        value.width = 230
        value.height = 72
        value.horizAlign = "right"
        value.vertAlign = "center"
        m.rows.Push({ g: g, chip: chip, name: name, value: value })
    end for
    m.top.observeField("visible", "onVisible")
    m.top.observeField("qualities", "paint")
    m.top.observeField("qualityChoice", "paint")
    m.top.observeField("count", "paint")
    paint()
end sub

sub onVisible()
    if m.top.visible then
        m.page = "main"
        m.sel = 0
        paint()
    end if
end sub

function definitions() as Object
    if m.page = "danmaku" then
        return [
            { key: "alpha", name: "不透明度" }
            { key: "area", name: "显示区域" }
            { key: "size", name: "字号" }
            { key: "speed", name: "滚动速度" }
            { key: "density", name: "密度" }
            { key: "scroll", name: "滚动弹幕" }
            { key: "top", name: "顶部弹幕" }
            { key: "bottom", name: "底部弹幕" }
            { key: "keywords", name: "关键词屏蔽" }
        ]
    else if m.page = "quality" then
        defs = [{ key: "q:auto", name: "自动" }]
        if m.top.qualities <> invalid then
            for each q in m.top.qualities
                defs.Push({ key: "q:" + strOf(q.qn), name: strOf(q.name) })
            end for
        end if
        return defs
    end if
    return [
        { key: "enabled", name: "弹幕" }
        { key: "dm_detail", name: "弹幕设置" }
        { key: "quality", name: "画质" }
        { key: "mode", name: "播放模式" }
        { key: "list", name: "选集/推荐" }
        { key: "interact", name: "互动" }
    ]
end function

function onOff(v as Boolean) as String
    if v then return "开"
    return "关"
end function

function choiceLabel(key as String) as String
    if key = "enabled" then return onOff(m.top.enabled)
    if key = "alpha" then return Int(m.top.alpha * 100).ToStr() + "%"
    if key = "area" then return Int(m.top.area * 100).ToStr() + "%"
    if key = "size" then
        if m.top.size = "small" then return "小"
        if m.top.size = "large" then return "大"
        return "中"
    end if
    if key = "speed" then
        if m.top.speed = "slow" then return "慢"
        if m.top.speed = "fast" then return "快"
        return "中"
    end if
    if key = "density" then
        if m.top.density = "low" then return "少"
        if m.top.density = "high" then return "多"
        return "标准"
    end if
    if key = "scroll" then return onOff(m.top.scrollEnabled)
    if key = "top" then return onOff(m.top.topEnabled)
    if key = "bottom" then return onOff(m.top.bottomEnabled)
    if key = "keywords" then return m.top.keywordCount.ToStr() + " 条  ›"
    if key = "mode" then
        for each md in m.modes
            if md.key = m.top.mode then return md.name
        end for
    end if
    if key = "quality" then
        if m.top.qualityChoice = "auto" then return "自动  ›"
        if m.top.qualities <> invalid then
            for each q in m.top.qualities
                if strOf(q.qn) = m.top.qualityChoice then return strOf(q.name) + "  ›"
            end for
        end if
        return "自动  ›"
    end if
    if Left(key, 2) = "q:" then
        if Mid(key, 3) = m.top.qualityChoice then return "✓"
        return ""
    end if
    return "›"
end function

sub paint()
    if m.rows = invalid then return
    defs = definitions()
    if m.sel >= defs.Count() then m.sel = defs.Count() - 1
    if m.page = "danmaku" then
        m.heading.text = "弹幕设置"
    else if m.page = "quality" then
        m.heading.text = "画质"
    else
        m.heading.text = "播放设置"
    end if
    if m.top.count > 0 then
        m.countLabel.text = "本集共 " + m.top.count.ToStr() + " 条弹幕"
    else
        m.countLabel.text = "本集暂无弹幕"
    end if
    m.hint.text = "上下选择　左右调整　返回键关闭"
    if m.page <> "main" then m.hint.text = "上下选择　OK 确认　返回键上一级"
    for i = 0 to m.rows.Count() - 1
        r = m.rows[i]
        r.g.visible = i < defs.Count()
        if i < defs.Count() then
            r.g.translation = [0, i * 76]
            key = defs[i].key
            r.name.text = defs[i].name
            r.value.text = choiceLabel(key)
            focused = (i = m.sel)
            r.chip.visible = focused
            if focused then
                r.name.color = onAccent()
                r.value.color = onAccent()
            else
                r.name.color = "0xD2D2DCFF"
                r.value.color = "0xD2D2DCFF"
            end if
        end if
    end for
end sub

function nextIndex(values as Object, current as Dynamic, delta as Integer, wrap as Boolean) as Integer
    index = 0
    for i = 0 to values.Count() - 1
        if values[i] = current then index = i
    end for
    index = index + delta
    if wrap then return (index + values.Count()) mod values.Count()
    if index < 0 or index >= values.Count() then return -1
    return index
end function

sub adjust(key as String, delta as Integer, wrap as Boolean)
    if key = "enabled" then
        m.top.enabled = not m.top.enabled
    else if key = "mode" then
        modes = []
        for each md in m.modes
            modes.Push(md.key)
        end for
        i = nextIndex(modes, m.top.mode, delta, wrap)
        if i >= 0 then m.top.mode = modes[i]
    else if key = "alpha" then
        i = nextIndex(m.alphas, m.top.alpha, delta, wrap)
        if i >= 0 then m.top.alpha = m.alphas[i]
    else if key = "area" then
        i = nextIndex(m.areas, m.top.area, delta, wrap)
        if i >= 0 then m.top.area = m.areas[i]
    else if key = "size" then
        values = ["small", "normal", "large"]
        i = nextIndex(values, m.top.size, delta, wrap)
        if i >= 0 then m.top.size = values[i]
    else if key = "speed" then
        values = ["slow", "normal", "fast"]
        i = nextIndex(values, m.top.speed, delta, wrap)
        if i >= 0 then m.top.speed = values[i]
    else if key = "density" then
        values = ["low", "normal", "high"]
        i = nextIndex(values, m.top.density, delta, wrap)
        if i >= 0 then m.top.density = values[i]
    else if key = "scroll" then
        m.top.scrollEnabled = not m.top.scrollEnabled
    else if key = "top" then
        m.top.topEnabled = not m.top.topEnabled
    else if key = "bottom" then
        m.top.bottomEnabled = not m.top.bottomEnabled
    end if
end sub

sub selectCurrent(key as String)
    if key = "dm_detail" then
        m.page = "danmaku"
        m.sel = 0
    else if key = "quality" then
        m.page = "quality"
        m.sel = 0
    else if key = "keywords" then
        m.top.keywordRequested = true
    else if key = "list" then
        m.top.listRequested = true
    else if key = "interact" then
        m.top.interactionRequested = true
    else if Left(key, 2) = "q:" then
        m.top.qualityChoice = Mid(key, 3)
        m.page = "main"
        m.sel = 2
    else
        adjust(key, 1, true)
    end if
    paint()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return true
    defs = definitions()
    if key = "up" and m.sel > 0 then
        m.sel = m.sel - 1
    else if key = "down" and m.sel < defs.Count() - 1 then
        m.sel = m.sel + 1
    else if key = "left" or key = "right" then
        current = defs[m.sel].key
        if current = "enabled" or current = "mode" or (m.page = "danmaku" and current <> "keywords") then
            delta = -1
            if key = "right" then delta = 1
            adjust(current, delta, false)
        else if key = "right" then
            selectCurrent(current)
        end if
    else if key = "OK" then
        selectCurrent(defs[m.sel].key)
    else if key = "back" or key = "options" then
        if m.page = "main" then
            m.top.closed = true
        else
            m.page = "main"
            m.sel = 0
        end if
    end if
    paint()
    return true
end function
