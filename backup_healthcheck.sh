#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "HATA: .env dosyası bulunamadı! Lütfen önce setup.sh çalıştırın."
    exit 1
fi

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
TEMP_DIR="/tmp/backup_$DATE"
ARCHIVE_NAME="backup_$DATE.zip"
ENCRYPTED_ARCHIVE="${ARCHIVE_NAME}.gpg"
mkdir -p "$SCRIPT_DIR/logs"
LOG_FILE="$SCRIPT_DIR/logs/system.log"
WEBHOOK_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

log_message() { echo "[$(date +"%Y-%m-%d %H:%M:%S")] [BASH] $1" | tee -a "$LOG_FILE"; }

mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"
log_message "İşlem başlatıldı..."

if [ "$1" != "--status" ]; then
    # Veritabanları Yedekleme
    IFS=',' read -ra DBS <<< "$DB_NAMES"
    for db in "${DBS[@]}"; do
        db=$(echo "$db" | xargs)
        if [ -n "$db" ]; then
            log_message "Veritabanı yedekleniyor: $db"
            mysqldump -u"$DB_USER" -p"$DB_PASS" "$db" > "$TEMP_DIR/db_${db}.sql" 2>> "$LOG_FILE"
        fi
    done
    
    # ZIP Komutu Hazırlama
    ZIP_CMD="zip -r -q \"$BACKUP_DIR/$ARCHIVE_NAME\" \"$TEMP_DIR\""
    IFS=',' read -ra DIRS <<< "$WEB_DIRS"
    for dir in "${DIRS[@]}"; do
        dir=$(echo "$dir" | xargs)
        if [ -d "$dir" ]; then
            ZIP_CMD="$ZIP_CMD \"$dir\""
        fi
    done
    IFS=',' read -ra EXCS <<< "$EXCLUDE_DIRS"
    for exc in "${EXCS[@]}"; do
        exc=$(echo "$exc" | xargs)
        if [ -n "$exc" ]; then
            ZIP_CMD="$ZIP_CMD -x \"*${exc}*\""
        fi
    done
    
    log_message "Dosyalar sıkıştırılıyor..."
    eval $ZIP_CMD 2>> "$LOG_FILE"
    
    log_message "Arşiv GPG ile şifreleniyor..."
    gpg --symmetric --batch --yes --passphrase "$GPG_PASSPHRASE" -o "$BACKUP_DIR/$ENCRYPTED_ARCHIVE" "$BACKUP_DIR/$ARCHIVE_NAME" 2>> "$LOG_FILE"
    if [ $? -eq 0 ]; then
        rm -f "$BACKUP_DIR/$ARCHIVE_NAME"
    fi
    rm -rf "$TEMP_DIR"
    
    # Eski yedekleri silme (Retention Policy)
    if [ -n "$RETENTION_DAYS" ] && [ "$RETENTION_DAYS" -gt 0 ]; then
        log_message "Eski yedekler temizleniyor (Son $RETENTION_DAYS gün harici)..."
        find "$BACKUP_DIR" -name "*.gpg" -type f -mtime +$RETENTION_DAYS -delete 2>> "$LOG_FILE"
    fi
else
    ENCRYPTED_ARCHIVE="YEDEK_ALINMADI"
fi

# Sağlık Kontrolleri
log_message "Sunucu metrikleri toplanıyor..."
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
RAM_TOTAL=$(free -m | awk 'NR==2 {print $2}')
RAM_USED=$(free -m | awk 'NR==2 {print $3}')
RAM_USAGE_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($RAM_USED/$RAM_TOTAL)*100}")
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
if command -v vmstat >/dev/null 2>&1; then
    CPU_USAGE=$(vmstat 1 2 | tail -1 | awk '{print 100 - $15}')"%"
