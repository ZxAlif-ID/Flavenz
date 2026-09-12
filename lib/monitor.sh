#!/data/data/com.termux/files/usr/bin/bash

run_live_monitor() {
    local interval=3
    while true; do
        printf '\033[H\033[J'
        draw_header

        local cpu_temp; cpu_temp=$(get_cpu_temp)
        local gpu_temp; gpu_temp=$(get_gpu_temp)
        local bat_temp; bat_temp=$(get_bat_temp)
        local bat_lvl;  bat_lvl=$(get_bat_level)
        local bat_sts;  bat_sts=$(get_bat_status)
        local cpu_freq; cpu_freq=$(get_cpu_freq)
        local gpu_freq; gpu_freq=$(get_gpu_freq)
        local gpu_busy; gpu_busy=$(get_gpu_busy)
        local ram_used; ram_used=$(get_ram_used)
        local sconfig;  sconfig=$(get_sconfig)
        local uptime;   uptime=$(get_uptime)
        local te_state; te_state=$(check_thermal_engine)
        local cc_state; cc_state=$(check_core_control)
        local aboost;   aboost=$(get_adrenoboost)
        local gpu_gov;  gpu_gov=$(get_gpu_current_governor)

        hline "=" "$C"
        center "${BOLD}${C}     ===== LIVE THERMAL MONITOR =====    ${NC}"
        hline "=" "$C"
        echo ""

        echo -e " ${BOLD}${W}[T]  TEMPERATURE${NC}"
        echo ""

        if [ "$cpu_temp" != "N/A" ] 2>/dev/null; then
            printf "   %-10s " "CPU"
            draw_temp_bar "$cpu_temp"
            echo ""
        else
            printf "   %-10s ${DIM}N/A${NC}\n" "CPU"
        fi

        if [ "$gpu_temp" != "N/A" ] 2>/dev/null; then
            printf "   %-10s " "GPU"
            draw_temp_bar "$gpu_temp"
            echo ""
        else
            printf "   %-10s ${DIM}N/A${NC}\n" "GPU"
        fi

        if [ "$bat_temp" != "N/A" ] 2>/dev/null; then
            printf "   %-10s " "Battery"
            draw_temp_bar "$bat_temp"
            echo ""
        else
            printf "   %-10s ${DIM}N/A${NC}\n" "Battery"
        fi

        echo ""
        hline "-" "$DIM"
        echo ""

        echo -e " ${BOLD}${W}[P]  CPU / GPU${NC}"
        printf "   %-22s ${Y}%s${NC}\n" "CPU Freq (Prime/Big)" "$cpu_freq"
        printf "   %-22s ${Y}%s${NC}\n" "GPU Freq"             "$gpu_freq"
        printf "   %-22s ${Y}%s%%${NC}\n" "GPU Load"           "${gpu_busy:-N/A}"
        printf "   %-22s ${C}%s${NC}\n"  "GPU Governor"        "$gpu_gov"
        printf "   %-22s ${C}%s${NC}\n"  "adrenoboost"         "$aboost"

        echo ""
        hline "-" "$DIM"
        echo ""

        echo -e " ${BOLD}${W}[B]  BATTERY / SYSTEM${NC}"
        printf "   %-22s ${G}%s%%%s  %b${NC}\n" "Battery" "$bat_lvl" "" "$bat_sts"
        printf "   %-22s ${W}%s${NC}\n" "RAM Used"   "$ram_used"
        printf "   %-22s ${W}%s${NC}\n" "Uptime"     "$uptime"

        echo ""
        hline "-" "$DIM"
        echo ""

        echo -e " ${BOLD}${W}[S]  THERMAL CONTROL${NC}"
        local te_color=$G; [ "$te_state" = "OFF" ] && te_color=$R
        local cc_color=$G; [ "$cc_state" = "OFF" ] && cc_color=$R
        [ "$cc_state" = "N/A" ] && cc_color=$DIM

        printf "   %-22s ${te_color}%s${NC}\n" "Thermal Engine"   "$te_state"
        printf "   %-22s ${cc_color}%s${NC}\n" "Core Control"     "$cc_state"
        printf "   %-22s ${W}%s${NC}\n"         "sconfig"          "$sconfig"
        printf "   %-22s ${M}%s${NC}\n"         "Active Profile"   "${ACTIVE_PROFILE:-None}"

        echo ""
        hline "=" "$C"
        printf " ${DIM}Refresh: %ds  |  [q] Keluar  |  [r] Refresh sekarang${NC}\n" "$interval"

        local key=""
        read -r -t "$interval" -n 1 key
        case "$key" in
            q|Q) break ;;
            r|R) continue ;;
        esac
    done
}
