#!/data/data/com.termux/files/usr/bin/bash

# WUTHERING WAVES CONFIG MANAGER
# Engine.ini + DeviceProfiles.ini manager dengan forbidden cvar filter
# Referensi: Arglax/Mobile-WuWa-Config v3.6, AZenith module design

WUWA_PKG="com.kurogame.wutheringwaves.global"
WUWA_CFG_DIR="/storage/emulated/0/Android/data/$WUWA_PKG/files/UE4Game/Client/Client/Saved/Config/Android"
WUWA_CFG_DIR_CN="/storage/emulated/0/Android/data/com.kurogame.wutheringwaves/files/UE4Game/Client/Client/Saved/Config/Android"
WUWA_ASSETS="$SCRIPT_DIR/configs/wuwa"
WUWA_BACKUP="$BACKUP_DIR/wuwa"
WUWA_APPLIED="$BACKUP_DIR/wuwa_applied.txt"

# FORBIDDEN CVARS - Kuro ConfigMonitor v3.6
# Cvar di daftar ini di-reject/di-track oleh ConfigMonitor -> auto-dihapus saat deploy
FORBIDDEN_CVARS="Kuro.CppEffectsystem.UseLowMemoryPlayerEffectLruCapacity r.AFME.Enable r.AsyncComputePSO r.DetailMode r.FEstimation.Option r.Kuro.SkeletalMesh.LODDistanceScale r.Kuro.TexturePool.ExtraBudgetMB r.KuroFI.Enable r.KuroMaterialQualityLevel r.LightMaxDrawDistanceScale r.MaterialQualityLevel r.MFRC.Enable r.MipMapLODBias r.Mobile.DeviceEvaluation r.MobileContentScaleFactor r.ParallelInitViews r.RayTracing.LimitDevice r.ScreenPercentage r.ScreenSizeCullRatioFactor r.SecondaryScreenPercentage.GameViewport r.Shadow.DistanceScale r.Shadow.MaxCSMResolution r.Shadow.MaxResolution r.streaming.AllowExtendedPoolSize r.Streaming.Boost r.Streaming.CPUReadback r.Streaming.DistancePriority.Texture2DArrayPriority r.streaming.ExtendedPoolSizeForceAllMipsThresholdPercentage r.streaming.ExtendedPoolSizeThresholdPercentage r.Streaming.KuroExtraPoolSize r.Streaming.LimitPoolSizeTOVRAM r.streaming.MaxExtendedPoolSizePercentage r.streaming.MaxExtendedPoolsizeVRAMPercentage r.Streaming.MaxNumTexturesTostreamPerFrame r.Streaming.MaxTempMemoryAllowed r.Streaming.MaxTempMemoryAllowedForTexture2DArray r.Streaming.MinBoost r.Streaming.MinMipForSplitRequest r.Streaming.PoolSize r.Streaming.PoolSizeExtraForTexture2DArray r.Streaming.Texture2DArrayStreamOutHysteresis r.Streaming.UseAllMips r.Streaming.UseAsyncCPUReadback r.Streaming.UseFixedPoolsize r.Streamline.DLSSG.RetainResourceswhenoff r.TextureGroup.Landscape.TextureLODBias r.ViewDistanceScale r.VolumetricFog r.VRS.EnableMaterial r.VRS.EnableMesh s.PriorityAsyncLoadingExtraTime"

# GAME.INI - file kedua di config dir; diisi via wuwa_set_framerate()
# (sg.* scalability efektifnya via DeviceProfile, bukan Game.ini)

# GPU FAMILY ADRENO (untuk forcer DeviceProfiles)
# Adreno 735 (SD 8s Gen 3) match ke Android_Adreno735 lalu fallback Adreno6xx/High
wuwa_resolve_cfg_dir() {
    if [ -d "$WUWA_CFG_DIR" ]; then
        echo "$WUWA_CFG_DIR"; return 0
    fi
    if [ -d "$WUWA_CFG_DIR_CN" ]; then
        echo "$WUWA_CFG_DIR_CN"; return 0
    fi
    return 1
}

