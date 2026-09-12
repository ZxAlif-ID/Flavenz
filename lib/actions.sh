#!/data/data/com.termux/files/usr/bin/bash


save_backup() {
    mkdir -p "$BACKUP_DIR" 2>/dev/null

    > "$BACKUP_CPU_GOV"
    for cpu in $(ls /sys/devices/system/cpu/ | grep -E '^cpu[0-9]+$'); do
        local gp="/sys/devices/system/cpu/$cpu/cpufreq/scaling_governor"
        local gov; gov=$(cat "$gp" 2>/dev/null)
        [ -n "$gov" ] && echo "$cpu $gov" >> "$BACKUP_CPU_GOV"
    done

    > "$BACKUP_CPU_FREQ"
    for cpu in $(ls /sys/devices/system/cpu/ | grep -E '^cpu[0-9]+$'); do
        local base="/sys/devices/system/cpu/$cpu/cpufreq"
        local minf; minf=$(cat "$base/scaling_min_freq" 2>/dev/null)
        local maxf; maxf=$(cat "$base/scaling_max_freq" 2>/dev/null)
        [ -n "$minf" ] && echo "$cpu min $minf" >> "$BACKUP_CPU_FREQ"
        [ -n "$maxf" ] && echo "$cpu max $maxf" >> "$BACKUP_CPU_FREQ"
    done

    local gpu_gov; gpu_gov=$(get_gpu_current_governor)
    echo "$gpu_gov" > "$BACKUP_GPU_GOV"

    local boost; boost=$(get_adrenoboost)
    echo "${boost:-N/A}" > "$BACKUP_ADRENOBOOST"

    local min_pl; min_pl=$(cat /sys/class/kgsl/kgsl-3d0/min_pwrlevel 2>/dev/null)
    local max_pl; max_pl=$(cat /sys/class/kgsl/kgsl-3d0/max_pwrlevel 2>/dev/null)
    echo "${min_pl:-N/A} ${max_pl:-N/A}" > "$BACKUP_DIR/gpu_pwrlevel.txt"

    action_save_walt_backup

    > "$BACKUP_ZONE_MODES"
    for zone in $(ls /sys/class/thermal/ 2>/dev/null | grep thermal_zone); do
        local mode; mode=$(cat "/sys/class/thermal/$zone/mode" 2>/dev/null)
        [ -n "$mode" ] && echo "$zone $mode" >> "$BACKUP_ZONE_MODES"
    done

    > "$BACKUP_TRIP_POINTS"
    local _seen=""
    while IFS= read -r node; do
        local nk; nk=$(readlink -f "$node" 2>/dev/null || echo "$node")
        echo "$_seen" | grep -qF "$nk" && continue
        _seen="${_seen}${nk}
"
        local rel="${node#/sys/class/thermal/}"
        local val; val=$(cat "$node" 2>/dev/null)
        [ -n "$val" ] && echo "$rel $val" >> "$BACKUP_TRIP_POINTS"
    done < <(find /sys/class/thermal -name 'trip_point_*_temp' -type f 2>/dev/null)

    local sconf; sconf=$(get_sconfig)
    echo "$sconf" > "$BACKUP_SCONFIG"

    local cc_node="/sys/module/msm_thermal/core_control/enabled"
    local cc_val; cc_val=$(cat "$cc_node" 2>/dev/null)
    echo "${cc_val:-N/A}" > "$BACKUP_CORE_CTRL"

    > "$BACKUP_SVC_STATES"
    for svc in thermal-engine thermald vendor.thermal-hal-2-0 vendor.thermal_manager mi_thermald; do
        local state; state=$(getprop init.svc.$svc 2>/dev/null)
        echo "$svc ${state:-N/A}" >> "$BACKUP_SVC_STATES"
    done

    local prop_val; prop_val=$(getprop sys.thermal.controller 2>/dev/null)
    echo "${prop_val:-N/A}" > "$BACKUP_THERMAL_PROP"

    local swp; swp=$(cat /proc/sys/vm/swappiness 2>/dev/null)
    echo "${swp:-N/A}" > "$BACKUP_SWAPPINESS"

    echo -e " ${G}[OK] Backup tersimpan di $BACKUP_DIR${NC}"
    log_event "INFO" "BACKUP saved"
}


action_disable_thermal() {
    echo -e "\n ${Y}[*] Menghentikan thermal service...${NC}"
    for svc in thermal-engine thermald vendor.thermal-hal-2-0 vendor.thermal_manager mi_thermald; do
        local before; before=$(getprop init.svc.$svc 2>/dev/null)
        [ -z "$before" ] && continue
        stop "$svc" 2>/dev/null
        sleep 0.3
        local after; after=$(getprop init.svc.$svc 2>/dev/null)
        if [ "$before" = "running" ]; then
            [ "$after" != "running" ] \
                && printf "   %-35s %s\n" "$svc" "$(result_badge "PASS")" \
                || printf "   %-35s %s\n" "$svc" "$(result_badge "FAIL")"
        fi
        log_change "svc:$svc" "$before" "${after:-N/A}" "stop"
    done
    setprop sys.thermal.controller 0 2>/dev/null
    local sc_node="/sys/class/thermal/thermal_message/sconfig"
    if [ -f "$sc_node" ]; then
        local before; before=$(cat "$sc_node" 2>/dev/null)
        swrite "$sc_node" 10
        local res; res=$(verify_node "$sc_node" "10")
        printf "   %-35s %s\n" "sconfig -> 10" "$(result_badge "$res")"
        log_change "$sc_node" "$before" "10" "$res"
    fi
    sleep 1
}

