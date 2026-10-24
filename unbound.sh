sudo apt update
sudo apt install -y unbound unbound-anchor

sudo mkdir -p /var/lib/unbound
sudo wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache

sudo -u unbound unbound-anchor -a "/var/lib/unbound/root.key"
sudo chown -R unbound:unbound /var/lib/unbound
sudo chmod 644 /var/lib/unbound/root.key /var/lib/unbound/root.hints

sudo bash -c 'cat <<EOF > /lib/systemd/system/unbound.service
[Unit]
Description=Unbound DNS server
Documentation=man:unbound(8)
After=network.target
Before=nss-lookup.target
Wants=nss-lookup.target

[Service]
Type=notify
Restart=on-failure
LimitNOFILE=16384
EnvironmentFile=-/etc/default/unbound
ExecStartPre=-/usr/libexec/unbound-helper chroot_setup
ExecStartPre=-/usr/libexec/unbound-helper root_trust_anchor_update
ExecStart=/usr/sbin/unbound -d \$DAEMON_OPTS
ExecStopPost=-/usr/libexec/unbound-helper chroot_teardown
ExecReload=+/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF'

sudo bash -c 'cat <<EOF > /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-ip6: no
    prefer-ip6: no
    do-udp: yes
    do-tcp: yes
    access-control: 127.0.0.0/8 allow
    module-config: "respip validator iterator"
    response-ip: ::/0 redirect

    root-hints: "/var/lib/unbound/root.hints"

    num-threads: 2
    msg-cache-slabs: 2
    rrset-cache-slabs: 2
    infra-cache-slabs: 2
    key-cache-slabs: 2

    msg-cache-size: 32m
    rrset-cache-size: 64m

    num-queries-per-thread: 4096
    outgoing-range: 8192

    so-rcvbuf: 4m
    so-sndbuf: 4m
    infra-cache-numhosts: 10000

    cache-min-ttl: 0
    cache-max-ttl: 86400
    prefetch: yes
    prefetch-key: yes
    aggressive-nsec: yes

    jostle-timeout: 200
    delay-close: 0

    edns-buffer-size: 1232
    minimal-responses: yes

    serve-expired: yes
    serve-expired-ttl: 86400
    serve-expired-reply-ttl: 30

    qname-minimisation: yes
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    
    harden-below-nxdomain: no
    harden-referral-path: no
    use-caps-for-id: no

    statistics-interval: 0
    statistics-cumulative: no
    extended-statistics: yes

remote-control:
    control-enable: yes
    control-interface: 127.0.0.1
    control-port: 8953
    server-key-file: "/etc/unbound/unbound_server.key"
    server-cert-file: "/etc/unbound/unbound_server.pem"
    control-key-file: "/etc/unbound/unbound_control.key"
    control-cert-file: "/etc/unbound/unbound_control.pem"
EOF'

sudo unbound-checkconf
sudo unbound-control-setup
sudo systemctl daemon-reload
sudo systemctl restart unbound
