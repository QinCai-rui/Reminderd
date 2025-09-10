# Reminderd

Reminder Daemon for Linux Desktop Environments

Lightweight reminder daemon for Linux desktop environments. Uses a Unix domain socket and `sqlite` for storage. Sends desktop notifications via `notify-send`.

## Files

- `src/reminderd.py` - the daemon
- `src/reminderctl.py` - simple CLI client
- `systemd/reminderd.socket` and `systemd/reminderd.service` - example user units

## Quick install (user)

1. Ensure `notify-send` is available (usually provided by `libnotify-bin`, it is already installed on Fedora KDE Plasma).

   On Debian/Ubuntu:

   ```bash
   sudo apt install libnotify-bin
   ```

   On Fedora:

   ```bash
   sudo dnf install libnotify
   ```

2. Clone the repo:

   ```bash
   git clone https://github.com/QinCai-rui/Reminderd.git ~/Reminderd
   ```

3. (Optional, but good) Create a Python venv and install nothing - scripts use only `stdlib`.

   ```bash
   python3 -m venv ~/Reminderd/venv
   source ~/Reminderd/venv/bin/activate
   ```

4. Make scripts executable:

   ```bash
   chmod +x ~/Reminderd/src/*.py
   ```

5. Copy systemd units to your user systemd dir and enable the socket:

   ```bash
   cd ~/Reminderd
   mkdir -p ~/.config/systemd/user
   cp systemd/reminderd.socket ~/.config/systemd/user/
   cp systemd/reminderd.service ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now reminderd.socket
   ```

6. (Optional, recommended) Add Reminderd to your PATH by adding the following line to your `~/.bashrc`, `~/.zshrc`, or whatever shell config file you use:

   ```bash
   export PATH="$HOME/Reminderd/src:$PATH"
   ```

## Usage

Add a reminder at an epoch timestamp:

   ```bash
   ~/Reminderd/src/reminderctl.py add 1234567890 "Drink Water"
   ```

List reminders:

   ```bash
   ~/Reminderd/src/reminderctl.py list
   ```

Remove:

   ```bash
   ~/Reminderd/src/reminderctl.py remove 1
   ```

## NOTES

- The socket and DB are by default at `~/.local/share/reminderd/`.
- The daemon sends notifications via `notify-send` when reminders are due.
- The systemd service `ExecStart` points to a venv path under the repo; adjust if you a different python.