#!/data/data/com.termux/files/usr/bin/bash

run_capability_scan() {
    echo -e "\n ${Y}[*] Mendeteksi kapabilitas perangkat...${NC}"
    mkdir -p "$BACKUP_DIR" 2>/dev/null

    local cpu_total=0 cpu_freq=0 cpu_perf=0 cpu_sched=0
    for cpu in $(ls /sys/devices/system/cpu/ | grep -E '^cpu[0-9]+$'); do
        cpu_total=$(( cpu_total + 1 ))
        local gp="/sys/devices/system/cpu/$cpu/cpufreq/scaling_governor"
        local ap="/sys/devices/system/cpu/$cpu/cpufreq/scaling_available_governors"
        if [ -f "$gp" ]; then
            cpu_freq=$(( cpu_freq + 1 ))
            local avail; avail=$(cat "$ap" 2>/dev/null)
            echo "$avail" | grep -qw "performance" && cpu_perf=$(( cpu_perf + 1 ))
            echo "$avail" | grep -qw "schedutil"   && cpu_sched=$(( cpu_sched + 1 ))
        fi
    done

    local walt_cap="N/A"
    [ -d /sys/devices/system/cpu/cpu0/cpufreq/walt ] && walt_cap="Available"

    local gpu_current gpu_avail gpu_perf=0
    gpu_current=$(get_gpu_current_governor)
    gpu_avail=$(get_gpu_available_governors)
    [ -z "$gpu_avail" ] && gpu_avail="N/A"
    echo "$gpu_avail" | grep -qw "performance" && gpu_perf=1

    local gpu_pwrlevel_cap="N/A" gpu_num_levels="N/A"
    if [ -f /sys/class/kgsl/kgsl-3d0/min_pwrlevel ] && [ -f /sys/class/kgsl/kgsl-3d0/max_pwrlevel ]; then
        gpu_pwrlevel_cap="Available"
        gpu_num_levels=$(cat /sys/class/kgsl/kgsl-3d0/num_pwrlevels 2>/dev/null || echo "N/A")
    fi

    local core_ctrl
    [ -f /sys/module/msm_thermal/core_control/enabled ] && core_ctrl="Available" || core_ctrl="N/A"

    local sconfig_cap
    [ -f /sys/class/thermal/thermal_message/sconfig ] && sconfig_cap="Available" || sconfig_cap="N/A"

    local zones_total=0 zones_mode=0
    for zone in $(ls /sys/class/thermal/ 2>/dev/null | grep thermal_zone); do
        zones_total=$(( zones_total + 1 ))
        [ -f "/sys/class/thermal/$zone/mode" ] && zones_mode=$(( zones_mode + 1 ))
    done

    local trip_total=0 trip_writable=0 _seen=""
    while IFS= read -r node; do
        local nk; nk=$(readlink -f "$node" 2>/dev/null || echo "$node")
        echo "$_seen" | grep -qF "$nk" && continue
        _seen="${_seen}${nk}
"
        local cur; cur=$(cat "$node" 2>/dev/null)
        [ -z "$cur" ] && continue
        trip_total=$(( trip_total + 1 ))
        local perm; perm=$(stat -c '%a' "$node" 2>/dev/null)
        local od="${perm:0:1}"
        case "$od" in 2|3|6|7) trip_writable=$(( trip_writable + 1 )) ;; esac
    done < <(find /sys/class/thermal -name 'trip_point_*_temp' -type f 2>/dev/null)

    local trip_locked=$(( trip_total - trip_writable ))
    local kver; kver=$(uname -r 2>/dev/null | tr -d '[:space:]')
    local model; model=$(getprop ro.product.model 2>/dev/null | tr ' ' '_')
    local cache_key="${kver}_${model}"

    {
        printf "CACHE_KEY=%s\n" "$cache_key"
        printf "CPU_TOTAL=%s\n" "$cpu_total"
        printf "CPU_FREQ=%s\n"  "$cpu_freq"
        printf "CPU_PERF=%s\n"  "$cpu_perf"
        printf "CPU_SCHED=%s\n" "$cpu_sched"
        printf "WALT=%s\n"      "$walt_cap"
        printf "GPU_CURRENT=%s\n" "$gpu_current"
        printf "GPU_AVAIL=%s\n"   "$gpu_avail"
        printf "GPU_PERF=%s\n"    "$gpu_perf"
        printf "GPU_PWRLEVEL=%s\n"    "$gpu_pwrlevel_cap"
        printf "GPU_NUM_LEVELS=%s\n"  "$gpu_num_levels"
        printf "CORE_CTRL=%s\n"   "$core_ctrl"
        printf "SCONFIG=%s\n"     "$sconfig_cap"
        printf "ZONES_TOTAL=%s\n" "$zones_total"
        printf "ZONES_MODE=%s\n"  "$zones_mode"
        printf "TRIP_TOTAL=%s\n"    "$trip_total"
        printf "TRIP_WRITABLE=%s\n" "$trip_writable"
        printf "TRIP_LOCKED=%s\n"   "$trip_locked"
    } > "$CAP_CACHE" 2>/dev/null

    _apply_cap_vars "$cpu_total" "$cpu_freq" "$cpu_perf" "$cpu_sched" "$walt_cap" \
        "$gpu_current" "$gpu_avail" "$gpu_perf" "$gpu_pwrlevel_cap" "$gpu_num_levels" \
        "$core_ctrl" "$sconfig_cap" \
        "$zones_total" "$zones_mode" \
        "$trip_total" "$trip_writable" "$trip_locked"

    echo -e " ${G}[OK] Capability scan selesai.${NC}"
}

