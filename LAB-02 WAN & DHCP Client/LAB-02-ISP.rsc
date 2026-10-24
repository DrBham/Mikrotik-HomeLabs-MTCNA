# 2026-08-21 15:53:50 by RouterOS 7.21.5
# system id = Qijs24pwqKH
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
set [ find default-name=ether5 ] disable-running-check=no
/ip pool
add name=ISP-POOL ranges=192.168.100.10-192.168.100.254
/ip dhcp-server
add address-pool=ISP-POOL interface=ether2 name=ISP-DHCP
/ip address
add address=192.168.100.1/24 interface=ether2 network=192.168.100.0
/ip dhcp-client
add interface=ether1
/ip dhcp-server network
add address=192.168.100.0/24 dns-server=192.168.100.1 gateway=192.168.100.1
/ip dns
set allow-remote-requests=yes
/system identity
set name=ISP
