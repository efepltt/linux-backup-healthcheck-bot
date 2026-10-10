# Linux Server Backup & Healthcheck Bot

An automated backup and healthcheck bot for Linux servers that reports status (RAM, CPU, Disk, Services) directly to Telegram.

## 🌟 Features
- 🗂️ **Multi-Directory & Database Backup:** Backup multiple folders and MySQL databases at once by separating them with commas.
- 🚫 **Exclude Folders:** Easily exclude cache, `node_modules`, or log files to save space.
- 🧹 **Auto-Cleanup (Retention):** Automatically deletes backups older than 7 days (configurable) to prevent full disks.
- 🩺 **Smart Healthchecks:** Monitors CPU, RAM, Load Average, Nginx, MySQL, PHP, Fail2ban, FFmpeg, ImageMagick, and more.
- 🚨 **Critical Alerts & Remote Auto-Heal:** Alerts you if a critical service crashes. Send `/restart nginx` via Telegram to remotely restart services!
- 🔒 **GPG Encryption:** Secure your backup archives with AES-256 encryption.

---

## 🚀 One-Liner Installation
Run the following command on your server terminal to start the interactive setup wizard:

```bash
git clone https://github.com/efepltt/linux-backup-healthcheck-bot.git && cd linux-backup-healthcheck-bot && chmod +x setup.sh && ./setup.sh
```

*(During installation, you will be prompted to enter your directory paths, database credentials, and Telegram Bot Token, which will be safely stored in a `.env` file).*

---

## 📱 Telegram Commands
Once the bot is running, you can manage your server directly from Telegram using these commands:

- `/durum` : Get real-time RAM, CPU, Disk, and Service status without taking a backup.
- `/yedekle` : Trigger a manual full backup immediately.
- `/log` : Fetch the last 20 lines of system logs (Backup started, errors, etc.) directly in Telegram.
- `/restart <service_name>` : Remotely restart a crashed service (e.g., `/restart nginx` or `/restart mysql`).

## 🛠️ Keeping the Bot Running 24/7
To make sure the bot constantly listens for your commands in the background, run the Python listener inside a screen session:

```bash
apt install screen
screen -S tgbot python3 telegram_listener.py
```
*(Press `Ctrl+A` then `D` to safely detach from the screen session).*