_apply_cap_vars() {
    CAP_CPU_TOTAL="$1"; CAP_CPU_FREQ="$2"; CAP_CPU_PERF="$3"; CAP_CPU_SCHED="$4"
    CAP_WALT="$5"
    CAP_GPU_CURRENT="$6"; CAP_GPU_AVAIL="$7"; CAP_GPU_PERF="$8"
    CAP_GPU_PWRLEVEL="$9"; CAP_GPU_NUM_LEVELS="${10}"
    CAP_CORE_CTRL="${11}"; CAP_SCONFIG="${12}"
    CAP_ZONES_TOTAL="${13}"; CAP_ZONES_MODE="${14}"
    CAP_TRIP_TOTAL="${15}"; CAP_TRIP_WRITABLE="${16}"; CAP_TRIP_LOCKED="${17}"
}

load_capability_cache() {
    local kver; kver=$(uname -r 2>/dev/null | tr -d '[:space:]')
    local model; model=$(getprop ro.product.model 2>/dev/null | tr ' ' '_')
    local cache_key_now="${kver}_${model}"

    if [ -f "$CAP_CACHE" ]; then
        local cached_key; cached_key=$(grep '^CACHE_KEY=' "$CAP_CACHE" | cut -d= -f2-)
        if [ "$cached_key" = "$cache_key_now" ]; then
            CAP_CPU_TOTAL=$(grep  '^CPU_TOTAL='    "$CAP_CACHE" | cut -d= -f2-)
            CAP_CPU_FREQ=$(grep   '^CPU_FREQ='     "$CAP_CACHE" | cut -d= -f2-)
            CAP_CPU_PERF=$(grep   '^CPU_PERF='     "$CAP_CACHE" | cut -d= -f2-)
            CAP_CPU_SCHED=$(grep  '^CPU_SCHED='    "$CAP_CACHE" | cut -d= -f2-)
            CAP_WALT=$(grep       '^WALT='          "$CAP_CACHE" | cut -d= -f2-)
            CAP_GPU_CURRENT=$(grep '^GPU_CURRENT=' "$CAP_CACHE" | cut -d= -f2-)
            CAP_GPU_AVAIL=$(grep   '^GPU_AVAIL='   "$CAP_CACHE" | cut -d= -f2-)
            CAP_GPU_PERF=$(grep    '^GPU_PERF='    "$CAP_CACHE" | cut -d= -f2-)
            CAP_GPU_PWRLEVEL=$(grep   '^GPU_PWRLEVEL='   "$CAP_CACHE" | cut -d= -f2-)
            CAP_GPU_NUM_LEVELS=$(grep '^GPU_NUM_LEVELS=' "$CAP_CACHE" | cut -d= -f2-)
            CAP_CORE_CTRL=$(grep  '^CORE_CTRL='    "$CAP_CACHE" | cut -d= -f2-)
            CAP_SCONFIG=$(grep    '^SCONFIG='      "$CAP_CACHE" | cut -d= -f2-)
            CAP_ZONES_TOTAL=$(grep '^ZONES_TOTAL=' "$CAP_CACHE" | cut -d= -f2-)
            CAP_ZONES_MODE=$(grep  '^ZONES_MODE='  "$CAP_CACHE" | cut -d= -f2-)
            CAP_TRIP_TOTAL=$(grep    '^TRIP_TOTAL='    "$CAP_CACHE" | cut -d= -f2-)
            CAP_TRIP_WRITABLE=$(grep '^TRIP_WRITABLE=' "$CAP_CACHE" | cut -d= -f2-)
            CAP_TRIP_LOCKED=$(grep   '^TRIP_LOCKED='   "$CAP_CACHE" | cut -d= -f2-)
            return 0
        fi
    fi
    run_capability_scan
}

