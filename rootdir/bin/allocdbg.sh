#!/system/bin/sh
# DEBUG (samurai lineage-23 bring-up): the graphics allocator
# (vendor.qti.hardware.display.allocator-service) starts but never registers
# @4.0::IAllocator, wedging SurfaceFlinger and rebooting to recovery ~51s.
# Dump its per-thread state to /dev/kmsg continuously so the dumps right before
# the reboot survive in the (256K, charger-spam-heavy) console-ramoops.
# Non-blocking only (no debuggerd -b: it hangs on a stuck target).
# REMOVE together with its init.target.rc service + device.mk copy once booting.
NAME=display.allocator-service
i=0
while [ $i -lt 30 ]; do
    i=$((i + 1))
    p=""
    for d in /proc/[0-9]*; do
        if grep -qa "$NAME" "$d/cmdline" 2>/dev/null; then
            p=${d#/proc/}
            break
        fi
    done
    if [ -z "$p" ]; then
        echo "ALLOCDBG i=$i NOPROC" > /dev/kmsg
    else
        echo "ALLOCDBG i=$i pid=$p state=$(cut -d' ' -f3 /proc/$p/stat 2>/dev/null) wchan=$(cat /proc/$p/wchan 2>/dev/null)" > /dev/kmsg
        for t in /proc/$p/task/*; do
            tid=${t##*/}
            echo "ALLOCDBG-THR i=$i tid=$tid name=$(cat $t/comm 2>/dev/null) state=$(cut -d' ' -f3 $t/stat 2>/dev/null) wchan=$(cat $t/wchan 2>/dev/null)" > /dev/kmsg
            echo "ALLOCDBG-STK i=$i tid=$tid" > /dev/kmsg
            cat $t/stack > /dev/kmsg 2>/dev/null
        done
    fi
    sleep 2
done
echo "ALLOCDBG-DONE" > /dev/kmsg
