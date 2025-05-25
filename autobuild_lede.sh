#!/bin/sh
#--------------------------------------------------------
# LEDE Firmware Autobuild Script (sh compatible)
# Author: Pakalolo Waraso
#--------------------------------------------------------

# ─── Warna Terminal ────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

LEDE_DIR="lede"
START_TIME=$(date +%s)

# Fungsi echo warna portable
echo_color() {
    # $1 = color code, $2 = message
    printf "%b%s%b\n" "$1" "$2" "$NC"
}

# ─── Branding ───────────────────────────────────────────
show_branding() {
    echo_color "$CYAN" "╔══════════════════════════════════════╗"
    echo_color "$CYAN" "║    AUTO BUILD LEDE / OPENWRT SCRIPT  ║"
    echo_color "$CYAN" "╚══════════════════════════════════════╝"
    echo "============== LEDE Firmware Autobuilder =============="
    echo_color "$BLUE" "Firmware Modification Project"
    echo_color "$BLUE" "Author: Pakalolo Waraso"
    echo_color "$BLUE" "Special Thanks: Awiks Telegram Group"
    echo_color "$BLUE" "Source: https://github.com/coolsnowwolf/lede"
    echo_color "$BLUE" "Maintainer: https://github.com/BootLoopLover"
    echo "======================================================="
    echo ""
}

