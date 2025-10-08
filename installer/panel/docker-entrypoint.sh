#!/usr/bin/env bash
set -Eeuo pipefail

# ===== helpers =====
log()   { printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" ; }
fail()  { log "ERROR: $*"; exit 1; }
need()  { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }
reqenv(){ [[ -n "${!1:-}" ]] || fail "Missing required env: $1"; }

# ===== required tools =====
need envsubst
need curl
need php
need bash

# ===== env & paths =====
TEMPLATE_IN="${AUTOINSTALL_TEMPLATE:-/opt/templates/autoinstall.ini.tmpl}"
AUTOINSTALL_OUT="/opt/autoinstall.ini"
AI_LOG="/var/log/ispconfig/auto-installer.log"

ISPC_AI_BIN="/opt/ispconfig3_install/install/ispc3-ai.sh"      # auto-installer (varsa)
ISPC_PHP_INSTALLER="/opt/ispconfig3_install/install/install.php" # klasik installer (fallback)

INSTALL_FLAG_DIR="/var/lib/ispconfig"
INSTALL_FLAG="${INSTALL_FLAG_DIR}/.installed"

# .env'den beklenenler
reqenv DB_HOST
reqenv DB_PORT
reqenv DB_ROOT_USER
reqenv DB_ROOT_PASSWORD
reqenv DB_NAME

# ISPConfig panel DB kullanıcısı & şifre (şablon kullanıyor)
reqenv ISPCONFIG_DB_USER
reqenv ISPCONFIG_DB_PASS

# Panel/FQDN & dil gibi ilave alanlar
: "${FQDN:=panel.example.com}"
: "${INSTALL_LANG:=en}"
: "${RUN_AUTOINSTALL:=yes}"

# log dizinleri
mkdir -p /var/log/nginx /var/log/ispconfig

# ===== wait for DB =====
wait_db() {
  local host="${DB_HOST}" port="${DB_PORT}" user="${DB_ROOT_USER}" pass="${DB_ROOT_PASSWORD}"
  log "[entrypoint] Waiting for DB ${host}:${port} ..."
  for i in {1..120}; do
    if mysqladmin ping -h "${host}" -P "${port}" -u "${user}" -p"${pass}" --silent >/dev/null 2>&1; then
      log "[entrypoint] DB is up."
      return 0
    fi
    sleep 1
  done
  fail "Database not reachable at ${host}:${port}"
}

# ===== render autoinstall.ini =====
render_ini() {
  # envsubst’in kullanacağı değişkenleri sınırlı tutalım
  export DB_HOST DB_PORT DB_ROOT_USER DB_ROOT_PASSWORD DB_NAME
  export ISPCONFIG_DB_USER ISPCONFIG_DB_PASS
  export FQDN INSTALL_LANG

  [[ -f "${TEMPLATE_IN}" ]] || fail "Template not found: ${TEMPLATE_IN}"
  envsubst < "${TEMPLATE_IN}" > "${AUTOINSTALL_OUT}" || fail "envsubst failed"
  log "[entrypoint] autoinstall.ini rendered -> ${AUTOINSTALL_OUT}"
}

# ===== clean any stale install (mount-aware) =====
clean_stale() {
  log "[entrypoint] Stale ISPConfig install found. Cleaning for fresh install..."
  # o an silmek istediğimiz path altında olmayalım
  cd /

  # /usr/local/ispconfig mount point mi?
  if [[ -d /usr/local/ispconfig ]]; then
    if mountpoint -q /usr/local/ispconfig; then
      log "[entrypoint] /usr/local/ispconfig is a mount; wiping contents..."
      find /usr/local/ispconfig -mindepth 1 -maxdepth 1 -exec rm -rf {} + || true
    else
      log "[entrypoint] Removing /usr/local/ispconfig..."
      rm -rf /usr/local/ispconfig || true
    fi
  fi

  # Diğer kalıntılar
  rm -rf /etc/ispconfig /var/www/ispconfig /usr/local/ispconfig_interface 2>/dev/null || true
}

# ===== run installer =====
run_installer() {
  log "[entrypoint] Running ISPConfig installer (non-interactive) ..."

  # auto-installer varsa onu kullan
  if [[ -x "${ISPC_AI_BIN}" ]]; then
    bash "${ISPC_AI_BIN}" \
      --channel=stable \
      --use-nginx \
      --lang="${INSTALL_LANG}" \
      --autoinstall="${AUTOINSTALL_OUT}" \
      --i-know-what-i-am-doing | tee -a "${AI_LOG}"
  # yoksa klasik PHP installer
  elif [[ -f "${ISPC_PHP_INSTALLER}" ]]; then
    php -q "${ISPC_PHP_INSTALLER}" --autoinstall="${AUTOINSTALL_OUT}" | tee -a "${AI_LOG}"
  else
    fail "No installer found (missing ${ISPC_AI_BIN} and ${ISPC_PHP_INSTALLER})"
  fi

  # başarı kontrolü
  if [[ -f /usr/local/ispconfig/server/lib/config.inc.php ]]; then
    mkdir -p "${INSTALL_FLAG_DIR}"
    touch "${INSTALL_FLAG}" || fail "Cannot write ${INSTALL_FLAG}"
    log "[entrypoint] ISPConfig install done. Flag written: ${INSTALL_FLAG}"
  else
    fail "ISPConfig seems not installed (config.inc.php missing)."
  fi
}

# ===== main =====
wait_db
render_ini

# İlk çalıştırma politikası:
# - Eğer config.inc.php var ama flag yoksa, kurulu sayalım ve flag yazalım.
# - Eğer config yok ama dizinler varsa "kurulu sanılma"yı önlemek için temizleyip sıfırdan kur.
if [[ -f /usr/local/ispconfig/server/lib/config.inc.php ]]; then
  if [[ ! -f "${INSTALL_FLAG}" ]]; then
    mkdir -p "${INSTALL_FLAG_DIR}"
    touch "${INSTALL_FLAG}" || fail "Cannot write ${INSTALL_FLAG}"
    log "[entrypoint] Existing ISPConfig detected. Install flag created."
  else
    log "[entrypoint] ISPConfig already installed. Skipping installer."
  fi
else
  # config yok → kurulum denenmiş ama yarım kalmış olabilir; temizle ve kur
  clean_stale
  if [[ "${RUN_AUTOINSTALL}" == "yes" ]]; then
    run_installer
  else
    log "[entrypoint] RUN_AUTOINSTALL!=yes, skipping installer."
  fi
fi

# Nginx ve PHP-FPM dosya/dizinleri (bazı image’larda gerekebilir)
mkdir -p /run/php /var/run/php /var/run/nginx

log "[entrypoint] Starting supervisor..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
