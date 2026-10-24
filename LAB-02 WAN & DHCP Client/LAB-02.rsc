# 2026-08-21 15:46:47 by RouterOS 7.21.5
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
/system identity
set name=MTCNA-SOHO-R1
