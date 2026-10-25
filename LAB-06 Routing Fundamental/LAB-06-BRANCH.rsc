# 2026-10-25 07:29:04 by RouterOS 7.21.5
# system id = lwyZIl1J8RG
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
set [ find default-name=ether5 ] disable-running-check=no
/ip pool
add name=BRANCH-POOL ranges=192.168.20.10-192.168.20.100
/ip dhcp-server
add address-pool=BRANCH-POOL interface=ether2 name=dhcp1
/ip address
add address=192.168.20.1/24 interface=ether2 network=192.168.20.0
add address=192.168.100.253/24 interface=ether3 network=192.168.100.0
/ip dhcp-client
add interface=ether1
# Interface not active
add interface=ether4
/ip dhcp-server network
add address=192.168.20.0/24 gateway=192.168.20.1
/ip route
add disabled=no dst-address=192.168.10.0/24 gateway=192.168.100.254 \
    routing-table=main
/system identity
set name=BRANCH
