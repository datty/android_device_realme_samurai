#!/vendor/bin/sh
# DEBUG (samurai lineage-23 bring-up): pinpoint where init hangs in late
# post-fs-data (it reaches keystore.boot_level / apexd-snapshotde / verity, then
# stalls before load-bpf-programs -> zygote, and the OPPO watchdog reboots to
# recovery ~25-39s). Non-oneshot + foreground so init keeps this alive until the
# reboot. Every second it OVERWRITES /mnt/vendor/persist/laststate.txt with a
# full snapshot (running services + process list + init block state); the final
# snapshot before the watchdog fires shows exactly which service init is blocked
# on. Uses /proc/uptime (monotonic) since the wall clock jumps during boot.
# REMOVE with its init.target.rc service + device.mk copy once booting.
LOG=/mnt/vendor/persist/allocdbg.log
STATE=/mnt/vendor/persist/laststate.txt
echo "ADBG START pid=$$ uptime=$(cat /proc/uptime 2>/dev/null)" >> $LOG

# Background: synced filtered watch for the reboot trigger (survives the kill).
/system/bin/logcat -b all -v threadtime 2>/dev/null | while read line; do
    case "$line" in
        *powerctl*|*Reboot*|*reboot,*|*"shutting down"*|*FATAL*|*wipe*|*Requesting*|*watchdog*|*phoenix*|*Phoenix*)
            echo "$line" >> /mnt/vendor/persist/rebootwatch.log; sync ;;
    esac
done &

i=0
while [ $i -lt 600 ]; do
    i=$((i + 1))
    # Progression timeline (appended): one line/sec showing how far init gets.
    echo "i=$i up=$(cut -d' ' -f1 /proc/uptime 2>/dev/null) khash=$(getprop keystore.module_hash.sent) apex=$(getprop apexd.status) acfg=$(getprop init.svc.mainline_aconfigd_socket_service) bpf=$(getprop init.svc.bpfloader) netd=$(getprop init.svc.netd) zyg=$(getprop init.svc.zygote) ss=$(getprop init.svc.system_server) bc=$(getprop sys.boot_completed)" >> $LOG
    {
        echo "=== iter=$i uptime=$(cat /proc/uptime 2>/dev/null) ==="
        echo "--- running/restarting init.svc ---"
        getprop 2>/dev/null | grep "init.svc" | grep -vE "stopped\]$"
        echo "--- key props ---"
        echo "apexd.status=$(getprop apexd.status) odsign.key.done=$(getprop odsign.key.done) odsign.verification.done=$(getprop odsign.verification.done) sys.boot_completed=$(getprop sys.boot_completed) vold.decrypt=$(getprop vold.decrypt)"
        echo "--- init(1) state/wchan ---"
        grep -E "^State|^Pid" /proc/1/status 2>/dev/null
        echo -n "wchan: "; cat /proc/1/wchan 2>/dev/null; echo
        echo "--- procs (blocking-exec suspects) ---"
        ps -A 2>/dev/null | grep -iE "bpfload|apexd|snapshot|netd|vold|zygote|odsign|odrefresh|derive|keystore|move_time|qcom-|toybox|defaultcontain" | grep -viE "allocdbg|logcat|grep"
    } > $STATE 2>&1
    sync
    /vendor/bin/sleep 1
done
echo "ADBG loop ended i=$i uptime=$(cat /proc/uptime 2>/dev/null)" >> $LOG
