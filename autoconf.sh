#!/bin/bash
echo "[RadLib] Creating calibre-server service"
sudo cat > /etc/systemd/system/calibre-server.service << EOF
[Unit]
Description=calibre Content server
After=network.target

[Service]
Type=simple
User=RadLib
Group=RadLib
ExecStart=/usr/bin/calibre-server "/home/to/library1" "/path/to/library2" "etc"

[Install]
WantedBy=multi-user.target
EOF

echo "[RadLib] reloading daemon-reload"

sudo systemctl daemon-reload

echo "[RadLib] starting calibre-server service"

sudo systemctl start calibre-server

echo "[RadLib] installing require utilities"

sudo apt-get install hostapd dnsmasq git build-essential libmicrohttpd-dev net-tools nginx dhcpcd5 -y

cd /opt; sudo git clone https://github.com/nodogsplash/nodogsplash.git; sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent

echo "[RadLib] Managing hostapd service"

sudo systemctl unmask hostapd; sudo systemctl disable hostapd

echo "[RadLib] creating dhcpd.conf"

sudo cat >> /etc/dhcpcd.conf << EOF
interface $(ip -o -4 route show to default | awk '{print $5}')
    static ip_address=192.168.131.2/24
    nohook wpa_supplicant
EOF

echo "Saving old dnsmasq config to /etc/dnsmasq.conf.orig and creating new one"

sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig

sudo cat > /etc/dnsmasq.conf << EOF
interface=$(ip -o -4 route show to default | awk '{print $5}')
dhcp-range=192.168.131.2,192.168.131.1, 255.255.255.0,24h
domain=wlan
address=/#/192.168.131.1
domain-needed
bogus-priv
expand-hosts
bind-interfaces
port=53
EOF

echo "[RadLib] Doing rfkill unblock wlan"

sudo rfkill unblock wlan

echo "[RadLib] stopping systemd-resolved"

sudo systemctl stop systemd-resolved

echo "[RadLib] Adding services to startup"

sudo cat > /etc/rc.local << EOF
#!/bin/bash
sudo ifconfig $(ip -o -4 route show to default | awk '{print $5}') 192.168.131.2 netmask 255.255.255.0
sudo service systemd-resolved stop
sudo service dnsmasq start
sudo nginx -t
EOF

echo "[RadLib] Managing nginx"

sudo unlink /etc/nginx/sites-enabled/default

sudo cat > /etc/nginx/sites-available/example.conf << EOF
server {
listen 80;

server_name book.server;

location / {
proxy_pass http://192.168.131.2:8080;
                
}

}
EOF

sudo ln -s /etc/nginx/sites-available/example.conf /etc/nginx/sites-enabled/

sudo systemctl restart nginx

echo "[RadLib] Configuring name resolution"

sudo cat >> /etc/hosts << EOF
192.168.131.2 book.server
EOF

echo -e "From here you want to do the following\n\
\t1) enable a DHCP server from your router settings\n\
\t2) Set the start and end IP addresses to 192.168.131.100 and 192.168.131.199, respectively\n\
\t3) Set the default gateway to 192.168.131.1\n\
\t4) Set the DNS server to 192.168.131.2"