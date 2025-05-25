#!/bin/bash
#--------------------------------------------------------
# 🚀 Universal OpenWrt Builder - Final Professional Version
# 👨‍💻 Author: Pakalolo Waraso (BootLoopLover)
#--------------------------------------------------------

# ─── Color Setup ─────────────────────────────────────────
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

# ─── Banner & Branding ──────────────────────────────────
show_banner() {
    clear
    local message="🚀 Launching Arcadyan Firmware Project by Pakalolo Waraso..."
    for ((i=0; i<${#message}; i++)); do
        echo -ne "${YELLOW}${message:$i:1}${NC}"
        sleep 0.01
    done
    echo -e "\n"
    for i in $(seq 1 60); do echo -ne "${BLUE}=${NC}"; sleep 0.005; done
    echo -e "\n${BLUE}"
    cat << "EOF"
   ___                   __                 
  / _ | ___________ ____/ /_ _____ ____   
 / __ |/ __/ __/ _ `/ _  / // / _ `/ _ \  
/_/ |_/_/  \__/\_,_/\_,_/\_, /\_,_/_//_/ 
   _____                /___/     
  / __(_)_____ _ _    _____ ________ 
 / _// / __/  ' \ |/|/ / _ `/ __/ -_)
/_/ /_/_/ /_/_/_/__,__/\_,_/_/  \__/            
   ___             _         __        
  / _ \_______    (_)__ ____/ /_       
 / ___/ __/ _ \  / / -_) __/ __/  _ _ _ 
/_/  /_/  \___/_/ /\__/\__/\__/  (_|_|_)
             |___/ 
EOF
    echo -e "${NC}"
    for i in $(seq 1 60); do echo -ne "${BLUE}-${NC}"; sleep 0.005; done
    echo -e "\n"
    show_branding
}

show_branding() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════╗"
    echo "║    🛠️  AUTO BUILD LEDE / OPENWRT SCRIPT   ║"
    echo "╚══════════════════════════════════════╝"
    echo "============== LEDE Firmware Autobuilder =============="
    echo -e "${BLUE}📦 Firmware Modification Project"
    🔧 Author: Pakalolo Waraso
    💬 Special Thanks: Awiks Telegram Group
    🌐 Source: https://github.com/coolsnowwolf/lede
    👤 Maintainer: https://github.com/BootLoopLover${NC}"
    echo "=======================================================${NC}"
}

# ─── Install Dependencies ───────────────────────────────
install_dependencies_prompt() {
    read -rp "$(echo -e ${YELLOW}🔧 Ingin install dependencies build? (y/n): ${NC})" yn
    case "$yn" in
        [Yy]* )
            if ! grep -qEi 'ubuntu|debian' /etc/*release; then
                echo -e "${RED}❌ Script ini hanya mendukung Debian/Ubuntu.${NC}"
                exit 1
            fi
            echo -e "${YELLOW}🔄 Memeriksa dan menginstall dependencies...${NC}"
            sudo apt-get update
            sudo apt-get install -y \
                build-essential flex bison g++ gawk gcc gettext git \
                libncurses5-dev libz-dev patch python3 \
                rsync subversion unzip zlib1g-dev file wget libssl-dev \
                ccache xsltproc libxml-parser-perl ecj fastjar \
                java-propose-classpath libglib2.0-dev libfuse-dev \
                clang lld llvm libelf-dev device-tree-compiler \
                bc u-boot-tools qemu-utils asciidoc sudo time
            echo -e "${GREEN}✅ Dependencies berhasil diinstall.${NC}"
            ;;
        * )
            echo -e "${BLUE}ℹ️  Lewati instalasi dependencies.${NC}"
            ;;
    esac
}

# ─── Pilih Mode Build ───────────────────────────────────
select_build_mode() {
    echo -e "${YELLOW}📌 Pilih mode build:${NC}"
    echo "1️⃣ Fresh build (clone ulang LEDE)"
    echo "2️⃣ Rebuild dari folder yang sudah ada"
    read -rp "👉 Masukkan pilihan [1-2]: " mode
    case $mode in
        1)
            echo -e "${BLUE}[INFO] 🧼 Melakukan fresh clone dari repo LEDE...${NC}"
            rm -rf "$LEDE_DIR"
            git clone --depth=1 https://github.com/coolsnowwolf/lede "$LEDE_DIR"
            ;;
        2)
            echo -e "${BLUE}[INFO] 🔁 Menggunakan folder build yang sudah ada.${NC}"
            ;;
        *)
            echo -e "${RED}⚠️  Pilihan tidak valid.${NC}"
            exit 1
            ;;
    esac
}

# ─── Masuk Folder LEDE ──────────────────────────────────
run_in_lede_dir() {
    if [ ! -d "$LEDE_DIR" ]; then
        echo -e "${RED}❌ Folder '$LEDE_DIR' tidak ditemukan.${NC}"
        exit 1
    fi
    cd "$LEDE_DIR" || exit 1
}

# ─── Tambah Feeds Tambahan ──────────────────────────────
add_feeds() {
    echo -e "${BLUE}🌱 Pilih feed tambahan:${NC}"
    echo "1) ❌ None"
    echo "2) 🧪 Custom Feed"
    echo "3) 🐘 PHP7 Feed"
    echo "4) 🌐 Both Custom & PHP7"
    echo "========================================================="
    read -p "👉 Pilih [1-4]: " feed_choice
    case "$feed_choice" in
        2) echo "src-git custom https://github.com/BootLoopLover/custom-package" >> feeds.conf.default ;;
        3) echo "src-git php7 https://github.com/BootLoopLover/openwrt-php7-package" >> feeds.conf.default ;;
        4)
            echo "src-git custom https://github.com/BootLoopLover/custom-package" >> feeds.conf.default
            echo "src-git php7 https://github.com/BootLoopLover/openwrt-php7-package" >> feeds.conf.default ;;
    esac
}

# ─── Gunakan Preset Config ──────────────────────────────
use_preset_menu() {
    echo -e "${BLUE}🧩 Gunakan preset konfigurasi?${NC}"
    echo "1) ✅ Ya (private use only)"
    echo "2) ❌ Tidak (manual setup)"
    read -p "👉 Pilih [1-2]: " preset_answer
    if [[ "$preset_answer" == "1" ]]; then
        [[ ! -d "../preset" ]] && {
            echo -e "${BLUE}📥 Cloning preset repository...${NC}"
            git clone "https://github.com/BootLoopLover/preset.git" "../preset" || {
                echo -e "${RED}❌ Gagal clone preset.${NC}"; exit 1;
            }
        }
        echo -e "${BLUE}📂 Daftar preset tersedia:${NC}"
        mapfile -t folders < <(find ../preset -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        for i in "${!folders[@]}"; do
            echo "$((i+1))) ${folders[$i]}"
        done
        read -p "📌 Pilih preset [1-${#folders[@]}]: " preset_choice
        selected_folder="../preset/${folders[$((preset_choice-1))]}"
        cp -rf "$selected_folder"/* ./
        [[ -f "$selected_folder/config-nss" ]] && cp "$selected_folder/config-nss" .config
    else
        [[ ! -f .config ]] && make menuconfig
    fi
}

# ─── Menu Build ──────────────────────────────────────────
build_action_menu() {
    echo -e "\n📋 ${BLUE}Pilih aksi:${NC}"
    echo "1) 🔄 Update feeds only"
    echo "2) 🔄 Update feeds + menuconfig"
    echo "3) 🛠️  Jalankan menuconfig"
    echo "4) 🏗️  Mulai build"
    echo "5) 🔙 Kembali"
    echo "6) ❌ Keluar"
    echo "========================================================="
    read -p "👉 Pilih [1-6]: " choice
    case "$choice" in
        1) ./scripts/feeds update -a && ./scripts/feeds install -a ;;
        2) ./scripts/feeds update -a && ./scripts/feeds install -a; make menuconfig ;;
        3) make menuconfig ;;
        4) return 0 ;;
        5) cd ..; return 1 ;;
        6) echo -e "${GREEN}👋 Keluar.${NC}"; exit 0 ;;
        *) echo -e "${RED}⚠️ Input tidak valid.${NC}" ;;
    esac
    return 1
}

# ─── Build Firmware ─────────────────────────────────────
start_build() {
    echo -e "${GREEN}🚀 Memulai proses build...${NC}"
    start_time=$(date +%s)
    if make -j$(nproc); then
        echo -e "${GREEN}✅ Build berhasil!${NC}"
    else
        echo -e "${RED}⚠️ Build gagal, mencoba ulang dengan verbose...${NC}"
        make -j1 V=s
    fi
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    echo -e "${BLUE}⏱️ Selesai dalam $((elapsed / 60)) menit $((elapsed % 60)) detik.${NC}"
}

# ─── Fresh Build ────────────────────────────────────────
fresh_build() {
    read -p "📁 Masukkan nama folder build (default: openwrt_build): " folder_name
    folder_name="${folder_name:-openwrt_build}"
    mkdir -p "$folder_name" || { echo -e "${RED}❌ Gagal membuat folder.${NC}"; exit 1; }
    cd "$folder_name" || exit 1

    select_distro
    git clone "$git_url" . || { echo -e "${RED}❌ Git clone gagal.${NC}"; exit 1; }
    checkout_tag
    add_feeds
    ./scripts/feeds update -a && ./scripts/feeds install -a
    use_preset_menu
    start_build
}

# ─── Rebuild Mode ───────────────────────────────────────
rebuild_mode() {
    while true; do
        show_banner
        echo -e "📂 ${BLUE}Pilih folder build yang sudah ada:${NC}"
        mapfile -t folders < <(find . -maxdepth 1 -type d \( ! -name . \))
        for i in "${!folders[@]}"; do
            echo "$((i+1))) ${folders[$i]##*/}"
        done
        echo "❌ 0) Keluar"
        read -p "👉 Pilih [0-${#folders[@]}]: " choice
        if [[ "$choice" == 0 ]]; then
            echo -e "${GREEN}👋 Keluar...${NC}"; exit 0
        elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -le "${#folders[@]}" ]]; then
            folder="${folders[$((choice-1))]}"
            cd "$folder" || continue
            while ! build_action_menu; do :; done
            start_build
            break
        else
            echo -e "${RED}⚠️ Pilihan tidak valid.${NC}"
        fi
    done
}

# ─── Main Menu ──────────────────────────────────────────
main_menu() {
    show_banner
    echo "1️⃣ Fresh build (baru)"
    echo "2️⃣ Rebuild existing folder"
    echo "3️⃣ ❌ Exit"
    echo "========================================================="
    read -p "👉 Pilih opsi [1-3]: " main_choice
    case "$main_choice" in
        1) fresh_build ;;
        2) rebuild_mode ;;
        3) echo -e "${GREEN}👋 Keluar...${NC}"; exit 0 ;;
        *) echo -e "${RED}⚠️ Pilihan tidak valid.${NC}"; exit 1 ;;
    esac
}

# === RUN SCRIPT ===
main_menu
