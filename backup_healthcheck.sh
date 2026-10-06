#!/bin/bash

# ==============================================================================
# Otomatik Linux Sunucu Yedekleme ve Sağlık Kontrol Botu
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Konfigürasyon Ayarları
# ------------------------------------------------------------------------------
WEB_DIR="/var/www/html"          # Yedeklenecek web dizini
BACKUP_DIR="/var/backups/server" # Yedeklerin saklanacağı ana dizin
DB_USER="root"                   # MySQL kullanıcı adı
DB_PASS="sifre123"               # MySQL şifresi
DB_NAME="veritabani_adi"         # Yedeklenecek veritabanı adı
GPG_PASSPHRASE="cok_guvenli_sifre" # GPG şifreleme parolası
WEBHOOK_URL="https://api.telegram.org/bot8282285130:AAHhj5Z1osJ4I1yV0Eu04Z_QqnHqftsO3Yw/sendMessage" # Telegram için
TELEGRAM_CHAT_ID="7082533439" # Kullanıcının Chat ID'si
DISCORD_WEBHOOK=false            # True ise Discord, False ise Telegram formatında gönderir

# ------------------------------------------------------------------------------
# İnteraktif Kurulum Sihirbazı (Sadece terminalden çalıştırıldığında aktif olur)
# ------------------------------------------------------------------------------
if [ -t 0 ] && [ "$1" != "--status" ]; then
    echo -e "\n================================================================="
    echo "Linux Sunucu Yedekleme ve Sağlık Kontrol Botu - Kurulum Sihirbazı"
    echo -e "=================================================================\n"
    read -p "Konfigürasyon ayarlarını şimdi interaktif olarak girmek ister misiniz? 
(Dosyayı zaten manuel düzenlediyseniz veya atlamak istiyorsanız 'h' girin) [e/H]: " SETUP_CHOICE

    if [[ "$SETUP_CHOICE" =~ ^[Ee]$ ]]; then
        read -p "Yedeklenecek web dizini [$WEB_DIR]: " INPUT_WEB_DIR
        WEB_DIR=${INPUT_WEB_DIR:-$WEB_DIR}
        
        read -p "Yedeklerin saklanacağı ana dizin [$BACKUP_DIR]: " INPUT_BACKUP_DIR
        BACKUP_DIR=${INPUT_BACKUP_DIR:-$BACKUP_DIR}
        
        read -p "MySQL kullanıcı adı [$DB_USER]: " INPUT_DB_USER
        DB_USER=${INPUT_DB_USER:-$DB_USER}
        
        read -p "MySQL şifresi [$DB_PASS]: " INPUT_DB_PASS
        DB_PASS=${INPUT_DB_PASS:-$DB_PASS}
        
        read -p "Yedeklenecek veritabanı adı [$DB_NAME]: " INPUT_DB_NAME
        DB_NAME=${INPUT_DB_NAME:-$DB_NAME}
        
        read -p "GPG şifreleme parolası [$GPG_PASSPHRASE]: " INPUT_GPG
        GPG_PASSPHRASE=${INPUT_GPG:-$GPG_PASSPHRASE}
        
        read -p "Webhook URL [$WEBHOOK_URL]: " INPUT_WEBHOOK
        WEBHOOK_URL=${INPUT_WEBHOOK:-$WEBHOOK_URL}
        
        # Sed ile betiğin kendi içindeki değişkenleri kalıcı olarak güncelle
        SCRIPT_PATH=$(readlink -f "$0")
        sed -i "s|^WEB_DIR=\"[^\"]*\"|WEB_DIR=\"$WEB_DIR\"|" "$SCRIPT_PATH"
        sed -i "s|^BACKUP_DIR=\"[^\"]*\"|BACKUP_DIR=\"$BACKUP_DIR\"|" "$SCRIPT_PATH"
        sed -i "s|^DB_USER=\"[^\"]*\"|DB_USER=\"$DB_USER\"|" "$SCRIPT_PATH"
        sed -i "s|^DB_PASS=\"[^\"]*\"|DB_PASS=\"$DB_PASS\"|" "$SCRIPT_PATH"
        sed -i "s|^DB_NAME=\"[^\"]*\"|DB_NAME=\"$DB_NAME\"|" "$SCRIPT_PATH"
        sed -i "s|^GPG_PASSPHRASE=\"[^\"]*\"|GPG_PASSPHRASE=\"$GPG_PASSPHRASE\"|" "$SCRIPT_PATH"
        sed -i "s|^WEBHOOK_URL=\"[^\"]*\"|WEBHOOK_URL=\"$WEBHOOK_URL\"|" "$SCRIPT_PATH"
        
        echo -e "\n✅ Ayarlar başarıyla kaydedildi! Betik güncellendi.\n"
    else
        echo -e "\nKurulum sihirbazı atlandı. Mevcut ayarlar ile devam ediliyor...\n"
    fi

    # ------------------------------------------------------------------------------
    # Otomatik Cron Kurulumu
    # ------------------------------------------------------------------------------
    read -p "Otomatik yedekleme için her gece saat 03:00'te çalışacak bir cron görevi eklensin mi? [E/h]: " CRON_CHOICE
    if [[ -z "$CRON_CHOICE" || "$CRON_CHOICE" =~ ^[Ee]$ ]]; then
        SCRIPT_PATH=$(readlink -f "$0")
        # Mevcut crontab'da bu dosya var mı kontrol et
        crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"
        if [ $? -eq 0 ]; then
            echo -e "ℹ️  Zaten ayarlanmış bir cron görevi bulundu, tekrar eklenmedi.\n"
        else
            (crontab -l 2>/dev/null; echo "0 3 * * * $SCRIPT_PATH > /dev/null 2>&1") | crontab -
            echo -e "✅ Cron görevi başarıyla eklendi! (Her gece 03:00)\n"
        fi
    fi

    read -p "Otomatik yedekleme scriptini şimdi çalıştırıp 'manuel bir yedek' almak istiyor musunuz? [E/h]: " RUN_CHOICE
    if [[ "$RUN_CHOICE" =~ ^[Hh]$ ]]; then
        echo -e "İşlem iptal edildi. Cron görevi eklendiyse belirlediğiniz saatte arka planda çalışacaktır.\n"
        exit 0
    fi
    echo -e "Manuel yedekleme ve sağlık kontrolü işlemi şimdi başlatılıyor...\n"
    sleep 2
