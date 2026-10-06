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
WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN" # Discord veya Telegram URL
DISCORD_WEBHOOK=true             # True ise Discord, False ise Telegram formatında gönderir

# ------------------------------------------------------------------------------
# İnteraktif Kurulum Sihirbazı (Sadece terminalden çalıştırıldığında aktif olur)
# ------------------------------------------------------------------------------
if [ -t 1 ]; then
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

    echo -e "İlk test yedeklemesi ve sağlık kontrolü işlemi şimdi başlatılıyor...\n"
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
log_message "Yedekleme işlemi başlatıldı..."

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

# Servis Durumları (Nginx ve MySQL)
NGINX_STATUS=$(systemctl is-active nginx 2>/dev/null || echo "bulunamadi/kapali")
MYSQL_STATUS=$(systemctl is-active mysql 2>/dev/null || systemctl is-active mariadb 2>/dev/null || echo "bulunamadi/kapali")

# ------------------------------------------------------------------------------
# 8. Webhook (Telegram / Discord) Bildirimi
# ------------------------------------------------------------------------------
log_message "Webhook üzerinden bildirim gönderiliyor..."

MESSAGE="✅ **Sunucu Yedekleme & Sağlık Raporu** ✅
🗓️ **Tarih:** $(date +"%Y-%m-%d %H:%M:%S")

💾 **Yedek Durumu:**
- **Dosya:** \`$ENCRYPTED_ARCHIVE\`
- **Konum:** \`$BACKUP_DIR\`
- **Durum:** Başarılı 🔒 (GPG Şifreli)

📊 **Sistem Sağlığı:**
- **Disk Kullanımı:** $DISK_USAGE (Boş: $DISK_FREE)
- **RAM Kullanımı:** %$RAM_USAGE_PERCENT (${RAM_USED}MB / ${RAM_TOTAL}MB)

⚙️ **Servis Durumları:**
- **Nginx:** \`$NGINX_STATUS\`
- **MySQL/MariaDB:** \`$MYSQL_STATUS\`"

if [ "$DISCORD_WEBHOOK" = true ]; then
    # Discord formatı
    curl -H "Content-Type: application/json" \
         -d "{\"content\": \"$MESSAGE\"}" \
         $WEBHOOK_URL 2>> "$LOG_FILE"
else
    # Telegram formatı
    curl -s -X POST $WEBHOOK_URL \
         -d chat_id="YOUR_TELEGRAM_CHAT_ID" \
         -d text="$MESSAGE" \
         -d parse_mode="Markdown" 2>> "$LOG_FILE"
fi

log_message "Yedekleme ve sağlık kontrolü işlemi tamamlandı."
echo "---------------------------------------------------" >> "$LOG_FILE"
