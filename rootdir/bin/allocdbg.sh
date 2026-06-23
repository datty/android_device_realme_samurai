#!/vendor/bin/sh
# DEBUG (samurai lineage-23 bring-up): capture WHO reboots the device to
# recovery in late post-fs-data. Earlier versions were `oneshot` + backgrounded,
# so when the launcher exited init killed the whole process group (cgroup) and
# the loop died at i~1-3. This version runs the poll loop in the FOREGROUND and
# the service is NOT oneshot, so init keeps the service (and its backgrounded
# children) alive until the shutdown SIGTERM at ~34s. The shutdown itself takes
# ~5s (apexd unmount -> sysrq -> partition unmounts), giving the synced logcat
# watcher time to flush the "Received sys.powerctl" line that names the culprit.
# REMOVE with its init.target.rc service + device.mk copy once booting.
LOG=/mnt/vendor/persist/allocdbg.log
echo "ADBG START pid=$$" >> $LOG

# (1) Watch the live log for the reboot trigger; sync each hit so it survives
#     the kill that follows immediately after the reboot is requested.
/system/bin/logcat -b all -v threadtime 2>/dev/null | while read line; do
    case "$line" in
        *powerctl*|*Reboot*|*reboot,*|*"shutting down"*|*FATAL*|*wipe*|*set_policy*|*Requesting*)
            echo "$line" >> /mnt/vendor/persist/rebootwatch.log
            sync
            ;;
    esac
done &

# (2) Full rolling log for context (rotated so /mnt/vendor/persist won't fill).
/system/bin/logcat -b all -v threadtime -f /mnt/vendor/persist/bootlog.txt -r 4096 -n 2 2>/dev/null &

# (3) Foreground state poll: keeps this service (and the bg watchers) alive, and
#     records how far init gets + the last service running before the reboot.
prev=""
i=0
while [ $i -lt 4000 ]; do
    i=$((i + 1))
    cur="apex=$(getprop apexd.status) od=$(getprop init.svc.odsign) vold=$(getprop vold.decrypt) zyg=$(getprop init.svc.zygote) ss=$(getprop init.svc.system_server) bpf=$(getprop init.svc.bpfloader) bc=$(getprop sys.boot_completed)"
    if [ "$cur" != "$prev" ]; then
        echo "i=$i $cur" >> $LOG
        sync
        prev="$cur"
    fi
    /vendor/bin/sleep 1
done
