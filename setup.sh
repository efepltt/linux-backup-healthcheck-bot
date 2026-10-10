#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    echo "✅ .env dosyası oluşturuldu!"
fi

source "$SCRIPT_DIR/.env"

echo -e "\n================================================================="
echo "Linux Sunucu Yedekleme Botu - Kurulum Sihirbazı"
echo -e "=================================================================\n"

read -p "Konfigürasyon ayarlarını şimdi interaktif olarak girmek ister misiniz? [e/H]: " SETUP_CHOICE
if [[ "$SETUP_CHOICE" =~ ^[Ee]$ ]]; then
    read -p "Yedeklenecek klasörler (virgülle ayırın) [$WEB_DIRS]: " I_WEB
    WEB_DIRS=${I_WEB:-$WEB_DIRS}
    
    read -p "Hariç tutulacak klasör/kelimeler (virgülle ayırın) [$EXCLUDE_DIRS]: " I_EXC
    EXCLUDE_DIRS=${I_EXC:-$EXCLUDE_DIRS}
    
    read -p "Yedeklerin saklanacağı ana dizin [$BACKUP_DIR]: " I_DIR
    BACKUP_DIR=${I_DIR:-$BACKUP_DIR}
    
    read -p "Yedekler kaç gün saklansın (Retention) [$RETENTION_DAYS]: " I_RET
    RETENTION_DAYS=${I_RET:-$RETENTION_DAYS}
    
    read -p "MySQL kullanıcı adı [$DB_USER]: " I_DBU
    DB_USER=${I_DBU:-$DB_USER}
    
    read -p "MySQL şifresi [$DB_PASS]: " I_DBP
    DB_PASS=${I_DBP:-$DB_PASS}
    
    read -p "Yedeklenecek veritabanları (virgülle ayırın) [$DB_NAMES]: " I_DBN
    DB_NAMES=${I_DBN:-$DB_NAMES}
    
    read -p "GPG şifreleme parolası [$GPG_PASSPHRASE]: " I_GPG
    GPG_PASSPHRASE=${I_GPG:-$GPG_PASSPHRASE}
    
    read -p "Telegram Bot Token [$TELEGRAM_BOT_TOKEN]: " I_TOK
    TELEGRAM_BOT_TOKEN=${I_TOK:-$TELEGRAM_BOT_TOKEN}
    
    read -p "Telegram Chat ID [$TELEGRAM_CHAT_ID]: " I_CHAT
    TELEGRAM_CHAT_ID=${I_CHAT:-$TELEGRAM_CHAT_ID}
    
    # .env dosyasını güncelle
    sed -i "s|^WEB_DIRS=.*|WEB_DIRS=\"$WEB_DIRS\"|" "$SCRIPT_DIR/.env"
    sed -i "s|^EXCLUDE_DIRS=.*|EXCLUDE_DIRS=\"$EXCLUDE_DIRS\"|" "$SCRIPT_DIR/.env"
    sed -i "s|^BACKUP_DIR=.*|BACKUP_DIR=\"$BACKUP_DIR\"|" "$SCRIPT_DIR/.env"
    sed -i "s|^RETENTION_DAYS=.*|RETENTION_DAYS=\"$RETENTION_DAYS\"|" "$SCRIPT_DIR/.env"
    sed -i "s|^DB_USER=.*|DB_USER=\"$DB_USER\"|" "$SCRIPT_DIR/.env"
    sed -i "s|^DB_PASS=.*|DB_PASS=\"$DB_PASS\"|" "$SCRIPT_DIR/.env"
    sed -i "s|^DB_NAMES=.*|DB_NAMES=\"$DB_NAMES\"|" "$SCRIPT_DIR/.env"
    sed -i "s|^GPG_PASSPHRASE=.*|GPG_PASSPHRASE=\"$GPG_PASSPHRASE\"|" "$SCRIPT_DIR/.env"
    sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"|" "$SCRIPT_DIR/.env"
    sed -i "s|^TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"|" "$SCRIPT_DIR/.env"
    
    echo -e "\n✅ Ayarlar .env dosyasına başarıyla kaydedildi!\n"
fi

chmod +x "$SCRIPT_DIR/backup_healthcheck.sh"

read -p "Her gece 03:00'te otomatik çalışacak CRON görevi eklensin mi? [E/h]: " CRON_CHOICE
if [[ -z "$CRON_CHOICE" || "$CRON_CHOICE" =~ ^[Ee]$ ]]; then
    crontab -l 2>/dev/null | grep -q "backup_healthcheck.sh"
    if [ $? -eq 0 ]; then
        echo "ℹ️ Zaten ayarlanmış bir cron görevi bulundu."
    else
        (crontab -l 2>/dev/null; echo "0 3 * * * $SCRIPT_DIR/backup_healthcheck.sh > /dev/null 2>&1") | crontab -
        echo "✅ Cron görevi eklendi!"
    fi
fi
echo "Kurulum tamamlandı. Telegram botunuzu aktif etmek için: python3 telegram_listener.py komutunu çalıştırın."
