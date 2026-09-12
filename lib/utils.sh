#!/data/data/com.termux/files/usr/bin/bash

cols=$(tput cols 2>/dev/null || echo 60)

center() {
    local text="$1"
    local clean
    clean=$(printf '%s' "$text" | tr -d '\033' | sed 's/\[[0-9;]*m//g')
    local len=${#clean}
    local pad=$(( (cols - len) / 2 ))
    [ $pad -lt 0 ] && pad=0
    printf "%${pad}s" ""
    echo -e "$text"
}

hline() {
    local char="${1:--}"
    local color="${2:-$DIM}"
    echo -e "${color}$(printf '%*s' "$cols" | tr ' ' "$char")${NC}"
}

check_root() {
    [ "$(id -u)" -eq 0 ] && return 0
    echo -e "${R}[ERROR]${NC} Root tidak tersedia."
    echo -e "${Y}[INFO]${NC}  Jalankan dengan: su -c 'bash main.sh'"
    echo -e "${Y}[INFO]${NC}  atau: sudo bash main.sh"
    exit 1
}

swrite() {
    local node="$1" val="$2"
    if [ ! -f "$node" ]; then
        echo "[WARN] Node tidak ditemukan: $node" >&2
        return 1
    fi
    chmod 644 "$node" 2>/dev/null
    if echo "$val" > "$node" 2>/dev/null; then
        chmod 444 "$node" 2>/dev/null
    else
        echo "[ERROR] Gagal tulis ke: $node" >&2
        chmod 444 "$node" 2>/dev/null
        return 1
    fi
}

verify_node() {
    local node="$1" expected="$2"
    local actual
    actual=$(cat "$node" 2>/dev/null | tr -d '[:space:]')
    expected=$(echo "$expected" | tr -d '[:space:]')
    [ "$actual" = "$expected" ] && echo "PASS" || echo "FAIL:$actual"
}

result_badge() {
    case "$1" in
        PASS)  echo -e "${G}[PASS]${NC}" ;;
        N/A*)  echo -e "${DIM}[N/A]${NC}" ;;
        SKIP*) echo -e "${Y}[SKIP]${NC}" ;;
        FAIL*) echo -e "${R}[FAIL]${NC}" ;;
        *)     echo -e "${DIM}[?]${NC}" ;;
    esac
}

log_event() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    local level="${1:-INFO}"; shift
    echo "[$ts] [$level] $*" >> "$LOG_FILE" 2>/dev/null
}

log_change() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    local node="$1" before="$2" after="$3" status="$4"
    echo "$(date +%H:%M:%S) | $status | $node | before=$before | after=$after" >> "$CHANGE_LOG" 2>/dev/null
}


get_cpu_temp() {
    for z in /sys/class/thermal/thermal_zone*; do
        [ -f "$z/type" ] && [ -f "$z/temp" ] || continue
        local type; type=$(cat "$z/type" 2>/dev/null)
        echo "$type" | grep -qi "cpu\|prime\|big\|LITTLE\|cpu-1-7" || continue
        local raw; raw=$(cat "$z/temp" 2>/dev/null)
        [ -n "$raw" ] && echo $(( raw / 1000 )) && return
    done
    local raw; raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    [ -z "$raw" ] && echo "N/A" || echo $(( raw / 1000 ))
}

get_gpu_temp() {
    for z in /sys/class/thermal/thermal_zone*; do
        [ -f "$z/type" ] && [ -f "$z/temp" ] || continue
        local type; type=$(cat "$z/type" 2>/dev/null)
        echo "$type" | grep -qi "gpu\|kgsl" || continue
        local raw; raw=$(cat "$z/temp" 2>/dev/null)
        [ -n "$raw" ] && echo $(( raw / 1000 )) && return
    done
    echo "N/A"
}

get_bat_temp() {
    local raw; raw=$(cat /sys/class/power_supply/battery/temp 2>/dev/null)
    [ -z "$raw" ] && echo "N/A" || echo $(( raw / 10 ))
}

get_bat_level() {
    cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo "N/A"
}

get_bat_status() {
    local s; s=$(cat /sys/class/power_supply/battery/status 2>/dev/null)
    case "$s" in
        Charging)    echo -e "${G}[P] Charging${NC}" ;;
        Discharging) echo -e "${Y}[B] Discharge${NC}" ;;
        Full)        echo -e "${G}OK Full${NC}" ;;
        *)           echo -e "${DIM}${s:-N/A}${NC}" ;;
    esac
}

get_cpu_freq() {
    local freq
    freq=$(cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_cur_freq 2>/dev/null)
    [ -z "$freq" ] && freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
    [ -z "$freq" ] && echo "N/A" || echo "$(( freq / 1000 )) MHz"
}

get_gpu_freq() {
    local freq
    freq=$(cat /sys/class/kgsl/kgsl-3d0/gpuclk 2>/dev/null)
    [ -z "$freq" ] && freq=$(cat /sys/class/kgsl/kgsl-3d0/cur_freq 2>/dev/null)
    [ -z "$freq" ] && echo "N/A" || echo "$(( freq / 1000000 )) MHz"
}

get_gpu_busy() {
    local v
    v=$(cat /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage 2>/dev/null | tr -d '%')
    [ -z "$v" ] && v=$(cat /sys/class/kgsl/kgsl-3d0/devfreq/gpu_load 2>/dev/null)
    echo "${v:-N/A}"
}

get_ram_used() {
    local total free used totalm
    total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    free=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    used=$(( (total - free) / 1024 ))
    totalm=$(( total / 1024 ))
    echo "${used}MB / ${totalm}MB"
}

get_uptime() {
    uptime -p 2>/dev/null | sed 's/up //' || uptime | awk '{print $3}' | tr -d ','
}

get_sconfig() {
    local v; v=$(cat /sys/class/thermal/thermal_message/sconfig 2>/dev/null)
    [ -z "$v" ] && echo "N/A" || echo "$v"
}

get_adrenoboost() {
    cat /sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost 2>/dev/null || echo "N/A"
}

get_gpu_current_governor() {
    cat /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null | tr -d '[:space:]' || echo "N/A"
}

get_gpu_available_governors() {
    cat /sys/class/kgsl/kgsl-3d0/devfreq/available_governors 2>/dev/null || echo ""
}

check_thermal_engine() {
    local r; r=$(getprop init.svc.mi_thermald 2>/dev/null)
    [ "$r" = "running" ] && echo "ON" && return
    r=$(getprop init.svc.thermal-engine 2>/dev/null)
    [ "$r" = "running" ] && echo "ON" || echo "OFF"
}

check_core_control() {
    local node="/sys/module/msm_thermal/core_control/enabled"
    [ -f "$node" ] || { echo "N/A"; return; }
    local v; v=$(cat "$node" 2>/dev/null)
    [ "$v" = "1" ] && echo "ON" || echo "OFF"
}

draw_temp_bar() {
    local temp=$1 max=100 width=20
    local filled=$(( temp * width / max ))
    [ $filled -gt $width ] && filled=$width
    local empty=$(( width - filled ))
    local color=$G
    [ "$temp" -ge 50 ] && color=$Y
    [ "$temp" -ge 70 ] && color=$R
    printf "${color}["
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "]${NC} ${BOLD}${color}${temp} degC${NC}"
}
