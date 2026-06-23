#!/vendor/bin/sh
# DEBUG (samurai lineage-23 bring-up): boot stalls before zygote and reboots to
# recovery ~51s. SurfaceFlinger is wedged waiting for @4.0::IAllocator, but the
# real reboot cause may instead be init blocked on an on-boot wait_for_prop
# (apexd / keystore.module_hash.sent / odsign). Dump both the boot-gate props
# + per-service states AND the allocator's per-thread state to /dev/kmsg every
# 2s (survives in pstore). Started from `on init` so it runs even if init's main
# thread later blocks. REMOVE with its init.target.rc service + device.mk copy.
i=0
while [ $i -lt 24 ]; do
    i=$((i + 1))
    echo "ALLOCDBG i=$i A apexd.status=$(getprop apexd.status) ks.mhsent=$(getprop keystore.module_hash.sent) ods.key=$(getprop odsign.key.done) ods.verif=$(getprop odsign.verification.done) bootcomplete=$(getprop dev.bootcomplete) sysboot=$(getprop sys.boot_completed)" > /dev/kmsg
    echo "ALLOCDBG i=$i B svc.zygote=$(getprop init.svc.zygote) svc.sf=$(getprop init.svc.surfaceflinger) svc.apexd=$(getprop init.svc.apexd) svc.odsign=$(getprop init.svc.odsign) svc.ks2=$(getprop init.svc.keystore2) svc.alloc=$(getprop init.svc.vendor.qti.hardware.display.allocator)" > /dev/kmsg
    p=
    for d in /proc/[0-9]*; do
        read c < "$d/cmdline" 2>/dev/null
        case $c in
            *display.allocator-service*) p=${d#/proc/}; break;;
        esac
    done
    if [ -n "$p" ]; then
        for t in /proc/$p/task/*; do
            echo "ALLOCDBG-THR i=$i tid=${t##*/} name=$(cat $t/comm 2>/dev/null) state=$(cut -d' ' -f3 $t/stat 2>/dev/null) wchan=$(cat $t/wchan 2>/dev/null)" > /dev/kmsg
        done
    else
        echo "ALLOCDBG i=$i allocproc=NONE" > /dev/kmsg
    fi
    sleep 2
done
echo "ALLOCDBG-DONE" > /dev/kmsg
