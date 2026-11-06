# ============================================================
# RouterOS auto-update (v7)
# - Does NOT change the update channel
# - Firmware after reboot is handled by ros-fw-auto-upgrade
# ============================================================

:local maxWaitLoops 24
:local checkStatus ""

:log info "RouterOS auto-update: checking for updates..."
/system package update check-for-updates

# Wait for the update server response
:local i 0
:set checkStatus [/system package update get status]
:while (($i < $maxWaitLoops) && ($checkStatus ~ "checking")) do={
    :delay 5s
    :set i ($i + 1)
    :set checkStatus [/system package update get status]
}

:local installedVer [/system package update get installed-version]
:local latestVer   [/system package update get latest-version]

:log info ("RouterOS auto-update: installed=" . $installedVer . ", latest=" . $latestVer . ", status=" . $checkStatus)

:if (($latestVer = "") || ($latestVer = "unknown")) do={
    :log error ("RouterOS auto-update: update check failed. Status: " . $checkStatus)
} else={
    :if ($installedVer != $latestVer) do={
        :log info ("RouterOS auto-update: new version available: " . $installedVer . " -> " . $latestVer)
        :log info "RouterOS auto-update: downloading and installing. Router will reboot."
        # Downloads packages and reboots automatically.
        # Post-reboot firmware step is done by ros-fw-auto-upgrade at startup.
        /system package update install
    } else={
        :log info ("RouterOS auto-update: system is already up to date. Version: " . $installedVer)
    }
}
