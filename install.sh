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
	echo "If you want to update the daemon & CLI, just do `cd $INSTALL_DIR && git pull`."
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
			install -m 644 "$SOURCE_PLIST" "$LAUNCH_AGENTS_DIR/"
			INSTALLED_PLIST="$LAUNCH_AGENTS_DIR/$(basename "$SOURCE_PLIST")"
		else
			echo "ERROR: launchd/reminderd.plist not found in the repository for some reason" >&2
			exit 1
		fi

		echo "Loading LaunchAgent..."
		echo "Loading LaunchAgent..."
		launchctl unload "$INSTALLED_PLIST" 2>/dev/null || true
		launchctl load "$INSTALLED_PLIST"
		echo "Reminderd LaunchAgent installed and loaded ($INSTALLED_PLIST)."
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