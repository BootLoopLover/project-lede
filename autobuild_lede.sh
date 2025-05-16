#!/bin/bash
#--------------------------------------------------------
# LEDE Firmware Autobuild Script
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

clone_and_copy_preset() {
	local repo_url=$1
	local folder_name=$2

	echo -e "${BLUE}Cloning ${folder_name}...${NC}"
	git clone "$repo_url" "../$folder_name" || {
		echo -e "${RED}Failed to clone ${folder_name}.${NC}"
		return 1
	}

	# Salin folder 'files' dari preset ke direktori build jika ada
	if [ -d "../$folder_name/files" ]; then
		echo "[INFO] Copying 'files' directory from preset..."
		mkdir -p files
		cp -r "../$folder_name/files/"* files/
	fi

	PRESET_LIST=$(find "../$folder_name" -type f -name "*.config")
	if [ -z "$PRESET_LIST" ]; then
		echo -e "${RED}[ERROR] No preset configuration files found in $folder_name.${NC}"
		return 1
	fi

	echo "[AVAILABLE PRESETS]"
	select preset in $PRESET_LIST; do
		if [[ -n "$preset" ]]; then
			cp "$preset" .config
			echo "[INFO] Applied preset: $(basename "$preset")"
			break
		else
			echo "[ERROR] Invalid selection."
		fi
	done
}

clear
echo "========== LEDE Firmware Autobuilder =========="
echo -e "${BLUE}Source: https://github.com/coolsnowwolf/lede${NC}"
echo -e "${BLUE}Maintainer: https://github.com/BootLoopLover${NC}"
echo "================================================"

set -e

# --- Build Mode Selection ---
while true; do
	echo ""
	echo "============ Build Mode Selection =============="
	echo "1. Fresh Build (clean and clone)"
	echo "2. Rebuild (use existing 'lede' directory)"
	echo "0. Exit"
	echo "================================================"
	read -rp "Select option [0-2]: " BUILD_MODE
	case "$BUILD_MODE" in
		1)
			rm -rf lede
			echo "[INFO] Cloning LEDE source..."
			git clone https://github.com/coolsnowwolf/lede.git
			cd lede
			break
			;;
		2)
			if [ ! -d lede ]; then
				echo -e "${RED}[ERROR] Directory 'lede' not found. Cannot proceed with rebuild.${NC}"
				exit 1
			fi
			cd lede
			break
			;;
		0)
			echo "[INFO] Exiting script."
			exit 0
			;;
		*)
			echo "[ERROR] Invalid selection. Please enter a number between 0 and 2."
			;;
	esac
done

# --- Git Tag Selection ---
while true; do
	echo ""
	echo "========= Git Tag Checkout (Optional) =========="
	echo "1. List and checkout available tags"
	echo "2. Skip"
	echo "================================================"
	read -rp "Select option [1-2]: " TAG_OPTION
	case "$TAG_OPTION" in
		1)
			TAGS=$(git tag)
			if [ -z "$TAGS" ]; then
				echo "[INFO] No Git tags found in repository."
				break
			fi
			echo "[AVAILABLE TAGS]"
			select tag in $TAGS; do
				if [ -n "$tag" ]; then
					git checkout "$tag"
					echo "[INFO] Checked out tag: $tag"
					break
				else
					echo "[ERROR] Invalid selection."
				fi
			done
			break
			;;
		2)
			break
			;;
		*)
			echo "[ERROR] Invalid input. Please select 1 or 2."
			;;
	esac
done

# --- Preset Configuration Selection ---
while true; do
	echo ""
	echo "============ Preset Configuration ============="
	echo "1. Clone and use preset from 'preset-lede' repo"
	echo "2. Skip"
	echo "================================================"
	read -rp "Select option [1-2]: " PRESET_OPTION
	case "$PRESET_OPTION" in
		1)
			if clone_and_copy_preset "https://github.com/BootLoopLover/preset-lede.git" "preset-lede"; then
				break
			else
				echo -e "${RED}[ERROR] Failed to apply preset.${NC}"
				exit 1
			fi
			;;
		2)
			echo "[INFO] Preset selection skipped."
			break
			;;
		*)
			echo "[ERROR] Invalid input."
			;;
	esac
done

# --- Feed Configuration ---
while true; do
	echo ""
	echo "============= Feed Configuration ==============="
	echo "1. Add feed: custompackage"
	echo "2. Add feed: php7"
	echo "3. Add both feeds"
	echo "4. Skip"
	echo "================================================"
	read -rp "Select option [1-4]: " FEED_OPTION
	case "$FEED_OPTION" in
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
			break
			;;
		*)
			echo "[ERROR] Invalid selection."
			;;
	esac
done

# --- Feeds Update ---
while true; do
	echo ""
	echo "================ Feed Update ==================="
	echo "1. Run 'feeds update' and 'feeds install'"
	echo "2. Skip"
	echo "================================================"
	read -rp "Select option [1-2]: " FEED_UPDATE
	case "$FEED_UPDATE" in
		1)
			./scripts/feeds update -a
			./scripts/feeds install -a
			break
			;;
		2)
			break
			;;
		*)
			echo "[ERROR] Invalid selection."
			;;
	esac
done

# --- Build Menu ---
while true; do
	echo ""
	echo "================== Build Menu =================="
	echo "1. Run 'make menuconfig'"
	echo "2. Start build immediately"
	echo "3. Exit"
	echo "================================================"
	read -rp "Select option [1-3]: " BUILD_CHOICE
	case "$BUILD_CHOICE" in
		1)
			make menuconfig
			read -rp "Proceed to build? [y/N]: " CONFIRM
			[[ "$CONFIRM" =~ ^[Yy]$ ]] && break || exit 0
			;;
		2)
			break
			;;
		3)
			exit 0
			;;
		*)
			echo "[ERROR] Invalid input."
			;;
	esac
done

# --- Build Process ---
echo "[TASK] Starting build process..."
BUILD_START=$(date +%s)

if ! make -j$(nproc); then
	echo -e "${YELLOW}[WARNING] Build failed. Retrying with verbose output...${NC}"
	if ! make -j$(nproc) V=s; then
		echo -e "${RED}[ERROR] Build failed again. Aborting.${NC}"
		exit 1
	fi
fi

BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))
echo -e "${GREEN}[SUCCESS] Build completed in: $(format_duration $BUILD_DURATION)${NC}"