fi

# ------------------------------------------------------------------------------
# 2. Dinamik Değişkenler ve Loglama
# ------------------------------------------------------------------------------
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
TEMP_DIR="/tmp/backup_$DATE"
ARCHIVE_NAME="backup_$DATE.zip"
ENCRYPTED_ARCHIVE="${ARCHIVE_NAME}.gpg"
LOG_FILE="/var/log/backup_healthcheck.log"

# Log fonksiyonu
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# Başlangıç
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"
log_message "İşlem başlatıldı..."

# Eğer sadece "--status" komutu ile çalıştırıldıysa yedeklemeyi atla
if [ "$1" != "--status" ]; then
    # ------------------------------------------------------------------------------
    # 3. Veritabanı Yedekleme
    # ------------------------------------------------------------------------------
    log_message "MySQL veritabanı yedekleniyor..."
    mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$TEMP_DIR/db_backup.sql" 2>> "$LOG_FILE"
    if [ $? -eq 0 ]; then
        log_message "Veritabanı yedeği başarıyla alındı."
    else
        log_message "HATA: Veritabanı yedeği alınamadı! Log dosyasını kontrol edin."
    fi

    # ------------------------------------------------------------------------------
    # 4. Web Dizini Kopyalama
    # ------------------------------------------------------------------------------
    log_message "Web dizini ($WEB_DIR) kopyalanıyor..."
    cp -r "$WEB_DIR" "$TEMP_DIR/web_files" 2>> "$LOG_FILE"

    # ------------------------------------------------------------------------------
    # 5. Sıkıştırma (Zip)
    # ------------------------------------------------------------------------------
    log_message "Dosyalar zip formatında sıkıştırılıyor..."
    (cd "/tmp" && zip -r -q "$BACKUP_DIR/$ARCHIVE_NAME" "backup_$DATE") 2>> "$LOG_FILE"

    # ------------------------------------------------------------------------------
    # 6. GPG Şifreleme
    # ------------------------------------------------------------------------------
    log_message "Arşiv GPG ile şifreleniyor..."
    gpg --symmetric --batch --yes --passphrase "$GPG_PASSPHRASE" -o "$BACKUP_DIR/$ENCRYPTED_ARCHIVE" "$BACKUP_DIR/$ARCHIVE_NAME" 2>> "$LOG_FILE"

    if [ $? -eq 0 ]; then
        log_message "Şifreleme başarılı. Şifresiz orijinal arşiv siliniyor..."
        rm -f "$BACKUP_DIR/$ARCHIVE_NAME"
    else
        log_message "HATA: Şifreleme başarısız oldu!"
    fi

    # Geçici dosyaları temizle
    rm -rf "$TEMP_DIR"
else
    log_message "Sadece sağlık kontrolü (--status) istendi, yedekleme adımları atlanıyor..."
    ENCRYPTED_ARCHIVE="YEDEK_ALINMADI"
fi

# ------------------------------------------------------------------------------
# 7. Sunucu Sağlık Kontrolü (Healthcheck)
# ------------------------------------------------------------------------------
log_message "Sunucu sağlık metrikleri toplanıyor..."