action_enable_thermal() {
    echo -e "\n ${Y}[*] Menjalankan thermal service...${NC}"
    for svc in mi_thermald thermal-engine thermald; do
        start "$svc" 2>/dev/null
        local after; after=$(getprop init.svc.$svc 2>/dev/null)
        printf "   %-35s -> %s\n" "$svc" "${after:-N/A}"
    done
    local sc_node="/sys/class/thermal/thermal_message/sconfig"
    if [ -f "$sc_node" ]; then
        local before; before=$(cat "$sc_node" 2>/dev/null)
        swrite "$sc_node" -1
        local res; res=$(verify_node "$sc_node" "-1")
        printf "   %-35s %s\n" "sconfig -> -1" "$(result_badge "$res")"
        log_change "$sc_node" "$before" "-1" "$res"
    fi
    echo -e " ${G}[OK] Thermal service dijalankan.${NC}"
    sleep 1
}


action_disable_core_control() {
    local node="/sys/module/msm_thermal/core_control/enabled"
    if [ ! -f "$node" ]; then
        echo -e "\n ${DIM}[N/A]${NC} Core Control tidak tersedia pada kernel ini."
        sleep 1; return
    fi
    local before; before=$(cat "$node" 2>/dev/null)
    swrite "$node" 0
    local res; res=$(verify_node "$node" "0")
    printf "\n   %-35s %s\n" "core_control -> 0" "$(result_badge "$res")"
    log_change "$node" "$before" "0" "$res"
    sleep 1
}


action_set_governor() {
    local target="$1"
    echo -e "\n ${Y}[*] Set CPU governor -> ${target}...${NC}"
    local pass=0 fail=0 skip=0
    for cpu in $(ls /sys/devices/system/cpu/ | grep -E '^cpu[0-9]+$'); do
        local gp="/sys/devices/system/cpu/$cpu/cpufreq/scaling_governor"
        local ap="/sys/devices/system/cpu/$cpu/cpufreq/scaling_available_governors"
        [ -f "$gp" ] || { skip=$(( skip + 1 )); continue; }
        local avail; avail=$(cat "$ap" 2>/dev/null)
        if ! echo "$avail" | grep -qw "$target"; then
            printf "   %-8s %s\n" "$cpu" "$(result_badge "N/A")"
            skip=$(( skip + 1 )); continue
        fi
        local before; before=$(cat "$gp" 2>/dev/null)
        swrite "$gp" "$target"
        local res; res=$(verify_node "$gp" "$target")
        printf "   %-8s %-20s %s\n" "$cpu" "-> $target" "$(result_badge "$res")"
        log_change "$gp" "$before" "$target" "$res"
        [ "$res" = "PASS" ] && pass=$(( pass + 1 )) || fail=$(( fail + 1 ))
    done
    echo -e "\n   ${W}CPU: ${G}${pass} PASS${NC}  ${R}${fail} FAIL${NC}  ${DIM}${skip} N/A${NC}"
    sleep 1
}

action_set_gpu_governor() {
    local target="$1"
    local gp="/sys/class/kgsl/kgsl-3d0/devfreq/governor"
    local ap="/sys/class/kgsl/kgsl-3d0/devfreq/available_governors"
    if [ ! -f "$gp" ]; then
        printf "   %-35s %s\n" "GPU devfreq" "$(result_badge "N/A")"
        return 1
    fi
    local avail; avail=$(cat "$ap" 2>/dev/null)
    if ! echo "$avail" | grep -qw "$target"; then
        printf "   %-35s %s ${DIM}(available: %s)${NC}\n" "GPU gov '$target'" "$(result_badge "N/A")" "${avail:-none}"
        return 1
    fi
    local before; before=$(cat "$gp" 2>/dev/null)
    swrite "$gp" "$target"
    local res; res=$(verify_node "$gp" "$target")
    printf "   %-35s %s\n" "GPU governor -> $target" "$(result_badge "$res")"
    log_change "$gp" "$before" "$target" "$res"
    [ "$res" = "PASS" ] && return 0 || return 1
}

action_set_adrenoboost() {
    local val="$1"
    local node="/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost"
    [ -f "$node" ] || { printf "   %-35s %s\n" "adrenoboost" "$(result_badge "N/A")"; return; }
    local before; before=$(cat "$node" 2>/dev/null)
    swrite "$node" "$val"
    local res; res=$(verify_node "$node" "$val")
    printf "   %-35s %s\n" "adrenoboost -> $val" "$(result_badge "$res")"
    log_change "$node" "$before" "$val" "$res"
}

action_set_gpu_pwrlevel() {
    local target_min="$1" target_max="$2"
    local minpl="/sys/class/kgsl/kgsl-3d0/min_pwrlevel"
    local maxpl="/sys/class/kgsl/kgsl-3d0/max_pwrlevel"
    local numpl="/sys/class/kgsl/kgsl-3d0/num_pwrlevels"

    if [ ! -f "$minpl" ] || [ ! -f "$maxpl" ]; then
        printf "   %-35s %s\n" "GPU pwrlevel" "$(result_badge "N/A")"
        return 1
    fi

    local num_levels; num_levels=$(cat "$numpl" 2>/dev/null)
    local safest=$(( ${num_levels:-11} - 1 ))

    local before_min; before_min=$(cat "$minpl" 2>/dev/null)
    local before_max; before_max=$(cat "$maxpl" 2>/dev/null)

    swrite "$minpl" "$safest"

    if [ -n "$target_max" ]; then
        swrite "$maxpl" "$target_max"
        local res_max; res_max=$(verify_node "$maxpl" "$target_max")
        printf "   %-35s %s\n" "max_pwrlevel -> $target_max" "$(result_badge "$res_max")"
        log_change "$maxpl" "$before_max" "$target_max" "$res_max"
    fi

    if [ -n "$target_min" ]; then
        swrite "$minpl" "$target_min"
        local res_min; res_min=$(verify_node "$minpl" "$target_min")
        printf "   %-35s %s\n" "min_pwrlevel -> $target_min" "$(result_badge "$res_min")"
        log_change "$minpl" "$before_min" "$target_min" "$res_min"
    fi
}

