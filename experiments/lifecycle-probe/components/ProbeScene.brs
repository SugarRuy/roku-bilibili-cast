sub init()
    m.top.allowBackgroundTask = true
    m.top.findNode("probe").control = "run"
end sub

sub customSuspend(arg as Dynamic)
    print "[lifecycle] suspend "; arg.lastSuspendOrResumeReason
end sub

sub customResume(arg as Dynamic)
    m.top.allowBackgroundTask = true
    m.top.signalBeacon("AppResumeComplete")
    print "[lifecycle] resume "; arg.lastSuspendOrResumeReason
end sub
