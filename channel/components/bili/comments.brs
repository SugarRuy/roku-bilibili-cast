' Read-only comments, normalized on the API Task before reaching the render thread.
function commentObject(value as Dynamic) as Object
    if type(value) = "roAssociativeArray" then return value
    return {}
end function

function commentId(value as Dynamic) as String
    id = strOf(value)
    if CreateObject("roRegex", "^[1-9][0-9]{0,18}$", "").IsMatch(id) then return id
    return ""
end function

function commentItem(raw as Object, uploader as String, pinned as Boolean) as Dynamic
    id = commentId(firstOf([raw.rpid_str, raw.rpid]))
    if id = "" then return invalid
    member = commentObject(raw.member)
    content = commentObject(raw.content)
    authorId = commentId(firstOf([member.mid_str, member.mid, raw.mid_str, raw.mid]))
    name = fit(strOf(member.uname))
    if name = "" then name = "用户"
    message = fit(strOf(content.message))
    pictures = content.pictures
    if type(pictures) = "roArray" then
        if pictures.Count() > 0 then message = message + Chr(10) + "［含图片，暂不显示］"
    end if
    if message.Trim() = "" then message = "［暂不支持的图片或表情内容］"
    replies = intOf(raw.rcount)
    ' A missing AA.count resolves to its built-in Count function on Roku.
    if raw.rcount = invalid and raw.DoesExist("count") then replies = intOf(raw.count)
    if replies < 0 then replies = 0
    return {
        id: id
        author: name
        body: message
        date: ago(intOf(raw.ctime))
        likes: fmtCount(raw.like)
        replies: replies
        pinned: pinned
        uploader: uploader <> "" and uploader = authorId
    }
end function

sub addComment(items as Object, seen as Object, value as Dynamic, uploader as String, pinned as Boolean)
    if type(value) <> "roAssociativeArray" then return
    item = commentItem(value, uploader, pinned)
    if item = invalid then return
    if seen.DoesExist(item.id) then return
    seen[item.id] = true
    items.Push(item)
end sub

function commentPage(data as Object, page as Integer, isThread as Boolean) as Object
    items = []
    seen = {}
    upper = commentObject(data.upper)
    uploader = commentId(firstOf([upper.mid_str, upper.mid]))
    if page = 1 and not isThread then
        top = commentObject(data.top)
        addComment(items, seen, top.upper, uploader, true)
        addComment(items, seen, top.admin, uploader, true)
        addComment(items, seen, upper.top, uploader, true)
    end if
    raw = data.replies
    if type(raw) <> "roArray" then raw = []
    for each item in raw
        addComment(items, seen, item, uploader, false)
    end for
    info = commentObject(data.page)
    size = intOf(info.size)
    if size <= 0 then size = 20
    total = 0
    if info.DoesExist("count") then total = intOf(info.count)
    if total < 0 then total = 0
    more = raw.Count() >= size
    if total > 0 and page * size >= total then more = false
    return { items: items, page: page, total: total, hasMore: more }
end function

function opComments(p as Object) as Object
    aid = commentId(p.aid)
    if aid = "" then return fail("这个视频暂不支持查看评论")
    page = intOf(p.page)
    if page < 1 then page = 1
    root = strOf(p.root)
    if root <> "" and commentId(root) = "" then return fail("评论编号无效")
    params = { type: 1, oid: aid, pn: page, ps: 20 }
    endpoint = "/x/v2/reply"
    if root <> "" then
        endpoint = endpoint + "/reply"
        params.root = root
    else
        params.sort = 2
    end if
    response = biliApi(apiBase() + endpoint, params)
    if not response.ok then return response
    if type(response.data) <> "roAssociativeArray" then return fail("评论暂不可用")
    return okWith(commentPage(response.data, page, root <> ""))
end function
