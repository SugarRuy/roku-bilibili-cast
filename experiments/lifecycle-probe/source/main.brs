sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("ProbeScene")
    screen.Show()
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent" then
            if event.IsScreenClosed() then return
        end if
    end while
end sub
