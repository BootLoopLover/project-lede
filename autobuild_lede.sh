#!/bin/bash
#--------------------------------------------------------
# LEDE Firmware Autobuild Script
# Author: Pakalolo Waraso
#--------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

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
    if ! grep -qiE 'ubuntu|debian' /etc/*release 2>/dev/null; then
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
        read -r -p "Pilih (1/2/0): " mode

        case "$mode" in
            1)
                read -r -p "Masukkan URL repo LEDE [default: https://github.com/coolsnowwolf/lede]: " REPO
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

# ─── Patch NAND (Opsional) ──────────────────────────────
apply_nand_patch() {
    if [[ -d ../patch-nand ]]; then
        echo -e "${YELLOW}[*] Menerapkan patch NAND...${NC}"
        cp -rf ../patch-nand/* target/linux/
    fi
}

# ─── Fungsi Penggunaan Preset ───────────────────────────
use_preset_menu() {
    echo -e "${BLUE}Gunakan preset konfigurasi?${NC}"
    echo "1) ✅ Ya (untuk penggunaan pribadi)"
    echo "2) ❌ Tidak (konfigurasi manual)"
    read -r -p "📌 Pilih opsi [1-2]: " preset_answer

    if [[ "$preset_answer" == "1" ]]; then
        if [[ ! -d ../preset ]]; then
            echo -e "${BLUE}Meng-clone repository preset...${NC}"
            git clone "https://github.com/BootLoopLover/preset.git" ../preset || {
                echo -e "${RED}❌ Gagal clone preset.${NC}"
                exit 1
            }
        fi

        echo -e "${BLUE}Daftar preset tersedia:${NC}"
        mapfile -t folders < <(find ../preset -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        for i in "${!folders[@]}"; do
            echo "$((i + 1))) ${folders[$i]}"
        done

        read -r -p "🔢 Pilih folder preset [1-${#folders[@]}]: " preset_choice

        if [[ "$preset_choice" =~ ^[0-9]+$ ]] && (( preset_choice >= 1 && preset_choice <= ${#folders[@]} )); then
            selected_folder="../preset/${folders[$((preset_choice - 1))]}"
            if [[ -d "$selected_folder" ]]; then
                cp -rf "$selected_folder"/* ./
                if [[ -f "$selected_folder/config-nss" ]]; then
                    cp "$selected_folder/config-nss" .config
                fi
            else
                echo -e "${RED}Folder preset tidak ditemukan.${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Pilihan preset tidak valid.${NC}"
            exit 1
        fi
    else
        # Jika tidak pakai preset dan .config tidak ada, langsung menuconfig
        if [[ ! -f .config ]]; then
            make menuconfig
        fi
    fi
}

# ─── Konfigurasi Feed ───────────────────────────────────
feed_configuration() {
    echo -e "${YELLOW}[*] Menambahkan feed tambahan...${NC}"

    # Pastikan feeds.conf.default ada
    if [[ ! -f feeds.conf.default ]]; then
        echo -e "${RED}feeds.conf.default tidak ditemukan!${NC}"
        exit 1
    fi

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
        read -r -p "Pilih (1/2): " FEED_OPT
        case "$FEED_OPT" in
            1)
                read -r -p "Masukkan baris feed (misal: src-git custom https://github.com/xxx.git): " LINE
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

# ─── Menu Update Feed dan Build ─────────────────────────
feeds_and_build_menu() {
    while true; do
        echo ""
        echo "========= Menu Update & Build ========="
        echo "1. Update & install feeds + jalankan menuconfig"
        echo "2. Jalankan 'make menuconfig' saja"
        echo "3. Mulai build firmware"
        echo "4. Keluar"
        echo "======================================="
        read -r -p "Pilih (1/2/3/4): " MENU_OPT

        case "$MENU_OPT" in
            1)
                echo -e "${YELLOW}[*] Update & install feeds...${NC}"
                ./scripts/feeds update -a
                ./scripts/feeds install -a
                echo -e "${CYAN}[*] Menjalankan menuconfig...${NC}"
                make menuconfig
                ;;
            2)
                make menuconfig
                ;;
            3)
                echo -e "${CYAN}[*] Memulai proses build...${NC}"
                if ! make -j"$(nproc)"; then
                    echo -e "${YELLOW}[!] Build gagal. Coba ulang dengan log verbose...${NC}"
                    make V=s
                fi
                END_TIME=$(date +%s)
                echo -e "${GREEN}[✔] Build selesai dalam $((END_TIME - START_TIME)) detik.${NC}"
                ;;
            4)
                echo -e "${YELLOW}Keluar...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid.${NC}"
                ;;
        esac
    done
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

    read -r -p "Install dependencies build? (y/n): " INSTALL_DEPS
    if [[ "$INSTALL_DEPS" =~ ^[Yy]$ ]]; then
        install_dependencies
    else
        echo -e "${YELLOW}[*] Melewati instalasi dependencies...${NC}"
    fi

    select_build_mode
    run_in_lede_dir
    apply_nand_patch
    use_preset_menu
    feed_configuration
    feeds_and_build_menu
}

main "$@"
