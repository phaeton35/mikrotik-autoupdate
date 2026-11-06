# ============================================================
# Offline install (v7): if the router cannot reach GitHub.
# 1) Download scripts/ros-auto-update.rsc and scripts/ros-fw-auto-upgrade.rsc
# 2) Upload both files to the router (WinBox -> Files, drag and drop)
# 3) Paste this whole file into Terminal
# Idempotent: safe to re-run, removes old entries first.
# ============================================================

# --- 0. Clean up old entries ---
:do { /system script remove [find name="ros-auto-update"] } on-error={}
:do { /system script remove [find name="ros-fw-auto-upgrade"] } on-error={}
:do { /system scheduler remove [find name="ros-auto-update"] } on-error={}
:do { /system scheduler remove [find name="ros-fw-upgrade-at-boot"] } on-error={}

# --- 1. Check uploaded files exist ---
:if ([:len [/file find name="ros-auto-update.rsc"]] = 0) do={ :error "Upload ros-auto-update.rsc first (WinBox -> Files)" }
:if ([:len [/file find name="ros-fw-auto-upgrade.rsc"]] = 0) do={ :error "Upload ros-fw-auto-upgrade.rsc first (WinBox -> Files)" }

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
