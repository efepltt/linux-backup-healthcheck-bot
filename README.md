# Linux Server Backup & Health Check Bot 🛡️

Bu proje, Linux sunucunuzdaki kritik web dizinlerini ve MySQL veritabanını otomatik olarak yedekleyen, `tar` ile sıkıştırıp `GPG` ile şifreleyen ve ardından sunucu sağlık durumunu (Disk, RAM, Servisler) Discord veya Telegram üzerinden size bildiren bir Bash betiğidir.

## Özellikler ✨
- **Otomatik Veritabanı Yedeği:** `mysqldump` ile MySQL/MariaDB yedeği alınır.
- **Dosya Yedeği:** Belirtilen web dizininin tam yedeği alınır.
- **Güvenli Arşivleme:** Dosyalar `zip` formatında sıkıştırılır ve `GPG` (AES-256) kullanılarak şifrelenir.
- **Sunucu Sağlık Kontrolü:** Disk doluluk oranı, RAM kullanımı, Nginx ve MySQL servis durumları anlık olarak raporlanır.
- **Canlı Bildirim (Webhook):** İşlem sonrasında Discord veya Telegram kanalınıza özet rapor olarak gönderilir.
- **Otomasyon (Cron):** `cron` entegrasyonu sayesinde her gece belirlediğiniz bir saatte el değmeden çalışır.

## Kurulum 🛠️

1. **Gereksinimleri Yükleyin:**
   Sunucunuzda `zip`, `mysql-client`, `gnupg` ve `curl` paketlerinin yüklü olduğundan emin olun. (Ubuntu/Debian tabanlı sistemler için:)
   ```bash
   sudo apt update
   sudo apt install zip mysql-client gnupg curl -y
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
gpg -d backup_2023-10-06_03-00-00.zip.gpg > backup.zip
```
Şifreyi çözdükten sonra standart bir zip arşivi olarak klasöre çıkartabilirsiniz:
```bash
unzip backup.zip
```

## Örnek Bildirim Ekran Görüntüsü 📱

Bot çalıştığında Discord/Telegram kanalınıza şu şekilde bir mesaj düşecektir:

> ✅ **Sunucu Yedekleme & Sağlık Raporu** ✅
> 🗓️ **Tarih:** 2026-10-06 03:00:01
> 
> 💾 **Yedek Durumu:**
> - **Dosya:** `backup_2026-10-06_03-00-00.zip.gpg`
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

*(Repo'yu GitHub'a yüklediğinizde buraya uygulamanın ekran görüntüsünü ekleyebilirsiniz.)*

---

## CV / Özgeçmiş Metni (Öneri) 📄

Özgeçmişinizde bu projeden bahsederken aşağıdaki cümleyi kullanabilirsiniz:

> **"Geliştirilen Bash betiği ve cron yapılandırması ile web ve veritabanı yedekleme süreçleri otomatikleştirildi; Telegram/Discord bot entegrasyonuyla sunucu sağlık metrikleri canlı bildirim hattına bağlandı."**

## Mülakat Soru & Cevapları 🎤

Bu proje özelinde gireceğiniz mülakatlarda gelebilecek olası sorular ve cevapları:

**Soru 1:** "Cron job çalışmadığında hatayı nasıl debug edersin (çözersin)?"
**Cevap:**
1. Öncelikle `/var/log/syslog` (Debian/Ubuntu) veya `/var/log/cron` (RHEL/CentOS) loglarına `grep CRON` komutu ile bakarak cron'un gerçekten tetiklenip tetiklenmediğini kontrol ederim.
2. Betiğin çalıştırılabilir izni (`chmod +x`) olup olmadığını kontrol ederim.
3. Cron'un çalıştırdığı çevre (environment), kullanıcının standart PATH değerlerini taşımaz. Bu yüzden betik içindeki komutların (`mysqldump`, `zip`, `gpg` vb.) veya cron tanımlamasındaki betiğin **tam dosya yolunu (absolute path)** doğru yazdığımdan emin olurum.
4. Crontab'a eklediğim satırın sonuna `>> /var/log/cron_hata.log 2>&1` ekleyerek `stdout` (çıktı) ve `stderr` (hata) loglarını spesifik bir dosyaya yazdırıp detaylı hatayı incelerim.

**Soru 2:** "Betiğin yetkisiz kullanıcılar tarafından değiştirilmesini nasıl engellersin?"
**Cevap:**
1. Güvenlik için dosyanın sahipliğini (owner) `root` kullanıcısına veririm: `chown root:root betik.sh`.
2. Dosya okuma, yazma ve çalıştırma izinlerini sadece root'a (veya yetkili kullanıcıya) kısıtlarım: `chmod 700 betik.sh`.
3. Eğer dosyanın çok kritik olduğunu düşünüyor ve root dahi olsa kazara silinmesini veya değiştirilmesini önlemek istiyorsam, Linux dosya sistemi özelliklerinden faydalanarak **immutable (değiştirilemez)** bayrağını eklerim: `chattr +i betik.sh`. Değişiklik yapmak istediğimde önce `chattr -i` ile kaldırıp sonra düzenlemem gerekir.
