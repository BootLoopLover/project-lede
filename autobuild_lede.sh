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

#---------- Timer ----------
start_timer() {
  START_TIME=$(date +%s)
}

end_timer() {
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  echo -e "\n${GREEN}Build selesai dalam $((DURATION / 60)) menit $((DURATION % 60)) detik.${NC}"
}

#---------- Retry Build ----------
retry_make() {
  make -j"$(nproc)" || make -j1 V=s
}

#---------- Pilih Distro ----------
select_distro() {
  echo -e "\nPilih distro:"
  select DISTRO in "lede"; do
    case $DISTRO in
      lede)
        GIT_URL="https://github.com/coolsnowwolf/lede"
        break ;;
      *) echo "Pilihan tidak valid!" ;;
    esac
  done
}

#---------- Clone Repo ----------
clone_repo() {
  echo -e "\nMasukkan nama folder build (contoh: build-openwrt):"
  read -p "Folder: " FOLDER
  git clone "$GIT_URL" "$FOLDER"
  cd "$FOLDER" || exit

  echo -e "\nIngin checkout tag/branch tertentu? (y/n)"
  read -p "> " CHOICE
  if [[ $CHOICE =~ [Yy] ]]; then
    git fetch --all
    echo -e "\nMasukkan nama tag/branch:"
    read -p "Tag/Branch: " TAG
    git checkout "$TAG"
  fi
}

#---------- Feed Tambahan ----------
add_extra_feeds() {
  echo -e "${BLUE}Pilih feed tambahan:${NC}"
  echo "1) ❌ Tidak ada"
  echo "2) 🧪 Custom Feed"
  echo "3) 🐘 PHP7 Feed"
  echo "4) 🌐 Keduanya (Custom & PHP7)"
  echo "========================================================="
  read -p "🔢 Pilihan [1-4]: " feed_choice
  case "$feed_choice" in
    2) echo "src-git custom https://github.com/BootLoopLover/custom-package" >> feeds.conf.default ;;
    3) echo "src-git php7 https://github.com/BootLoopLover/openwrt-php7-package" >> feeds.conf.default ;;
    4)
      echo "src-git custom https://github.com/BootLoopLover/custom-package" >> feeds.conf.default
      echo "src-git php7 https://github.com/BootLoopLover/openwrt-php7-package" >> feeds.conf.default ;;
  esac
}

#---------- Update Feed ----------
update_feeds() {
  echo -e "\nUpdate dan install feeds sekarang? (y/n)"
  read -p "> " FEED_CHOICE
  if [[ $FEED_CHOICE =~ [Yy] ]]; then
    ./scripts/feeds update -a
    ./scripts/feeds install -f -a
  fi
}

#---------- Gunakan Preset Config ----------
use_preset_menu() {
  echo -e "${BLUE}Gunakan preset konfigurasi?${NC}"
  echo "1) ✅ Ya (private use only)"
  echo "2) ❌ Tidak (manual setup)"
  read -p "📌 Pilihan [1-2]: " preset_answer

  if [[ "$preset_answer" == "1" ]]; then
    [[ ! -d "../preset" ]] && {
      echo -e "${BLUE}Cloning preset repository...${NC}"
      git clone "https://github.com/BootLoopLover/preset.git" "../preset" || {
        echo -e "${RED}❌ Gagal clone preset.${NC}"; exit 1;
      }
    }

    echo -e "${BLUE}Daftar preset yang tersedia:${NC}"
    mapfile -t folders < <(find ../preset -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
    for i in "${!folders[@]}"; do
      echo "$((i + 1))) ${folders[$i]}"
    done
    read -p "🔢 Pilih folder preset [1-${#folders[@]}]: " preset_choice
    selected_folder="../preset/${folders[$((preset_choice - 1))]}"
    cp -rf "$selected_folder"/* ./
    [[ -f "$selected_folder/config-nss" ]] && cp "$selected_folder/config-nss" .config
  else
    [[ ! -f .config ]] && make menuconfig
  fi
}

#---------- Menu Build ----------
build_menu() {
  echo -e "\n📋 ${BLUE}Pilih aksi:${NC}"
  echo "1) 🔄 Update feeds saja"
  echo "2) 🔄 Update feeds + menuconfig"
  echo "3) 🛠️  Jalankan menuconfig saja"
  echo "4) 🏗️  Mulai build"
  echo "5) 🔙 Kembali"
  echo "6) ❌ Keluar"
  echo "========================================================="
  read -p "📌 Pilihan [1-6]: " choice
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

#=========================#
#        MAIN SCRIPT      #
#=========================#

branding
echo -e "Pilih mode build:"
select MODE in "Fresh Build" "Rebuild"; do
  case $MODE in
    "Fresh Build")
      select_distro
      clone_repo
      add_extra_feeds
      update_feeds
      use_preset_menu
      while ! build_menu; do :; done
      start_timer
      retry_make
      end_timer
      break ;;
    "Rebuild")
      echo -e "\nMasukkan path folder build:"
      read -p "Path: " BUILD_PATH
      cd "$BUILD_PATH" || exit
      update_feeds
      while ! build_menu; do :; done
      start_timer
      retry_make
      end_timer
      break ;;
    *) echo "Pilihan tidak valid!" ;;
  esac
done
