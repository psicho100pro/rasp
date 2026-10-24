sudo apt update && sudo apt install monit -y
sudo nano /etc/monit/monitrc
set daemon  240 
set httpd port 2812 and
    use address 0.0.0.0
    allow 0.0.0.0/0


check process unbound matching "^/usr/sbin/unbound"
    group dns
    start program = "/usr/bin/systemctl start unbound"
    stop program = "/usr/bin/systemctl stop unbound"

check process AdGuardHome matching "AdGuardHome"
    group dns
    start program = "/usr/bin/systemctl start AdGuardHome"
    stop program = "/usr/bin/systemctl stop AdGuardHome"
    depends on unbound
    
check process pihole-FTL matching "pihole-FTL"
    group dns
    start program = "/usr/bin/systemctl start pihole-FTL"
    stop program = "/usr/bin/systemctl stop pihole-FTL"
    depends on AdGuardHome

check process redis-server matching "redis-server"
    group mail
    start program = "/usr/bin/systemctl start redis-server"
    stop program = "/usr/bin/systemctl stop redis-server"

check process rspamd matching "rspamd"
    group mail
    start program = "/usr/bin/systemctl start rspamd"
    stop program = "/usr/bin/systemctl stop rspamd"
    depends on redis-server

check process rspamd-iscan matching "rspamd-iscan"
    group mail
    start program = "/usr/bin/systemctl start rspamd-iscan"
    stop program = "/usr/bin/systemctl stop rspamd-iscan"
    depends on rspamd

check process imapfilter matching "imapfilter"
    group mail
    start program = "/usr/bin/systemctl start imapfilter"
    stop program = "/usr/bin/systemctl stop imapfilter"
    if 5 restarts within 5 cycles then timeout

check process fan-control matching "fan_ctrl"
    group hardware
    start program = "/usr/bin/systemctl start fan"
    stop program = "/usr/bin/systemctl stop fan"

check process pihole-led matching "pihole-led"
    group hardware
    start program = "/usr/bin/systemctl start pihole-led"
    stop program = "/usr/bin/systemctl stop pihole-led"

check program cpu_temp with path "/bin/sh -c 'TEMP=$(cat /sys/class/thermal/thermal_zone0/temp); expr $TEMP / 1000; [ $TEMP -le 75000 ]'"
    if status != 0 then alert
    group system

check program LastSystemUpdate with path "/bin/sh -c 'stat -c %y /var/log/apt/history.log 2>/dev/null | cut -d. -f1 | tr \" \" \"_\"'"
    every 60 cycles
    if status != 0 then alert
    group system

check program disk_info with path "/bin/sh -c 'df -h / | tail -n 1 | while read D S U A P M; do echo Total:${S}_Used:${U}_Free:${A}; done'"
    if status != 0 then alert
    group system


sudo systemctl restart monit
sudo monit validate
