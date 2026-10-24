sudo nano /usr/local/bin/update_pi.sh
#!/bin/bash
apt update && apt full-upgrade -y && apt autoremove --purge -y && apt clean >/dev/null 2>&1
pihole -up --unattended >/dev/null 2>&1 || true
/opt/AdGuardHome/AdGuardHome --update >/dev/null 2>&1
#sudo apt install --only-upgrade unbound
systemctl restart unbound && systemctl reload rspamd >/dev/null 2>&1
sleep 30

systemctl is-active --quiet unbound AdGuardHome pihole-FTL redis-server rspamd imapfilter || exit 1

touch /usr/local/bin/update_pi.sh


sudo chmod +x /usr/local/bin/update_pi.sh

(sudo crontab -l 2>/dev/null; echo "30 2 * * 6 /usr/local/bin/update_pi.sh") | sudo crontab -