# ─── Install Dependencies ───────────────────────────────
install_dependencies() {
    if ! grep -qEi 'ubuntu|debian' /etc/*release 2>/dev/null; then
        echo_color "$RED" "[ERROR] Script ini hanya mendukung Debian/Ubuntu."
        exit 1
    fi

    echo_color "$YELLOW" "[*] Memeriksa dan menginstall dependencies build..."
    sudo apt-get update
    sudo apt-get install -y \
        build-essential flex bison g++ gawk gcc gettext git \
        libncurses5-dev libz-dev patch python3 \
        rsync subversion unzip zlib1g-dev file wget libssl-dev \
        ccache xsltproc libxml-parser-perl ecj fastjar \
        java-propose-classpath libglib2.0-dev libfuse-dev \
        clang lld llvm libelf-dev device-tree-compiler \
        bc u-boot-tools qemu-utils asciidoc sudo time

    echo_color "$GREEN" "[✔] Dependencies berhasil diinstall."
}

# ─── Pilih Mode Build ───────────────────────────────────
select_build_mode() {
    while :; do
        echo ""
        echo "============ Build Mode Selection =============="
        echo "1. Fresh Build (hapus dan clone ulang)"
        echo "2. Rebuild (lanjutkan direktori 'lede' yang ada)"
        echo "0. Exit"
        echo "================================================"
        printf "Pilih (1/2/0): "
        read mode

        case "$mode" in
            1)
                printf "Masukkan URL repo LEDE [default: https://github.com/coolsnowwolf/lede]: "
                read REPO
                if [ -z "$REPO" ]; then
                    REPO="https://github.com/coolsnowwolf/lede"
                fi
                rm -rf "$LEDE_DIR"
                git clone "$REPO" "$LEDE_DIR"
                break
                ;;
            2)
                if [ ! -d "$LEDE_DIR" ]; then
                    echo_color "$RED" "[ERROR] Folder '$LEDE_DIR' tidak ditemukan!"
                    exit 1
                fi
                break
                ;;
            0)
                echo_color "$YELLOW" "Keluar..."
                exit 0
                ;;
            *)
                echo_color "$RED" "Pilihan tidak valid."
                ;;
        esac
    done
}

# ─── Masuk Folder LEDE ──────────────────────────────────
run_in_lede_dir() {
    cd "$LEDE_DIR" 2>/dev/null || {
        echo_color "$RED" "[ERROR] Gagal masuk folder $LEDE_DIR"
        exit 1
    }
}

# ─── Patch NAND (Opsional) ──────────────────────────────
apply_nand_patch() {
    if [ -d "../patch-nand" ]; then
        echo_color "$YELLOW" "[*] Menerapkan patch NAND..."
        cp -rf ../patch-nand/* target/linux/
    fi
}

# ─── Fungsi Penggunaan Preset ───────────────────────────
use_preset_menu() {
    echo_color "$BLUE" "Gunakan preset konfigurasi?"
    echo "1) ✅ Ya (untuk penggunaan pribadi)"
    echo "2) ❌ Tidak (konfigurasi manual)"
    printf "📌 Pilih opsi [1-2]: "
    read preset_answer

    if [ "$preset_answer" = "1" ]; then
        if [ ! -d "../preset" ]; then
            echo_color "$BLUE" "Meng-clone repository preset..."
            git clone "https://github.com/BootLoopLover/preset.git" "../preset" || {
                echo_color "$RED" "❌ Gagal clone preset."
                exit 1
            }
        fi

        echo_color "$BLUE" "Daftar preset tersedia:"
        # List folder preset manually
        i=1
        PRESET_FOLDERS=""
        for d in ../preset/*/ ; do
            foldername=$(basename "$d")
            echo "$i) $foldername"
            PRESET_FOLDERS="$PRESET_FOLDERS $foldername"
            i=$((i+1))
        done

        printf "🔢 Pilih folder preset [1-$((i-1))]: "
        read preset_choice

        # Validasi input angka
        expr "$preset_choice" + 1 >/dev/null 2>&1
        if [ $? -ne 0 ] || [ "$preset_choice" -lt 1 ] || [ "$preset_choice" -ge "$i" ]; then
            echo_color "$RED" "Pilihan preset tidak valid."
            exit 1
        fi

        # Ambil nama folder berdasarkan index
        count=1
        for folder in $PRESET_FOLDERS; do
            if [ "$count" -eq "$preset_choice" ]; then
                selected_folder="../preset/$folder"
                break
            fi
            count=$((count+1))
        done

        cp -rf "$selected_folder"/* ./
        if [ -f "$selected_folder/config-nss" ]; then
            cp "$selected_folder/config-nss" .config
        fi

    else
        # Jika tidak pakai preset dan .config tidak ada, langsung menuconfig
        if [ ! -f .config ]; then
            make menuconfig
        fi
    fi
}

# ─── Konfigurasi Feed ───────────────────────────────────
feed_configuration() {
    echo_color "$YELLOW" "[*] Menambahkan feed tambahan..."

    # Tambah baris jika belum ada
    grep -q "src-git custompackage " feeds.conf.default 2>/dev/null || \
        echo 'src-git custompackage https://github.com/BootLoopLover/custom-package.git' >> feeds.conf.default

    grep -q "src-git php7package " feeds.conf.default 2>/dev/null || \
        echo 'src-git php7package https://github.com/BootLoopLover/openwrt-php7-package.git' >> feeds.conf.default

    while :; do
        echo ""
        echo "=========== Feed Tambahan ==========="
        echo "1. Tambahkan feed custom manual"
        echo "2. Lewati"
        echo "====================================="
        printf "Pilih (1/2): "
        read FEED_OPT
        case "$FEED_OPT" in
            1)
                printf "Masukkan baris feed (misal: src-git custom https://github.com/xxx.git): "
                read LINE
                echo "$LINE" >> feeds.conf.default
                ;;
            2)
                break
                ;;
            *)
                echo_color "$RED" "Pilihan tidak valid."
                ;;
        esac
    done
}

# ─── Menu Update Feed dan Build ─────────────────────────
feeds_and_build_menu() {
    while :; do
        echo ""
        echo "========= Menu Update & Build ========="
        echo "1. Update & install feeds + jalankan menuconfig"
        echo "2. Jalankan 'make menuconfig' saja"
        echo "3. Mulai build firmware"
        echo "4. Keluar"
        echo "======================================="
        printf "Pilih (1/2/3/4): "
        read MENU_OPT

        case "$MENU_OPT" in
            1)
                echo_color "$YELLOW" "[*] Update & install feeds..."
                ./scripts/feeds update -a
                ./scripts/feeds install -a
                echo_color "$CYAN" "[*] Menjalankan menuconfig..."
                make menuconfig
                ;;
            2)
                make menuconfig
                ;;
            3)
                echo_color "$CYAN" "[*] Memulai proses build..."
                if ! make -j"$(nproc)"; then
                    echo_color "$YELLOW" "[!] Build gagal. Coba ulang dengan log verbose..."
                    make V=s
                fi
                END_TIME=$(date +%s)
                echo_color "$GREEN" "[✔] Build selesai dalam $((END_TIME - START_TIME)) detik."
                ;;
            4)
                echo_color "$YELLOW" "Keluar..."
                exit 0
                ;;
            *)
                echo_color "$RED" "Pilihan tidak valid."
                ;;
        esac
    done
}

# ─── Main ───────────────────────────────────────────────
main() {
    show_branding

    printf "Install dependencies build? (y/n): "
    read INSTALL_DEPS
    case "$INSTALL_DEPS" in
        y|Y)
            install_dependencies
            ;;
        *)
            echo_color "$YELLOW" "[*] Melewati instalasi dependencies..."
            ;;
    esac

    select_build_mode
    run_in_lede_dir
    apply_nand_patch
    use_preset_menu
    feed_configuration
    feeds_and_build_menu
}

main "$@"
