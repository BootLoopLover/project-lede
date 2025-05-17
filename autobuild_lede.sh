#!/bin/bash
#--------------------------------------------------------
# LEDE Firmware Autobuild Script
# Author: Pakalolo Waraso
#--------------------------------------------------------
set -e

# ─── Warna Terminal ────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

LEDE_DIR="lede"
START_TIME=$(date +%s)

# ─── Branding ───────────────────────────────────────────
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

# ─── Install Dependencies ───────────────────────────────
install_dependencies() {
    if ! grep -qEi 'ubuntu|debian' /etc/*release; then
        echo -e "${RED}[ERROR] Script ini hanya mendukung Debian/Ubuntu.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}[*] Memeriksa dan menginstall dependencies build...${NC}"
    sudo apt-get update
    sudo apt-get install -y \
        build-essential flex bison g++ gawk gcc gettext git \
        libncurses5-dev libz-dev patch python3 \
        rsync subversion unzip zlib1g-dev file wget libssl-dev \
        ccache xsltproc libxml-parser-perl ecj fastjar \
        java-propose-classpath libglib2.0-dev libfuse-dev \
        clang lld llvm libelf-dev device-tree-compiler \
        bc u-boot-tools qemu-utils asciidoc sudo time

    echo -e "${GREEN}[✔] Dependencies berhasil diinstall.${NC}"
}

# ─── Pilih Mode Build ───────────────────────────────────
select_build_mode() {
    while true; do
        echo ""
        echo "============ Build Mode Selection =============="
        echo "1. Fresh Build (hapus dan clone ulang)"
        echo "2. Rebuild (lanjutkan direktori 'lede' yang ada)"
        echo "0. Exit"
        echo "================================================"
        read -p "Pilih (1/2): " mode

        case "$mode" in
            1)
                read -p "Masukkan URL repo LEDE [default: https://github.com/coolsnowwolf/lede]: " REPO
                REPO=${REPO:-https://github.com/coolsnowwolf/lede}
                rm -rf "$LEDE_DIR"
                git clone "$REPO" "$LEDE_DIR"
                break
                ;;
            2)
                if [[ ! -d "$LEDE_DIR" ]]; then
                    echo -e "${RED}[ERROR] Folder '$LEDE_DIR' tidak ditemukan!${NC}"
                    exit 1
                fi
                break
                ;;
            0)
                echo -e "${YELLOW}Keluar...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid.${NC}"
                ;;
        esac
    done
}

# ─── Masuk Folder LEDE ──────────────────────────────────
run_in_lede_dir() {
    cd "$LEDE_DIR" || {
        echo -e "${RED}[ERROR] Gagal masuk folder $LEDE_DIR${NC}"
        exit 1
    }
}

# ─── Pilih Tag Git (Opsional) ───────────────────────────
select_git_tag() {
    echo -e "${YELLOW}[*] Menampilkan daftar tag git...${NC}"
    git fetch --tags
    git tag -l
    read -p "Masukkan tag git untuk checkout (biarkan kosong untuk skip): " TAG
    if [[ -n "$TAG" ]]; then
        git checkout "$TAG"
    fi
}

# ─── Patch NAND (Opsional) ──────────────────────────────
apply_nand_patch() {
    if [[ -d "../patch-nand" ]]; then
        echo -e "${YELLOW}[*] Menerapkan patch NAND...${NC}"
        cp -rf ../patch-nand/* target/linux/
    fi
}

# ─── Preset Konfigurasi ─────────────────────────────────
preset_configuration() {
    read -p "Gunakan preset config dari GitHub? (y/n): " USE_PRESET
    if [[ "$USE_PRESET" =~ ^[Yy]$ ]]; then
        read -p "Masukkan URL preset repo: " PRESET_REPO
        git clone "$PRESET_REPO" ../preset-temp
        [[ -d ../preset-temp/files ]] && cp -rf ../preset-temp/files ./files
        [[ -f ../preset-temp/.config ]] && cp -f ../preset-temp/.config .config
        rm -rf ../preset-temp
    fi
}

# ─── Konfigurasi Feed ───────────────────────────────────
feed_configuration() {
    echo -e "${YELLOW}[*] Menambahkan feed tambahan...${NC}"

    if ! grep -q "src-git custompackage " feeds.conf.default; then
        echo 'src-git custompackage https://github.com/BootLoopLover/custom-package.git' >> feeds.conf.default
    fi

    if ! grep -q "src-git php7package " feeds.conf.default; then
        echo 'src-git php7package https://github.com/BootLoopLover/openwrt-php7-package.git' >> feeds.conf.default
    fi

    while true; do
        echo ""
        echo "=========== Feed Tambahan ==========="
        echo "1. Tambahkan feed custom manual"
        echo "2. Lewati"
        echo "====================================="
        read -p "Pilih (1/2): " FEED_OPT
        case "$FEED_OPT" in
            1)
                read -p "Masukkan baris feed (misal: src-git custom https://github.com/xxx.git): " LINE
                echo "$LINE" >> feeds.conf.default
                ;;
            2)
                break
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid.${NC}"
                ;;
        esac
    done
}

# ─── Update Feed ────────────────────────────────────────
update_feeds() {
    echo -e "${YELLOW}[*] Update & install feeds...${NC}"
    ./scripts/feeds update -a
    ./scripts/feeds install -a
}

# ─── Menu Build ─────────────────────────────────────────
build_menu() {
    echo ""
    echo "============= Build Menu =============="
    echo "1. Jalankan 'make menuconfig'"
    echo "2. Langsung mulai build"
    echo "3. Keluar"
    echo "======================================="
    read -p "Pilih (1/2/3): " BACT
    case "$BACT" in
        1) make menuconfig ;;
        2) ;;
        3) echo -e "${YELLOW}Keluar...${NC}"; exit 0 ;;
        *) echo -e "${RED}Pilihan tidak valid.${NC}" ;;
    esac
}

# ─── Build Firmware ─────────────────────────────────────
start_build() {
    echo -e "${CYAN}[*] Memulai proses build...${NC}"
    if ! make -j"$(nproc)"; then
        echo -e "${YELLOW}[!] Build gagal. Coba ulang dengan log verbose...${NC}"
        make V=s
    fi
    END_TIME=$(date +%s)
    echo -e "${GREEN}[✔] Build selesai dalam $((END_TIME - START_TIME)) detik.${NC}"
}

# ─── Main ───────────────────────────────────────────────
main() {
    show_branding

    read -p "Install dependencies build? (y/n): " INSTALL_DEPS
    [[ "$INSTALL_DEPS" =~ ^[Yy]$ ]] && install_dependencies || echo -e "${YELLOW}[*] Melewati instalasi dependencies...${NC}"

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
