# ============================================================
# One-shot install: paste into RouterOS Terminal (v7)
# ============================================================

# --- 1. Main update script ---
/system script add name="ros-auto-update" policy=read,write,reboot,policy,test source=":local maxWaitLoops 24;\r\
:local checkStatus \"\";\r\
:log info \"RouterOS auto-update: checking for updates...\";\r\
/system package update check-for-updates;\r\
:local i 0;\r\
:set checkStatus [/system package update get status];\r\
:while (($i < $maxWaitLoops) && ($checkStatus ~ \"checking\")) do={\r\
    :delay 5s;\r\
    :set i ($i + 1);\r\
    :set checkStatus [/system package update get status];\r\
}\r\
:local installedVer [/system package update get installed-version];\r\
:local latestVer [/system package update get latest-version];\r\
:log info (\"RouterOS auto-update: installed=\" . $installedVer . \", latest=\" . $latestVer . \", status=\" . $checkStatus);\r\
:if (($latestVer = \"\") || ($latestVer = \"unknown\")) do={\r\
    :log error (\"RouterOS auto-update: update check failed. Status: \" . $checkStatus);\r\
} else={\r\
    :if ($installedVer != $latestVer) do={\r\
        :log info (\"RouterOS auto-update: new version available: \" . $installedVer . \" -> \" . $latestVer);\r\
        /system package update install;\r\
    } else={\r\
        :log info (\"RouterOS auto-update: system is already up to date. Version: \" . $installedVer);\r\
    }\r\
}"

# --- 2. Post-boot firmware script ---
/system script add name="ros-fw-auto-upgrade" policy=read,write,reboot,policy,test source=":delay 120s;\r\
:local isRB false;\r\
:do {\r\
    :if ([/system routerboard get routerboard] = true) do={ :set isRB true }\r\
} on-error={}\r\
:if ($isRB) do={\r\
    :local cf [/system routerboard get current-firmware];\r\
    :local uf [/system routerboard get upgrade-firmware];\r\
    :if ($cf != $uf) do={\r\
        :log warning (\"RouterOS post-update: firmware \" . $cf . \" -> \" . $uf . \", upgrading and rebooting.\");\r\
        /system routerboard upgrade;\r\
        :delay 10s;\r\
        /system reboot;\r\
    } else={\r\
        :log info (\"RouterOS post-update: firmware is up to date (\" . $cf . \").\");\r\
    }\r\
} else={\r\
    :log info \"RouterOS post-update: not a RouterBOARD, skipping firmware check.\";\r\
}"

# --- 3. Startup scheduler (permanent, never toggled) ---
/system scheduler add name="ros-fw-upgrade-at-boot" start-time=startup interval=0s \
    on-event="/system script run ros-fw-auto-upgrade" \
    policy=read,write,reboot,policy,test comment="Firmware check after every boot"

# --- 4. Weekly update scheduler ---
/system scheduler add name="ros-auto-update" interval=7d start-time=03:30:00 \
    on-event="/system script run ros-auto-update" \
    policy=read,write,reboot,policy,test comment="Weekly RouterOS update check"

# --- 5. First run ---
:log info "Install done. Run manually: /system script run ros-auto-update"
