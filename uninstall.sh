#!/usr/bin/env bash
set -e

INSTALL_DIR="$HOME/Reminderd"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# Remove launchd plist on macOS
if [ "$(uname)" = "Darwin" ]; then
    echo "Detected macOS - attempting to unload and remove LaunchAgent if present..."
    PLIST_NAME="reminderd.plist"
    INSTALLED_PLIST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"
    if [ -f "$INSTALLED_PLIST" ]; then
        echo "Unloading LaunchAgent: $INSTALLED_PLIST"
        launchctl unload "$INSTALLED_PLIST" 2>/dev/null || true
        echo "Removing $INSTALLED_PLIST"
        rm -f "$INSTALLED_PLIST"
    else
        echo "No LaunchAgent found at $INSTALLED_PLIST"
    fi

    echo "Removing terminal-notifier is not handled automatically. If you installed it via Homebrew and want to remove it, run: brew uninstall terminal-notifier"
else
    echo "Assuming Linux with systemd user units - attempting to disable and remove units..."
    if [ -d "$SYSTEMD_USER_DIR" ]; then
        for f in reminderd.socket reminderd.service; do
            if [ -f "$SYSTEMD_USER_DIR/$f" ]; then
                echo "Stopping and disabling $f"
                systemctl --user stop "$f" 2>/dev/null || true
                systemctl --user disable "$f" 2>/dev/null || true
                echo "Removing $SYSTEMD_USER_DIR/$f"
                rm -f "$SYSTEMD_USER_DIR/$f"
            fi
        done
        echo "Reloading systemd user daemon"
        systemctl --user daemon-reload 2>/dev/null || true
    else
        echo "No systemd user units found at $SYSTEMD_USER_DIR"
    fi
fi

# Remove PATH line from shell config
SHELL_CONFIG=""
if [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
else
    SHELL_CONFIG="$HOME/.bashrc"
fi

PATH_LINE="export PATH=\"$INSTALL_DIR/src:\$PATH\""
if [ -f "$SHELL_CONFIG" ]; then
    if grep -Fxq "$PATH_LINE" "$SHELL_CONFIG"; then
        echo "Removing Reminderd PATH line from $SHELL_CONFIG"
        # Use a temporary file to remove the exact line
        grep -Fxv "$PATH_LINE" "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp" && mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
    else
        echo "Reminderd PATH line not found in $SHELL_CONFIG"
    fi
else
    echo "Shell config $SHELL_CONFIG not found - skipping PATH removal"
fi

# Optionally remove install directory
read -p "Do you want to remove the installed Reminderd directory at $INSTALL_DIR? [y/N] " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "$INSTALL_DIR" ]; then
        echo "Removing $INSTALL_DIR"
        rm -rf "$INSTALL_DIR"
    else
        echo "$INSTALL_DIR not found"
    fi
else
    echo "Preserving $INSTALL_DIR"
fi

echo "Uninstall complete."
