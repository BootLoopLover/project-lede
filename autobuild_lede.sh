#!/bin/bash
#--------------------------------------------------------
# LEDE Firmware Autobuild Script - Final Version
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

    echo -e "${GREEN}[\u2714] Dependencies berhasil diinstall.${NC}"
}

# ─── Pilih Mode Build ───────────────────────────────────
select_build_mode() {
    echo -e "${YELLOW}Pilih mode build:${NC}"
    echo "1) Fresh build (clone ulang LEDE)"
    echo "2) Rebuild dari folder yang sudah ada"
    read -rp "Masukkan pilihan [1-2]: " mode
    case $mode in
        1)
            echo -e "${BLUE}[INFO] Melakukan fresh clone dari repo LEDE...${NC}"
            rm -rf "$LEDE_DIR"
            git clone --depth=1 https://github.com/coolsnowwolf/lede "$LEDE_DIR"
            ;;
        2)
            echo -e "${BLUE}[INFO] Menggunakan folder build yang sudah ada.${NC}"
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid.${NC}"
            exit 1
            ;;
    esac
}

# ─── Masuk Folder LEDE ──────────────────────────────────
run_in_lede_dir() {
    if [ ! -d "$LEDE_DIR" ]; then
        echo -e "${RED}[ERROR] Folder '$LEDE_DIR' tidak ditemukan.${NC}"
        exit 1
    fi
    cd "$LEDE_DIR" || exit 1
}

# ─── Patch NAND (Opsional) ──────────────────────────────
apply_nand_patch() {
    if [[ -d "../patch-nand" ]]; then
        echo -e "${YELLOW}[*] Menerapkan patch NAND...${NC}"
        cp -rf ../patch-nand/* target/linux/
    fi
}

# ─── Fungsi Penggunaan Preset ───────────────────────────
use_preset_menu() {
    echo -e "${BLUE}Gunakan preset konfigurasi?${NC}"
    echo "1) ✅ Ya (untuk penggunaan pribadi)"
    echo "2) ❌ Tidak (konfigurasi manual)"
    read -p "📌 Pilih opsi [1-2]: " preset_answer

    if [[ "$preset_answer" == "1" ]]; then
        if [[ ! -d "../preset" ]]; then
            echo -e "${BLUE}Meng-clone repository preset...${NC}"
            git clone "https://github.com/BootLoopLover/preset.git" "../preset" || {
                echo -e "${RED}❌ Gagal clone preset.${NC}"
                exit 1
            }
        fi

        echo -e "${BLUE}Daftar preset tersedia:${NC}"
        mapfile -t folders < <(find ../preset -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        for i in "${!folders[@]}"; do
            echo "$((i + 1))) ${folders[$i]}"
        done

        read -p "🔢 Pilih folder preset [1-${#folders[@]}]: " preset_choice
        selected_folder="../preset/${folders[$((preset_choice - 1))]}"
        cp -rf "$selected_folder"/* ./

        if [[ -f "$selected_folder/config-nss" ]]; then
            cp "$selected_folder/config-nss" .config
        fi
    else
        [[ ! -f .config ]] && make menuconfig
    fi
}

# ─── Opsi Clean Build ───────────────────────────────────
clean_build_menu() {
    echo -e "${YELLOW}Apakah ingin melakukan clean build (hapus hasil kompilasi sebelumnya)?${NC}"
    echo "1) Ya, bersihkan semua (make clean && make dirclean)"
    echo "2) Tidak, lanjutkan tanpa clean build"
    read -rp "Masukkan pilihan [1-2]: " clean_choice
    case $clean_choice in
        1)
            echo -e "${BLUE}[INFO] Melakukan clean build...${NC}"
            make clean
            make dirclean
            echo -e "${GREEN}[\u2714] Clean build selesai.${NC}"
            ;;
        2)
            echo -e "${BLUE}[INFO] Melewati tahap clean build.${NC}"
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid, melewati tahap clean build.${NC}"
            ;;
    esac
}

# ─── Menu Build ─────────────────────────────────────────
feeds_and_build_menu() {
    while true; do
        echo -e "${YELLOW}Pilih opsi:${NC}"
        echo "1) Update feeds + make menuconfig"
        echo "2) Make menuconfig"
        echo "3) Build firmware"
        echo "4) Keluar"
        read -rp "Masukkan pilihan [1-4]: " choice
        case $choice in
            1)
                echo -e "${YELLOW}Update feeds dan run menuconfig...${NC}"
                ./scripts/feeds update -a
                ./scripts/feeds install -a
                echo -e "${GREEN}[\u2714] Feeds fully updates.${NC}"
                echo -e "${YELLOW}Masuk menuconfig...${NC}"
                make menuconfig
                ;;
            2)
                echo -e "${YELLOW}Masuk menuconfig...${NC}"
                make menuconfig
                ;;
            3)
                clean_build_menu
                echo -e "${YELLOW}Memulai build firmware...${NC}"
                BUILD_START=$(date +%s)
                if make -j"$(nproc)"; then
                    BUILD_END=$(date +%s)
                    BUILD_DURATION=$((BUILD_END - BUILD_START))
                    echo -e "${GREEN}[\u2714] Build selesai dalam waktu: $(date -u -d @$BUILD_DURATION +"%H:%M:%S")${NC}"
                else
                    echo -e "${RED}[\u2718] Build gagal.${NC}"
                    exit 1
                fi
                ;;
            4)
                echo -e "${CYAN}Keluar dari menu build.${NC}"
                break
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid.${NC}"
                ;;
        esac
    done
}

# ─── Eksekusi Utama ─────────────────────────────────────
main() {
    show_branding
    install_dependencies
    select_build_mode
    run_in_lede_dir
    apply_nand_patch
    use_preset_menu
    feeds_and_build_menu
}

main
