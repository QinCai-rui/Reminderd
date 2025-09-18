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
			# Replace placeholders __HOME__ and __USER__ with expanded paths because launchd will not
			# expand environment variables in plist files. Expand both to ensure ProgramArguments,
			# WorkingDirectory and Std paths are absolute.
			sed "s|__HOME__|$HOME|g; s|__USER__|$USER|g" "$SOURCE_PLIST" > "$TMP_PLIST"
			# Verify the expansion worked (no remaining $HOME or $USER tokens)
			if grep -q "\$HOME\|\$USER" "$TMP_PLIST"; then
				echo "ERROR: Failed to expand \$HOME or \$USER in plist" >&2
				cat "$TMP_PLIST" >&2
				rm -f "$TMP_PLIST"
				exit 1
			fi
			INSTALLED_PLIST="$LAUNCH_AGENTS_DIR/$(basename "$SOURCE_PLIST")"
			# Install to the final filename (not into the directory keeping the temp basename). This
			# avoids leaving temporary-named files like reminderd.plist.qADJiq which break launchctl.
			install -m 644 "$TMP_PLIST" "$INSTALLED_PLIST"
			rm -f "$TMP_PLIST"
			echo "Installed plist with expanded paths to $INSTALLED_PLIST"
		else
			echo "ERROR: launchd/reminderd.plist not found in the repository for some reason" >&2
			exit 1
		fi

		echo "Loading LaunchAgent..."
		launchctl unload "$INSTALLED_PLIST" 2>/dev/null || true
		launchctl load "$INSTALLED_PLIST"
		echo "Reminderd LaunchAgent installed and loaded ($INSTALLED_PLIST)."

		# Quick health check: wait a few seconds and check if socket exists
		echo "Performing health check..."
		sleep 3
		if [ -S "$HOME/.local/share/reminderd/reminderd.sock" ]; then
			echo "✓ Daemon socket found - Reminderd is running!"
		else
			echo "⚠ Daemon socket not found. Check logs at ~/Library/Logs/reminderd.err.log"
			echo "  You may need to run: launchctl unload $INSTALLED_PLIST && launchctl load $INSTALLED_PLIST"
		fi

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
			# Prefer terminal-notifier as the primary method. Instead of invoking it directly, exercise the full
			# pipeline by sending an immediate reminder via reminderctl so the daemon sends notifications using
			# its configured order (terminal-notifier first on macOS).
			CLI_BIN="$INSTALL_DIR/src/reminderctl"
			if [ -x "$CLI_BIN" ]; then
				echo "Sending test reminder via reminderctl (this exercises the daemon and terminal-notifier)..."
				# Add a reminder for now (epoch seconds) so the daemon should pick it up immediately
				NOW_EPOCH=$(date +%s)
				# Use the daemon socket via reminderctl; reminderctl should connect to the user's socket path
				"$CLI_BIN" add "$NOW_EPOCH" "Test notification from Reminderd install" || true
				# Wait briefly for the daemon to process
				sleep 2
				# If terminal-notifier is installed we'll trust the daemon, otherwise show a direct osascript test
				if command -v terminal-notifier >/dev/null 2>&1; then
					echo "terminal-notifier appears installed; reminderctl test sent. Check for visible notification."
				else
					echo "terminal-notifier not found; falling back to osascript notification for manual check."
					osascript -e 'display notification "Testing osascript notifications" with title "Reminderd Setup" sound name "default"' || true
				fi
			else
				echo "reminderctl not executable at $CLI_BIN; falling back to direct terminal-notifier/osascript tests"
				if command -v terminal-notifier >/dev/null 2>&1; then
					echo "Sending direct terminal-notifier test..."
					terminal-notifier -title "Reminderd Setup" -message "Installation complete! Notifications are working." -sound "default" || true
				fi
				echo "Testing osascript notifications..."
				osascript -e 'display notification "Testing osascript notifications" with title "Reminderd Setup" sound name "default"' || true
			fi
				echo ""
				echo "IMPORTANT: If you don't see notifications above, please:"
				echo "1. Open System Settings → Notifications"
				echo "2. Find 'Terminal' or 'terminal-notifier' and enable notifications"
				echo "3. Also find 'Script Editor' and enable notifications for osascript"
				echo ""
				# Open System Settings to Notifications pane to help user enable notifications
				if [[ "$OSTYPE" == "darwin"* ]]; then
					echo "Opening Notification Settings..."
					open "x-apple.systempreferences:com.apple.Notifications-Settings.extension" || true
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