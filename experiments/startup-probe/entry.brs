sub RunScreenSaver()
    startProbe("screensaver")
end sub

sub startProbe(role as String)
    print "[startup-probe] entry="; role
    section = CreateObject("roRegistrySection", "startup-probe")
    section.Write("last-entry", role)
    section.Flush()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    globals = screen.GetGlobalNode()
    globals.AddFields({ entryRole: role })
    scene = screen.CreateScene("ProbeScene")
    screen.Show()
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent" then
            if event.IsScreenClosed() then return
        end if
    end while
end sub
