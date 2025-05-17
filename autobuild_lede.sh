#!/bin/bash
#--------------------------------------------------------
# LEDE Firmware Autobuild Script
# Author: Pakalolo Waraso
#--------------------------------------------------------
set -e

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

LEDE_DIR="lede"
START_TIME=$(date +%s)

# ─── Branding ─────────────────────────────────────────────────────
show_branding() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════╗"
    echo "║    AUTO BUILD LEDE / OPENWRT SCRIPT  ║"
    echo "╚══════════════════════════════════════╝"
    echo "============== LEDE Firmware Autobuilder =============="
    echo -e "${BLUE}Firmware Modification Project${NC}"
    echo -e "${BLUE}Author: Pakalolo Waraso${NC}"
    echo -e "${BLUE}Special Thanks: Awiks Telegram Group${NC}"
    echo -e "${BLUE}Source: https://github.com/coolsnowwolf/lede${NC}"
    echo -e "${BLUE}Maintainer: https://github.com/BootLoopLover${NC}"
    echo "======================================================="
    echo -e "${NC}"
}

# ─── Install Dependencies ─────────────────────────────────────────
install_dependencies() {
    if ! grep -qEi 'ubuntu|debian' /etc/*release; then
        echo -e "${RED}[ERROR] Script ini hanya mendukung Debian/Ubuntu.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}[*] Memeriksa dan menginstall dependencies build...${NC}"

    sudo apt-get update

    sudo apt-get install -y \
        build-essential flex bison g++ gawk gcc gettext git \
        libncurses5-dev libz-dev patch python3 python3-distutils \
        rsync subversion unzip zlib1g-dev file wget libssl-dev \
        ccache xsltproc libxml-parser-perl ecj fastjar \
        java-propose-classpath libglib2.0-dev libfuse-dev \
        clang lld llvm libelf-dev device-tree-compiler \
        bc u-boot-tools qemu-utils asciidoc sudo time

    echo -e "${GREEN}[✔] Dependencies berhasil diinstall.${NC}"
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
    read -p "Pilih (1/2): " mode

    if [[ "$mode" == "1" ]]; then
        read -p "Masukkan URL repo LEDE (default: https://github.com/coolsnowwolf/lede): " REPO
        REPO=${REPO:-https://github.com/coolsnowwolf/lede}
        rm -rf "$LEDE_DIR"
        git clone "$REPO" "$LEDE_DIR"
    elif [[ "$mode" != "2" ]]; then
        echo -e "${RED}Pilihan tidak valid.${NC}"
        exit 1
    fi
}

# ─── Masuk Folder LEDE ────────────────────────────────────────────
run_in_lede_dir() {
    cd "$LEDE_DIR" || {
        echo -e "${RED}[ERROR] Gagal masuk folder $LEDE_DIR${NC}"
        exit 1
    }
}

# ─── Pilih Tag Git ────────────────────────────────────────────────
select_git_tag() {
    echo -e "${YELLOW}[*] Memilih git tag (opsional)...${NC}"
    git fetch --tags
    TAGS=$(git tag -l)
    echo "$TAGS"
    read -p "Masukkan tag git (atau kosongkan untuk skip): " TAG
    if [[ -n "$TAG" ]]; then
        git checkout "$TAG"
    fi
}

# ─── Patch NAND (Opsional) ────────────────────────────────────────
apply_nand_patch() {
    if [[ -d "../patch-nand" ]]; then
        echo -e "${YELLOW}[*] Menerapkan patch NAND...${NC}"
        cp -rf ../patch-nand/* target/linux/
    fi
}

# ─── Preset Config ────────────────────────────────────────────────
preset_configuration() {
    read -p "Gunakan preset config dari GitHub? (y/n): " USE_PRESET
    if [[ "$USE_PRESET" =~ ^[Yy]$ ]]; then
        read -p "Masukkan URL preset repo: " PRESET_REPO
        git clone "$PRESET_REPO" ../preset-temp
        cp -rf ../preset-temp/files ./files 2>/dev/null || true
        cp -f ../preset-temp/.config .config 2>/dev/null || true
        rm -rf ../preset-temp
    fi
}

# ─── Feed Custom ──────────────────────────────────────────────────
feed_configuration() {
    read -p "Tambahkan feed custom? (y/n): " FEED_CUSTOM
    if [[ "$FEED_CUSTOM" =~ ^[Yy]$ ]]; then
        read -p "Masukkan baris feed misal: src-git custom https://github.com/xxx.git: " LINE
        echo "$LINE" >> feeds.conf.default
    fi
    read -p "Tambahkan feed PHP7 dari OpenWrt 22.03? (y/n): " FEED_PHP
    if [[ "$FEED_PHP" =~ ^[Yy]$ ]]; then
        echo "src-git php7 https://github.com/openwrt/packages;openwrt-22.03" >> feeds.conf.default
    fi
}

# ─── Update Feed ──────────────────────────────────────────────────
update_feeds() {
    read -p "Update dan install feeds? (y/n): " FEEDS
    if [[ "$FEEDS" =~ ^[Yy]$ ]]; then
        ./scripts/feeds update -a
        ./scripts/feeds install -a
    fi
}

# ─── Menu Build ───────────────────────────────────────────────────
build_menu() {
        echo "============= Build Menu =============="
        echo "1. Run 'make menuconfig'"
        echo "2. Start build immediately"
        echo "3. Exit"
        echo "======================================="
    read -p "Pilih (1/2): " BACT

    if [[ "$BACT" == "1" ]]; then
        make menuconfig
    fi
}

# ─── Mulai Build ──────────────────────────────────────────────────
start_build() {
    echo -e "${CYAN}[*] Memulai build...${NC}"
    make -j"$(nproc)" || make V=s
    END_TIME=$(date +%s)
    BUILD_DURATION=$((END_TIME - START_TIME))
    echo -e "${GREEN}[✔] Build selesai dalam $BUILD_DURATION detik.${NC}"
}

# ─── Main ─────────────────────────────────────────────────────────
main() {
    show_branding

    read -p "Install build dependencies? (y/n): " INSTALL_DEPS
    if [[ "$INSTALL_DEPS" =~ ^[Yy]$ ]]; then
        install_dependencies
    else
        echo -e "${YELLOW}[*] Melewati instalasi dependencies...${NC}"
    fi

    select_build_mode
    run_in_lede_dir
    select_git_tag
    apply_nand_patch
    preset_configuration
    feed_configuration
    update_feeds
    build_menu
    start_build
}

main "$@"
