cd ~/hostfs/projects/andr2000/domu-kernel/drivers/gpu/drm
echo 8 > /proc/sys/kernel/printk
modprobe drm_kms_helper 
rmmod drm_kms_helper
rmmod drm
insmod drm.ko
insmod drm_kms_helper.ko
echo 0xff > /sys/module/drm/parameters/debug
#tail -f /var/log/syslog &
