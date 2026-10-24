curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --advertise-routes=192.168.50.0/24 --advertise-exit-node --accept-dns=false

echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf

sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i tailscale0 -o eth0 -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o tailscale0 -m state --state RELATED,ESTABLISHED -j ACCEPT

sudo apt install iptables-persistent

sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

sudo apt install iptables-persistent -y
sudo netfilter-persistent save

https://login.tailscale.com/admin/machines
