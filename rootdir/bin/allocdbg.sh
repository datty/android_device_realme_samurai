#!/vendor/bin/sh
# DEBUG (samurai lineage-23 bring-up): boot stalls before zygote, reboots to
# recovery ~51-112s. SurfaceFlinger waits forever for @4.0::IAllocator because
# init never reaches 'on boot' (class_start hal) so the allocator is never
# started (composer/SF are explicitly started at late-fs, allocator is not).
# Find WHICH on-boot gate init is stuck on by logging the boot-gate props +
# per-service states over time to /cache (persists across reboot, readable from
# recovery; /dev/kmsg writes are below console loglevel and never survive here).
# Pure getprop only -- no /proc scan (that blocks on a D-state process).
# REMOVE with its init.target.rc service + device.mk copy once booting.
LOG=/metadata/allocdbg.log
echo "ALLOCDBG STARTED (a fresh STARTED line = init restarted this service)" >> $LOG
i=0
while [ $i -lt 60 ]; do
    i=$((i + 1))
    echo "i=$i gate: apexd=$(getprop apexd.status) ks.mh=$(getprop keystore.module_hash.sent) ods.key=$(getprop odsign.key.done) ods.verif=$(getprop odsign.verification.done) sysboot=$(getprop sys.boot_completed) bootcomplete=$(getprop dev.bootcomplete)" >> $LOG
    echo "i=$i svc: zygote=$(getprop init.svc.zygote) sf=$(getprop init.svc.surfaceflinger) apexd=$(getprop init.svc.apexd) odsign=$(getprop init.svc.odsign) ks2=$(getprop init.svc.keystore2) alloc=$(getprop init.svc.vendor.qti.hardware.display.allocator) bootanim=$(getprop init.svc.bootanim)" >> $LOG
    /vendor/bin/sleep 2
done
echo "ALLOCDBG DONE" >> $LOG
