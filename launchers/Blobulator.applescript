on run
    set bundlePath to POSIX path of (path to me)
    set projectFolder to do shell script "/usr/bin/dirname " & quoted form of bundlePath
    set launcher to projectFolder & "/blobulator/Open_Blobulator.sh"
    set logFile to projectFolder & "/Blobulator_launcher.log"
    do shell script "/usr/bin/nohup " & quoted form of launcher & " >" & quoted form of logFile & " 2>&1 </dev/null &"
end run
