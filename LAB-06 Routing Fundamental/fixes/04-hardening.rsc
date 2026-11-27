# Basic management hardening for CHR-ISP-1, CHR-HQ-1 and CHR-BRANCH-1
# (RouterOS 7). Status: proposed, not yet validated in the lab.
# Assumes ether1 is the management port on 192.168.56.0/24.
# Run on each router from WinBox on ether1, with Safe Mode enabled.

# 1. Management interface list
/interface list add name=MGMT
/interface list member add list=MGMT interface=ether1

# 2. Turn off unused services; allow WinBox and SSH from management only
/ip service disable [find name~"^(telnet|ftp|www|api|api-ssl)\$"]
/ip service set [find name~"^(winbox|ssh)\$"] address=192.168.56.0/24

# 3. Limit discovery and MAC access to the management port
/ip neighbor discovery-settings set discover-interface-list=MGMT
/tool mac-server set allowed-interface-list=MGMT
/tool mac-server mac-winbox set allowed-interface-list=MGMT
/tool bandwidth-server set enabled=no

# 4. Replace the default admin account (manual, needs your own password):
#   /user add name=<NEW_ADMIN> group=full password=<STRONG_PASSWORD>
#   Log in again as <NEW_ADMIN>, then:
#   /user disable admin
