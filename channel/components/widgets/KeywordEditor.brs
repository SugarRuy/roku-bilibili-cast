sub init()
    m.kb = m.top.findNode("kb")
    m.list = m.top.findNode("list")
    m.message = m.top.findNode("message")
    m.top.findNode("heading").font = cjkFont(48)
    m.top.findNode("hint").font = cjkFont(27)
    m.top.findNode("listHeading").font = cjkFont(34)
    m.message.font = cjkFont(27)
    m.list.font = cjkFont(30)
    m.list.focusedFont = cjkFont(30)
    m.list.focusBitmapUri = themed("chip")
    m.list.focusedColor = onAccent()
    m.list.observeField("itemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.observeField("visible", "onVisible")
    m.words = []
    m.focusNode = m.kb
end sub

sub onVisible()
    if m.top.visible then
        m.kb.text = ""
        m.message.text = "最多 20 条，每条最多 40 个字符"
        m.focusNode = m.kb
        if m.words.Count() > 0 then
            m.focusNode = m.list
            m.list.jumpToItem = 1
        end if
        m.focusNode.setFocus(true)
    end if
end sub

sub onKeywords()
    m.words = []
    if m.top.keywords <> invalid then
        for each word in m.top.keywords
            m.words.Push(word)
        end for
    end if
    renderList()
end sub

sub renderList()
    content = CreateObject("roSGNode", "ContentNode")
    action = content.createChild("ContentNode")
    action.title = "  ＋ 添加当前输入"
    for each word in m.words
        row = content.createChild("ContentNode")
        row.title = "  ✕ " + word
    end for
    m.list.content = content
end sub

sub onSelected()
    index = m.list.itemSelected
    if index = 0 then
        addWord()
        return
    else if index > 0 and index <= m.words.Count() then
        word = m.words[index - 1]
        m.words.Delete(index - 1)
        m.message.text = "已删除：“" + word + "”"
        print "[keyword] removed count="; m.words.Count()
    end if
    renderList()
    m.top.updated = m.words
end sub

sub addWord()
    word = m.kb.text.Trim()
    if word = "" then
        m.message.text = "先在左侧输入关键词"
        return
    end if
    if Len(word) > 40 then
        m.message.text = "关键词最多 40 个字符"
        return
    end if
    if m.words.Count() >= 20 then
        m.message.text = "最多只能屏蔽 20 个关键词"
        return
    end if
    for each existing in m.words
        if LCase(existing) = LCase(word) then
            m.message.text = "这个关键词已存在"
            return
        end if
    end for
    m.words.Push(word)
    m.kb.text = ""
    m.message.text = "已添加：“" + word + "”"
    print "[keyword] added count="; m.words.Count()
    m.focusNode = m.kb
    m.kb.setFocus(true)
    renderList()
    m.top.updated = m.words
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.focusNode.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        if m.kb.isInFocusChain() and m.kb.text.Trim() <> "" then
            addWord()
        else
            m.top.closed = true
        end if
        return true
    end if
    if m.kb.isInFocusChain() and key = "right" then
        m.focusNode = m.list
        m.list.setFocus(true)
        return true
    end if
    if m.list.isInFocusChain() and key = "left" then
        m.focusNode = m.kb
        m.kb.setFocus(true)
        return true
    end if
    return false
end function