wuwa_check_game() {
    if ! wuwa_resolve_cfg_dir >/dev/null; then
        echo -e " ${R}[!] Config dir WuWa tidak ditemukan.${NC}"
        echo -e " ${DIM}Dicari:${NC}"
        echo -e "   $WUWA_CFG_DIR"
        echo -e "   $WUWA_CFG_DIR_CN"
        echo -e " ${Y}[*] Pastikan game sudah pernah dibuka minimal 1x${NC}"
        echo -e " ${DIM}dan path Android/data bisa diakses (shizuku/root/SAF).${NC}"
        return 1
    fi
    return 0
}

wuwa_status() {
    local dir; dir=$(wuwa_resolve_cfg_dir) || { echo "NOT_INSTALLED"; return; }
    local out=""
    for f in Engine.ini DeviceProfiles.ini Game.ini GameUserSettings.ini Scalability.ini; do
        if [ -f "$dir/$f" ]; then
            local sz; sz=$(stat -c %s "$dir/$f" 2>/dev/null || echo "?")
            out="$out $f=${sz}B"
        fi
    done
    [ -z "$out" ] && out=" (config vanilla, belum ada file custom)"
    echo "DIR=$dir"
    echo "FILES:$out"
    [ -f "$WUWA_APPLIED" ] && echo "APPLIED=$(cat "$WUWA_APPLIED")"
}

# Filter forbidden cvars dari stream ini -> stdout
# Menjaga baris [Section] dan komentar utuh
wuwa_filter_forbidden() {
    local src="$1"
    while IFS= read -r line; do
        local key
        key=$(printf '%s' "$line" | sed 's/^[[:space:]]*//' | cut -d= -f1 | sed 's/[[:space:]]*$//')
        local skip=0
        for f in $FORBIDDEN_CVARS; do
            if [ "$key" = "$f" ]; then
                skip=1
                break
            fi
        done
        if [ "$skip" -eq 0 ]; then
            printf '%s\n' "$line"
        else
            printf '; [filtered-forbidden] %s\n' "$line"
        fi
    done < "$src"
}

wuwa_backup_current() {
    local dir; dir=$(wuwa_resolve_cfg_dir) || return 1
    mkdir -p "$WUWA_BACKUP"
    local n=0
    for f in Engine.ini DeviceProfiles.ini Game.ini GameUserSettings.ini Scalability.ini; do
        if [ -f "$dir/$f" ] && [ ! -f "$WUWA_BACKUP/$f.orig" ]; then
            cp "$dir/$f" "$WUWA_BACKUP/$f.orig"
            n=$((n+1))
        fi
    done
    [ "$n" -gt 0 ] && log_change "WUWA backup $n file ke $WUWA_BACKUP"
    return 0
}

wuwa_deploy_preset() {
    local preset="$1"
    local eng="$WUWA_ASSETS/${preset}_Engine.ini"
    local dp="$WUWA_ASSETS/${preset}_DeviceProfiles.ini"
    local gi="$WUWA_ASSETS/${preset}_Game.ini"

    if [ ! -f "$eng" ] || [ ! -f "$dp" ]; then
        echo -e " ${R}[!] Preset $preset tidak lengkap di $WUWA_ASSETS${NC}"
        return 1
    fi

    local dir; dir=$(wuwa_resolve_cfg_dir) || { echo -e " ${R}[!] WuWa tidak terinstall.${NC}"; return 1; }

    wuwa_backup_current

    echo -e " ${Y}[*]${NC} Deploy preset ${M}$preset${NC} -> $dir"

    local tmp; tmp="$LOG_DIR/.wuwa_tmp.ini"
    mkdir -p "$LOG_DIR"

    wuwa_filter_forbidden "$eng" > "$tmp"
    cp "$tmp" "$dir/Engine.ini"

    wuwa_filter_forbidden "$dp" > "$tmp"
    cp "$tmp" "$dir/DeviceProfiles.ini"

    if [ -f "$gi" ]; then
        wuwa_filter_forbidden "$gi" > "$tmp"
        cp "$tmp" "$dir/Game.ini"
    fi

    rm -f "$tmp"
    echo "$preset" > "$WUWA_APPLIED"
    log_change "WUWA preset=$preset deployed (forbidden filtered) ke $dir"

    echo -e " ${G}[OK]${NC} Deploy selesai. Forbidden cvars sudah difilter otomatis."
    echo -e " ${Y}[!]${NC} Clear cache game agar shader recompile:"
    echo -e "     buka game -> setelah splash, force-close 1x, buka lagi."
    return 0
}

