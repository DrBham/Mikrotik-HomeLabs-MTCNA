# LAB-06 post-lab fix for CHR-HQ-1 (RouterOS 7)
# Status: proposed, not yet validated in the lab.
# Run once on the LAB-06 state. Enable WinBox Safe Mode first.
#
# Problem: DHCP hands PC1 the DNS server 192.168.10.1, but HQ does
# not accept remote DNS requests and the input chain drops new
# DNS traffic from the LAN. PC1 cannot resolve names.

# 1. Let HQ answer DNS queries (upstream comes from the WAN DHCP lease)
/ip dns set allow-remote-requests=yes

# 2. Accept DNS from the LAN, above the final "drop new input" rule
/ip firewall filter
add chain=input action=accept protocol=udp dst-port=53 in-interface=ether2 \
    comment="Allow LAN DNS (udp)" \
    place-before=[find chain=input action=drop connection-state=new]
add chain=input action=accept protocol=tcp dst-port=53 in-interface=ether2 \
    comment="Allow LAN DNS (tcp)" \
    place-before=[find chain=input action=drop connection-state=new]
