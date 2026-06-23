#!/vendor/bin/sh
# DEBUG (samurai lineage-23 bring-up): boot loops to recovery at a fixed ~51s
# with no zygote and no logged reason. Poll the boot gates AND sys.powerctl
# every second and write to /dev/kmsg at CRIT priority ("<2>" prefix) so it
# survives console-ramoops (plain kmsg writes are below the console loglevel)
# and doesn't depend on /metadata or /cache (which get locked in post-fs-data).
# Catches what sets sys.powerctl=reboot,* (the reboot trigger).
# REMOVE with its init.target.rc service + device.mk copy once booting.
i=0
while [ $i -lt 70 ]; do
    i=$((i + 1))
    echo "<2>ADBG $i pc=[$(getprop sys.powerctl)] odsvc=$(getprop init.svc.odsign) odk=$(getprop odsign.key.done) odv=$(getprop odsign.verification.done) odok=$(getprop odsign.verification.success) apexd=$(getprop apexd.status) zyg=$(getprop init.svc.zygote) ss=$(getprop init.svc.system_server) bc=$(getprop sys.boot_completed)" > /dev/kmsg
    /vendor/bin/sleep 1
done
echo "<2>ADBG DONE" > /dev/kmsg
