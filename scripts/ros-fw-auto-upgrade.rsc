# ============================================================
# Post-boot RouterBOARD firmware auto-upgrade (v7)
# Idempotent: after upgrade+reboot current-firmware ==
# upgrade-firmware, so the script exits without writing
# anything. No infinite reboot loop possible.
# ============================================================

:delay 120s

:local isRB false
:do {
    :if ([/system routerboard get routerboard] = true) do={ :set isRB true }
} on-error={}

:if ($isRB) do={
    :local cf [/system routerboard get current-firmware]
    :local uf [/system routerboard get upgrade-firmware]

    :if ($cf != $uf) do={
        :log warning ("RouterOS post-update: firmware " . $cf . " -> " . $uf . ", upgrading and rebooting.")
        /system routerboard upgrade
        :delay 10s
        /system reboot
    } else={
        :log info ("RouterOS post-update: firmware is up to date (" . $cf . ").")
    }
} else={
    :log info "RouterOS post-update: not a RouterBOARD, skipping firmware check."
}
