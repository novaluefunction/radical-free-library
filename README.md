# radical-free-library
Share information with anyone in wifi distance
================================================================================================================================================================================================================
================================================================================================================================================================================================================
RadLib setup instructions
================================================================================================================================================================================================================
================================================================================================================================================================================================================

High-level setup:
    server <-> router <-> {{{local wifi}}}

    Server: The computer which hosts calibre book server on port 8080 (and ideally an nginx proxy @ http://book.server, but not yet working properly. A workaround is in place.)

    Router: A router configured to act as a router, assigning a static IP to the server.

    Local Network: WiFi network users can connect to to access the book server.

    We want our server running Calibre/whatever, with the server having a static IP on the network. We want the router configured to redirect to a captive portal which would give instructions to those who connect, but this capability seems router dependant and my current router does not allow for this (at least not easily).

================================================================================================================================================================================================================
================================================================================================================================================================================================================

Quick(ish) setup:
    Follow steps 1), 2), and 3) below. Then, edit `autoconf.sh` such that line 12, "ExecStart=..." so that the directory it points to is your library.
    From there, do
        ./autoconf.sh
    which should set up everything for you, and then tell you the next steps to take. You may need to do
        chmod +x autoconf.sh
    before you attempt to run it

================================================================================================================================================================================================================
================================================================================================================================================================================================================