action_set_walt_profile() {
    local profile="$1"
    [ "$CAP_WALT" != "Available" ] && echo -e "   ${DIM}WALT N/A, skip.${NC}" && return

    local clusters="0 4 7"
    local hl_vals up_vals dn_vals rtg_vals

    case "$profile" in
        balanced)
            hl_vals="90 85 85"
            up_vals="2000 2000 2000"
            dn_vals="12000 12000 12000"
            rtg_vals="595200 768000 0"
            ;;
        gaming)
            hl_vals="75 70 70"
            up_vals="500 500 500"
            dn_vals="20000 20000 20000"
            rtg_vals="768000 1075200 1459200"
            ;;
        extreme)
            hl_vals="60 55 55"
            up_vals="0 0 0"
            dn_vals="0 0 0"
            rtg_vals="1113600 1459200 1804800"
            ;;
        default)
            hl_vals="$WALT_DEF_HISPEED_LOAD"
            up_vals="$WALT_DEF_UP_RATE"
            dn_vals="$WALT_DEF_DOWN_RATE"
            rtg_vals="$WALT_DEF_RTG_BOOST"
            ;;
        *) return 1 ;;
    esac

    local i=1
    for cpu in $clusters; do
        local base="/sys/devices/system/cpu/cpu${cpu}/cpufreq/walt"
        [ -d "$base" ] || continue
        local hl up dn rtg
        hl=$(echo "$hl_vals"  | awk -v i=$i '{print $i}')
        up=$(echo "$up_vals"  | awk -v i=$i '{print $i}')
        dn=$(echo "$dn_vals"  | awk -v i=$i '{print $i}')
        rtg=$(echo "$rtg_vals" | awk -v i=$i '{print $i}')

        swrite "$base/hispeed_load"     "$hl"
        swrite "$base/up_rate_limit_us" "$up"
        swrite "$base/down_rate_limit_us" "$dn"
        [ -n "$rtg" ] && [ "$rtg" != "0" ] && swrite "$base/rtg_boost_freq" "$rtg"
        i=$(( i + 1 ))
    done

    printf "   %-35s ${G}%s${NC}\n" "WALT profile" "$profile"
    log_event "INFO" "WALT profile: $profile"
}

action_save_walt_backup() {
    [ "$CAP_WALT" != "Available" ] && return
    > "$BACKUP_WALT"
    for cpu in $(ls /sys/devices/system/cpu/ | grep -E '^cpu[0-9]+$'); do
        local base="/sys/devices/system/cpu/$cpu/cpufreq/walt"
        [ -d "$base" ] || continue
        for param in hispeed_load hispeed_freq up_rate_limit_us down_rate_limit_us rtg_boost_freq pl; do
            local val; val=$(cat "$base/$param" 2>/dev/null)
            [ -n "$val" ] && echo "$cpu $param $val" >> "$BACKUP_WALT"
        done
    done
}

action_restore_walt() {
    [ -f "$BACKUP_WALT" ] || return
    while IFS=" " read -r cpu param val; do
        [ -z "$cpu" ] && continue
        local node="/sys/devices/system/cpu/$cpu/cpufreq/walt/$param"
        [ -f "$node" ] && swrite "$node" "$val"
    done < "$BACKUP_WALT"
    printf "   %-35s ${G}restored${NC}\n" "WALT params"
}

action_set_gpu_profile() {
    local profile="$1"
    case "$profile" in
        auto)     action_set_gpu_pwrlevel 10 0; ACTIVE_GPU_PROFILE="Auto" ;;
        balanced) action_set_gpu_pwrlevel 7 3;  ACTIVE_GPU_PROFILE="Balanced" ;;
        gaming)   action_set_gpu_pwrlevel 5 0;  ACTIVE_GPU_PROFILE="Gaming" ;;
        max)      action_set_gpu_pwrlevel 0 0;  ACTIVE_GPU_PROFILE="Max" ;;
        *) return 1 ;;
    esac
    log_event "INFO" "GPU profile: $profile"
}


action_disable_zones() {
    echo -e "\n ${Y}[*] Menonaktifkan semua thermal zone...${NC}"
    local pass=0 fail=0
    for zone in $(ls /sys/class/thermal/ 2>/dev/null | grep thermal_zone); do
        local mp="/sys/class/thermal/$zone/mode"
        [ -f "$mp" ] || continue
        local before; before=$(cat "$mp" 2>/dev/null)
        swrite "$mp" "disabled"
        local res; res=$(verify_node "$mp" "disabled")
        [ "$res" = "PASS" ] && pass=$(( pass + 1 )) || fail=$(( fail + 1 ))
        log_change "$mp" "$before" "disabled" "$res"
    done
    printf "\n   Zones: ${G}%s disabled${NC}  ${R}%s gagal${NC}\n" "$pass" "$fail"
    sleep 1
}

