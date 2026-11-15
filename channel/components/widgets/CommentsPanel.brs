sub init()
    m.heading = m.top.findNode("heading")
    m.status = m.top.findNode("status")
    m.hint = m.top.findNode("hint")
    m.empty = m.top.findNode("empty")
    m.cardGroup = m.top.findNode("cards")
    m.detail = m.top.findNode("detail")
    m.author = m.top.findNode("author")
    m.body = m.top.findNode("body")
    m.detailMeta = m.top.findNode("detailMeta")
    m.heading.font = cjkFont(40)
    m.status.font = cjkFont(26)
    m.hint.font = cjkFont(24)
    m.empty.font = cjkFont(30)
    m.author.font = cjkFont(28)
    m.author.color = accent()
    m.body.font = cjkFont(32)
    m.detailMeta.font = cjkFont(24)
    m.cards = []
    for i = 0 to 1
        group = m.cardGroup.createChild("Group")
        group.translation = [0, i * 356]
        chip = group.createChild("Poster")
        chip.uri = themed("chip")
        chip.width = 496
        chip.height = 340
        author = group.createChild("Label")
        author.font = cjkFont(28)
        author.translation = [16, 14]
        author.width = 464
        author.maxLines = 1
        text = group.createChild("Label")
        text.font = cjkFont(32)
        text.translation = [16, 60]
        text.width = 464
        text.height = 230
        text.wrap = true
        text.maxLines = 5
        meta = group.createChild("Label")
        meta.font = cjkFont(24)
        meta.translation = [16, 296]
        meta.width = 464
        m.cards.Push({ group: group, chip: chip, author: author, body: text, meta: meta })
    end for
    m.serial = 0
    resetContext()
    m.top.observeField("visible", "onVisible")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

function newContext(root as String) as Object
    return { root: root, page: 1, selected: 0, first: 0, pages: {}, order: [], wanted: 1, wantedEnd: false, loading: false, error: "" }
end function

sub resetContext()
    cancelRequest()
    m.context = newContext("")
    m.parents = []
    m.mode = "list"
    m.detailItem = invalid
end sub

sub cancelRequest()
    if m.task <> invalid then m.task.cancelled = true
    m.task = invalid
    m.serial = m.serial + 1
    if m.context <> invalid then m.context.loading = false
end sub

sub onAid()
    if m.cards = invalid then return
    resetContext()
    if m.top.visible then
        onVisible()
        focusContent()
    end if
end sub

sub onVisible()
    if m.top.visible then
        if m.top.aid = "" then
            m.context.error = "这个视频暂不支持查看评论"
        else if currentPage() = invalid then
            requestPage(m.context.page)
        end if
        paint()
    else
        cancelRequest()
        m.body.setFocus(false)
    end if
end sub

function currentPage() as Dynamic
    return m.context.pages[m.context.page.ToStr()]
end function

function currentItems() as Object
    page = currentPage()
    if page = invalid then return []
    return page.items
end function

sub choosePage(page as Integer)
    m.context.page = page
    items = currentItems()
    m.context.selected = 0
    if m.context.wantedEnd and items.Count() > 0 then m.context.selected = items.Count() - 1
    m.context.first = m.context.selected - 1
    if m.context.first < 0 then m.context.first = 0
    m.context.wanted = page
end sub

' Cache three API pages per level; only two native comment cards are displayed.
sub cachePage(data as Object)
    key = data.page.ToStr()
    if not m.context.pages.DoesExist(key) then m.context.order.Push(key)
    m.context.pages[key] = data
    if m.context.wanted = data.page then choosePage(data.page)
    while m.context.order.Count() > 3
        oldest = m.context.order.Shift()
        if oldest = m.context.page.ToStr() then
            m.context.order.Push(oldest)
        else
            m.context.pages.Delete(oldest)
        end if
    end while
end sub

sub requestPage(page as Integer, atEnd = false as Boolean, prefetch = false as Boolean)
    if page < 1 or m.top.aid = "" then return
    if not prefetch then
        m.context.wanted = page
        m.context.wantedEnd = atEnd
    end if
    if m.context.pages.DoesExist(page.ToStr()) then
        if not prefetch then
            choosePage(page)
            paint()
        end if
        return
    end if
    if m.task <> invalid then
        if m.pendingPage = page then return
        cancelRequest()
    end if
    m.context.loading = true
    m.context.error = ""
    m.serial = m.serial + 1
    m.pendingPage = page
    m.task = api("comments", { aid: m.top.aid, root: m.context.root, page: page }, "onPage", m.serial.ToStr())
    paint()
end sub

sub onPage(event as Object)
    if m.task = invalid or not m.top.visible then return
    if event.getRoSGNode().tag <> m.serial.ToStr() then return
    if not event.getRoSGNode().isSameNode(m.task) then return
    m.task = invalid
    m.context.loading = false
    result = event.getData()
    if not result.ok then
        m.context.error = "评论加载失败：" + strOf(result.error)
    else
        data = result.data
        page = currentPage()
        if data.items.Count() = 0 and data.page > m.context.page and page <> invalid then
            page.hasMore = false
            m.context.wanted = m.context.page
        else
            cachePage(data)
        end if
        m.context.error = ""
    end if
    paint()
end sub

function authorText(item as Object) as String
    text = item.author
    if item.uploader then text = "UP主 · " + text
    if item.pinned then text = "置顶 · " + text
    return text
end function

function metaText(item as Object) as String
    text = "赞 " + item.likes
    if item.replies > 0 then text = text + "  回复 " + item.replies.ToStr()
    if item.date <> "" then text = text + "  " + item.date
    return text