wuwa_restore_vanilla() {
    local dir; dir=$(wuwa_resolve_cfg_dir) || return 1
    echo -e " ${Y}[*]${NC} Restore config vanilla WuWa..."
    local n=0
    for f in Engine.ini DeviceProfiles.ini Game.ini GameUserSettings.ini Scalability.ini; do
        if [ -f "$WUWA_BACKUP/$f.orig" ]; then
            cp "$WUWA_BACKUP/$f.orig" "$dir/$f"
            n=$((n+1))
        else
            rm -f "$dir/$f" 2>/dev/null
        fi
    done
    rm -f "$WUWA_APPLIED"
    log_change "WUWA restore vanilla ($n file dari backup)"
    echo -e " ${G}[OK]${NC} Restore selesai ($n file)."
    return 0
}

# FORCER - DeviceProfile match paksa per GPU family
# Adreno match: model device -> profile name eksplisit di DeviceProfiles.ini
wuwa_force_profile() {
    local profile="$1"
    local dir; dir=$(wuwa_resolve_cfg_dir) || return 1
    local dp="$dir/DeviceProfiles.ini"
    local model; model=$(getprop ro.product.model 2>/dev/null)
    local gpu; gpu=$(getprop ro.hardware.egl 2>/dev/null)
    [ -z "$gpu" ] && gpu=$(dumpsys SurfaceFlinger 2>/dev/null | grep -oE 'GLES:.*Adreno[^,)]*' | head -1 | grep -oE 'Adreno[^(0-9]*[0-9]+' | head -1)

    [ -f "$dp" ] || { echo -e " ${R}[!] DeviceProfiles.ini belum ada. Deploy preset dulu.${NC}"; return 1; }

    if grep -q "^\[$model DeviceProfile\]" "$dp" 2>/dev/null; then
        echo -e " ${Y}[*]${NC} Forcer untuk model '$model' sudah ada, skip."
        return 0
    fi

    {
        echo ""
        echo "[Flavenz_Forced DeviceProfile]"
        echo "BaseProfileName=$profile"
        echo ""
        echo "[$model DeviceProfile]"
        echo "BaseProfileName=Flavenz_Forced"
        [ -n "$gpu" ] && { echo "" ; echo "[Android_$gpu DeviceProfile]"; echo "BaseProfileName=Flavenz_Forced"; }
    } >> "$dp"

    log_change "WUWA force profile=$profile model=$model gpu=${gpu:-unknown}"
    echo -e " ${G}[OK]${NC} Device '$model' (GPU: ${gpu:-?}) dipaksa ke profile '$profile'."
    return 0
}

# GAME.INI generator - fps cap + vsync runtime
wuwa_set_framerate() {
    local fps="$1"
    local dir; dir=$(wuwa_resolve_cfg_dir) || return 1

    cat > "$dir/Game.ini" << EOF
[/Script/Engine.GameUserSettings]
FrameRateLimit=${fps}.000000
bUseVSync=False
EOF
    log_change "WUWA Game.ini FrameRateLimit=$fps"
    echo -e " ${G}[OK]${NC} Game.ini -> FrameRateLimit=${fps}"
    return 0
}

show_wuwa_status() {
    clear; draw_header
    echo -e " ${BOLD}${W}WuWa Config Status${NC}"
    echo ""
    local st; st=$(wuwa_status)
    if [ "$st" = "NOT_INSTALLED" ]; then
        echo -e " ${R}[!] WuWa global/CN tidak terdeteksi di storage.${NC}"
    else
        printf '%s\n' "$st" | while IFS= read -r line; do
            case "$line" in
                DIR=*)      echo -e " ${DIM}Dir:${NC} ${line#DIR=}" ;;
                FILES:*)    echo -e " ${DIM}Files:${NC}${line#FILES:}" ;;
                APPLIED=*)  echo -e " ${M}Preset aktif:${NC} ${line#APPLIED=}" ;;
            esac
        done
    fi
    echo ""
    echo -ne " ${DIM}[Enter]...${NC}"; read -r
}