# Disk Kullanımı
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')

# RAM Kullanımı
RAM_TOTAL=$(free -m | awk 'NR==2 {print $2}')
RAM_USED=$(free -m | awk 'NR==2 {print $3}')
RAM_USAGE_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($RAM_USED/$RAM_TOTAL)*100}")

# CPU ve Yük (Load Average)
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
if command -v vmstat >/dev/null 2>&1; then
    CPU_USAGE=$(vmstat 1 2 | tail -1 | awk '{print 100 - $15}')"%"
else
    CPU_USAGE=$(LC_ALL=C top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')"%"
fi

# Servis Durumları (Nginx ve MySQL)
NGINX_STATUS=$(systemctl is-active nginx 2>/dev/null || echo "kapali")
MYSQL_STATUS=$(systemctl is-active mysql 2>/dev/null || systemctl is-active mariadb 2>/dev/null || echo "kapali")

# Ekstra Hizmetler (UFW, Fail2Ban, PHP, ImageMagick, FFmpeg, FFprobe)
UFW_STATUS=$(systemctl is-active ufw 2>/dev/null || echo "kapali")
FAIL2BAN_STATUS=$(systemctl is-active fail2ban 2>/dev/null || echo "kapali")
PHP_STATUS=$(command -v php >/dev/null 2>&1 && echo "aktif" || echo "bulunamadi")
IMAGEMAGICK_STATUS=$( (command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1) && echo "aktif" || echo "bulunamadi" )
FFMPEG_STATUS=$(command -v ffmpeg >/dev/null 2>&1 && echo "aktif" || echo "bulunamadi")
FFPROBE_STATUS=$(command -v ffprobe >/dev/null 2>&1 && echo "aktif" || echo "bulunamadi")

# ------------------------------------------------------------------------------
# 8. Webhook (Telegram / Discord) Bildirimi
# ------------------------------------------------------------------------------
log_message "Webhook üzerinden bildirim gönderiliyor..."

if [ "$1" != "--status" ]; then
    # YEDEKLEME MESAJ FORMATI
    MESSAGE="✅ **Sunucu Yedekleme Raporu** ✅
🗓️ **Tarih:** $(date +"%Y-%m-%d %H:%M:%S")

💾 **Yedeklenen Kısımlar:**
- **Klasör:** \`$WEB_DIR\`
- **Veritabanı:** \`$DB_NAME\`

📦 **Arşiv Durumu:**
- **Dosya:** \`$ENCRYPTED_ARCHIVE\`
- **Konum:** \`$BACKUP_DIR\`
- **Durum:** Başarılı 🔒 (GPG Şifreli)

📊 **Sistem Sağlığı:**
- **CPU Kullanımı:** %$CPU_USAGE (Load: $LOAD_AVG)
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
    # SADECE DURUM (STATUS) MESAJ FORMATI
    MESSAGE="📊 **Sunucu Durum Raporu** 📊
🗓️ **Tarih:** $(date +"%Y-%m-%d %H:%M:%S")

💾 **Donanım Durumu:**
- **CPU Kullanımı:** $CPU_USAGE
- **Load Average:** $LOAD_AVG
- **Disk Kullanımı:** $DISK_USAGE (Boş: $DISK_FREE)
- **RAM Kullanımı:** %$RAM_USAGE_PERCENT (${RAM_USED}MB / ${RAM_TOTAL}MB)

⚙️ **Servisler & Araçlar:**
- **Nginx:** \`$NGINX_STATUS\`
- **MySQL/MariaDB:** \`$MYSQL_STATUS\`
- **UFW (Güvenlik Duvarı):** \`$UFW_STATUS\`
- **Fail2Ban:** \`$FAIL2BAN_STATUS\`
- **PHP:** \`$PHP_STATUS\`
- **ImageMagick:** \`$IMAGEMAGICK_STATUS\`
- **FFmpeg:** \`$FFMPEG_STATUS\`
- **FFprobe:** \`$FFPROBE_STATUS\`"
fi

if [ "$DISCORD_WEBHOOK" = true ]; then
    # Discord formatı
    curl -H "Content-Type: application/json" \
         -d "{\"content\": \"$MESSAGE\"}" \
         $WEBHOOK_URL 2>> "$LOG_FILE"
else
    # Telegram formatı (text verisi urlencode edilerek gönderiliyor)
    curl -s -X POST $WEBHOOK_URL \
         -d chat_id="$TELEGRAM_CHAT_ID" \
         --data-urlencode text="$MESSAGE" \
         -d parse_mode="Markdown" 2>> "$LOG_FILE"
fi

log_message "Yedekleme ve sağlık kontrolü işlemi tamamlandı."
echo "---------------------------------------------------" >> "$LOG_FILE"
