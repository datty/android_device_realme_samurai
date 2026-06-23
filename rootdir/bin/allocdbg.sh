#!/vendor/bin/sh
# DEBUG (samurai lineage-23 bring-up): boot stalls before zygote, reboots to
# recovery ~51s. SurfaceFlinger waits forever for @4.0::IAllocator. Hypothesis:
# init never reaches 'on boot' (class_start hal), so the allocator is never
# started (composer/SF are explicitly started at late-fs, allocator is not).
# Log boot-gate props + per-service states + allocator threads to /cache (which
# persists across the reboot and is readable from recovery -- avoids the 256K
# console-ramoops rotating our /dev/kmsg writes out under charger spam).
# REMOVE with its init.target.rc service + device.mk copy once booting.
LOG=/cache/allocdbg.log
echo "ALLOCDBG STARTED" >> $LOG
echo "ALLOCDBG STARTED" > /dev/kmsg
i=0
while [ $i -lt 40 ]; do
    i=$((i + 1))
    {
        echo "=== i=$i ==="
        echo "gate: apexd.status=$(getprop apexd.status) ks.mhsent=$(getprop keystore.module_hash.sent) ods.key=$(getprop odsign.key.done) ods.verif=$(getprop odsign.verification.done) sysboot=$(getprop sys.boot_completed) bootcomplete=$(getprop dev.bootcomplete)"
        echo "svc: zygote=$(getprop init.svc.zygote) sf=$(getprop init.svc.surfaceflinger) apexd=$(getprop init.svc.apexd) odsign=$(getprop init.svc.odsign) ks2=$(getprop init.svc.keystore2) keystore=$(getprop init.svc.keystore) alloc=$(getprop init.svc.vendor.qti.hardware.display.allocator) composer=$(getprop init.svc.vendor.hwcomposer-2-4)"
    } >> $LOG
    p=
    for d in /proc/[0-9]*; do
        read c < "$d/cmdline" 2>/dev/null
        case $c in
            *display.allocator-service*) p=${d#/proc/}; break;;
        esac
    done
    if [ -n "$p" ]; then
        for t in /proc/$p/task/*; do
            echo "THR i=$i tid=${t##*/} name=$(cat $t/comm 2>/dev/null) state=$(cut -d' ' -f3 $t/stat 2>/dev/null) wchan=$(cat $t/wchan 2>/dev/null)" >> $LOG
        done
    else
        echo "alloc=NOPROC i=$i" >> $LOG
    fi
    /vendor/bin/sleep 2
done
echo "ALLOCDBG DONE" >> $LOG
