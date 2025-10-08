# ISPConfig Docker — Sıfırdan ve .env'i değiştirmeden

Bu paket, **mevcut .env'ini HİÇ değiştirmeden** autoinstall.ini'yi üretir ve kurulum başlatır.

## Yapı
- `docker-compose.yml` — MariaDB (sadece root şifresi) + ISPConfig servisi
- `installer/panel/Dockerfile` — ISPConfig 3-stable indirir, servisleri kurar
- `installer/panel/docker-entrypoint.sh` — kurulumdan **ÖNCE** autoinstall.ini render eder
- `installer/autoinstall.ini.tmpl` — SADE; sadece elindeki .env anahtarlarını kullanır
- `installer/supervisord.conf` ve `installer/supervisord.d/*` — servis yönetimi

## Kullanım
1. Bu klasörü projenin köküne koy.
2. `.env` dosyan **dokunulmadan** kalsın (içinde FQDN, DB_HOST, DB_PORT, DB_ROOT_USER, DB_ROOT_PASSWORD, DB_NAME, DB_CHARSET vb. zaten var).
3. Çalıştır:
   ```sh
   docker compose build
   docker compose up -d
   ```
4. Log kontrolü:
   ```sh
   docker compose logs --tail=200 ispconfig
   ```

> Notlar
> - Postfix / Firewall uyarıları kapalıdır (`configure_mail=n`, `configure_firewall=n`). İstiyorsan .env'e `CONFIGURE_MAIL=y` ekleyebilirsin (zorunlu değil).
> - Let’s Encrypt, FQDN DNS’i doğruysa otomatik denenir; değilse self-signed kullanılır.
> - Önceki denemelerden kalan DB'yi sıfırlamak istersen: `docker compose down -v` (VERİ SİLİNİR!).
