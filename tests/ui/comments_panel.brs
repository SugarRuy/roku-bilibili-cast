' Exercises the real panel state machine; only SceneGraph/network are doubles.
sub main()
    m.checks = 0
    m.requests = []
    m.serial = 0
    m.top = fakeNode()
    m.top.aid = "170001"
    m.top.visible = true
    init()
    onVisible()
    firstTask = m.task
    check(m.requests.Count() = 1 and m.context.loading, "opening fetches first page")
    deliver(firstTask, testPage(1, true))
    check(currentItems().Count() = 6, "first page displayed")
    moveSelection(1)
    moveSelection(1)
    check(m.context.selected = 2 and m.context.page = 1, "down updates selection")
    nextTask = m.task
    check(nextTask.params.page = 2, "next page is prefetched")
    deliver(nextTask, testPage(2, true))
    check(m.context.page = 1, "prefetch does not move focus")
    openDetail()
    check(m.mode = "detail" and m.body.text = "comment 13", "OK opens selected full text")
    openReplies()
    threadTask = m.task
    check(m.context.root = "13" and threadTask.params.root = "13", "reply request uses selected root")
    deliver(threadTask, testPage(1, false))
    goBack()
    check(m.mode = "detail" and m.detailItem.id = "13", "back from replies restores parent text")
    goBack()
    check(m.mode = "list" and m.context.selected = 2, "back from full text preserves selection")
    check(not m.body.focused, "hidden full text relinquishes focus")
    moveSelection(1)
    moveSelection(1)
    moveSelection(1)
    moveSelection(1)
    check(m.context.page = 2 and m.context.selected = 0, "cached next page opens at first row")
    moveSelection(-1)
    check(m.context.page = 1 and m.context.selected = 5, "previous page restores last row")
    requestPage(3)
    stale = m.task
    m.top.aid = "200002"
    onAid()
    fresh = m.task
    check(stale.cancelled and fresh.params.aid = "200002", "video change cancels old request")
    deliver(stale, testPage(3, false))
    check(m.task.tag = fresh.tag and currentItems().Count() = 0, "stale result cannot populate new video")
    deliver(fresh, testPage(1, true))
    check(m.context.page = 1 and currentItems().Count() = 6, "new video gets its own first page")
    requestPage(2)
    pending = m.task
    m.top.visible = false
    onVisible()
    check(pending.cancelled and m.task = invalid, "closing cancels pending request")
    deliver(pending, testPage(2, false))
    check(not m.context.pages.DoesExist("2"), "hidden panel ignores late response")
    m.top.visible = true
    onVisible()
    check(currentItems().Count() = 6, "reopen retains loaded page")
    requestPage(2)
    deliverError(m.task)
    check(currentItems().Count() = 6 and m.context.error <> "", "pagination error retains comments")
    requestPage(2)
    deliver(m.task, { page: 2, items: [], total: 6, hasMore: false })
    check(m.context.page = 1 and not currentPage().hasMore, "empty next page keeps current list")
    m.top.aid = ""
    onAid()
    check(m.empty.visible and m.context.error <> "" and currentItems().Count() = 0, "missing new video ID clears old UI")
    m.top.togglePlayback = false
    check(onKeyEvent("OK", false), "OK release consumed")
    check(not m.top.togglePlayback, "OK release does not pause")
    onKeyEvent("play", true)
    check(m.top.togglePlayback, "dedicated Play key requests pause")
    m.mode = "detail"
    m.top.visible = false
    m.top.focused = true
    m.body.focused = false
    onFocusChanged()
    check(not m.body.focused, "hidden panel cannot reclaim text focus")
    print "PASS comments_panel"; m.checks
end sub

function testPage(number as Integer, more as Boolean) as Object
    items = []
    for i = 1 to 6
        id = (number * 10 + i).ToStr()
        items.Push({ id: id, author: "Reader", body: "comment " + id, date: "", likes: "1", replies: 2, pinned: false, uploader: false })
    end for
    return { page: number, items: items, hasMore: more, total: 30 }
end function

sub deliver(task as Object, data as Object)
    event = { node: task, result: { ok: true, data: data }, getRoSGNode: eventNode, getData: eventData }
    onPage(event)
end sub

sub deliverError(task as Object)
    onPage({ node: task, result: { ok: false, error: "offline" }, getRoSGNode: eventNode, getData: eventData })
end sub

function eventNode() as Object
    return m.node
end function

function eventData() as Object
    return m.result
end function

function api(op as String, params as Object, callback as String, tag = "" as String) as Object
    task = { params: params, tag: tag, cancelled: false, isSameNode: sameTask }
    m.requests.Push(task)
    return task
end function

function sameTask(other as Object) as Boolean
    return m.tag = other.tag
end function

function fakeNode() as Object
    return { visible: true, children: {}, findNode: findFake, createChild: createFake, setFocus: focusFake, hasFocus: hasFakeFocus, observeField: observeFake }
end function

function findFake(id as String) as Object
    if not m.children.DoesExist(id) then m.children[id] = fakeNode()
    return m.children[id]
end function

function createFake(kind as String) as Object
    return fakeNode()
end function

sub focusFake(focused as Boolean)
    m.focused = focused
end sub

function hasFakeFocus() as Boolean
    return m.focused = true
end function

sub observeFake(field as String, callback as String)
end sub

function cjkFont(size as Integer) as Object
    return { size: size }
end function

function accent() as String
    return "0xFB7299FF"
end function

function onAccent() as String
    return "0xFFFFFFFF"
end function

function themed(name as String) as String
    return name
end function
