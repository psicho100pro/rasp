sudo nmcli connection modify "LAN" \
    ipv4.addresses 192.168.50.50/24 \
    ipv4.gateway 192.168.50.1 \
    ipv4.method manual \
    ipv4.route-metric 100

sudo bash -c 'cat <<EOF > /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF'
sudo sysctl --system

sudo systemctl stop avahi-daemon
sudo systemctl disable avahi-daemon

sudo nano /etc/resolv.conf
# nameserver 8.8.8.8
nameserver 192.168.50.50

sudo bash -c 'cat <<EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=0.cz.pool.ntp.org 1.cz.pool.ntp.org
FallbackNTP=time.cloudflare.com time.google.com
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF'

sudo timedatectl set-timezone Europe/Prague
systemctl restart systemd-timesyncd

sudo bash -c 'cat <<EOF >> /boot/firmware/config.txt
dtparam=i2c_arm=off
#dtparam=i2s=on
dtparam=spi=off

dtparam=audio=off
#dtoverlay=pwm-2chan

camera_auto_detect=0

display_auto_detect=1

auto_initramfs=1

dtoverlay=vc4-kms-v3d
max_framebuffers=2

disable_fw_kms_setup=1

arm_64bit=1

disable_overscan=1

arm_boost=1

[cm4]
otg_mode=1

[cm5]
dtoverlay=dwc2,dr_mode=host

[pi5]
dtoverlay=nospi10

[all]
dtoverlay=disable-wifi
dtoverlay=disable-bt
hdmi_ignore_hotplug=1
hdmi_blanking=2
dtparam=watchdog=on
EOF'

sudo apt update && sudo apt install smartmontools watchdog -y

sudo bash -c 'cat <<EOF > /etc/watchdog.conf
watchdog-device = /dev/watchdog
watchdog-timeout = 15
max-load-1 = 24
realtime = yes
priority = 1
EOF'

sudo systemctl enable --now watchdog
sudo systemctl enable --now fstrim.timer