action_enable_zones() {
    echo -e "\n ${Y}[*] Mengaktifkan semua thermal zone...${NC}"
    local pass=0 fail=0
    for zone in $(ls /sys/class/thermal/ 2>/dev/null | grep thermal_zone); do
        local mp="/sys/class/thermal/$zone/mode"
        [ -f "$mp" ] || continue
        local before; before=$(cat "$mp" 2>/dev/null)
        swrite "$mp" "enabled"
        local res; res=$(verify_node "$mp" "enabled")
        [ "$res" = "PASS" ] && pass=$(( pass + 1 )) || fail=$(( fail + 1 ))
        log_change "$mp" "$before" "enabled" "$res"
    done
    printf "\n   Zones: ${G}%s enabled${NC}  ${R}%s gagal${NC}\n" "$pass" "$fail"
    sleep 1
}

action_list_zones() {
    clear; draw_header
    echo -e " ${W}+------------------------------------------------------+${NC}"
    echo -e " ${W}|${NC}      ${BOLD}${C}Thermal Zones${NC}"
    echo -e " ${W}|${NC}"
    printf " ${W}|${NC}  ${DIM}%-4s %-30s %8s %10s${NC}\n" "No." "Type" "Temp" "Mode"
    hline "-"
    for z in $(ls /sys/class/thermal/ 2>/dev/null | grep thermal_zone | sort -V); do
        local path="/sys/class/thermal/$z"
        local type raw mode temp num
        type=$(cat "$path/type" 2>/dev/null)
        raw=$(cat "$path/temp" 2>/dev/null)
        mode=$(cat "$path/mode" 2>/dev/null)
        num=$(echo "$z" | sed 's/thermal_zone//')
        temp="N/A"
        if [ -n "$raw" ] && [ "$raw" -eq "$raw" ] 2>/dev/null && [ "$raw" -gt 1000 ]; then
            temp="$(( raw / 1000 )) degC"
        elif [ -n "$raw" ]; then temp="${raw} degC"; fi
        local mc=$G; [ "$mode" = "disabled" ] && mc=$R
        printf " ${W}|${NC}  ${DIM}%-4s${NC} %-30s ${Y}%8s${NC} ${mc}%10s${NC}\n" \
            "$num" "${type:0:29}" "$temp" "$mode"
    done
    echo -e " ${W}+------------------------------------------------------+${NC}"
    echo ""
    echo -ne " ${DIM}[Enter] untuk kembali...${NC}"; read -r
}


action_set_trip_points() {
    local target="$1"
    local pass=0 fail=0 skip=0
    local _seen=""
    while IFS= read -r node; do
        local nk; nk=$(readlink -f "$node" 2>/dev/null || echo "$node")
        echo "$_seen" | grep -qF "$nk" && continue
        _seen="${_seen}${nk}
"
        local cur; cur=$(cat "$node" 2>/dev/null)
        [ -z "$cur" ] && { skip=$(( skip + 1 )); continue; }
        [ "$cur" -lt 1000 ] 2>/dev/null && { skip=$(( skip + 1 )); continue; }
        local perm; perm=$(stat -c '%a' "$node" 2>/dev/null)
        local od="${perm:0:1}"
        case "$od" in
            2|3|6|7) ;;
            *) skip=$(( skip + 1 )); continue ;;
        esac
        swrite "$node" "$target"
        local res; res=$(verify_node "$node" "$target")
        [ "$res" = "PASS" ] && pass=$(( pass + 1 )) || fail=$(( fail + 1 ))
    done < <(find /sys/class/thermal -name 'trip_point_*_temp' -type f 2>/dev/null)
    printf "   Trip points: ${G}%s PASS${NC}  ${R}%s FAIL${NC}  ${Y}%s SKIP${NC}\n" "$pass" "$fail" "$skip"
}


show_profile_menu() {
    clear; draw_header
    hline "=" "$G"
    center "${BOLD}${G}     ===== PERFORMANCE PROFILES =====    ${NC}"
    hline "=" "$G"
    echo ""
    echo -e "   ${G}[1]${NC} ${BOLD}Balanced${NC}   - schedutil + zones on + thermal services on"
    echo -e "   ${G}[2]${NC} ${BOLD}Gaming${NC}     - performance + adrenoboost=2 + sconfig=10"
    echo -e "   ${G}[3]${NC} ${BOLD}Extreme${NC}    - performance + adrenoboost=3 + zones off"
    echo -e "   ${DIM}[0]${NC} Kembali"
    echo ""
    echo -ne " ${BOLD}${C}Pilih >${NC} "
    local c; read -r c
    case "$c" in
        1) _profile_balanced ;;
        2) _profile_gaming ;;
        3) _profile_extreme ;;
        0) return ;;
        *) echo -e " ${R}[!] Pilihan tidak valid${NC}"; sleep 0.5 ;;
    esac
}

_profile_balanced() {
    echo -e "\n ${Y}[*] Applying Balanced Profile...${NC}"
    [ ! -f "$BACKUP_SCONFIG" ] && save_backup
    action_set_governor "schedutil"
    action_set_walt_profile "balanced"
    action_set_gpu_profile "auto"
    action_set_adrenoboost 0
    action_enable_zones
    for svc in mi_thermald thermal-engine; do start "$svc" 2>/dev/null; done
    local sc="/sys/class/thermal/thermal_message/sconfig"
    [ -f "$sc" ] && swrite "$sc" -1
    ACTIVE_PROFILE="Balanced"
    echo -e " ${G}[OK] Balanced profile applied.${NC}"
    log_event "INFO" "PROFILE: Balanced"
    sleep 1
}