menu_wuwa() {
    while true; do
        clear; draw_header
        echo -e " ${BOLD}${W}WuWa Config Manager${NC}  ${DIM}(Engine.ini / DeviceProfiles.ini / Game.ini)${NC}"
        local applied="None"
        [ -f "$WUWA_APPLIED" ] && applied=$(cat "$WUWA_APPLIED")
        echo -e "   Preset aktif: ${M}${applied}${NC}"
        echo ""
        echo -e "   ${G}[1]${NC} Status config"
        echo -e "   ${G}[2]${NC} Preset: BALANCED  ${DIM}(60fps稳定, visual standar+, hemat)${NC}"
        echo -e "   ${G}[3]${NC} Preset: GAMING    ${DIM}(fps prioritized, visual medium)${NC}"
        echo -e "   ${G}[4]${NC} Preset: MAXVISUAL ${DIM}(visual penuh, butuh cooler)${NC}"
        echo -e "   ${G}[5]${NC} Preset: POTATO    ${DIM}(survival mode, fps maksimal)${NC}"
        echo -e "   ${G}[6]${NC} Forcer: paksa DeviceProfile per GPU/model"
        echo -e "   ${G}[7]${NC} Game.ini: set FrameRateLimit manual"
        echo -e "   ${C}[R]${NC} Restore vanilla (hapus custom config)"
        echo -e "   ${DIM}[0]${NC} Kembali"
        echo ""
        echo -ne " ${BOLD}${C}Pilih >${NC} "
        local c; read -r c
        case "$c" in
            1) show_wuwa_status ;;
            2) wuwa_deploy_preset "balanced"; echo -ne " ${DIM}[Enter]...${NC}"; read -r ;;
            3) wuwa_deploy_preset "gaming"; echo -ne " ${DIM}[Enter]...${NC}"; read -r ;;
            4) wuwa_deploy_preset "maxvisual"; echo -ne " ${DIM}[Enter]...${NC}"; read -r ;;
            5) wuwa_deploy_preset "potato"; echo -ne " ${DIM}[Enter]...${NC}"; read -r ;;
            6) menu_wuwa_forcer ;;
            7) menu_wuwa_fps ;;
            R) wuwa_restore_vanilla; echo -ne " ${DIM}[Enter]...${NC}"; read -r ;;
            0) return ;;
            *) echo -e " ${R}[!] Tidak valid${NC}"; sleep 0.4 ;;
        esac
    done
}

menu_wuwa_forcer() {
    clear; draw_header
    echo -e " ${BOLD}${W}Forcer DeviceProfile${NC}  ${DIM}(append section match ke DeviceProfiles.ini)${NC}"
    echo ""
    echo -e "   ${G}[1]${NC} Android_High"
    echo -e "   ${G}[2]${NC} Android_VeryHigh"
    echo -e "   ${G}[3]${NC} Android_Adreno840 (HV reference)"
    echo -e "   ${G}[4]${NC} Input manual profile name"
    echo -e "   ${DIM}[0]${NC} Kembali"
    echo ""
    echo -ne " ${BOLD}${C}Pilih >${NC} "
    local c; read -r c
    local p=""
    case "$c" in
        1) p="Android_High" ;;
        2) p="Android_VeryHigh" ;;
        3) p="Android_Adreno840" ;;
        4) echo -ne " Profile name: "; read -r p ;;
        0) return ;;
        *) echo -e " ${R}[!] Tidak valid${NC}"; sleep 0.4; return ;;
    esac
    [ -n "$p" ] && wuwa_force_profile "$p"
    echo -ne " ${DIM}[Enter]...${NC}"; read -r
}

menu_wuwa_fps() {
    clear; draw_header
    echo -e " ${BOLD}${W}Game.ini FrameRateLimit${NC}"
    echo ""
    echo -e "   ${G}[1]${NC} 60"
    echo -e "   ${G}[2]${NC} 90"
    echo -e "   ${G}[3]${NC} 120"
    echo -e "   ${G}[4]${NC} Manual"
    echo -e "   ${DIM}[0]${NC} Kembali"
    echo ""
    echo -ne " ${BOLD}${C}Pilih >${NC} "
    local c; read -r c
    local f=""
    case "$c" in
        1) f="60" ;;
        2) f="90" ;;
        3) f="120" ;;
        4) echo -ne " FPS: "; read -r f ;;
        0) return ;;
        *) echo -e " ${R}[!] Tidak valid${NC}"; sleep 0.4; return ;;
    esac
    [ -n "$f" ] && wuwa_set_framerate "$f"
    echo -ne " ${DIM}[Enter]...${NC}"; read -r
}
