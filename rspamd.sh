sudo groupadd --system rspamd
sudo useradd --system -g rspamd -s /bin/false -d /var/lib/rspamd rspamd

wget -O- https://rspamd.com/rpm/gpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/rspamd.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/rspamd.gpg] https://rspamd.com/apt/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/rspamd.list
sudo apt update
sudo apt install -y rspamd


sudo bash -c 'cat <<EOF > /etc/systemd/system/rspamd.service
[Unit]
Description=rapid spam filtering system
After=network-online.target redis-server.service pihole-FTL.service
Wants=redis-server.service pihole-FTL.service
Documentation=https://rspamd.com

[Service]
Type=simple
LimitNOFILE=1048576
NonBlocking=true
ExecStart=/usr/bin/rspamd -c /etc/rspamd/rspamd.conf -f
ExecReload=/bin/kill -HUP \$MAINPID
User=rspamd
Group=rspamd
RuntimeDirectory=rspamd
RuntimeDirectoryMode=0755
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF'

sudo mkdir -p /etc/rspamd/local.d
sudo chown -R rspamd:rspamd /var/lib/rspamd
sudo chown -R rspamd:rspamd /var/log/rspamd
sudo chown -R rspamd:rspamd /etc/rspamd

sudo mkdir -p /etc/rspamd/local.d

sudo bash -c 'cat <<EOF > /etc/rspamd/local.d/worker-controller.inc
bind_socket = "0.0.0.0:11334";
allow_file_and_shm_inputs = false;
secure_ip = [
  "127.0.0.1",
  "192.168.10.0/26",
  "192.168.20.0/26",
  "192.168.30.0/26"
];
EOF'

sudo bash -c 'cat <<EOF > /etc/rspamd/local.d/dkim_signing.conf
enabled = false;
EOF'

echo 'servers = "127.0.0.1:6379";' | sudo tee /etc/rspamd/local.d/redis.conf

sudo bash -c 'cat <<EOF > /etc/rspamd/local.d/rbl.conf
rbls {
  nixspam {
    enabled = false;
  }
}
EOF'

sudo bash -c 'cat <<EOF > /etc/rspamd/local.d/statistic.conf
new_schema = true;

classifier "bayes" {
  backend = "redis";
  autolearn = true;
  new_schema = true;
  expire = 86400000;
  min_learns = 50;

  statfile {
    symbol = "BAYES_SPAM";
  }
  statfile {
    symbol = "BAYES_HAM";
  }
}
EOF'

sudo bash -c 'cat <<EOF > /etc/rspamd/local.d/options.inc
user = "rspamd";
group = "rspamd";
map_watch_interval = 1209600;
rules_update_interval = "336h";
chunk_size = 16kb;
max_memory_usage = 128Mb;
max_urls = 50;
max_images = 10;
max_message = 20Mb;
dns {
    nameserver = ["127.0.0.1:53"];
    retransmits = 3;
    timeout = 3s;
    error_time = 30s;
    max_errors = 5;
    remote_signals = false;
    skip_local = true;
}
EOF'

sudo systemctl enable rspamd
sudo systemctl restart rspamd
