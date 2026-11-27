# 2026-11-27 11:18:11 by RouterOS 7.21.5
# system id = Qijs24pwqKH
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
add name=ISP-POOL ranges=192.168.100.10-192.168.100.200
/ip dhcp-server
add address-pool=ISP-POOL interface=ether2 name=ISP-DHCP
/ip neighbor discovery-settings
set discover-interface-list=MGMT
/interface list member
add interface=ether1 list=MGMT
/ip address
add address=192.168.100.1/24 interface=ether2 network=192.168.100.0
/ip dhcp-client
add interface=ether1
/ip dhcp-server lease
add address=192.168.100.254 client-id=1:8:0:27:fd:dc:5f comment=\
    "HQ WAN reserved" mac-address=08:00:27:FD:DC:5F server=ISP-DHCP
/ip dhcp-server network
add address=192.168.100.0/24 dns-server=192.168.100.1 gateway=192.168.100.1
/ip dns
set allow-remote-requests=yes
/ip dns static
add address=192.168.100.1 comment="DNS test record" name=isp.lab type=A
/ip service
set ftp disabled=yes
set ssh address=192.168.56.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=192.168.56.0/24
set api disabled=yes
set api-ssl disabled=yes
/system identity
set name=ISP
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=MGMT
/tool mac-server mac-winbox
set allowed-interface-list=MGMT
