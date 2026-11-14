' Prepare the two CJK text blocks off the render thread. Numeric cover badges
' remain native labels. A URI is published only after the complete PNG exists.
sub prepareGridText(items as Object, width as Integer)
    started = CreateObject("roTimespan")
    fs = CreateObject("roFileSystem")
    directory = "tmp:/grid-text"
    if not fs.Exists(directory) then
        if not fs.CreateDirectory(directory) then return
    end if
    entries = fs.GetDirectoryListing(directory).Count()
    face = currentFont()
    registry = CreateObject("roFontRegistry")
    if not registry.Register(face.uri) then return
    family = "Gouli " + UCase(Left(face.key, 1)) + Mid(face.key, 2)
    titleSize = 26
    metaSize = 22
    if width < 400 then
        titleSize = 23
        metaSize = 20
    end if
    titleFont = registry.GetFont(family, titleSize, false, false)
    metaFont = registry.GetFont(family, metaSize, false, false)
    if titleFont = invalid or metaFont = invalid then return
    lineHeight = titleSize + 10
    metaY = 6 + lineHeight * 2
    height = metaY + metaSize + 10
    hits = 0
    for each item in items
        if m.top.cancelled then return
        title = strOf(item.title)
        meta = strOf(item.up)
        extra = strOf(item.date_text)
        if boolOf(item.history) then extra = strOf(item.view_text)
        if extra <> "" then
            if meta <> "" then meta += "  ·  "
            meta += extra
        end if
        key = md5Hex(FormatJson([2, face.key, width, title, meta]))
        uri = directory + "/" + key + ".png"
        ready = fs.Exists(uri)
        if ready then
            hits += 1
        else if entries < 2048 then
            if not waitForGridTextIdle() then return
            bitmap = CreateObject("roBitmap", { width: width, height: height, AlphaEnable: true })
            if bitmap = invalid then return
            bitmap.Clear(&h00000000)
            lines = gridTitleLines(title, titleFont, width)
            bitmap.DrawText(lines[0], 0, 0, &hFFFFFFFF, titleFont)
            if not waitForGridTextIdle() then return
            bitmap.DrawText(lines[1], 0, lineHeight, &hFFFFFFFF, titleFont)
            if not waitForGridTextIdle() then return
            bitmap.DrawText(gridTextEllipsis(meta, metaFont, width), 0, metaY, &hAAAAAAFF, metaFont)
            if not waitForGridTextIdle() then return
            bitmap.Finish()
            png = bitmap.GetPng(0, 0, width, height)
            bitmap = invalid
            if png <> invalid then
                temporary = uri + "." + gridClockMs().ToStr() + "-" + Rnd(1000000).ToStr() + ".part"
                if png.WriteFile(temporary) then
                    ready = fs.Rename(temporary, uri)
                    if not ready then ready = fs.Exists(uri)
                    if fs.Exists(temporary) then fs.Delete(temporary)
                    if ready then entries += 1
                end if
            end if
        end if
        if ready then
            item.grid_text_uri = uri
            item.grid_text_width = width
            item.grid_text_height = height
        end if
    end for
    print "[grid-text] items="; items.Count(); " cached="; hits; " ms="; started.TotalMilliseconds()
end sub

function waitForGridTextIdle() as Boolean
    ' Yield between graphics operations, including when a second feed is
    ' preparing. Never hold up cancellation while the user keeps scrolling.
    Sleep(2)
    while gridClockMs() < m.global.gridScrollUntil
        if m.top.cancelled then return false
        Sleep(10)
    end while
    return not m.top.cancelled
end function

function gridTextPrefix(text as String, font as Object, width as Integer) as Integer
    low = 0
    high = Len(text)
    while low < high
        middle = Int((low + high + 1) / 2)
        if font.GetOneLineWidth(Left(text, middle), 32767) <= width then
            low = middle
        else
            high = middle - 1
        end if
    end while
    return low
end function

function gridTextEllipsis(text as String, font as Object, width as Integer) as String
    text = text.Replace(Chr(13), "").Replace(Chr(10), " ")
    count = gridTextPrefix(text, font, width)
    if count = Len(text) then return text
    count = gridTextPrefix(text, font, width - font.GetOneLineWidth("…", 32767))
    return Left(text, count) + "…"
end function

function gridTitleLines(text as String, font as Object, width as Integer) as Object
    text = text.Replace(Chr(13), "")
    count = gridTextPrefix(text.Replace(Chr(10), " "), font, width)
    newline = Instr(1, text, Chr(10))
    if newline > 0 and newline <= count + 1 then
        return [Left(text, newline - 1), gridTextEllipsis(Mid(text, newline + 1), font, width)]
    end if
    if count >= Len(text) then return [text, ""]
    ' Keep Latin words together when a nearby space provides a natural break.
    boundary = 0
    for i = 1 to count
        if Mid(text, i, 1) = " " then boundary = i
    end for
    if boundary > count * 0.65 then count = boundary
    return [Left(text, count).Trim(), gridTextEllipsis(Mid(text, count + 1).Trim(), font, width)]
end function
