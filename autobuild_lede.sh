#!/bin/bash
#--------------------------------------------------------
# LEDE Firmware Autobuild Script
# Author: Pakalolo Waraso
#--------------------------------------------------------

# === Warna untuk output terminal ===
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

# --- Fungsi format durasi (detik ke hh:mm:ss) ---
format_duration() {
    local T=$1
    printf '%02d:%02d:%02d\n' $((T/3600)) $((T%3600/60)) $((T%60))
}

# --- Fungsi tampilkan branding ---
show_branding() {
    clear
    echo "============== LEDE Firmware Autobuilder =============="
    echo -e "${BLUE}Firmware Modification Project${NC}"
    echo -e "${BLUE}Author: Pakalolo Waraso${NC}"
    echo -e "${BLUE}Special Thanks: Awiks Telegram Group${NC}"
    echo -e "${BLUE}Source: https://github.com/coolsnowwolf/lede${NC}"
    echo -e "${BLUE}Maintainer: https://github.com/BootLoopLover${NC}"
    echo "======================================================="
}

# --- Fungsi pilih mode build ---
select_build_mode() {
    while true; do
        echo ""
        echo "============ Build Mode Selection =============="
        echo "1. Fresh Build (clean and clone)"
        echo "2. Rebuild (use existing 'lede' directory)"
        echo "0. Exit"
        echo "================================================"
        read -rp "Select option [0-2]: " BUILD_MODE
        case "$BUILD_MODE" in
            1)
                echo "[INFO] Starting fresh build..."
                rm -rf lede
                git clone https://github.com/coolsnowwolf/lede.git
                cd lede
                break
                ;;
            2)
                if [ ! -d lede ]; then
                    echo -e "${RED}[ERROR] Directory 'lede' not found. Cannot proceed with rebuild.${NC}"
                    exit 1
                fi
                cd lede
                echo "[INFO] Using existing 'lede' directory."
                break
                ;;
            0)
                echo "[INFO] Exiting script."
                exit 0
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid selection. Please enter a number between 0 and 2.${NC}"
                ;;
        esac
    done
}

# --- Fungsi apply NAND patch ---
apply_nand_patch() {
    echo -e "${BLUE}[TASK] Checking for NAND support patch...${NC}"
    PATCH_SRC="target/linux/qualcommax/patches-6.6/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch"
    PATCH_DST="target/linux/qualcommax/patches-6.1/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch"

    if [ -f "$PATCH_SRC" ]; then
        cp "$PATCH_SRC" "$PATCH_DST"
        echo -e "${GREEN}[INFO] NAND patch copied successfully.${NC}"
    else
        echo -e "${YELLOW}[INFO] NAND patch not found at ${PATCH_SRC}. Skipping patch copy.${NC}"
    fi
}

# --- Fungsi update feeds ---
update_feeds() {
    while true; do
        echo ""
        echo "============= Feed Update ==================="
        echo "1. Run 'feeds update' and 'feeds install'"
        echo "2. Skip"
        echo "=============================================="
        read -rp "Select option [1-2]: " FEED_UPDATE
        case "$FEED_UPDATE" in
            1)
                ./scripts/feeds update -a
                ./scripts/feeds install -a
                break
                ;;
            2)
                break
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid selection.${NC}"
                ;;
        esac
    done
}

# --- Fungsi clone dan copy preset ---
clone_and_copy_preset() {
    local repo_url=$1
    local folder_name=$2
    echo -e "${BLUE}Cloning ${folder_name}...${NC}"
    git clone "$repo_url" "../$folder_name" || {
        echo -e "${RED}Failed to clone ${folder_name}.${NC}"
        return 1
    }

    if [ -d "../$folder_name/files" ]; then
        echo "[INFO] Copying 'files' directory from preset..."
        mkdir -p files
        cp -r "../$folder_name/files/"* files/
    fi

    if [ -f "../$folder_name/config-preset" ]; then
        cp "../$folder_name/config-preset" .config
        skip_menuconfig=true
        echo -e "${GREEN}[INFO] Applied preset: config-preset. Skipping menuconfig.${NC}"
    else
        echo -e "${YELLOW}[WARNING] No preset config file found in ${folder_name}. Continuing with menuconfig.${NC}"
        skip_menuconfig=false
    fi
}

# --- Fungsi konfigurasi preset ---
preset_configuration() {
    echo ""
    echo "============ Preset Configuration ============="
    echo "1. Clone and use preset from 'preset-lede' repo"
    echo "2. Skip"
    echo "==============================================="
    read -rp "Select option [1-2]: " PRESET_OPTION

    case "$PRESET_OPTION" in
        1)
            clone_and_copy_preset "https://github.com/BootLoopLover/preset-lede.git" "preset-lede"
            ;;
        2)
            echo "[INFO] Preset selection skipped."
            ;;
        *)
            echo -e "${RED}[ERROR] Invalid input. Proceeding without preset.${NC}"
            ;;
    esac
}

