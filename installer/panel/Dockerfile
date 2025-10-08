FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash","-o","pipefail","-c"]

RUN apt-get update && apt-get install -y --no-install-recommends     tzdata ca-certificates curl wget gnupg lsb-release gettext-base     supervisor rsyslog cron logrotate     nginx php-fpm php-cli php-curl php-xml php-mysql php-mbstring php-zip php-intl php-gd php-imap     mariadb-client unzip tar crudini &&     apt-get clean && rm -rf /var/lib/apt/lists/*

# Timezone configurable at runtime; keep default as UTC to avoid surprises
RUN ln -snf /usr/share/zoneinfo/${TZ:-Etc/UTC} /etc/localtime && echo ${TZ:-Etc/UTC} >/etc/timezone || true

# Fetch ISPConfig (rolling stable tarball)
RUN set -euo pipefail;     URL_S="https://www.ispconfig.org/downloads/ISPConfig-3-stable.tar.gz";     curl -fSL "$URL_S" -o /tmp/ISPConfig.tar.gz &&     mkdir -p /opt && tar -xzf /tmp/ISPConfig.tar.gz -C /opt && rm /tmp/ISPConfig.tar.gz &&     ln -s /opt/ispconfig3_install /opt/ispconfig-installer &&     if [ -d /opt/ispconfig3_install/docs/autoinstall_samples ]; then         cp -a /opt/ispconfig3_install/docs/autoinstall_samples/*.sample /opt/ispconfig3_install/install/ || true ;     fi

# Minimal default site so nginx test succeeds before install writes real vhosts
# Minimal default site so nginx test succeeds before install writes real vhosts

RUN set -eux; \
    mkdir -p /var/www/html; \
    printf '%s\n' '<!doctype html><title>ISPConfig container is running</title>' > /var/www/html/index.html; \
    cat >/etc/nginx/sites-available/default <<'EOF'
server {
  listen 80 default_server;
  server_name _;
  root /var/www/html;
  index index.html;
  location /status { return 200 "OK\n"; }
}
EOF

RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

RUN mkdir -p /var/lib/isp-state /var/log/ispconfig

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisord.d/ /etc/supervisor/conf.d/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80 443 8080
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
