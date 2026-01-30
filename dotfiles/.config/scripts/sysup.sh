#!/bin/bash

# ==============================================================================
# sysup - Arch Linux System Update Utility
# Description: Checks Arch news, updates keyrings first, then runs yay/paru.
# ==============================================================================

# 1. Check AUR Helper
UPDATE_CMD=""
if command -v yay >/dev/null 2>&1; then
    UPDATE_CMD="yay"
elif command -v paru >/dev/null 2>&1; then
    UPDATE_CMD="paru"
else
    printf "\n\033[1;31m!!! Error: No AUR helper found (yay/paru) !!!\033[0m\n"
    exit 1
fi

# 2. Configuration (English Only)
NEWS_URL="https://archlinux.org/feeds/news/"
MSG_PREPARING="==> Preparing to update system with $UPDATE_CMD..."
MSG_FETCHING="==> Fetching latest Arch Linux news..."
MSG_CONFIRM="Read above. Proceed with $UPDATE_CMD? [Y/n] "
MSG_EXECUTING="==> Executing $UPDATE_CMD..."
MSG_CANCEL="==> Update cancelled."
MSG_ERR_FETCH="!!! WARNING: Failed to fetch news (Network/Source error) !!!"
MSG_FORCE_ASK="Force update ignoring news? [y/N] "
MSG_FORCING="==> Forcing update..."
MSG_EXIT="==> Safe exit."
PY_HEADER=">>> Recent {} Arch Linux news items:"

# 3. Set Display Limit (Default 15, or use $1)
COUNT_LIMIT=15
if [ -n "$1" ]; then
    COUNT_LIMIT="$1"
fi

# 4. Execution Logic
printf "\n\033[1;36m%s\033[0m\n" "$MSG_PREPARING"
printf "\033[1;36m%s\033[0m\n" "$MSG_FETCHING"

# Embedded Python Script
PYTHON_SCRIPT=$(cat <<'EOF'
import sys
import xml.etree.ElementTree as ET

try:
    limit = int(sys.argv[1])
    header_template = sys.argv[2]
    
    # Force UTF-8 reading
    sys.stdin.reconfigure(encoding='utf-8')
    raw_data = sys.stdin.read()
    
    if not raw_data.strip():
        sys.exit(1)

    root = ET.fromstring(raw_data)
    items = root.findall('./channel/item')[:limit]

    print(f'\n\033[1;33m{header_template.format(len(items))}\033[0m\n')

    for item in items:
        title = item.find('title').text
        pub_date = item.find('pubDate').text
        date_str = pub_date[:16]

        check_text = title.lower()
        # Highlight 'intervention' or 'manual'
        if any(x in check_text for x in ['intervention', 'manual']):
            color = '\033[1;31m' # Red
            prefix = '!!! '
        else:
            color = '\033[1;32m' # Green
            prefix = ''
        
        print(f'{color}[{date_str}] {prefix}{title}\033[0m')

except Exception as e:
    sys.stderr.write(f'\nParse Error: {e}\n')
    sys.exit(1)
EOF
)

# Fetch news and pipe to python
if curl -sS -L --connect-timeout 15 -A "Mozilla/5.0" "$NEWS_URL" | python -c "$PYTHON_SCRIPT" "$COUNT_LIMIT" "$PY_HEADER"; then
    
    # === A. Success Branch ===
    printf "\n"
    printf "%s" "$MSG_CONFIRM"
    read -r confirm
    
    case "$confirm" in
        [Yy]*|"" )
            # --- Step 1: Sync DB & Keyring ---
            printf "\n\033[1;34m==> [Step 1/3] Syncing DB & Updating keyrings...\033[0m\n"
            KEYRING_TARGETS="archlinux-keyring"
            
            # Check if archlinuxcn-keyring is installed
            if pacman -Qq archlinuxcn-keyring >/dev/null 2>&1; then
                KEYRING_TARGETS="$KEYRING_TARGETS archlinuxcn-keyring"
            fi
            
            # -Sy: Sync DB. --needed: Only reinstall if newer. --noconfirm: Automated.
            if sudo pacman -Sy --needed --noconfirm $KEYRING_TARGETS; then
                printf "\033[1;32m==> Keyrings & DB synced.\033[0m\n"
            else
                printf "\033[1;31m!!! Warning: Keyring update encountered issues. Proceeding...\033[0m\n"
            fi
            
            # --- Step 2: System Update (Optimized) ---
            printf "\n\033[1;36m==> [Step 2/3] Upgrading system...\033[0m\n"
            # 使用 -Su 而不是默认的 -Syu，因为第一步已经 -Sy 过了
            $UPDATE_CMD -Su

            # --- Step 3: Flatpak Update ---
            if command -v flatpak >/dev/null 2>&1; then
                printf "\n\033[1;35m==> [Step 3/3] Checking Flatpak updates...\033[0m\n"
                flatpak update
            fi
            ;;
        * )
            printf "\n\033[1;33m%s\033[0m\n" "$MSG_CANCEL"
            exit 0
            ;;
    esac

else
    # === B. Failure Branch ===
    printf "\n\033[1;31m%s\033[0m\n" "$MSG_ERR_FETCH"
    
    printf "%s" "$MSG_FORCE_ASK"
    read -r force_confirm
    
    case "$force_confirm" in
        [Yy]* )
            # --- Step 1: Sync DB & Keyring ---
            printf "\n\033[1;34m==> Checking/Updating keyrings first...\033[0m\n"
            KEYRING_TARGETS="archlinux-keyring"
            
            if pacman -Qq archlinuxcn-keyring >/dev/null 2>&1; then
                KEYRING_TARGETS="$KEYRING_TARGETS archlinuxcn-keyring"
            fi
            
            if sudo pacman -Sy --needed --noconfirm $KEYRING_TARGETS; then
                printf "\033[1;32m==> Keyrings verified.\033[0m\n"
            else
                printf "\033[1;31m!!! Warning: Keyring update encountered issues. Proceeding...\033[0m\n"
            fi
            
            # --- Step 2: System Update (Optimized) ---
            printf "\n\033[1;31m%s\033[0m\n" "$MSG_FORCING"
            $UPDATE_CMD -Su

            # --- Step 3: Flatpak Update ---
            if command -v flatpak >/dev/null 2>&1; then
                printf "\n\033[1;35m==> Checking Flatpak updates...\033[0m\n"
                flatpak update
            fi
            ;;
        * )
            printf "\n\033[1;33m%s\033[0m\n" "$MSG_EXIT"
            exit 1
            ;;
    esac
fi
