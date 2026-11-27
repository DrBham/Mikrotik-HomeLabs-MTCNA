# LAB-06 post-lab fix for CHR-BRANCH-1 (RouterOS 7)
# Status: proposed, not yet validated in the lab.
# Run once on the LAB-06 state, from WinBox on ether1 (management),
# with Safe Mode enabled. The firewall keeps ether1 reachable from
# 192.168.56.0/24.
#
# Problems: BRANCH has no firewall, no default route, no NAT, gives
# clients no DNS server, and keeps a leftover DHCP client on ether4.

# 1. Clean-up and naming
/ip dhcp-client remove [find interface=ether4]
/ip dhcp-server set [find name=dhcp1] name=DHCP-BRANCH
/ip address set [find address="192.168.20.1/24"] comment="BRANCH LAN"
/ip address set [find address="192.168.100.253/24"] comment="Transit to HQ/ISP"

# 2. DNS for BRANCH clients, forwarded to the ISP resolver
/ip dns set allow-remote-requests=yes servers=192.168.100.1
/ip dhcp-server network set [find address="192.168.20.0/24"] dns-server=192.168.20.1

# 3. Default route to the ISP; HQ LAN keeps its more specific route
/ip route add dst-address=0.0.0.0/0 gateway=192.168.100.1 comment="Default to ISP"

# 4. NAT: route to HQ with original addresses, masquerade the rest
/ip firewall nat
add chain=srcnat action=accept src-address=192.168.20.0/24 \
    dst-address=192.168.10.0/24 comment="No NAT BRANCH to HQ"
add chain=srcnat action=masquerade out-interface=ether3 comment="Masquerade to ISP"

# 5. Stateful firewall, same policy as HQ
/ip firewall filter
add chain=input action=drop connection-state=invalid
add chain=input action=accept connection-state=established,related
add chain=input action=accept in-interface=ether1 src-address=192.168.56.0/24 \
    comment="Management"
add chain=input action=accept protocol=icmp
add chain=input action=accept in-interface=ether2 protocol=udp dst-port=67 \
    comment="LAN DHCP"
add chain=input action=accept in-interface=ether2 protocol=udp dst-port=53 \
    comment="LAN DNS (udp)"
add chain=input action=accept in-interface=ether2 protocol=tcp dst-port=53 \
    comment="LAN DNS (tcp)"
add chain=input action=drop comment="Drop other input"
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept connection-state=established,related
add chain=forward action=accept connection-state=new src-address=192.168.20.0/24 \
    out-interface=ether3 comment="BRANCH LAN out"
add chain=forward action=accept connection-state=new src-address=192.168.10.0/24 \
    dst-address=192.168.20.0/24 comment="Allow HQ to BRANCH"
add chain=forward action=drop comment="Drop other forward"
