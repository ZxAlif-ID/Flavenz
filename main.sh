#!/data/data/com.termux/files/usr/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/capability.sh"
source "$SCRIPT_DIR/lib/actions.sh"
source "$SCRIPT_DIR/lib/monitor.sh"
source "$SCRIPT_DIR/lib/wuwa.sh"

draw_header() {
    local model; model=$(getprop ro.product.model 2>/dev/null)
    local kver;  kver=$(uname -r 2>/dev/null)
    local sc;    sc=$(get_sconfig)
    local te;    te=$(check_thermal_engine)
    local te_color=$G; [ "$te" = "OFF" ] && te_color=$R

    hline "=" "$M"
    center "${BOLD}${M}  FLAVENZ ${VERSION}${NC}  ${DIM}Performance Suite - Snapdragon${NC}"
    hline "-" "$DIM"
    printf "  ${DIM}Device: ${W}%-25s${NC}  ${DIM}Kernel: ${W}%s${NC}\n" "${model:-Unknown}" "${kver:-Unknown}"
    printf "  ${DIM}sconfig: ${W}%-5s${NC}  ${DIM}Thermal Engine: ${te_color}%-5s${NC}  ${DIM}Profile: ${M}%s${NC}\n" \
        "$sc" "$te" "${ACTIVE_PROFILE:-None}"
    hline "=" "$M"
    echo ""
}

show_main_menu() {
    clear
    draw_header
    echo -e "   ${BOLD}${W}MONITOR${NC}"
    echo -e "   ${C}[M]${NC} Live Monitor (temp, freq, load, status)"
    echo ""
    echo -e "   ${BOLD}${W}ACTIONS${NC}"
    echo -e "   ${G}[1]${NC} Backup state saat ini"
    echo -e "   ${G}[2]${NC} Performance Profiles (Balanced / Gaming / Extreme)"
    echo -e "   ${G}[3]${NC} Set CPU — Governor & WALT"
    echo -e "   ${G}[4]${NC} Set GPU — Governor & Profiles"
    echo -e "   ${G}[5]${NC} Thermal Control"
    echo ""
    echo -e "   ${BOLD}${W}WUTHERING WAVES${NC}"
    echo -e "   ${C}[7]${NC} WuWa Config Manager (Engine.ini / DeviceProfiles.ini)"
    echo ""
    echo -e "   ${BOLD}${W}DANGER ZONE${NC}"
    echo -e "   ${R}[6]${NC} Full Kill Mode - semua proteksi off"
    echo ""
    echo -e "   ${BOLD}${W}RESTORE${NC}"
    echo -e "   ${C}[R]${NC} Restore original state (dari backup)"
    echo -e "   ${R}[E]${NC} Emergency Restore (cepat, no-frills)"
    echo ""
    echo -e "   ${BOLD}${W}INFO${NC}"
    echo -e "   ${DIM}[C]${NC} Capability Report"
    echo -e "   ${DIM}[S]${NC} Re-scan capability"
    echo -e "   ${DIM}[L]${NC} Lihat log"
    echo ""
    echo -e "   ${DIM}[Q]${NC} Keluar"
    echo ""
    hline "-" "$DIM"
    echo -ne " ${BOLD}${C}Pilih >${NC} "
}

show_log() {
    clear; draw_header
    echo -e " ${BOLD}${W}=== LOG: ${LOG_FILE} ===${NC}"
    echo ""
    if [ -f "$LOG_FILE" ]; then
        tail -40 "$LOG_FILE"
    else
        echo -e " ${DIM}Log kosong.${NC}"
    fi
    echo ""
    echo -e " ${BOLD}${W}=== CHANGES: ${CHANGE_LOG} ===${NC}"
    echo ""
    if [ -f "$CHANGE_LOG" ]; then
        tail -30 "$CHANGE_LOG"
    else
        echo -e " ${DIM}Change log kosong.${NC}"
    fi
    echo ""
    echo -ne " ${DIM}[Enter]...${NC}"; read -r
}

init() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${Y}[*]${NC} Membutuhkan akses root..."
        exec su -c "exec '$0'" "$@"
    fi
    mkdir -p "$BACKUP_DIR" "$LOG_DIR" 2>/dev/null
    log_event "INFO" "Session started - Flavenz $VERSION"
    load_capability_cache
}

main() {
    init

    while true; do
        show_main_menu
        local choice; read -r choice

        case "${choice^^}" in
            M)  run_live_monitor ;;
            1)  save_backup; echo -ne " ${DIM}[Enter]...${NC}"; read -r ;;
            2)  show_profile_menu ;;
            3)  menu_cpu ;;
            4)  menu_gpu ;;
            5)  menu_thermal ;;
            6)  action_full_kill ;;
            7)  menu_wuwa ;;
            R)  action_restore ;;
            E)  action_emergency_restore ;;
            C)  show_capability_report ;;
            S)  run_capability_scan; echo -ne " ${DIM}[Enter]...${NC}"; read -r ;;
            L)  show_log ;;
            Q)  echo -e "\n ${DIM}Bye.${NC}\n"; log_event "INFO" "Session ended"; exit 0 ;;
            *)  echo -e " ${R}[!] Pilihan tidak valid${NC}"; sleep 0.4 ;;
        esac
    done
}

main
