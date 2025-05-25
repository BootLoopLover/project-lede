
#!/bin/bash
#--------------------------------------------------------
# 🚀 LEDE Builder - Professional Version
# 👨‍💻 Author: Pakalolo Waraso (BootLoopLover)
#--------------------------------------------------------

BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

REPO_URL="https://github.com/coolsnowwolf/lede"

show_banner() {
    clear
    message="🚀 Launching LEDE Firmware Builder by Pakalolo Waraso..."
    for ((i=0; i<${#message}; i++)); do
        echo -ne "${YELLOW}${message:$i:1}${NC}"
        sleep 0.01
    done
    echo -e "\n"
    for _ in {1..60}; do
        echo -ne "${BLUE}=${NC}"
        sleep 0.005
    done
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
    for _ in {1..60}; do
        echo -ne "${BLUE}-${NC}"
        sleep 0.005
    done
    echo -e "\n"
    echo "========================================================="
    echo -e "📦 ${BLUE}LEDE Firmware Builder${NC}"
    echo "========================================================="
    echo -e "👤 ${BLUE}Author   : Pakalolo Waraso${NC}"
    echo -e "🌐 ${BLUE}GitHub   : https://github.com/BootLoopLover${NC}"
    echo -e "💬 ${BLUE}Telegram : t.me/PakaloloWaras0${NC}"
    echo "========================================================="
}

checkout_tag() {
    echo -e "${YELLOW}Fetching git tags...${NC}"
    mapfile -t tag_list < <(git tag -l | sort -Vr)
    if [[ ${#tag_list[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️ No tags found. Using default branch.${NC}"
    else
        for i in "${!tag_list[@]}"; do
            echo "$((i+1))) ${tag_list[$i]}"
        done
        read -rp "🔖 Select tag to checkout [1-${#tag_list[@]}] or press Enter to skip: " tag_index
        if [[ -n "$tag_index" && "$tag_index" =~ ^[0-9]+$ && "$tag_index" -ge 1 && "$tag_index" -le ${#tag_list[@]} ]]; then
            git checkout "${tag_list[$((tag_index-1))]}" || {
                echo -e "${RED}❌ Failed to checkout tag.${NC}"
                exit 1
            }
        fi
    fi
}

add_feeds() {
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

use_preset_menu() {
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
        # Jika pilih manual, pastikan .config ada atau user akan buat sendiri nanti
        [[ ! -f .config ]] && echo -e "${YELLOW}⚠️ No .config file found, you'll need to create one manually later.${NC}"
    fi
}

build_action_menu() {
    echo -e "\n📋 ${BLUE}Select action:${NC}"
    echo "1) 🔄 Update feeds only"
    echo "2) 🔄 Update feeds + menuconfig"
    echo "3) 🛠️  Run menuconfig only"
    echo "4) 🏗️  Proceed to build"
    echo "5) 🔙 Back"
    echo "6) ❌ Exit"
    echo "========================================================="
    read -rp "📌 Choice [1-6]: " choice
    case "$choice" in
        1)
            ./scripts/feeds update -a && ./scripts/feeds install -f -a
            ;;
        2)
            ./scripts/feeds update -a && ./scripts/feeds install -f -a
            make menuconfig
            ;;
        3)
            make menuconfig
            ;;
        4)
            return 0
            ;;
        5)
            return 1
            ;;
        6)
            echo -e "${GREEN}👋 Exit.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}⚠️ Invalid input.${NC}"
            ;;
    esac
    return 1
}

fresh_build() {
    read -rp "📁 Enter build folder name (default: lede_build): " folder_name
    folder_name="${folder_name:-lede_build}"
    mkdir -p "$folder_name" || { echo -e "${RED}❌ Failed to create folder.${NC}"; exit 1; }
    cd "$folder_name" || exit 1

    echo -e "${BLUE}Cloning LEDE repository...${NC}"
    git clone "$REPO_URL" . || { echo -e "${RED}❌ Git clone failed.${NC}"; exit 1; }

    checkout_tag
    add_feeds
    use_preset_menu

    echo -e "${BLUE}Updating and installing feeds...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a

    start_build
}

rebuild_mode() {
    while true; do
        show_banner
        echo -e "📂 ${BLUE}Select existing build folder:${NC}"
        mapfile -t folders < <(find . -maxdepth 1 -type d \( ! -name . \) -printf '%f\n')
        if [[ ${#folders[@]} -eq 0 ]]; then
            echo -e "${RED}❌ No build folders found in current directory.${NC}"
            exit 1
        fi
        for i in "${!folders[@]}"; do
            echo "$((i+1))) ${folders[$i]}"
        done
        echo "0) ❌ Exit"
        read -rp "📌 Choice [0-${#folders[@]}]: " choice

        if [[ "$choice" == "0" ]]; then
            echo -e "${GREEN}👋 Exiting...${NC}"; exit 0
        elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le ${#folders[@]} ]]; then
            folder="${folders[$((choice-1))]}"
            cd "$folder" || continue
            while ! build_action_menu; do :; done
            start_build
            break
        else
            echo -e "${RED}⚠️ Invalid choice. Try again.${NC}"
        fi
    done
}

main_menu() {
    while true; do
        show_banner
        echo "1️⃣ Fresh build (baru)"
        echo "2️⃣ Rebuild existing folder"
        echo "3️⃣ ❌ Exit"
        echo "========================================================="
        read -rp "📌 Select option [1-3]: " main_choice
        case "$main_choice" in
            1) fresh_build; break ;;
            2) rebuild_mode; break ;;
            3) echo -e "${GREEN}👋 Exiting...${NC}"; exit 0 ;;
            *) echo -e "${RED}⚠️ Invalid choice.${NC}" ;;
        esac
    done
}

# === Run ===
main_menu
