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
                cd lede || exit
                break
                ;;
            2)
                if [ ! -d lede ]; then
                    echo -e "${RED}[ERROR] Directory 'lede' not found. Cannot proceed with rebuild.${NC}"
                    exit 1
                fi
                cd lede || exit
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

# --- Fungsi update dependencies (opsional) ---
update_dependencies() {
    echo -e "${BLUE}[TASK] Updating build dependencies...${NC}"

    # Update dan upgrade sistem dengan output terlihat
    sudo apt update -y 2>&1 | tee /dev/tty
    sudo apt full-upgrade -y 2>&1 | tee /dev/tty

    # Install dependencies
    sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
        bzip2 ccache clang cmake cpio curl device-tree-compiler flex gawk gcc-multilib g++-multilib gettext \
        genisoimage git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev \
        libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev \
        libreadline-dev libssl-dev libtool llvm lrzsz msmtp ninja-build p7zip p7zip-full patch pkgconf \
        python3 python3-pyelftools python3-setuptools qemu-utils rsync scons squashfs-tools subversion \
        swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev 2>&1 | tee /dev/tty
}

# --- Fungsi tanya apakah ingin update dependencies ---
ask_update_dependencies() {
    echo ""
    echo "========== Dependencies Setup =========="
    echo "1. Update build dependencies (recommended)"
    echo "2. Skip"
    echo "========================================"
    read -rp "Select option [1-2]: " DEP_OPTION
    case "$DEP_OPTION" in
        1)
            update_dependencies
            ;;
        2)
            echo "[INFO] Skipping dependency update."
            ;;
        *)
            echo -e "${YELLOW}[WARNING] Invalid input. Skipping dependency update.${NC}"
            ;;
    esac
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
                        git checkout "$tag" || {
                            echo -e "${RED}[ERROR] Failed to checkout tag $tag. Aborting.${NC}"
                            exit 1
                        }
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

# --- Fungsi apply NAND patch ---
apply_nand_patch() {
    echo -e "${BLUE}[TASK] Checking for NAND support patch...${NC}"
    PATCH_SRC="target/linux/qualcommax/patches-6.6/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch"
    PATCH_DST="target/linux/qualcommax/patches-6.1/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch"

    if [ -f "$PATCH_SRC" ]; then
        if [ ! -f "$PATCH_DST" ]; then
            cp "$PATCH_SRC" "$PATCH_DST"
            echo -e "${GREEN}[INFO] NAND patch copied successfully.${NC}"
        else
            echo -e "${YELLOW}[INFO] NAND patch already exists. Skipping copy.${NC}"
        fi
    else
        echo -e "${YELLOW}[INFO] NAND patch not found at ${PATCH_SRC}. Skipping.${NC}"
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
            echo -e "${BLUE}Cloning preset-lede...${NC}"
            git clone https://github.com/BootLoopLover/preset-lede.git ../preset-lede || {
                echo -e "${RED}Failed to clone preset repo.${NC}"
                return
            }
            if [ -d ../preset-lede/files ]; then
                echo "[INFO] Copying 'files' directory..."
                mkdir -p files
                cp -r ../preset-lede/files/* files/
            fi
            if [ -f ../preset-lede/config-preset ]; then
                cp ../preset-lede/config-preset .config
                skip_menuconfig=true
                echo -e "${GREEN}[INFO] Applied preset: config-preset. Skipping menuconfig.${NC}"
            else
                echo -e "${YELLOW}[WARNING] Preset config not found. Will open menuconfig.${NC}"
                skip_menuconfig=false
            fi
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
                ./scripts/feeds update -a && ./scripts/feeds install -a
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