_profile_gaming() {
    echo -e "\n ${Y}[*] Applying Gaming Profile...${NC}"
    [ ! -f "$BACKUP_SCONFIG" ] && save_backup
    action_set_governor "performance"
    action_set_walt_profile "gaming"
    action_set_gpu_profile "gaming"
    action_set_adrenoboost 2
    local sc="/sys/class/thermal/thermal_message/sconfig"
    if [ -f "$sc" ]; then
        swrite "$sc" 10
        local res; res=$(verify_node "$sc" "10")
        printf "   %-35s %s\n" "sconfig -> 10" "$(result_badge "$res")"
    fi
    setprop sys.thermal.controller 0 2>/dev/null
    ACTIVE_PROFILE="Gaming"
    echo -e " ${G}[OK] Gaming profile applied.${NC}"
    log_event "INFO" "PROFILE: Gaming"
    sleep 1
}

_profile_extreme() {
    echo -e "\n ${Y}[*] Applying Extreme Profile...${NC}"
    [ ! -f "$BACKUP_SCONFIG" ] && save_backup
    action_set_governor "performance"
    action_set_walt_profile "extreme"
    action_set_gpu_profile "max"
    action_set_adrenoboost 3
    action_disable_zones
    setprop sys.thermal.controller 0 2>/dev/null
    ACTIVE_PROFILE="Extreme"
    echo -e " ${G}[OK] Extreme profile applied.${NC}"
    echo -e " ${R}[!] Pantau suhu! Zones dinonaktifkan.${NC}"
    log_event "WARN" "PROFILE: Extreme"
    sleep 1
}


action_full_kill() {
    clear; draw_header
    hline "=" "$R"
    center "${BOLD}${R}  [!]  FULL KILL MODE - SEMUA THERMAL PROTECTION OFF  [!]  ${NC}"
    hline "=" "$R"
    echo ""
    echo -e " ${R}[WARNING] Mematikan SEMUA proteksi thermal.${NC}"
    echo -e " ${Y}          TJMax Snapdragon 8s Gen 3: ~95 degC${NC}"
    echo -e " ${Y}          Gunakan cooler eksternal!${NC}"
    echo ""

    echo -e " ${C}[Capability Check]${NC}"
    [ "${CAP_CPU_PERF:-0}" -gt 0 ] \
        && printf "   %-35s ${G}OK${NC}\n" "CPU Performance governor" \
        || printf "   %-35s ${Y}N/A${NC}\n" "CPU Performance governor"
    [ "$CAP_WALT" = "Available" ] \
        && printf "   %-35s ${G}OK${NC}\n" "WALT tuning" \
        || printf "   %-35s ${Y}N/A${NC}\n" "WALT tuning"
    [ "$CAP_GPU_PERF" = "1" ] \
        && printf "   %-35s ${G}OK${NC}\n" "GPU Performance governor" \
        || printf "   %-35s ${Y}N/A - via pwrlevel${NC}\n" "GPU Performance governor"
    [ "$CAP_GPU_PWRLEVEL" = "Available" ] \
        && printf "   %-35s ${G}OK (%s levels)${NC}\n" "GPU pwrlevel control" "$CAP_GPU_NUM_LEVELS" \
        || printf "   %-35s ${Y}N/A${NC}\n" "GPU pwrlevel control"
    [ "$CAP_SCONFIG" = "Available" ] \
        && printf "   %-35s ${G}OK${NC}\n" "sconfig node" \
        || printf "   %-35s ${Y}N/A${NC}\n" "sconfig node"
    printf "   %-35s ${W}%s/%s${NC}\n" "Trip points (writable)" "$CAP_TRIP_WRITABLE" "$CAP_TRIP_TOTAL"
    echo ""

    echo -ne " ${W}Ketik ${R}FULLKILL${W} untuk konfirmasi: ${NC}"
    local confirm; read -r confirm
    [ "$confirm" != "FULLKILL" ] && echo -e " ${DIM}Dibatalkan.${NC}" && sleep 1 && return

    [ ! -f "$BACKUP_SCONFIG" ] && save_backup

    echo ""
    echo -e " ${R}[*] Executing Full Kill...${NC}"
    echo ""

    echo -e " ${C}- Thermal Services -${NC}"
    local svc_pass=0 svc_fail=0 svc_na=0
    for svc in thermal-engine thermald vendor.thermal-hal-2-0 vendor.thermal_manager mi_thermald; do
        local before; before=$(getprop init.svc.$svc 2>/dev/null)
        if [ -z "$before" ]; then
            printf "   %-35s %s\n" "$svc" "$(result_badge "N/A")"
            svc_na=$(( svc_na + 1 )); continue
        fi
        stop "$svc" 2>/dev/null; sleep 0.2
        local after; after=$(getprop init.svc.$svc 2>/dev/null)
        if [ "$before" = "running" ]; then
            if [ "$after" != "running" ]; then
                printf "   %-35s %s\n" "$svc" "$(result_badge "PASS")"
                svc_pass=$(( svc_pass + 1 ))
            else
                printf "   %-35s %s\n" "$svc" "$(result_badge "FAIL")"
                svc_fail=$(( svc_fail + 1 ))
            fi
        else
            printf "   %-35s %s ${DIM}(was: %s)${NC}\n" "$svc" "$(result_badge "SKIP")" "$before"
            svc_na=$(( svc_na + 1 ))
        fi
    done
    setprop sys.thermal.controller 0 2>/dev/null
    local prop_after; prop_after=$(getprop sys.thermal.controller 2>/dev/null)
    local prop_res="FAIL"; [ "$prop_after" = "0" ] && prop_res="PASS"
    printf "   %-35s %s\n" "sys.thermal.controller -> 0" "$(result_badge "$prop_res")"

    echo ""
    echo -e " ${C}- sconfig -${NC}"
    local sc_res="N/A"
    if [ "$CAP_SCONFIG" = "Available" ]; then
        local sc="/sys/class/thermal/thermal_message/sconfig"
        swrite "$sc" 14
        sc_res=$(verify_node "$sc" "14")
        printf "   %-35s %s\n" "sconfig -> 14" "$(result_badge "$sc_res")"
    else
        printf "   %-35s %s\n" "sconfig" "$(result_badge "N/A")"
    fi

    echo ""
    echo -e " ${C}- Core Control -${NC}"
    local cc_res="N/A"
    if [ "$CAP_CORE_CTRL" = "Available" ]; then
        local cc="/sys/module/msm_thermal/core_control/enabled"
        swrite "$cc" 0
        cc_res=$(verify_node "$cc" "0")
        printf "   %-35s %s\n" "core_control -> 0" "$(result_badge "$cc_res")"
    else
        printf "   %-35s %s\n" "core_control" "$(result_badge "N/A")"
    fi

    echo ""
    echo -e " ${C}- Thermal Zones -${NC}"
    local z_pass=0 z_fail=0
    for zone in $(ls /sys/class/thermal/ 2>/dev/null | grep thermal_zone); do
        local mp="/sys/class/thermal/$zone/mode"
        [ -f "$mp" ] || continue
        swrite "$mp" "disabled"
        local zr; zr=$(verify_node "$mp" "disabled")
        [ "$zr" = "PASS" ] && z_pass=$(( z_pass + 1 )) || z_fail=$(( z_fail + 1 ))
    done
    printf "   %-35s ${G}%s OK${NC}  ${R}%s FAIL${NC}\n" "Zones disabled" "$z_pass" "$z_fail"

    echo ""
    echo -e " ${C}- Trip Points -${NC}"
    action_set_trip_points 125000

    echo ""
    echo -e " ${C}- CPU Governor -${NC}"
    local cpu_pass=0 cpu_fail=0
    for cpu in $(ls /sys/devices/system/cpu/ | grep -E '^cpu[0-9]+$'); do
        local gp="/sys/devices/system/cpu/$cpu/cpufreq/scaling_governor"
        local ap="/sys/devices/system/cpu/$cpu/cpufreq/scaling_available_governors"
        [ -f "$gp" ] || continue
        local avail; avail=$(cat "$ap" 2>/dev/null)
        echo "$avail" | grep -qw "performance" || continue
        swrite "$gp" "performance"
        local cr; cr=$(verify_node "$gp" "performance")
        printf "   %-10s %-20s %s\n" "$cpu" "-> performance" "$(result_badge "$cr")"
        [ "$cr" = "PASS" ] && cpu_pass=$(( cpu_pass + 1 )) || cpu_fail=$(( cpu_fail + 1 ))
    done
    echo -e "   ${W}CPU: ${G}${cpu_pass} PASS${NC}  ${R}${cpu_fail} FAIL${NC}"

    echo ""
    echo -e " ${C}- CPU Governor + WALT -${NC}"
    action_set_governor "performance"
    action_set_walt_profile "extreme"

    echo ""
    echo -e " ${C}- GPU Governor + adrenoboost -${NC}"
    action_set_gpu_governor "performance"
    action_set_adrenoboost 3

    echo ""
    echo -e " ${C}- GPU Pwrlevel -${NC}"
    action_set_gpu_profile "max"

    ACTIVE_PROFILE="FULL_KILL"
    echo ""
    echo -e " ${BOLD}${R}   FULL KILL ACTIVE. PANTAU SUHU DARI LIVE MONITOR.${NC}"
    echo -e " ${Y}   Gunakan [R] Restore atau [E] Emergency untuk recovery.${NC}"
    log_event "WARN" "FULL KILL executed"
    echo ""
    echo -ne " ${DIM}[Enter] untuk kembali...${NC}"; read -r
}