show_capability_report() {
    clear; draw_header
    hline "=" "$C"
    center "${BOLD}${C}     ===== DEVICE CAPABILITY REPORT =====    ${NC}"
    hline "=" "$C"
    echo ""

    echo -e " ${BOLD}${W}CPU:${NC}"
    printf "   %-35s ${W}%s/%s${NC}\n" "Cores dengan cpufreq" "$CAP_CPU_FREQ" "$CAP_CPU_TOTAL"
    [ "${CAP_CPU_PERF:-0}" -gt 0 ] 2>/dev/null \
        && printf "   %-35s ${G}Supported (%s core)${NC}\n" "Governor: performance" "$CAP_CPU_PERF" \
        || printf "   %-35s ${R}Not Supported${NC}\n" "Governor: performance"
    [ "${CAP_CPU_SCHED:-0}" -gt 0 ] 2>/dev/null \
        && printf "   %-35s ${G}Supported (%s core)${NC}\n" "Governor: schedutil" "$CAP_CPU_SCHED" \
        || printf "   %-35s ${R}Not Supported${NC}\n" "Governor: schedutil"
    [ "$CAP_WALT" = "Available" ] \
        && printf "   %-35s ${G}Available${NC}\n" "WALT tuning nodes" \
        || printf "   %-35s ${DIM}N/A${NC}\n" "WALT tuning nodes"

    echo ""
    echo -e " ${BOLD}${W}GPU (Adreno 735 / KGSL):${NC}"
    printf "   %-35s ${W}%s${NC}\n" "Current governor" "$CAP_GPU_CURRENT"
    printf "   %-35s ${W}%s${NC}\n" "Available governors" "$CAP_GPU_AVAIL"
    local boost; boost=$(get_adrenoboost)
    printf "   %-35s ${W}%s${NC}\n" "adrenoboost (current)" "${boost:-N/A}"
    [ "$CAP_GPU_PERF" = "1" ] \
        && printf "   %-35s ${G}Supported${NC}\n" "Governor: performance" \
        || printf "   %-35s ${DIM}N/A (kontrol via pwrlevel)${NC}\n" "Governor: performance"
    local cur_min cur_max
    cur_min=$(cat /sys/class/kgsl/kgsl-3d0/min_pwrlevel 2>/dev/null)
    cur_max=$(cat /sys/class/kgsl/kgsl-3d0/max_pwrlevel 2>/dev/null)
    if [ -n "$cur_min" ]; then
        printf "   %-35s ${G}Available${NC} ${DIM}(%s levels, 0=max perf)${NC}\n" "GPU pwrlevel control" "${CAP_GPU_NUM_LEVELS:-?}"
        printf "   %-35s min=${Y}%s${NC}  max=${Y}%s${NC}  profile=${M}%s${NC}\n" "Current pwrlevel" "$cur_min" "$cur_max" "${ACTIVE_GPU_PROFILE:-None}"
    else
        printf "   %-35s ${DIM}N/A${NC}\n" "GPU pwrlevel control"
    fi

    echo ""
    echo -e " ${BOLD}${W}THERMAL:${NC}"
    printf "   %-35s ${W}%s${NC}\n" "Thermal zones (total)"  "$CAP_ZONES_TOTAL"
    printf "   %-35s ${W}%s${NC}\n" "Zones dengan mode node" "$CAP_ZONES_MODE"
    printf "   %-35s ${W}%s${NC}\n" "Trip points (total)"    "$CAP_TRIP_TOTAL"
    printf "   %-35s ${G}%s${NC}\n" "Trip points (writable)" "$CAP_TRIP_WRITABLE"
    printf "   %-35s ${Y}%s${NC}\n" "Trip points (locked)"   "$CAP_TRIP_LOCKED"

    echo ""
    echo -e " ${BOLD}${W}SYSTEM:${NC}"
    [ "$CAP_CORE_CTRL" = "Available" ] \
        && printf "   %-35s ${G}Available${NC}\n" "Core Control (msm_thermal)" \
        || printf "   %-35s ${DIM}N/A${NC}\n" "Core Control"
    [ "$CAP_SCONFIG" = "Available" ] \
        && printf "   %-35s ${G}Available${NC}\n" "sconfig (thermal_message)" \
        || printf "   %-35s ${DIM}N/A${NC}\n" "sconfig"
    local tc; tc=$(getprop sys.thermal.controller 2>/dev/null)
    printf "   %-35s ${W}%s${NC}\n" "sys.thermal.controller" "${tc:-N/A}"

    echo ""
    hline "=" "$C"
    echo -ne " ${DIM}[Enter] untuk kembali...${NC}"; read -r
}
