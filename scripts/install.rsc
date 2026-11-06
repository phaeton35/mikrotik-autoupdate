# ============================================================
# One-shot install (v7): pasted into RouterOS Terminal.
# Requires internet access to raw.githubusercontent.com.
# Idempotent: safe to re-run, removes old entries first.
# ============================================================

:local baseUrl "https://raw.githubusercontent.com/phaeton35/mikrotik-autoupdate/main/scripts"

# --- 0. Clean up old entries (idempotent reinstall) ---
:do { /system script remove [find name="ros-auto-update"] } on-error={}
:do { /system script remove [find name="ros-fw-auto-upgrade"] } on-error={}
:do { /system scheduler remove [find name="ros-auto-update"] } on-error={}
:do { /system scheduler remove [find name="ros-fw-upgrade-at-boot"] } on-error={}

# --- 1. Fetch script files from GitHub raw ---
:log info "Install: fetching scripts from GitHub..."
/tool fetch url=($baseUrl . "/ros-auto-update.rsc") dst-path="ros-auto-update.rsc"
/tool fetch url=($baseUrl . "/ros-fw-auto-upgrade.rsc") dst-path="ros-fw-auto-upgrade.rsc"
:delay 2s

:if ([:len [/file find name="ros-auto-update.rsc"]] = 0 || [:len [/file find name="ros-fw-auto-upgrade.rsc"]] = 0) do={
    :log error "Install: fetch failed. Check internet/DNS. For offline use install-offline.rsc."
    :error "Install: fetch failed"
}

# --- 2. Create scripts from file contents (keeps proper multiline) ---
/system script add name="ros-auto-update" policy=read,write,reboot,policy,test source=[/file get "ros-auto-update.rsc" contents]
/system script add name="ros-fw-auto-upgrade" policy=read,write,reboot,policy,test source=[/file get "ros-fw-auto-upgrade.rsc" contents]

# --- 3. Schedulers ---
/system scheduler add name="ros-fw-upgrade-at-boot" start-time=startup interval=0s on-event="/system script run ros-fw-auto-upgrade" policy=read,write,reboot,policy,test comment="Firmware check after every boot"
/system scheduler add name="ros-auto-update" interval=7d start-time=03:30:00 on-event="/system script run ros-auto-update" policy=read,write,reboot,policy,test comment="Weekly RouterOS update check"

# --- 4. Cleanup and verify ---
/file remove [find name="ros-auto-update.rsc"]
/file remove [find name="ros-fw-auto-upgrade.rsc"]

:log info "Install done. Scripts:"
/system script print where name="ros-auto-update" || name="ros-fw-auto-upgrade"
/system scheduler print where name="ros-auto-update" || name="ros-fw-upgrade-at-boot"
:log info "Install done. Run manually: /system script run ros-auto-update"
