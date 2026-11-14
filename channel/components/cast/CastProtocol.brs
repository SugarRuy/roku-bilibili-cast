' Wire helpers are independent of the player and networking task.
function castBytes(text as String) as Object
    b = CreateObject("roByteArray")
    b.FromAsciiString(text)
    return b
end function

function castSlice(b as Object, start as Integer, count as Integer) as Object
    out = CreateObject("roByteArray")
    if count > 0 then
        for i = start to start + count - 1
            out.Push(b[i])
        end for
    end if
    return out
end function

function castU32(b as Object, at as Integer) as LongInteger
    return ((b[at] * 256& + b[at + 1]) * 256& + b[at + 2]) * 256& + b[at + 3]
end function

sub castPutU32(b as Object, value as LongInteger)
    b.Push((value \ 16777216) and 255)
    b.Push((value \ 65536) and 255)
    b.Push((value \ 256) and 255)
    b.Push(value and 255)
end sub

function castText(v as Dynamic) as String
    if v = invalid then return ""
    t = type(v)
    if t = "String" or t = "roString" then return v
    if t = "Integer" or t = "roInt" or t = "LongInteger" or t = "roLongInteger" then return v.ToStr()
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return v.ToStr()
    return ""
end function

function castNumber(v as Dynamic) as Integer
    return Int(Val(castText(v)))
end function

function castXml(text as String) as String
    return text.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace(Chr(34), "&quot;")
end function

function castJson(text as String) as Dynamic
    if text.Trim() = "" then return invalid
    ' Preserve Bilibili identifiers before ParseJson rounds numeric JSON values.
    rx = CreateObject("roRegex", """(aid|cid|oid|mid|id|epId|seasonId|roomId)""\s*:\s*(\d{9,})", "")
    return ParseJson(rx.ReplaceAll(text, """\1"":""\2"""))
end function

function castHeaders(text as String) as Object
    out = {}
    for each line in text.Split(Chr(10))
        colon = Instr(1, line, ":")
        if colon > 0 then out[LCase(Left(line, colon - 1).Trim())] = Mid(line, colon + 1).Trim()
    end for
    return out
end function

' Incremental parser: invalid means incomplete; bad=true means reject the connection.
function castFrame(b as Object) as Dynamic
    if b.Count() < 6 then return invalid
    first = b[0]
    count = b[1]
    seq = castU32(b, 2)
    if first <> &he0 and first <> &he4 and first <> &hc0 and first <> &hc4 then return { bad: true }
    if count = 0 then return { size: 6, kind: first, seq: seq, action: "", body: "" }
    if first = &hc0 or first = &hc4 then
        if count <> 1 then return { bad: true }
        if b.Count() < 10 then return invalid
        size = castU32(b, 6)
        if size > 65536 then return { bad: true }
        if b.Count() < 10 + size then return invalid
        return { size: 10 + size, kind: first, seq: seq, action: "", body: "" }
    end if
    if first <> &he0 or count > 3 then return { bad: true }
    if b.Count() < 8 then return invalid
    if b[6] <> 1 then return { bad: true }
    at = 8 + b[7]
    if b.Count() < at then return invalid
    if count = 1 then return { size: at, kind: first, seq: seq, action: "", body: "" }
    if b.Count() < at + 1 then return invalid
    length = b[at]
    at = at + 1
    if b.Count() < at + length then return invalid
    action = castSlice(b, at, length).ToAsciiString()
    at = at + length
    body = ""
    if count = 3 then
        if b.Count() < at + 4 then return invalid
        length = castU32(b, at)
        if length > 65536 then return { bad: true }
        at = at + 4
        if b.Count() < at + length then return invalid
        body = castSlice(b, at, length).ToAsciiString()
        at = at + length
    end if
    return { size: at, kind: first, seq: seq, action: action, body: body }
end function

function castReply(seq as LongInteger, data as Dynamic) as Object
    out = CreateObject("roByteArray")
    out.Push(&hc0)
    if data = invalid then
        out.Push(0)
        castPutU32(out, seq)
    else
        out.Push(1)
        castPutU32(out, seq)
        body = castBytes(FormatJson(data))
        castPutU32(out, body.Count())
        out.Append(body)
    end if
    return out
end function

function castNotice(seq as LongInteger, action as String, data = invalid as Dynamic) as Object
    out = CreateObject("roByteArray")
    out.Push(&he0)
    if data = invalid then
        out.Push(2)
    else
        out.Push(3)
    end if
    castPutU32(out, seq)
    out.Push(1)
    out.Push(7)
    out.Append(castBytes("Command"))
    label = castBytes(action)
    out.Push(label.Count())
    out.Append(label)
    if data <> invalid then
        body = castBytes(FormatJson(data))
        castPutU32(out, body.Count())
        out.Append(body)
    end if
    return out
end function

function castQuery(url as String, name as String) as String
    q = Instr(1, url, "?")
    if q = 0 then return ""
    for each pair in Mid(url, q + 1).Split("&")
        eq = Instr(1, pair, "=")
        if eq > 0 and Left(pair, eq - 1) = name then
            return CreateObject("roUrlTransfer").Unescape(Mid(pair, eq + 1))
        end if
    end for
    return ""
end function

' Only video identifiers cross into the player; received URLs are never fetched.
function castContent(data as Dynamic, depth = 0 as Integer) as Dynamic
    if depth > 4 then return invalid
    if type(data) <> "roAssociativeArray" then return invalid
    if type(data.content) = "roAssociativeArray" then data = data.content
    if type(data.playItem) = "roAssociativeArray" then data = data.playItem
    url = castText(data.url)
    if url <> "" then
        extra = castQuery(url, "nva_ext")
        if extra <> "" then return castContent(castJson(extra), depth + 1)
    end if
    bvid = castText(data.bvid)
    aid = castText(data.aid)
    cid = castText(data.cid)
    if bvid = "" and url <> "" then
        matches = CreateObject("roRegex", "BV[0-9A-Za-z]{10}", "").Match(url)
        if matches.Count() > 0 then bvid = matches[0]
    end if
    if bvid <> "" then
        if not CreateObject("roRegex", "^BV[0-9A-Za-z]{10}$", "").IsMatch(bvid) then return invalid
    else
        if not CreateObject("roRegex", "^[1-9][0-9]{0,17}$", "").IsMatch(aid) then return invalid
    end if
    if cid <> "" and not CreateObject("roRegex", "^[0-9]{1,18}$", "").IsMatch(cid) then return invalid
    seconds = 0
    if data.seekTs <> invalid then seconds = castNumber(data.seekTs)
    if data.position <> invalid then seconds = castNumber(data.position)
    if seconds < 0 then seconds = 0
    return { action: "play", bvid: bvid, aid: aid, cid: cid, position: seconds }
end function
