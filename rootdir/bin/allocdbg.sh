#!/vendor/bin/sh
# DEBUG (samurai lineage-23 bring-up): boot loops to recovery (now ~75s after a
# data wipe) still stuck in on-post-fs-data, no zygote. Log boot gates +
# sys.powerctl (the reboot trigger) every 1s to /mnt/vendor/persist, which is a
# plain partition vold does NOT re-key in post-fs-data (unlike /metadata and
# /cache, where earlier dumpers' writes vanished ~12s). /dev/kmsg userspace
# writes don't survive console-ramoops here, so persist is the sink.
# Read back in recovery: cat /mnt/vendor/persist/allocdbg.log
# REMOVE with its init.target.rc service + device.mk copy once booting.
LOG=/mnt/vendor/persist/allocdbg.log
echo "ADBG STARTED" >> $LOG
i=0
while [ $i -lt 110 ]; do
    i=$((i + 1))
    echo "i=$i pc=[$(getprop sys.powerctl)] vold=$(getprop init.svc.vold) odsvc=$(getprop init.svc.odsign) odk=$(getprop odsign.key.done) odv=$(getprop odsign.verification.done) zyg=$(getprop init.svc.zygote) ss=$(getprop init.svc.system_server) bc=$(getprop sys.boot_completed)" >> $LOG
    /vendor/bin/sleep 1
done
echo "ADBG DONE" >> $LOG
