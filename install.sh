#!/bin/bash
set -e

REPO_URL="https://github.com/QinCai-rui/Reminderd.git"
INSTALL_DIR="$HOME/Reminderd"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

if [ ! -d "$INSTALL_DIR" ]; then
	echo "Cloning Reminderd repo to $INSTALL_DIR..."
	git clone "$REPO_URL" "$INSTALL_DIR"
else
	echo "Repo already exists at $INSTALL_DIR. Skipping clone."
	echo "If you want to update the daemon & CLI, just do: cd $INSTALL_DIR && git pull."
fi

echo "Making scripts executable..."
chmod +x "$INSTALL_DIR"/src/*
echo "Installing service for this platform..."
if [ "$(uname)" = "Darwin" ]; then
		echo "Detected macOS - installing LaunchAgent..."
		mkdir -p "$LAUNCH_AGENTS_DIR"
		# install plist from repo
		SOURCE_PLIST="$INSTALL_DIR/launchd/reminderd.plist"
		if [ -f "$SOURCE_PLIST" ]; then
			# Expand $HOME in the plist because launchd will not expand env vars in plist files.
			# Create a temporary plist with absolute paths and install that.
			TMP_PLIST=$(mktemp /tmp/reminderd.plist.XXXXXX)
			# Replace literal "$HOME" occurrences with the expanded path.
			sed "s|\$HOME|$HOME|g" "$SOURCE_PLIST" > "$TMP_PLIST"
			install -m 644 "$TMP_PLIST" "$LAUNCH_AGENTS_DIR/"
			INSTALLED_PLIST="$LAUNCH_AGENTS_DIR/$(basename "$SOURCE_PLIST")"
			rm -f "$TMP_PLIST"
		else
			echo "ERROR: launchd/reminderd.plist not found in the repository for some reason" >&2
			exit 1
		fi

		echo "Loading LaunchAgent..."
		launchctl unload "$INSTALLED_PLIST" 2>/dev/null || true
		launchctl load "$INSTALLED_PLIST"
		echo "Reminderd LaunchAgent installed and loaded ($INSTALLED_PLIST)."

		# macOS: ensure terminal-notifier is installed for better notifications
		# If Homebrew is present, use it to install terminal-notifier. Otherwise, inform the user.
		if command -v brew >/dev/null 2>&1; then
			if ! command -v terminal-notifier >/dev/null 2>&1; then
				echo "Installing terminal-notifier via Homebrew..."
				brew install terminal-notifier || true
			else
				echo "terminal-notifier already installed"
			fi
			# Try a test notification to prompt macOS notification permission if needed
			if command -v terminal-notifier >/dev/null 2>&1; then
				echo "Sending test notification via terminal-notifier..."
				terminal-notifier -title "Reminderd" -message "This is a test notification from Reminderd" || true
				# Open System Settings to Notifications pane to help user enable notifications
				if [[ "$OSTYPE" == "darwin"* ]]; then
					# macOS Ventura+ uses 'open' to System Settings; this will open Notifications settings
					open "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
				fi
			else
				echo "terminal-notifier not available after attempted install. You may need to install it manually: brew install terminal-notifier"
			fi
		else
			echo "Homebrew not found. To get native macOS notifications install Homebrew (https://brew.sh/) and run: brew install terminal-notifier"
		fi
else
		echo "Assuming Linux with systemd user units..."
		echo "Copying systemd user units..."
		mkdir -p "$SYSTEMD_USER_DIR"
		install -m 644 "$INSTALL_DIR"/systemd/reminderd.socket "$SYSTEMD_USER_DIR/"
		install -m 644 "$INSTALL_DIR"/systemd/reminderd.service "$SYSTEMD_USER_DIR/"

		echo "Reloading and enabling reminderd.socket (user)..."
		systemctl --user daemon-reload # this might not be needed, but just in case
		systemctl --user enable --now reminderd.socket

		echo "Reminderd user-level installation complete."
fi

# Add Reminderd CLI to shell config
SHELL_CONFIG=""
if [ -n "$ZSH_VERSION" ]; then
	SHELL_CONFIG="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
	SHELL_CONFIG="$HOME/.bashrc"
else
	# Default to `.bashrc` if shell is unknown
	SHELL_CONFIG="$HOME/.bashrc"
fi

PATH_LINE="export PATH=\"$INSTALL_DIR/src:\$PATH\""
if ! grep -Fxq "$PATH_LINE" "$SHELL_CONFIG"; then
	if [ -w "$SHELL_CONFIG" ]; then
		echo "$PATH_LINE" >> "$SHELL_CONFIG"
		echo "Added Reminderd CLI to $SHELL_CONFIG."
	else
		echo "ERROR: Cannot write to $SHELL_CONFIG. Please add the following line manually:" >&2 # print to stderr
		echo "$PATH_LINE" >&2 # print to stderr
	fi
else
	echo "Reminderd CLI path already present in $SHELL_CONFIG."
fi

echo "Reminderd user-level installation complete. Please restart your shell or run:"
echo "  source $SHELL_CONFIG"