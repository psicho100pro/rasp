sudo apt update && sudo apt install curl

curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

sudo useradd -r -s /usr/sbin/nologin adguard 2>/dev/null || true

sudo find /opt/AdGuardHome -type d -exec chmod 755 {} +
sudo find /opt/AdGuardHome -type f -exec chmod 644 {} +
sudo chmod +x /opt/AdGuardHome/AdGuardHome
sudo setcap 'CAP_NET_BIND_SERVICE=+eip CAP_NET_RAW=+eip' /opt/AdGuardHome/AdGuardHome
sudo chown -R adguard:adguard /opt/AdGuardHome

sudo mkdir -p /etc/adguardhome
sudo mkdir -p /var/lib/adguardhome
sudo touch /etc/adguardhome/AdGuardHome.yaml
sudo chown -R adguard:adguard /etc/adguardhome
sudo chown -R adguard:adguard /var/lib/adguardhome

sudo mkdir -p /etc/systemd/system/AdGuardHome.service.d/

sudo bash -c 'cat <<EOF > /etc/systemd/system/AdGuardHome.service.d/user_isolation.conf
[Service]
User=adguard
Group=adguard
WorkingDirectory=/var/lib/adguardhome
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
ProtectHome=yes
ProtectSystem=full
ReadWritePaths=/etc/adguardhome /var/lib/adguardhome
EOF'

sudo bash -c 'cat <<EOF > /etc/systemd/system/AdGuardHome.service
[Unit]
Description=AdGuard Home: Network-level blocker
After=network-online.target unbound.service
Requires=unbound.service

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/opt/AdGuardHome/AdGuardHome -s run -c /etc/adguardhome/AdGuardHome.yaml -w /var/lib/adguardhome
WorkingDirectory=/var/lib/adguardhome
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable AdGuardHome
sudo systemctl restart AdGuardHome
