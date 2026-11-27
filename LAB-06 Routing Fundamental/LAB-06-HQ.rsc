# 2026-11-27 11:16:33 by RouterOS 7.21.5
# system id = QDNvwgrnPIO
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
add name=LAN-POOL ranges=192.168.10.10-192.168.10.100
/ip dhcp-server
add address-pool=LAN-POOL interface=ether2 name=DHCP-LAN
/ip neighbor discovery-settings
set discover-interface-list=MGMT
/interface list member
add interface=ether1 list=MGMT
/ip address
add address=192.168.10.1/24 comment=LAN interface=ether2 network=192.168.10.0
/ip dhcp-client
add interface=ether1
add interface=ether3
/ip dhcp-server network
add address=192.168.10.0/24 dns-server=192.168.10.1 gateway=192.168.10.1
/ip dns
set allow-remote-requests=yes
/ip firewall filter
add action=drop chain=input connection-state=invalid
add action=drop chain=forward connection-state=invalid
add action=accept chain=input connection-state=established,related
add action=accept chain=forward comment="Accept established forward" \
    connection-state=established,related
add action=accept chain=forward comment="LAN to WAN" connection-state=new \
    out-interface=ether3 src-address=192.168.10.0/24
add action=accept chain=forward comment=LAB06-Allow-Branch-to-HQ \
    connection-state=new dst-address=192.168.10.0/24 src-address=\
    192.168.20.0/24
add action=drop chain=forward comment="Drop other new forward" \
    connection-state=new
add action=accept chain=input connection-state=new src-address=\
    192.168.56.0/24
add action=accept chain=input protocol=icmp src-address=192.168.10.0/24
add action=accept chain=input comment="Allow LAN DNS (udp)" dst-port=53 \
    in-interface=ether2 protocol=udp
add action=accept chain=input comment="Allow LAN DNS (tcp)" dst-port=53 \
    in-interface=ether2 protocol=tcp
add action=drop chain=input comment="Drop other new input" connection-state=\
    new
/ip firewall nat
add action=accept chain=srcnat comment=LAB06-No-NAT-HQ-to-Branch dst-address=\
    192.168.20.0/24 src-address=192.168.10.0/24
add action=masquerade chain=srcnat out-interface=ether3
/ip route
add disabled=no dst-address=192.168.20.0/24 gateway=192.168.100.253 \
    routing-table=main
/ip service
set ftp disabled=yes
set ssh address=192.168.56.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=192.168.56.0/24
set api disabled=yes
set api-ssl disabled=yes
/system identity
set name=HQ
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=MGMT
/tool mac-server mac-winbox
set allowed-interface-list=MGMT
