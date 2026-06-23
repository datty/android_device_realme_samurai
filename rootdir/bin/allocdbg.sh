#!/vendor/bin/sh
# DEBUG (samurai lineage-23 bring-up): the polling dumper kept getting killed
# the instant odsign starts (~the apex mount-namespace switch, which kills
# bootstrap-namespace services). Detach the actual loop into a backgrounded
# subshell that ignores HUP/TERM and is orphaned to init, so it survives the
# switch/class_reset and can log the whole boot (incl. post-odsign + the
# sys.powerctl that triggers the reboot) to /mnt/vendor/persist.
# REMOVE with its init.target.rc service + device.mk copy once booting.
LOG=/mnt/vendor/persist/allocdbg.log
{
    trap '' HUP TERM INT
    echo "ADBG STARTED-bg pid=$$" >> $LOG
    i=0
    while [ $i -lt 200 ]; do
        i=$((i + 1))
        echo "i=$i pc=[$(getprop sys.powerctl)] odsvc=$(getprop init.svc.odsign) odk=$(getprop odsign.key.done) odv=$(getprop odsign.verification.done) zyg=$(getprop init.svc.zygote) ss=$(getprop init.svc.system_server) bpf=$(getprop init.svc.bpfloader) bc=$(getprop sys.boot_completed)" >> $LOG
        /vendor/bin/sleep 1
    done
} &
echo "ADBG launcher exiting, bg=$!" >> $LOG