# --- Fungsi konfigurasi feeds ---
feed_configuration() {
    while true; do
        echo ""
        echo "=========== Feed Configuration ==========="
        echo "1. Add feed: custompackage"
        echo "2. Add feed: php7"
        echo "3. Add both feeds"
        echo "4. Skip"
        echo "==========================================="
        read -rp "Select option [1-4]: " FEED_OPTION
        case "$FEED_OPTION" in
            1)
                echo 'src-git custompackage https://github.com/BootLoopLover/custom-package.git' >> feeds.conf.default
                break
                ;;
            2)
                echo 'src-git php7 https://github.com/BootLoopLover/openwrt-php7-package.git' >> feeds.conf.default
                break
                ;;
            3)
                echo 'src-git custompackage https://github.com/BootLoopLover/custom-package.git' >> feeds.conf.default
                echo 'src-git php7 https://github.com/BootLoopLover/openwrt-php7-package.git' >> feeds.conf.default
                break
                ;;
            4)
                break
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid selection.${NC}"
                ;;
        esac
    done
}

# --- Fungsi update feeds ---
update_feeds() {
    while true; do
        echo ""
        echo "============= Feed Update ==================="
        echo "1. Run 'feeds update' and 'feeds install'"
        echo "2. Skip"
        echo "=============================================="
        read -rp "Select option [1-2]: " FEED_UPDATE
        case "$FEED_UPDATE" in
            1)
                ./scripts/feeds update -a
                ./scripts/feeds install -a
                break
                ;;
            2)
                break
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid selection.${NC}"
                ;;
        esac
    done
}

# --- Fungsi checkout git tag ---
select_git_tag() {
    while true; do
        echo ""
        echo "========== Git Tag Checkout (Optional) ========"
        echo "1. List and checkout available tags"
        echo "2. Skip"
        echo "================================================"
        read -rp "Select option [1-2]: " TAG_OPTION
        case "$TAG_OPTION" in
            1)
                TAGS=$(git tag)
                if [ -z "$TAGS" ]; then
                    echo "[INFO] No Git tags found in repository."
                    break
                fi
                echo "[AVAILABLE TAGS]"
                select tag in $TAGS; do
                    if [ -n "$tag" ]; then
                        git checkout "$tag"
                        echo -e "${GREEN}[INFO] Checked out tag: $tag${NC}"
                        break 2
                    else
                        echo -e "${RED}[ERROR] Invalid selection.${NC}"
                    fi
                done
                ;;
            2)
                break
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid input. Please select 1 or 2.${NC}"
                ;;
        esac
    done
}


# --- Fungsi menu build ---
build_menu() {
    while true; do
        echo ""
        echo "============= Build Menu =============="
        echo "1. Run 'make menuconfig'"
        echo "2. Start build immediately"
        echo "3. Exit"
        echo "======================================="
        if [ "$skip_menuconfig" = true ]; then
            echo -e "${YELLOW}[INFO] Skipping menuconfig as preset config has been applied.${NC}"
            break
        fi
        read -rp "Select option [1-3]: " BUILD_CHOICE
        case "$BUILD_CHOICE" in
            1)
                make menuconfig
                read -rp "Proceed to build? [y/N]: " CONFIRM
                [[ "$CONFIRM" =~ ^[Yy]$ ]] && break || exit 0
                ;;
            2)
                break
                ;;
            3)
                exit 0
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid input.${NC}"
                ;;
        esac
    done
}

# --- Fungsi proses build ---
start_build() {
    echo "[TASK] Starting build process..."
    local BUILD_START
    local BUILD_END
    local BUILD_DURATION

    BUILD_START=$(date +%s)

    if ! make -j"$(nproc)"; then
        echo -e "${YELLOW}[WARNING] Build failed. Retrying with verbose output...${NC}"
        if ! make -j"$(nproc)" V=s; then
            echo -e "${RED}[ERROR] Build failed again. Aborting.${NC}"
            exit 1
        fi
    fi

    BUILD_END=$(date +%s)
    BUILD_DURATION=$((BUILD_END - BUILD_START))
    echo -e "${GREEN}[SUCCESS] Build completed in: $(format_duration $BUILD_DURATION)${NC}"
}

# === MAIN SCRIPT EXECUTION ===

show_branding
select_build_mode
select_git_tag
apply_nand_patch
preset_configuration
feed_configuration
update_feeds
build_menu
start_build
