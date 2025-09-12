#!/bin/bash
set -e

REPO_URL="https://github.com/QinCai-rui/Reminderd.git"
INSTALL_DIR="$HOME/Reminderd"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

if [ ! -d "$INSTALL_DIR" ]; then
	echo "Cloning Reminderd repo to $INSTALL_DIR..."
	git clone "$REPO_URL" "$INSTALL_DIR"
else
	echo "Repo already exists at $INSTALL_DIR. Skipping clone."
	echo "If you want to update the daemon & CLI, just do `cd $INSTALL_DIR && git pull`."
fi

echo "Making scripts executable..."
chmod +x "$INSTALL_DIR"/src/*

echo "Copying systemd user units..."
mkdir -p "$SYSTEMD_USER_DIR"
cp "$INSTALL_DIR"/systemd/reminderd.socket "$SYSTEMD_USER_DIR/"
cp "$INSTALL_DIR"/systemd/reminderd.service "$SYSTEMD_USER_DIR/"

echo "Reloading and enabling reminderd.socket (user)..."
systemctl --user daemon-reload # this might not be needed, but just in case
systemctl --user enable --now reminderd.socket

echo "Reminderd user-level installation complete."

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
	echo "$PATH_LINE" >> "$SHELL_CONFIG"
	echo "Added Reminderd CLI to $SHELL_CONFIG."
else
	echo "Reminderd CLI path already present in $SHELL_CONFIG."
fi

echo "Reminderd user-level installation complete. Please restart your shell or run:"
echo "  source $SHELL_CONFIG"