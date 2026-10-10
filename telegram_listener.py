import urllib.request
import urllib.parse
import json
import time
import subprocess
import os
import re
from datetime import datetime

def get_log_file():
    log_dir = os.path.join(os.path.dirname(__file__), "logs")
    os.makedirs(log_dir, exist_ok=True)
    return os.path.join(log_dir, "system.log")

def log_msg(msg):
    print(msg)
    try:
        with open(get_log_file(), "a", encoding="utf-8") as f:
            now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(f"[{now}] [PYTHON] {msg}\n")
    except:
        pass

def load_env():
    env_dict = {}
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    if os.path.exists(env_path):
        with open(env_path, encoding="utf-8") as f:
            for line in f:
                if line.strip() and not line.startswith("#"):
                    parts = line.strip().split("=", 1)
                    if len(parts) == 2:
                        env_dict[parts[0]] = parts[1].strip('"').strip("'")
    return env_dict

config = load_env()
TOKEN = config.get("TELEGRAM_BOT_TOKEN", "")

def send_message(chat_id, text):
    if not TOKEN: return
    url = f"https://api.telegram.org/bot{TOKEN}/sendMessage"
    data = urllib.parse.urlencode({'chat_id': chat_id, 'text': text}).encode('utf-8')
    try:
        urllib.request.urlopen(url, data=data)
    except Exception as e:
        log_msg(f"❌ Mesaj gönderilemedi: {e}")

def main():
    if not TOKEN:
        log_msg("HATA: .env dosyasında TELEGRAM_BOT_TOKEN bulunamadı!")
        return

    log_msg("✅ Telegram dinleyicisi başlatıldı! /durum, /yedekle, /log veya /restart komutları aktif.")
    offset = 0
    
    while True:
        try:
            url = f"https://api.telegram.org/bot{TOKEN}/getUpdates?offset={offset}&timeout=30"
            req = urllib.request.urlopen(url)
            response = json.loads(req.read().decode('utf-8'))
            
            for update in response.get('result', []):
                offset = update['update_id'] + 1
                message = update.get('message', {})
                if not message:
                    continue
                    
                chat_id = message.get('chat', {}).get('id')
                text = str(message.get('text', '')).strip()
                
                log_msg(f"📩 YENİ MESAJ GELDİ: '{text}' (Chat ID: {chat_id})")
                
                if text == '/durum':
                    send_message(chat_id, "⏳ Sunucu durumu analiz ediliyor...")
                    subprocess.run(["bash", "./backup_healthcheck.sh", "--status"], stdin=subprocess.DEVNULL)
                    
                elif text == '/yedekle':
                    send_message(chat_id, "📦 Manuel yedekleme başlatılıyor...")
                    subprocess.run(["bash", "./backup_healthcheck.sh"], stdin=subprocess.DEVNULL)
                
                elif text == '/log':
                    log_msg("-> /log komutu algılandı, loglar gönderiliyor...")
                    try:
                        with open(get_log_file(), "r", encoding="utf-8") as f:
                            lines = f.readlines()
                            last_lines = "".join(lines[-20:])
                        send_message(chat_id, f"📝 **Son Sistem Logları:**\n```\n{last_lines}\n```")
                    except Exception as e:
                        send_message(chat_id, f"❌ Log dosyası okunamadı: {e}")
                        
                elif text.startswith('/restart '):
                    service = text.split(' ', 1)[1][:20].strip()
                    if re.match(r'^[a-zA-Z0-9_-]+$', service):
                        send_message(chat_id, f"🔄 {service} servisi yeniden başlatılıyor...")
                        res = subprocess.run(["sudo", "systemctl", "restart", service], capture_output=True, text=True)
                        if res.returncode == 0:
                            send_message(chat_id, f"✅ {service} başarıyla yeniden başlatıldı!")
                            log_msg(f"✅ {service} başarıyla yeniden başlatıldı!")
                            subprocess.run(["bash", "./backup_healthcheck.sh", "--status"], stdin=subprocess.DEVNULL)
                        else:
                            send_message(chat_id, f"❌ {service} başlatılamadı!\nHata: {res.stderr}")
                            log_msg(f"❌ {service} başlatılamadı! Hata: {res.stderr}")
                    else:
                        send_message(chat_id, "❌ Geçersiz servis adı! Lütfen düzgün bir format girin.")
                else:
                    log_msg(f"-> Bilinmeyen komut: {text}")
                    
        except Exception as e:
            log_msg(f"⚠️ HATA OLUŞTU: {e}")
            time.sleep(5)

if __name__ == '__main__':
    main()
