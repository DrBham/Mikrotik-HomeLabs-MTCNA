# 2026-11-27 11:17:46 by RouterOS 7.21.5
# system id = lwyZIl1J8RG
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
set [ find default-name=ether5 ] disable-running-check=no
/interface list
add name=MGMT
/ip pool
add name=BRANCH-POOL ranges=192.168.20.10-192.168.20.100
/ip dhcp-server
add address-pool=BRANCH-POOL interface=ether2 name=DHCP-BRANCH
/ip neighbor discovery-settings
set discover-interface-list=MGMT
/interface list member
add interface=ether1 list=MGMT
/ip address
add address=192.168.20.1/24 comment="BRANCH LAN" interface=ether2 network=\
    192.168.20.0
add address=192.168.100.253/24 comment="Transit to HQ/ISP" interface=ether3 \
    network=192.168.100.0
/ip dhcp-client
add interface=ether1
/ip dhcp-server network
add address=192.168.20.0/24 dns-server=192.168.20.1 gateway=192.168.20.1
/ip dns
set allow-remote-requests=yes servers=192.168.100.1
/ip firewall filter
add action=drop chain=input connection-state=invalid
add action=accept chain=input connection-state=established,related
add action=accept chain=input comment=Management in-interface=ether1 \
    src-address=192.168.56.0/24
add action=accept chain=input protocol=icmp
add action=accept chain=input comment="LAN DHCP" dst-port=67 in-interface=\
    ether2 protocol=udp
add action=accept chain=input comment="LAN DNS (udp)" dst-port=53 \
    in-interface=ether2 protocol=udp
add action=accept chain=input comment="LAN DNS (tcp)" dst-port=53 \
    in-interface=ether2 protocol=tcp
add action=drop chain=input comment="Drop other input"
add action=drop chain=forward connection-state=invalid
add action=accept chain=forward connection-state=established,related
add action=accept chain=forward comment="BRANCH LAN out" connection-state=new \
    out-interface=ether3 src-address=192.168.20.0/24
add action=accept chain=forward comment="Allow HQ to BRANCH" \
    connection-state=new dst-address=192.168.20.0/24 src-address=\
    192.168.10.0/24
add action=drop chain=forward comment="Drop other forward"
/ip firewall nat
add action=accept chain=srcnat comment="No NAT BRANCH to HQ" dst-address=\
    192.168.10.0/24 src-address=192.168.20.0/24
add action=masquerade chain=srcnat comment="Masquerade to ISP" out-interface=\
    ether3
/ip route
add disabled=no dst-address=192.168.10.0/24 gateway=192.168.100.254 \
    routing-table=main
add comment="Default to ISP" dst-address=0.0.0.0/0 gateway=192.168.100.1
/ip service
set ftp disabled=yes
set ssh address=192.168.56.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=192.168.56.0/24
set api disabled=yes
set api-ssl disabled=yes
/system identity
set name=BRANCH
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=MGMT
/tool mac-server mac-winbox
set allowed-interface-list=MGMT
