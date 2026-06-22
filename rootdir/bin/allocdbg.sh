#!/system/bin/sh
# DEBUG (samurai lineage-23 bring-up): the graphics allocator
# (vendor.qti.hardware.display.allocator-service) starts but never registers
# @4.0::IAllocator, wedging SurfaceFlinger and rebooting to recovery ~51s.
# This dumps its runtime state to /dev/kmsg so it survives in pstore.
# REMOVE together with its init.target.rc service + device.mk copy once booting.
NAME=display.allocator-service
i=0
while [ $i -lt 14 ]; do
    i=$((i + 1))
    p=""
    for d in /proc/[0-9]*; do
        if grep -qa "$NAME" "$d/cmdline" 2>/dev/null; then
            p=${d#/proc/}
            break
        fi
    done
    echo "ALLOCDBG i=$i pid=$p wchan=$([ -n "$p" ] && cat /proc/$p/wchan 2>/dev/null)" > /dev/kmsg
    if [ -n "$p" ] && { [ "$i" = 4 ] || [ "$i" = 10 ]; }; then
        echo "ALLOCDBG-BT-BEGIN i=$i pid=$p" > /dev/kmsg
        /system/bin/debuggerd -b "$p" > /dev/kmsg 2>&1
        echo "ALLOCDBG-BT-END i=$i" > /dev/kmsg
    fi
    sleep 3
done
t=$(ls -t /data/tombstones/tombstone_* 2>/dev/null | head -1)
echo "ALLOCDBG-TOMB=$t" > /dev/kmsg
[ -n "$t" ] && sed -n '1,80p' "$t" > /dev/kmsg 2>/dev/null
echo "ALLOCDBG-DONE" > /dev/kmsg
