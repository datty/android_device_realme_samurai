#!/vendor/bin/sh
# DEBUG (samurai lineage-23 bring-up). $1 = output suffix so two instances can
# run: the late-fs one (suffix "") dies at the apex mount-namespace switch ~28s;
# a second one started on apexd.status=activated (suffix "2") runs in the
# post-apex default namespace and survives to the watchdog reboot ~40s, capturing
# the 28-40s window where the reboot is triggered.
# Boot currently works but is too slow (apexd ~23s + odsign fresh compile) for
# the ~40s OPPO watchdog, so it never caches artifacts -> loops.
# REMOVE with its init.target.rc services + device.mk copy once booting.
SFX="$1"
LOG=/mnt/vendor/persist/allocdbg${SFX}.log
STATE=/mnt/vendor/persist/laststate${SFX}.txt
BOOTLOG=/mnt/vendor/persist/bootlog${SFX}.txt
echo "ADBG${SFX} START pid=$$ uptime=$(cat /proc/uptime 2>/dev/null)" >> $LOG

# Full unfiltered log capture (rotated). The late window is short so it won't roll.
/system/bin/logcat -b all -v threadtime -f $BOOTLOG -r 8192 -n 2 2>/dev/null &

i=0
while [ $i -lt 600 ]; do
    i=$((i + 1))
    # Progression incl. sys.powerctl (catches a reboot request) + boot milestones.
    echo "i=$i up=$(cut -d' ' -f1 /proc/uptime 2>/dev/null) khash=$(getprop keystore.module_hash.sent) apex=$(getprop apexd.status) bpf=$(getprop init.svc.bpfloader) netd=$(getprop init.svc.netd) zyg=$(getprop init.svc.zygote) ss=$(getprop init.svc.system_server) bc=$(getprop sys.boot_completed) pc=[$(getprop sys.powerctl)] shut=[$(getprop sys.shutdown.requested)]" >> $LOG
    {
        echo "=== iter=$i uptime=$(cat /proc/uptime 2>/dev/null) ==="
        echo "--- running/restarting init.svc ---"; getprop 2>/dev/null | grep "init.svc" | grep -vE "stopped\]$"
        echo "--- init(1) State/wchan ---"; grep -E "^State" /proc/1/status 2>/dev/null; echo -n "wchan: "; cat /proc/1/wchan 2>/dev/null; echo
        echo "--- full ps ---"; ps -A 2>/dev/null
    } > $STATE 2>&1
    sync
    /vendor/bin/sleep 1
done
echo "ADBG${SFX} ended i=$i uptime=$(cat /proc/uptime 2>/dev/null)" >> $LOG