end function

sub paint()
    if m.cards = invalid then return
    m.heading.text = "评论"
    if m.context.root <> "" then m.heading.text = "评论回复"
    m.detail.visible = m.mode = "detail"
    m.cardGroup.visible = m.mode = "list"
    m.empty.visible = false
    if m.mode = "detail" and m.detailItem <> invalid then
        m.status.text = "评论全文"
        m.author.text = authorText(m.detailItem)
        m.detailMeta.text = metaText(m.detailItem)
        m.hint.text = "上下阅读　返回评论"
        if m.context.root = "" and m.detailItem.replies > 0 then m.hint.text = "上下阅读　OK 查看回复" + Chr(10) + "返回评论　播放键暂停/继续"
        return
    end if
    items = currentItems()
    page = currentPage()
    m.status.text = "热门评论"
    if m.context.root <> "" then m.status.text = "楼中楼"
    if page <> invalid then m.status.text = m.status.text + " · 第 " + m.context.page.ToStr() + " 页"
    if m.context.loading then m.status.text = m.status.text + " · 加载中"
    if m.context.selected >= items.Count() then m.context.selected = items.Count() - 1
    if m.context.selected < 0 then m.context.selected = 0
    for i = 0 to 1
        card = m.cards[i]
        index = m.context.first + i
        card.group.visible = index < items.Count()
        if card.group.visible then
            item = items[index]
            card.author.text = authorText(item)
            card.body.text = item.body
            card.meta.text = metaText(item)
            focused = index = m.context.selected
            card.chip.visible = focused
            color = "0xE4E4EDFF"
            if focused then color = onAccent()
            card.author.color = color
            card.body.color = color
            card.meta.color = color
        end if
    end for
    m.hint.text = "上下选择　OK 读全文　右键看回复" + Chr(10) + "返回上一级　播放键暂停/继续"
    if m.context.error <> "" then
        if items.Count() = 0 then
            m.empty.visible = true
            m.empty.text = m.context.error
            m.hint.text = "OK 重试　返回关闭"
        else
            m.status.text = "加载失败 · 保留当前评论"
            m.hint.text = "下到页尾重试　OK 读全文" + Chr(10) + "返回上一级　播放键暂停/继续"
        end if
    else if items.Count() = 0 then
        m.empty.visible = true
        m.empty.text = "暂无可显示的评论"
        if m.context.loading then m.empty.text = "正在读取评论…"
        m.hint.text = "返回关闭　播放键暂停/继续"
    end if
end sub

sub moveSelection(delta as Integer)
    items = currentItems()
    if items.Count() = 0 then return
    index = m.context.selected + delta
    if index < 0 then
        if m.context.page > 1 then requestPage(m.context.page - 1, true)
    else if index >= items.Count() then
        page = currentPage()
        if page.hasMore then requestPage(m.context.page + 1)
    else
        m.context.selected = index
        m.context.wanted = m.context.page
        if index < m.context.first then m.context.first = index
        if index > m.context.first + 1 then m.context.first = index - 1
        page = currentPage()
        if delta > 0 and index >= items.Count() - 4 and page.hasMore and m.context.error = "" then requestPage(m.context.page + 1, false, true)
        paint()
    end if
end sub

sub openDetail()
    items = currentItems()
    if items.Count() = 0 then
        if not m.context.loading then requestPage(m.context.page)
        return
    end if
    m.detailItem = items[m.context.selected]
    m.body.text = m.detailItem.body
    m.mode = "detail"
    paint()
    m.body.setFocus(true)
end sub

sub openReplies()
    if m.context.root <> "" then return
    item = m.detailItem
    if m.mode = "list" then
        items = currentItems()
        if items.Count() = 0 then return
        item = items[m.context.selected]
    end if
    if item = invalid then return
    if item.replies <= 0 then return
    cancelRequest()
    m.parents.Push({ context: m.context, mode: m.mode, item: m.detailItem })
    m.context = newContext(item.id)
    m.mode = "list"
    m.detailItem = invalid
    focusContent()
    requestPage(1)
end sub

sub goBack()
    if m.mode = "detail" then
        m.mode = "list"
        m.detailItem = invalid
        focusContent()
        paint()
    else if m.parents.Count() > 0 then
        cancelRequest()
        parent = m.parents.Pop()
        m.context = parent.context
        m.mode = parent.mode
        m.detailItem = parent.item
        if m.mode = "detail" then m.body.text = m.detailItem.body
        paint()
        focusContent()
    else
        m.top.closed = true
    end if
end sub

sub focusContent()
    if m.mode = "detail" then
        m.body.setFocus(true)
    else
        ' Focusing the parent alone can leave a hidden ScrollableText handling keys.
        m.body.setFocus(false)
        m.top.setFocus(true)
    end if
end sub

sub onFocusChanged()
    if m.top.visible and m.top.hasFocus() and m.mode = "detail" then m.body.setFocus(true)
end sub

' Consume releases too: PlayerScreen toggles pause on an unhandled OK release.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return true
    if key = "play" then
        m.top.togglePlayback = true
    else if key = "back" or key = "left" then
        goBack()
    else if key = "options" then
        m.top.closed = true
    else if key = "right" then
        openReplies()
    else if key = "OK" then
        if m.mode = "detail" then
            openReplies()
        else
            openDetail()
        end if
    else if m.mode = "list" then
        if key = "up" then moveSelection(-1)
        if key = "down" then moveSelection(1)
    end if
    return true
end function