To replicate:
    Server: Largely can follow instructions from https://anarchosolarpunk.substack.com/p/bannedbooklibrary for the calibre server, but here's the bare-bones from that.
    1) do 
                `sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin`
        This will download calibre and install it.
    2) do 
                `calibre` 
        This will run calibre
    3) At this point set up your calibre instance with the books you want, see the above link for more details
    4) do 
                `sudo cat > /etc/systemd/system/calibre-server.service << EOF
                [Unit]
                Description=calibre Content server
                After=network.target

                [Service]
                Type=simple
                User=
                Group=
                ExecStart=/usr/bin/calibre-server "/path/to/library1" "/path/to/library2" "etc"

                [Install]
                WantedBy=multi-user.target
                EOF`
        with "User" set to the name of your library, "Group" set to the name of the user, and the paths on the exec start line replaced with paths to each of the libraries you want included (each in quotes, space-separated). This will create a file for starting calibre as a service on boot, which will be enabled later in (15)
    5) do 
                `sudo systemctl daemon-reload` 
        This forces service configs to be reloaded
    6) do 
                `sudo systemctl start calibre-server` 
        This starts the service we created in (4)
    7) do
                `sudo apt-get install hostapd dnsmasq git build-essential libmicrohttpd-dev net-tools nginx dhcpcd5 -y`
        If you really want to cut out chaff, my set up doesn't use hostapd or git, and I don't think makes use of build-essential, libmicrohttpd-dev, or net-tools, and I am unsure about dhcpd5 (it's been a minute between setting it up and writing this), which means I /think/ you just need "dnsmasq" and "nginx" from that list, but since you're removing the computer's ability to connect to the internet at a point it might save you some heartache down the line to go ahead and grab all this now if system resources aren't a concern, and you think you may want to make it fancier later.
    8) Optionally, if you want to mess with the nice webpage stuff, you would now want to
                `cd /opt; sudo git clone https://github.com/nodogsplash/nodogsplash.git; sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent`
    9) do
                `sudo systemctl unmask hostapd; sudo systemctl disable hostapd`
    10) do
                `sudo cat >> /etc/dhcpcd.conf << EOF
                interface IFACE
                    static ip_address=192.168.131.2/24
                    nohook wpa_supplicant
                EOF`
        replacing IFACE with the name of the interface you want to specify, possible 'wlan0' or something, can be found by doing `ifconfig` or `ip addr` and seeing which device corresponds to your wireless card. Be careful to use ">>" and not ">" since you want to append this line to /etc/dhcpcd, not overwrite the whole file.
    11) do
                `sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig`
    12) do
                `sudo cat > /etc/dnsmasq.conf << EOF
                interface=IFACE
                dhcp-range=192.168.131.2,192.168.131.1, 255.255.255.0,24h
                domain=wlan
                address=/#/192.168.131.1
                domain-needed
                bogus-priv
                expand-hosts
                bind-interfaces
                port=53
                EOF`
        replacing IFACE with the name of the interface you want to specify, possible 'wlan0' or something, can be found by doing `ifconfig` or `ip addr` and seeing which device corresponds to your wireless card.
    13) do
                `sudo rfkill unblock wlan`
    14) do
                `sudo systemctl stop systemd-resolved`
    15) do
                `sudo cat > /etc/rc.local << EOF
                #!/bin/bash
                sudo ifconfig IFACE 192.168.131.2 netmask 255.255.255.0
                sudo service systemd-resolved stop
                sudo service dnsmasq start
                sudo nginx -t
                EOF`
        replacing IFACE with the name of the interface you want to specify, possibly 'wlan0' or something, can be found by doing `ifconfig` or `ip addr` and seeing which device corresponds to your wireless card. The "ifconfig" line will set a static IP for your computer.
    16) do
                `sudo unlink /etc/nginx/sites-enabled/default`
    17) do
                `sudo cat > /etc/nginx/sites-available/example.conf << EOF
                server {
                listen 80;

                server_name book.server;

                location / {
                proxy_pass http://192.168.131.2:8080;
                
                }

                }
                EOF`
    18) do
                `sudo ln -s /etc/nginx/sites-available/example.conf /etc/nginx/sites-enabled/`
    19) do
                `sudo nginx -t`
    if it says "test successful": yay, else: not yay.
    20) do
                `sudo systemctl restart nginx`
    21) do
                `sudo cat >> /etc/hosts << EOF
                192.168.131.2 book.server
                EOF`
        This is something, in addition to the next few steps, that I had to do to actually get http://book.server to resolve to http://192.168.131.2, i.e. our calibre webserver, since my router does not play well with the instructions as provided in the blog post. As such, I'm sure some of what was done above is rendered redundant, but I'm unsure what exactly, so I left things I was unsure were necessary, but that I was sure did not cause problems. YMMV. 
    
    ASIDE: Unfortunately, for these next few steps I do not have any command line things to do what I want, since as best as I could tell my router does not have an easy to access command line interface, so I just logged in and toggled settings. This is a recounting of those togglings.
    
    22) If you router has an option to enable a DHCP server, do so.
    23) Set the start IP address to 192.168.131.100 and the end to 192.168.131.199
    24) Set the default gateway to 192.168.131.1 (the router's IP)
    25) Set the DNS server to 192.168.131.2 (the computer's IP)
    
    Steps 21-25, to the best of my understanding, tell the router to check the file /etc/hosts on the computer to try and resolve names, and we specifically tied 192.168.131.2 to book.server in that file.

    26) If you want to run the server in headless mode, do
                `sudo systemctl set-default multi-user`
    27) Finally, reboot the server and everything should work as desired.

================================================================================================================================================================================================================
================================================================================================================================================================================================================

List of important files that were created/edited:
    /etc/systemd/system/calibre-server.service
    /etc/dhcpcd.conf
    /etc/dnsmasq.conf.orig
    /etc/dnsmasq.conf
    /etc/rc.local
    /etc/nginx/sites-available/example.conf
    /etc/hosts

So keep these in mind if you're trying to debug anything.

================================================================================================================================================================================================================================================================================================================================================================================================================================================

Misc. Notes: 
    This can pretty much all be automated, and I'll start working on a script soon to try and tie it together, though some manual work will likely have to be done to interact with calibre, and programmatic router interaction seems model-dependant. I'll again point you, gentle reader, back to the original blog post which goes into much greater detail about the "whys" of a lot of this stuff, as I don't want to really rehash it all here (and I don't understand a lot of the specific configurations very well at the time of writing). More broadly, I would like to set up something portable like a qcow pre-configured to do as much of this as possible, with additional instructions on how to just run that under qemu from any linux system, which (hopefully) would take a lot of the load off of whoever might be maintaining the server, but I haven't put a lot of thought into that yet, or tested it, so I'm unsure if that would just create more problems than it solves. These notes are more for me, than you, after all.
