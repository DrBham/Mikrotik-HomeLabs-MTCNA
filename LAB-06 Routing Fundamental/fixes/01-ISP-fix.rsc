# LAB-06 post-lab fix for CHR-ISP-1 (RouterOS 7)
# Status: proposed, not yet validated in the lab.
# Run once on the LAB-06 state, from the Terminal of CHR-ISP-1.
#
# Problem: ISP-POOL (192.168.100.10-254) contains the static BRANCH
# transit address .253 and the HQ lease .254 that BRANCH routes to.
# Fix: pin the HQ lease and move the pool away from both addresses.

# 1. Turn the current HQ lease into a static reservation
/ip dhcp-server lease make-static [find address=192.168.100.254]
/ip dhcp-server lease set [find address=192.168.100.254] comment="HQ WAN reserved"

# 2. Keep .201-.254 out of the dynamic pool (BRANCH .253, HQ .254)
/ip pool set [find name=ISP-POOL] ranges=192.168.100.10-192.168.100.200

# 3. Local record so LAN clients can test DNS end to end
/ip dns static add name=isp.lab address=192.168.100.1 comment="DNS test record"
