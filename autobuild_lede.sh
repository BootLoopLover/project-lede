#!/bin/bash
#--------------------------------------------------------
# OpenWrt Rebuild Script - Technical Style with Folder Selection
# Author: Pakalolo Waraso
#--------------------------------------------------------

BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

format_duration() {
	local T=$1
	printf '%02d:%02d:%02d\n' $((T/3600)) $((T%3600/60)) $((T%60))
}

clear
echo "========== Project Lede =========="
echo -e "${BLUE}Firmware Modifications Project${NC}"
echo -e "${BLUE}Github : https://github.com/BootLoopLover${NC}"
echo -e "${BLUE}Telegram : t.me/PakaloloWaras0${NC}"
echo "=================================="

set -e

while true; do
	echo ""
	echo "========== Build Mode =========="
	echo "1. Fresh Build"
	echo "2. Rebuild"
	echo "0. Exit"
	read -rp "Select build mode [0-2]: " BUILD_MODE

	case "$BUILD_MODE" in
		1)
			rm -rf lede
			git clone https://github.com/coolsnowwolf/lede.git
			cd lede

			# === Git Tag Selection ===
			echo -e "${BLUE}Fetching available Git tags...${NC}"
			git fetch --tags
			tags=$(git tag | sort -V)
			if [[ -n "$tags" ]]; then
				echo "========== Available Git Tags =========="
				echo "$tags" | nl
				echo "========================================"
				read -rp "Enter tag number to checkout (leave blank to skip): " tag_number
				if [[ "$tag_number" =~ ^[0-9]+$ ]]; then
					selected_tag=$(echo "$tags" | sed -n "${tag_number}p")
					if [[ -n "$selected_tag" ]]; then
						echo -e "${BLUE}Checking out tag: ${selected_tag}${NC}"
						git checkout "$selected_tag"
					else
						echo -e "${RED}Invalid selection. Skipping tag checkout.${NC}"
					fi
				else
					echo -e "${YELLOW}Skipping tag checkout.${NC}"
				fi
			fi
			break
			;;
		2)
			if [ ! -d lede ]; then
				echo -e "${RED}[ERROR] Folder 'lede' tidak ditemukan.${NC}"
				exit 1
			fi
			cd lede
			break
			;;
		0)
			echo "[INFO] Exiting."
			exit 0
			;;
		*)
			echo "[ERROR] Invalid input."
			;;
	esac
done

echo "[TASK] Applying NAND support patch..."
cp target/linux/qualcommax/patches-6.6/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch \
   target/linux/qualcommax/patches-6.1/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch || true

# === PILIH PRESET CONFIG ===
while true; do
	echo ""
	echo "========== Select Config Preset =========="
	echo "1. Use preset from: BootLoopLover/preset-lede (.config)"
	echo "2. Skip and use default config"
	echo "0. Exit"
	read -rp "Choose option [0-2]: " PRESET_CHOICE

	case "$PRESET_CHOICE" in
		1)
			echo "[TASK] Downloading preset config..."
			wget -O .config https://raw.githubusercontent.com/BootLoopLover/preset-lede/main/.config
			break
			;;
		2)
			echo "[INFO] Using default (empty) config."
			break
			;;
		0)
			echo "[INFO] Exit requested."
			exit 0
			;;
		*)
			echo "[ERROR] Invalid input."
			;;
	esac
done

# Feed configuration
while true; do
	echo ""
	echo "========== Feed Configuration =========="
	echo "1. Add feed: custompackage"
	echo "2. Add feed: php7"
	echo "3. Add both"
	echo "4. Skip"
	echo "0. Exit"
	read -rp "Choose [0-4]: " FEED_CHOICE

	case "$FEED_CHOICE" in
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
			echo "[INFO] Skipping feed modification."
			break
			;;
		0)
			echo "[ABORT] Exit."
			exit 0
			;;
		*)
			echo "[ERROR] Invalid input."
			;;
	esac
done

# Feed update
while true; do
	echo ""
	echo "========== Feed Update =========="
	echo "1. Update and install"
	echo "2. Skip"
	read -rp "Select [1-2]: " FEED_UPDATE_CHOICE

	case "$FEED_UPDATE_CHOICE" in
		1)
			./scripts/feeds update -a
			./scripts/feeds install -a
			break
			;;
		2)
			echo "[INFO] Skipping feed update."
			break
			;;
		*)
			echo "[ERROR] Invalid input."
			;;
	esac
done

# Build Menu
while true; do
	echo ""
	echo "=========== Build Menu ==========="
	echo "1. Run make menuconfig"
	echo "2. Start build directly"
	echo "3. Exit"
	read -rp "Select [1-3]: " BUILD_CHOICE

	case "$BUILD_CHOICE" in
		1)
			make menuconfig
			read -rp "Proceed to build? [y/N]: " CONFIRM_BUILD
			[[ "$CONFIRM_BUILD" =~ ^[Yy]$ ]] || exit 0
			break
			;;
		2)
			break
			;;
		3)
			echo "[INFO] Exiting. You are still in ./lede"
			exit 0
			;;
		*)
			echo "[ERROR] Invalid input."
			;;
	esac
done

# Build firmware
echo "[TASK] Building firmware..."
BUILD_START=$(date +%s)

if ! make -j$(nproc); then
    echo -e "${YELLOW}[WARN] Build failed. Retrying with verbose...${NC}"
    if ! make -j10 V=s; then
        echo -e "${RED}[ERROR] Build failed again. Abort.${NC}"
        exit 1
    fi
fi

BUILD_END=$(date +%s)
echo -e "${GREEN}[DONE] Build completed in: $(format_duration $((BUILD_END - BUILD_START)))${NC}"
