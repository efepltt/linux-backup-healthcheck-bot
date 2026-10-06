import urllib.request
import urllib.parse
import json
import time
import subprocess
import os

# ==========================================
# Telegram Bot Dinleyici (Listener) Scripti
# ==========================================
# Bu script 7/24 çalışarak Telegram'dan gelen komutları dinler
# ve backup_healthcheck.sh scriptini tetikler.

TOKEN = "TOKEN" # BotFather'dan aldığınız token

def send_message(chat_id, text):
    url = f"https://api.telegram.org/bot{TOKEN}/sendMessage"
    data = urllib.parse.urlencode({'chat_id': chat_id, 'text': text}).encode('utf-8')
    try:
        urllib.request.urlopen(url, data=data)
    except Exception as e:
        print(f"❌ Mesaj gönderilemedi: {e}")

def main():
    if TOKEN == "TOKEN_BURAYA" or TOKEN == "":
        print("HATA: Lütfen telegram_listener.py dosyasını açıp TOKEN bilginizi girin!")
        return

    print("✅ Telegram dinleyicisi başlatıldı! Bota /durum veya /yedekle yazabilirsiniz...")
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
                
                print(f"\n📩 YENİ MESAJ GELDİ: '{text}' (Chat ID: {chat_id})")
                
                if text == '/durum':
                    print("-> /durum komutu algılandı, bash script çalıştırılıyor...")
                    send_message(chat_id, "⏳ Sunucu durumu analiz ediliyor...")
                    # DEVNULL ekledik ki bash betiği interaktif soru sormaya çalışıp kilitlenmesin
                    subprocess.run(["bash", "./backup_healthcheck.sh", "--status"], stdin=subprocess.DEVNULL)
                    
                elif text == '/yedekle':
                    print("-> /yedekle komutu algılandı, bash script çalıştırılıyor...")
                    send_message(chat_id, "📦 Manuel yedekleme başlatılıyor...")
                    subprocess.run(["bash", "./backup_healthcheck.sh"], stdin=subprocess.DEVNULL)
                else:
                    print(f"-> Sistemde tanımlı olmayan bir mesaj atıldı: {text}")
                    
        except Exception as e:
            print(f"⚠️ HATA OLUŞTU (Sistem 5 saniye bekliyor): {e}")
            time.sleep(5)

if __name__ == '__main__':
    main()
