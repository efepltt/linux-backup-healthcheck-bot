# Linux Server Backup & Health Check Bot 🛡️

Bu proje, Linux sunucunuzdaki kritik web dizinlerini ve MySQL veritabanını otomatik olarak yedekleyen, `tar` ile sıkıştırıp `GPG` ile şifreleyen ve ardından sunucu sağlık durumunu (Disk, RAM, Servisler) Discord veya Telegram üzerinden size bildiren bir Bash betiğidir.

## Özellikler ✨
- **Otomatik Veritabanı Yedeği:** `mysqldump` ile MySQL/MariaDB yedeği alınır.
- **Dosya Yedeği:** Belirtilen web dizininin tam yedeği alınır.
- **Güvenli Arşivleme:** Dosyalar `tar.gz` formatında sıkıştırılır ve `GPG` (AES-256) kullanılarak şifrelenir.
- **Sunucu Sağlık Kontrolü:** Disk doluluk oranı, RAM kullanımı, Nginx ve MySQL servis durumları anlık olarak raporlanır.
- **Canlı Bildirim (Webhook):** İşlem sonrasında Discord veya Telegram kanalınıza özet rapor olarak gönderilir.
- **Otomasyon (Cron):** `cron` entegrasyonu sayesinde her gece belirlediğiniz bir saatte el değmeden çalışır.

## Kurulum 🛠️

1. **Gereksinimleri Yükleyin:**
   Sunucunuzda `tar`, `mysql-client`, `gnupg` ve `curl` paketlerinin yüklü olduğundan emin olun. (Ubuntu/Debian tabanlı sistemler için:)
   ```bash
   sudo apt update
   sudo apt install tar mysql-client gnupg curl -y
   ```

2. **Repoyu Klonlayın:**
   ```bash
   git clone https://github.com/efepltt/linux-backup-healthcheck-bot.git
   cd linux-backup-healthcheck-bot
   ```

3. **Betiği Yapılandırın:**
   `backup_healthcheck.sh` dosyasını `nano` veya `vim` ile açarak baş kısımdaki konfigürasyon değişkenlerini sunucunuza göre ayarlayın:
   ```bash
   WEB_DIR="/var/www/html"          # Yedeklenecek web dizini
   BACKUP_DIR="/var/backups/server" # Yedeklerin barındırılacağı yer
   DB_USER="root"                   # Veritabanı kullanıcı adı
   DB_PASS="sifre123"               # Veritabanı parolası
   DB_NAME="veritabani_adi"         # Yedeklenecek DB adı
   GPG_PASSPHRASE="guclu_sifre"     # Arşivi şifrelemek için kullanılacak parola
   WEBHOOK_URL="https://discord.com/..." # Webhook URL'niz
   ```

4. **Çalıştırma İzni Verin:**
   Betik dosyasının çalıştırılabilir olması gerekir.
   ```bash
   chmod +x backup_healthcheck.sh
   ```

5. **Test Edin:**
   Her şeyin doğru çalıştığını görmek için manuel olarak bir defa test edin. (Root dizinleri etkileniyorsa sudo ile çalıştırın)
   ```bash
   sudo ./backup_healthcheck.sh
   ```

## Cron Job (Zamanlanmış Görev) Ayarlama ⏰

Betiği her gece saat 03:00'te otomatik çalışacak şekilde crontab'a ekleyebilirsiniz:

1. Root veya yetkili kullanıcının crontab dosyasını düzenleyin:
   ```bash
   sudo crontab -e
   ```
2. Dosyanın en altına aşağıdaki satırı ekleyip kaydedin:
   ```bash
   0 3 * * * /dosya/tam/yolu/linux-backup-healthcheck-bot/backup_healthcheck.sh > /dev/null 2>&1
   ```
   *(Not: `/dosya/tam/yolu/` kısmını betiğin sistemdeki gerçek yoluyla değiştirin. Loglar betiğin içinde `/var/log/backup_healthcheck.log` konumuna kaydedildiği için cron çıktısını `> /dev/null 2>&1` ile sessize aldık.)*

## Yedeği Geri Yükleme (Decrypt & Extract) 🔓

Şifrelenmiş `.gpg` uzantılı yedeği açmak için aşağıdaki komutu kullanın (şifre sorulacaktır):
```bash
gpg -d backup_2023-10-06_03-00-00.tar.gz.gpg > backup.tar.gz
```
Şifreyi çözdükten sonra standart bir tar arşivi olarak klasöre çıkartabilirsiniz:
```bash
tar -xzf backup.tar.gz
```

## Örnek Bildirim Ekran Görüntüsü 📱

Bot çalıştığında Discord/Telegram kanalınıza şu şekilde bir mesaj düşecektir:

> ✅ **Sunucu Yedekleme & Sağlık Raporu** ✅
> 🗓️ **Tarih:** 2026-10-06 03:00:01
> 
> 💾 **Yedek Durumu:**
> - **Dosya:** `backup_2026-10-06_03-00-00.tar.gz.gpg`
> - **Konum:** `/var/backups/server`
> - **Durum:** Başarılı 🔒 (GPG Şifreli)
> 
> 📊 **Sistem Sağlığı:**
> - **Disk Kullanımı:** 45% (Boş: 110G)
> - **RAM Kullanımı:** %65.20 (1335MB / 2048MB)
> 
> ⚙️ **Servis Durumları:**
> - **Nginx:** `active`
> - **MySQL/MariaDB:** `active`