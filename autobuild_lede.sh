#!/bin/bash

# universal_builder.sh - Skrip builder profesional LEDE/OpenWrt/ImmortalWrt
# Versi: Final Profesional

# Warna terminal
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

show_banner() {
    clear
    message="🚀 Launching LEDE Firmware Builder by Pakalolo Waraso..."
    for ((i=0; i<${#message}; i++)); do
        echo -ne "${YELLOW}${message:$i:1}${NC}"
        sleep 0.01
    done
    echo -e "\n"
    for _ in {1..60}; do echo -ne "${BLUE}=${NC}"; sleep 0.005; done
    echo -e "\n"
    echo -e "${BLUE}"
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
  LEDE Firmware Builder
EOF
    echo -e "${NC}"
    for _ in {1..60}; do echo -ne "${BLUE}-${NC}"; sleep 0.005; done
    echo -e "\n"
    echo "========================================================="
    echo -e "📦 ${BLUE}LEDE Firmware Builder${NC}"
    echo "========================================================="
    echo -e "👤 ${BLUE}Author   : Pakalolo Waraso${NC}"
    echo -e "🌐 ${BLUE}GitHub   : https://github.com/BootLoopLover${NC}"
    echo -e "💬 ${BLUE}Telegram : t.me/PakaloloWaras0${NC}"
    echo "========================================================="
}

check_dependencies() {
    read -p "Memeriksa dan menginstal dependencies...(y/n): " jawab
    [[ "$jawab" == "y" ]] || return
    sudo apt-get update
    sudo apt-get install -y build-essential clang flex bison g++ gawk \
        gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
        python3-distutils rsync unzip zlib1g-dev file wget python3
}

select_mode() {
    echo "Pilih mode build:"
    echo "1. Fresh Build"
    echo "2. Rebuild"
    read -p "Pilihan (1/2): " build_mode
}

select_distro() {
    echo "Pilih distro:"
    echo "1. Lede"
    read -p "Pilihan (1): " distro_option
    case "$distro_option" in
        1) repo="https://github.com/coolsnowwolf/lede.git" ;;
        *) echo "Pilihan tidak valid."; exit 1 ;;
    esac
}

clone_repo() {
    read -p "Masukkan nama folder build: " folder
    git clone "$repo" "$folder" || { echo "Gagal clone repo."; exit 1; }
    cd "$folder" || exit 1
}

checkout_tag() {
    read -p "Ingin checkout ke tag tertentu? (y/n): " tag_choice
    if [[ $tag_choice == "y" ]]; then
        git fetch --tags
        echo "Daftar tag tersedia:"
        git tag
        read -p "Masukkan nama tag: " git_tag
        git checkout "$git_tag" || { echo "Tag tidak ditemukan."; exit 1; }
    fi
}

copy_patch_nand() {
    echo "[*] Menyalin patch NAND dari 6.6 ke 6.1..."
    PATCH_SRC="target/linux/qualcommax/patches-6.6/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch"
    PATCH_DEST="target/linux/qualcommax/patches-6.1/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch"
    if [[ -f "$PATCH_SRC" ]]; then
        cp "$PATCH_SRC" "$PATCH_DEST"
        echo "✅ Patch berhasil disalin."
    else
        echo "⚠️ Patch sumber tidak ditemukan: $PATCH_SRC"
    fi
}

select_preset() {
    echo -e "${BLUE}Use preset configuration files?${NC}"
    echo "1) ✅ Yes (private use only)"
    echo "2) ❌ No (manual setup)"
    read -rp "📌 Choice [1-2]: " preset_answer

    if [[ "$preset_answer" == "1" ]]; then
        if [[ ! -d "../preset" ]]; then
            echo -e "${BLUE}Cloning preset repository...${NC}"
            git clone "https://github.com/BootLoopLover/preset.git" "../preset" || {
                echo -e "${RED}❌ Failed to clone preset.${NC}"
                exit 1
            }
        fi

        echo -e "${BLUE}Available presets:${NC}"
        mapfile -t folders < <(find ../preset -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        if [[ ${#folders[@]} -eq 0 ]]; then
            echo -e "${RED}❌ No preset folders found.${NC}"
            return
        fi
        for i in "${!folders[@]}"; do
            echo "$((i+1))) ${folders[$i]}"
        done
        read -rp "🔢 Select preset folder [1-${#folders[@]}]: " preset_choice
        if [[ "$preset_choice" =~ ^[0-9]+$ && "$preset_choice" -ge 1 && "$preset_choice" -le ${#folders[@]} ]]; then
            selected_folder="../preset/${folders[$((preset_choice-1))]}"
            cp -rf "$selected_folder"/* ./
            if [[ -f "$selected_folder/config-nss" ]]; then
                cp "$selected_folder/config-nss" .config
            fi
        else
            echo -e "${RED}⚠️ Invalid preset selection.${NC}"
        fi
    else
        [[ ! -f .config ]] && echo -e "${YELLOW}⚠️ No .config file found, you'll need to create one manually later.${NC}"
    fi
}

add_optional_feeds() {
    echo -e "${BLUE}Select additional feeds to include:${NC}"
    echo "1) ❌ None"
    echo "2) 🧪 Custom Feed"
    echo "3) 🐘 PHP7 Feed"
    echo "4) 🌐 Both Custom & PHP7"
    echo "========================================================="
    read -rp "🔢 Select feed option [1-4]: " feed_choice
    case "$feed_choice" in
        2)
            echo "src-git custom https://github.com/BootLoopLover/custom-package" >> feeds.conf.default
            ;;
        3)
            echo "src-git php7 https://github.com/BootLoopLover/openwrt-php7-package" >> feeds.conf.default
            ;;
        4)
            echo "src-git custom https://github.com/BootLoopLover/custom-package" >> feeds.conf.default
            echo "src-git php7 https://github.com/BootLoopLover/openwrt-php7-package" >> feeds.conf.default
            ;;
        *)
            echo "No additional feeds added."
            ;;
    esac
}

update_feeds() {
    echo "[*] Update dan install feeds..."
    ./scripts/feeds update -a
    ./scripts/feeds install -a
}

menuconfig_prompt() {
    read -p "Ingin masuk menuconfig? (y/n): " config_menu
    [[ $config_menu == "y" ]] && make menuconfig
}

build_firmware() {
    echo "[*] Mulai proses build..."
    START=$(date +%s)
    make -j$(nproc) || make -j1 V=s
    END=$(date +%s)
    DURATION=$((END - START))
    echo "Build selesai dalam $((DURATION / 60)) menit $((DURATION % 60)) detik."
}

# ===========================
# Eksekusi utama skrip
# ===========================

show_banner
select_mode

if [[ $build_mode == 1 ]]; then
    check_dependencies
    select_distro
    clone_repo
    checkout_tag
    copy_patch_nand
    select_preset
    add_optional_feeds
    update_feeds
    menuconfig_prompt
    build_firmware
elif [[ $build_mode == 2 ]]; then
    read -p "Masukkan path ke folder build: " folder
    cd "$folder" || { echo "Folder tidak ditemukan!"; exit 1; }
    add_optional_feeds
    update_feeds
    menuconfig_prompt
    build_firmware
else
    echo "Pilihan tidak valid. Keluar."
    exit 1
fi
