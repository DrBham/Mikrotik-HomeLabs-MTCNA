# 2026-08-23 11:04:03 by RouterOS 7.21.5
# system id = QDNvwgrnPIO
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
set [ find default-name=ether5 ] disable-running-check=no
/ip address
add address=192.168.10.1/24 comment=LAN interface=ether2 network=192.168.10.0
/ip dhcp-client
add interface=ether1
add interface=ether3
/ip firewall filter
add action=drop chain=input connection-state=invalid
add action=drop chain=forward connection-state=invalid
add action=accept chain=input connection-state=established,related
add action=accept chain=forward connection-state=established,related
add action=accept chain=forward connection-state=new out-interface=ether3 \
    src-address=192.168.10.0/24
add action=drop chain=forward connection-state=new
add action=accept chain=input connection-state=new src-address=\
    192.168.56.0/24
add action=accept chain=input protocol=icmp src-address=192.168.10.0/24
add action=drop chain=input connection-state=new
/ip firewall nat
add action=masquerade chain=srcnat out-interface=ether3
/system identity
set name=HQ
