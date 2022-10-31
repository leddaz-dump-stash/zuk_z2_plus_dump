#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/bootdevice/by-name/recovery:45315318:c456c0cfdcea7fdead54a424078b8d1948e718b6; then
  applypatch -b /system/etc/recovery-resource.dat EMMC:/dev/block/bootdevice/by-name/boot:39322866:212f0cfa42698ac7da83a728a877a64bce55fa88 EMMC:/dev/block/bootdevice/by-name/recovery c456c0cfdcea7fdead54a424078b8d1948e718b6 45315318 212f0cfa42698ac7da83a728a877a64bce55fa88:/system/recovery-from-boot.p && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
else
  log -t recovery "Recovery image already installed"
fi
