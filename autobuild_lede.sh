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

# === Utility: Format durasi dalam hh:mm:ss ===
format_duration() {
	local T=$1
	printf '%02d:%02d:%02d\n' $((T/3600)) $((T%3600/60)) $((T%60))
}

clear
echo -e "${BLUE}Project Lede${NC}"
echo "--------------------------------------------------------"
echo -e "${BLUE}Firmware Modifications Project${NC}"
echo -e "${BLUE}Github : https://github.com/BootLoopLover${NC}"
echo -e "${BLUE}Telegram : t.me/PakaloloWaras0${NC}"

set -e

echo "[TASK] Cloning LEDE source repository..."
git clone https://github.com/coolsnowwolf/lede.git
cd lede

echo "[TASK] Applying NAND support patch..."
cp target/linux/qualcommax/patches-6.6/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch \
   target/linux/qualcommax/patches-6.1/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch || true

# Feed configuration menu
while true; do
	echo ""
	echo "========== Feed Configuration =========="
	echo "1. Add feed: custompackage"
	echo "2. Add feed: php7"
	echo "3. Add both feeds"
	echo "4. Skip feed modification"
	echo "0. Abort and exit"
	echo "========================================"
	read -rp "Select option [0-4]: " FEED_CHOICE

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
			echo "[ABORT] Process aborted by user."
			exit 0
			;;
		*)
			echo "[ERROR] Invalid input. Please enter a number between 0 and 4."
			;;
	esac
done

# Feed update menu
while true; do
	echo ""
	echo "========== Feed Update =========="
	echo "1. Run feeds update and install"
	echo "2. Skip feeds update/install"
	echo "=================================="
	read -rp "Select option [1-2]: " FEED_UPDATE_CHOICE

	case "$FEED_UPDATE_CHOICE" in
		1)
			echo "[TASK] Running feeds update and install..."
			./scripts/feeds update -a
			./scripts/feeds install -a
			break
			;;
		2)
			echo "[INFO] Skipping feeds update and install."
			break
			;;
		*)
			echo "[ERROR] Invalid input. Please enter 1 or 2."
			;;
	esac
done

# Build menu
while true; do
	echo ""
	echo "=========== Build Menu ==========="
	echo "1. Run make menuconfig"
	echo "2. Start build directly"
	echo "3. Exit without building"
	echo "=================================="
	read -rp "Select option [1-3]: " BUILD_CHOICE

	case "$BUILD_CHOICE" in
		1)
			echo "[TASK] Starting build configuration (make menuconfig)..."
			make menuconfig
			read -rp "Proceed to build? [y/N]: " CONFIRM_BUILD
			if [[ "$CONFIRM_BUILD" =~ ^[Yy]$ ]]; then
				break
			else
				echo "[INFO] Build cancelled by user."
				exit 0
			fi
			;;
		2)
			break
			;;
		3)
			echo "[INFO] Exiting. You are still inside the 'lede' directory."
			exit 0
			;;
		*)
			echo "[ERROR] Invalid input. Please enter a number between 1 and 3."
			;;
	esac
done

# === Start Build with Retry on Failure ===
echo "[TASK] Starting firmware build..."
BUILD_START=$(date +%s)

if ! make -j$(nproc); then
    echo -e "${YELLOW}[WARN] Initial build failed. Retrying with verbose output (make -j10 V=s)...${NC}"
    if ! make -j10 V=s; then
        echo -e "${RED}[ERROR] Build failed again with verbose output. Aborting.${NC}"
        exit 1
    fi
fi

BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

echo ""
echo -e "${GREEN}[DONE] Build completed in: $(format_duration $BUILD_DURATION)${NC}"
