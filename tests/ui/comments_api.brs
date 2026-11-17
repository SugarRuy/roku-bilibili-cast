' Synthetic data only. The runner loads the actual comments API and helpers.
sub main()
    m.checks = 0
    m.calls = []
    bigId = "9007199254740993"
    pinned = { rpid_str: bigId, member: { mid_str: "42", uname: "Uploader" }, content: { message: "Pinned comment" }, rcount: 7, like: 12 }
    normal = { rpid_str: "9007199254740994", member: { uname: "Reader" }, content: { message: "A comment" }, count: 2 }
    raw = { upper: { mid: "42", top: pinned }, top: { upper: pinned }, page: { size: 2, count: 6 }, replies: [pinned, normal] }
    result = commentPage(raw, 1, false)
    check(result.items.Count() = 2, "pinned duplicate is removed")
    check(result.items[0].id = bigId, "64-bit reply ID remains exact")
    check(result.items[0].pinned and result.items[0].uploader, "pinned uploader is marked")
    check(result.items[1].replies = 2 and not result.items[1].pinned, "reply count fallback")
    check(result.hasMore, "full first page has another page")
    result = commentPage(raw, 3, false)
    check(not result.hasMore, "known total ends pagination")
    check(not result.items[0].pinned, "pinned block is only prepended on first page")
    result = commentPage({ replies: invalid }, 1, false)
    check(result.items.Count() = 0 and not result.hasMore, "missing list is empty")
    result = commentPage({ replies: [invalid, "bad", {}, { rpid_str: "12", member: 9, content: invalid, rcount: -2 }] }, 1, false)
    check(result.items.Count() = 1, "invalid rows are skipped")
    check(result.items[0].body <> "" and result.items[0].author <> "", "missing text/member has fallback")
    check(result.items[0].replies = 0, "negative reply count is clamped")
    result = commentItem({ rpid_str: "13", content: { pictures: [{}] } }, "", false)
    check(Instr(1, result.body, "图片") > 0, "image-only comment explains placeholder")
    result = opComments({ aid: "bad" })
    check(not result.ok and m.calls.Count() = 0, "invalid video rejected before network")
    result = opComments({ aid: "170001", root: "0 OR 1" })
    check(not result.ok and m.calls.Count() = 0, "invalid root rejected before network")
    m.response = { ok: true, data: raw }
    result = opComments({ aid: "170001", page: 0 })
    check(result.ok and m.calls.Count() = 1, "valid root comments request")
    check(m.calls[0].url = "https://api.bilibili.com/x/v2/reply", "root endpoint")
    check(m.calls[0].params.pn = 1 and m.calls[0].params.sort = 2, "hot sort and page minimum")
    result = opComments({ aid: "170001", root: bigId, page: 2 })
    check(m.calls[1].url = "https://api.bilibili.com/x/v2/reply/reply", "thread endpoint")
    check(m.calls[1].params.root = bigId and m.calls[1].params.sort = invalid, "thread ID exact, no root sort")
    m.response = { ok: false, error: "offline", data: invalid }
    result = opComments({ aid: "170001" })
    check(not result.ok and result.error = "offline", "network error preserved")
    m.response = { ok: true, data: "bad response" }
    result = opComments({ aid: "170001" })
    check(not result.ok, "unexpected response rejected")
    print "PASS comments_api"; m.checks
end sub

function biliApi(url as String, params as Object) as Object
    m.calls.Push({ url: url, params: params })
    return m.response
end function

' Glyph coverage and date rendering are unrelated to API normalization tests.
function fit(text as String) as String
    return text
end function

function ago(timestamp as Integer) as String
    return ""
end function