else
    CPU_USAGE=$(LC_ALL=C top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')"%"
fi

NGINX_STATUS=$(systemctl is-active nginx 2>/dev/null || echo "kapali")
MYSQL_STATUS=$(systemctl is-active mysql 2>/dev/null || systemctl is-active mariadb 2>/dev/null || echo "kapali")
UFW_STATUS=$(systemctl is-active ufw 2>/dev/null || echo "kapali")
FAIL2BAN_STATUS=$(systemctl is-active fail2ban 2>/dev/null || echo "kapali")
PHP_STATUS=$(command -v php >/dev/null 2>&1 && echo "aktif" || echo "bulunamadi")
IMAGEMAGICK_STATUS=$( (command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1) && echo "aktif" || echo "bulunamadi" )
FFMPEG_STATUS=$(command -v ffmpeg >/dev/null 2>&1 && echo "aktif" || echo "bulunamadi")
FFPROBE_STATUS=$(command -v ffprobe >/dev/null 2>&1 && echo "aktif" || echo "bulunamadi")

# Kritik Uyarı Kontrolü
ALERT_MSG=""
if [[ "$NGINX_STATUS" == *"kapali"* ]] || [[ "$MYSQL_STATUS" == *"kapali"* ]]; then
    ALERT_MSG="
🚨 **KRİTİK UYARI:** Bazı kritik servisler çökmüş durumda!
Uzaktan müdahale edip yeniden başlatmak için bota \`/restart nginx\` veya \`/restart mysql\` komutu gönderebilirsiniz.
"
fi

if [ "$1" != "--status" ]; then
    MESSAGE="$ALERT_MSG
✅ **Sunucu Yedekleme Raporu** ✅
🗓️ **Tarih:** $(date +"%Y-%m-%d %H:%M:%S")

💾 **Yedeklenen Kısımlar:**
- **Klasörler:** \`$WEB_DIRS\`
- **Veritabanları:** \`$DB_NAMES\`

📦 **Arşiv Durumu:**
- **Dosya:** \`$ENCRYPTED_ARCHIVE\`
- **Konum:** \`$BACKUP_DIR\`
- **Durum:** Başarılı 🔒 (GPG Şifreli)

📊 **Sistem Sağlığı:**
- **CPU:** $CPU_USAGE (Load: $LOAD_AVG)
- **Disk:** $DISK_USAGE (Boş: $DISK_FREE)
- **RAM:** %$RAM_USAGE_PERCENT (${RAM_USED}MB / ${RAM_TOTAL}MB)

⚙️ **Servis Durumları:**
- **Nginx:** \`$NGINX_STATUS\`
- **MySQL/MariaDB:** \`$MYSQL_STATUS\`
- **UFW:** \`$UFW_STATUS\`
- **Fail2Ban:** \`$FAIL2BAN_STATUS\`
- **PHP:** \`$PHP_STATUS\`
- **ImageMagick:** \`$IMAGEMAGICK_STATUS\`
- **FFmpeg:** \`$FFMPEG_STATUS\`
- **FFprobe:** \`$FFPROBE_STATUS\`"
else
    MESSAGE="$ALERT_MSG
📊 **Sunucu Durum Raporu** 📊
🗓️ **Tarih:** $(date +"%Y-%m-%d %H:%M:%S")

💾 **Donanım Durumu:**
- **CPU Kullanımı:** $CPU_USAGE
- **Load Average:** $LOAD_AVG
- **Disk Kullanımı:** $DISK_USAGE (Boş: $DISK_FREE)
- **RAM Kullanımı:** %$RAM_USAGE_PERCENT (${RAM_USED}MB / ${RAM_TOTAL}MB)

⚙️ **Servisler & Araçlar:**
- **Nginx:** \`$NGINX_STATUS\`
- **MySQL/MariaDB:** \`$MYSQL_STATUS\`
- **UFW:** \`$UFW_STATUS\`
- **Fail2Ban:** \`$FAIL2BAN_STATUS\`
- **PHP:** \`$PHP_STATUS\`
- **ImageMagick:** \`$IMAGEMAGICK_STATUS\`
- **FFmpeg:** \`$FFMPEG_STATUS\`
- **FFprobe:** \`$FFPROBE_STATUS\`"
fi

curl -s -X POST $WEBHOOK_URL -d chat_id="$TELEGRAM_CHAT_ID" --data-urlencode text="$MESSAGE" -d parse_mode="Markdown" > /dev/null 2>&1
log_message "İşlem tamamlandı."