action_restore() {
    clear; draw_header
    hline "=" "$C"
    center "${BOLD}${C}     ===== RESTORE ORIGINAL STATE =====    ${NC}"
    hline "=" "$C"
    echo ""

    if [ ! -f "$BACKUP_SCONFIG" ]; then
        echo -e " ${Y}[!] Tidak ada backup. Jalankan action dulu.${NC}"
        echo -ne " ${DIM}[Enter]...${NC}"; read -r; return
    fi

    local cpu_pass=0 cpu_fail=0 gpu_res="N/A" zm_pass=0 zm_fail=0
    local sc_res="N/A" cc_res="N/A" prop_res="N/A"
    local svc_pass=0 svc_fail=0 svc_na=0

    echo -e " ${C}[1/7] CPU Governor...${NC}"
    if [ -f "$BACKUP_CPU_GOV" ]; then
        while IFS=" " read -r cpu gov; do
            [ -z "$cpu" ] || [ -z "$gov" ] && continue
            local gp="/sys/devices/system/cpu/$cpu/cpufreq/scaling_governor"
            [ -f "$gp" ] && swrite "$gp" "$gov"
            local cr; cr=$(verify_node "$gp" "$gov")
            [ "$cr" = "PASS" ] && cpu_pass=$(( cpu_pass + 1 )) || cpu_fail=$(( cpu_fail + 1 ))
        done < "$BACKUP_CPU_GOV"
    fi

    echo -e " ${C}[2/7] GPU Governor...${NC}"
    local gpu_orig; gpu_orig=$(cat "$BACKUP_GPU_GOV" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$gpu_orig" ] && [ "$gpu_orig" != "N/A" ]; then
        action_set_gpu_governor "$gpu_orig" && gpu_res="PASS" || gpu_res="FAIL"
    fi

    echo -e " ${C}[3/7] adrenoboost...${NC}"
    local boost_orig; boost_orig=$(cat "$BACKUP_ADRENOBOOST" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$boost_orig" ] && [ "$boost_orig" != "N/A" ]; then
        action_set_adrenoboost "$boost_orig"
    else
        printf "   %-35s %s\n" "adrenoboost" "$(result_badge "N/A")"
    fi

    echo -e " ${C}[4/7] Thermal Zones...${NC}"
    if [ -f "$BACKUP_ZONE_MODES" ]; then
        while IFS=" " read -r zone mode; do
            [ -z "$zone" ] || [ -z "$mode" ] && continue
            local mp="/sys/class/thermal/$zone/mode"
            [ -f "$mp" ] && swrite "$mp" "$mode"
            local zr; zr=$(verify_node "$mp" "$mode")
            [ "$zr" = "PASS" ] && zm_pass=$(( zm_pass + 1 )) || zm_fail=$(( zm_fail + 1 ))
        done < "$BACKUP_ZONE_MODES"
    fi

    echo -e " ${C}[5/7] sconfig...${NC}"
    local sc_orig; sc_orig=$(cat "$BACKUP_SCONFIG" 2>/dev/null | tr -d '[:space:]')
    local sc_node="/sys/class/thermal/thermal_message/sconfig"
    if [ -n "$sc_orig" ] && [ "$sc_orig" != "N/A" ] && [ -f "$sc_node" ]; then
        swrite "$sc_node" "$sc_orig"
        sc_res=$(verify_node "$sc_node" "$sc_orig")
    fi

    echo -e " ${C}[5b/7] GPU Pwrlevel...${NC}"
    local pl_file="$BACKUP_DIR/gpu_pwrlevel.txt"
    if [ -f "$pl_file" ]; then
        local orig_min orig_max
        orig_min=$(awk '{print $1}' "$pl_file" 2>/dev/null)
        orig_max=$(awk '{print $2}' "$pl_file" 2>/dev/null)
        [ -n "$orig_min" ] && [ "$orig_min" != "N/A" ] && \
        [ -n "$orig_max" ] && [ "$orig_max" != "N/A" ] && \
            action_set_gpu_pwrlevel "$orig_min" "$orig_max"
    fi

    echo -e " ${C}[5c/7] WALT params...${NC}"
    action_restore_walt

    echo -e " ${C}[6/7] Core Control + sys.thermal.controller...${NC}"
    local cc_orig; cc_orig=$(cat "$BACKUP_CORE_CTRL" 2>/dev/null | tr -d '[:space:]')
    local cc_node="/sys/module/msm_thermal/core_control/enabled"
    if [ -n "$cc_orig" ] && [ "$cc_orig" != "N/A" ] && [ -f "$cc_node" ]; then
        swrite "$cc_node" "$cc_orig"
        cc_res=$(verify_node "$cc_node" "$cc_orig")
    fi
    local orig_prop; orig_prop=$(cat "$BACKUP_THERMAL_PROP" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$orig_prop" ] && [ "$orig_prop" != "N/A" ]; then
        setprop sys.thermal.controller "$orig_prop" 2>/dev/null
        prop_res="PASS"
    fi

    echo -e " ${C}[7/7] Thermal Services...${NC}"
    if [ -f "$BACKUP_SVC_STATES" ]; then
        while IFS=" " read -r svc state; do
            [ -z "$svc" ] || [ -z "$state" ] && continue
            [ "$state" = "N/A" ] && svc_na=$(( svc_na + 1 )) && continue
            if [ "$state" = "running" ]; then
                start "$svc" 2>/dev/null; sleep 0.3
                local after; after=$(getprop init.svc.$svc 2>/dev/null)
                [ "$after" = "running" ] && svc_pass=$(( svc_pass + 1 )) || svc_fail=$(( svc_fail + 1 ))
            fi
        done < "$BACKUP_SVC_STATES"
    else
        for svc in thermal-engine thermald mi_thermald; do start "$svc" 2>/dev/null; done
        svc_pass=3
    fi

    ACTIVE_PROFILE="None"

    echo ""
    hline "=" "$C"
    center "${BOLD}${C}     ===== RESTORE RESULT =====    ${NC}"
    hline "=" "$C"
    echo ""
    printf "   %-30s ${G}%s PASS${NC}  ${R}%s FAIL${NC}\n" "CPU Governor:"    "$cpu_pass"  "$cpu_fail"
    printf "   %-30s %s\n"                                   "GPU Governor:"    "$(result_badge "$gpu_res")"
    printf "   %-30s ${G}%s PASS${NC}  ${R}%s FAIL${NC}\n" "Thermal Zones:"   "$zm_pass"   "$zm_fail"
    printf "   %-30s %s\n"                                   "sconfig:"         "$(result_badge "$sc_res")"
    printf "   %-30s %s\n"                                   "Core Control:"    "$(result_badge "$cc_res")"
    printf "   %-30s %s\n"                                   "thermal.ctrl:"    "$(result_badge "$prop_res")"
    printf "   %-30s ${G}%s PASS${NC}  ${R}%s FAIL${NC}  ${DIM}%s N/A${NC}\n" \
        "Thermal Services:" "$svc_pass" "$svc_fail" "$svc_na"
    echo ""

    local r_fail=$(( cpu_fail + zm_fail + svc_fail ))
    [ "$r_fail" -eq 0 ] \
        && center "${BOLD}${G}     OVERALL: FULL RESTORE OK    ${NC}" \
        || center "${BOLD}${Y}     OVERALL: PARTIAL RESTORE [!]    ${NC}"
    hline "=" "$C"

    log_event "RESTORE" "RESTORE done: cpu=${cpu_pass}/${cpu_fail} zones=${zm_pass}/${zm_fail} svc=${svc_pass}/${svc_fail}"
    echo ""
    echo -e " ${G}[OK] Restore selesai.${NC}"
    echo -ne " ${DIM}[Enter]...${NC}"; read -r
}


_emergency_restore_silent() {
    if [ -f "$BACKUP_ZONE_MODES" ]; then
        while IFS=" " read -r zone mode; do
            [ -z "$zone" ] || [ -z "$mode" ] && continue
            local mp="/sys/class/thermal/$zone/mode"
            [ -f "$mp" ] && echo "$mode" > "$mp" 2>/dev/null
        done < "$BACKUP_ZONE_MODES"
    fi

    local sc_node="/sys/class/thermal/thermal_message/sconfig"
    local sc_orig; sc_orig=$(cat "$BACKUP_SCONFIG" 2>/dev/null | tr -d '[:space:]')
    [ -n "$sc_orig" ] && [ "$sc_orig" != "N/A" ] && [ -f "$sc_node" ] && \
        echo "$sc_orig" > "$sc_node" 2>/dev/null

    local orig_prop; orig_prop=$(cat "$BACKUP_THERMAL_PROP" 2>/dev/null | tr -d '[:space:]')
    [ -n "$orig_prop" ] && [ "$orig_prop" != "N/A" ] && \
        setprop sys.thermal.controller "$orig_prop" 2>/dev/null

    if [ -f "$BACKUP_CPU_GOV" ]; then
        while IFS=" " read -r cpu gov; do
            [ -z "$cpu" ] || [ -z "$gov" ] && continue
            local gp="/sys/devices/system/cpu/$cpu/cpufreq/scaling_governor"
            [ -f "$gp" ] && echo "$gov" > "$gp" 2>/dev/null
        done < "$BACKUP_CPU_GOV"
    fi

    local gpu_orig; gpu_orig=$(cat "$BACKUP_GPU_GOV" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$gpu_orig" ] && [ "$gpu_orig" != "N/A" ]; then
        local gp="/sys/class/kgsl/kgsl-3d0/devfreq/governor"
        [ -f "$gp" ] && echo "$gpu_orig" > "$gp" 2>/dev/null
    fi

    local boost_orig; boost_orig=$(cat "$BACKUP_ADRENOBOOST" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$boost_orig" ] && [ "$boost_orig" != "N/A" ]; then
        local bn="/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost"
        [ -f "$bn" ] && echo "$boost_orig" > "$bn" 2>/dev/null
    fi

    local pl_file="$BACKUP_DIR/gpu_pwrlevel.txt"
    if [ -f "$pl_file" ]; then
        local orig_min orig_max
        orig_min=$(awk '{print $1}' "$pl_file" 2>/dev/null)
        orig_max=$(awk '{print $2}' "$pl_file" 2>/dev/null)
        local numpl="/sys/class/kgsl/kgsl-3d0/num_pwrlevels"
        local safest=$(( $(cat "$numpl" 2>/dev/null || echo 11) - 1 ))
        local minpl="/sys/class/kgsl/kgsl-3d0/min_pwrlevel"
        local maxpl="/sys/class/kgsl/kgsl-3d0/max_pwrlevel"
        [ -f "$minpl" ] && echo "$safest" > "$minpl" 2>/dev/null
        [ -n "$orig_max" ] && [ "$orig_max" != "N/A" ] && [ -f "$maxpl" ] && echo "$orig_max" > "$maxpl" 2>/dev/null
        [ -n "$orig_min" ] && [ "$orig_min" != "N/A" ] && [ -f "$minpl" ] && echo "$orig_min" > "$minpl" 2>/dev/null
    fi

    action_restore_walt

    if [ -f "$BACKUP_SVC_STATES" ]; then
        while IFS=" " read -r svc state; do
            [ "$state" = "running" ] && start "$svc" 2>/dev/null
        done < "$BACKUP_SVC_STATES"
    else
        start mi_thermald 2>/dev/null
        start thermal-engine 2>/dev/null
    fi
}

action_emergency_restore() {
    clear; draw_header
    echo -e " ${BOLD}${R}  [!!]  EMERGENCY RESTORE  [!!]${NC}"
    echo -e " ${Y}      Fast recovery - prioritas keamanan hardware.${NC}"
    echo ""

    if [ ! -f "$BACKUP_ZONE_MODES" ] && [ ! -f "$BACKUP_SCONFIG" ]; then
        echo -e " ${R}[!] Tidak ada backup - default restore...${NC}"
        for zone in $(ls /sys/class/thermal/ 2>/dev/null | grep thermal_zone); do
            local mp="/sys/class/thermal/$zone/mode"
            [ -f "$mp" ] && echo "enabled" > "$mp" 2>/dev/null
        done
        for svc in thermal-engine thermald mi_thermald; do start "$svc" 2>/dev/null; done
        ACTIVE_PROFILE="None"
        echo -e " ${G}[OK] Default emergency restore selesai.${NC}"
        echo -ne " ${DIM}[Enter]...${NC}"; read -r
        return
    fi

    _emergency_restore_silent
    ACTIVE_PROFILE="None"
    log_event "RESTORE" "EMERGENCY RESTORE executed"
    echo -e " ${G}[OK] Emergency restore selesai.${NC}"
    echo -ne " ${DIM}[Enter]...${NC}"; read -r
}
