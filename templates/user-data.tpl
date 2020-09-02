#!/bin/bash -v
apt update -y
apt install -y wireguard awscli

mkdir /etc/wireguard && touch /etc/wireguard/wg0.conf
cat > /etc/wireguard/wg0.conf <<- EOF
[Interface]
Address = 172.32.0.1/24
PrivateKey = ${wg_server_private_key}
ListenPort = 51820
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

${peers}
EOF

export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
export REGION=$(curl -fsq http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
aws --region $${REGION} ec2 associate-address --allocation-id ${eip_id} --instance-id $${INSTANCE_ID}


chown -R root:root /etc/wireguard/
chmod -R og-rwx /etc/wireguard/*
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p
ufw allow ssh
ufw allow 51820/udp
ufw --force enable
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
