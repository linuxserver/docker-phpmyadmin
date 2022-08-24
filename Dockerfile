FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.15

ARG BUILD_DATE
ARG VERSION
ARG PHPMYADMIN_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="TheSpad"

ARG PHPMYADMIN_RELEASE_GPG_KEY="3D06A59ECE730EB71B511C17CE752F178259BD92"
ENV MAX_EXECUTION_TIME 600
ENV MEMORY_LIMIT 512M
ENV UPLOAD_LIMIT 8192K

RUN \
  apk add --no-cache --virtual=build-dependencies \
    gpg \
    gpg-agent \
    gnupg-dirmngr && \
  apk add -U --upgrade --no-cache \
    curl \
    jq \
    php8-bz2 \
    php8-curl \
    php8-dom \
    php8-gd \
    php8-iconv \
    php8-mysqli \
    php8-opcache \
    php8-pecl-uploadprogress \
    php8-tokenizer \
    php8-zip && \
  echo "**** configure php-fpm to pass env vars ****" && \
  sed -E -i 's/^;?clear_env ?=.*$/clear_env = no/g' /etc/php8/php-fpm.d/www.conf && \
  grep -qxF 'clear_env = no' /etc/php8/php-fpm.d/www.conf || echo 'clear_env = no' >> /etc/php8/php-fpm.d/www.conf && \
  echo "env[PATH] = /usr/local/bin:/usr/bin:/bin" >> /etc/php8/php-fpm.conf && \
  echo "**** setup php opcache ****" && \  
  { \
      echo 'opcache.memory_consumption=128'; \
      echo 'opcache.interned_strings_buffer=8'; \
      echo 'opcache.max_accelerated_files=4000'; \
      echo 'opcache.revalidate_freq=2'; \
      echo 'opcache.fast_shutdown=1'; \
  } > /etc/php8/conf.d/opcache-recommended.ini; \
  \
  { \
      echo 'session.cookie_httponly=1'; \
      echo 'session.use_strict_mode=1'; \
  } > /etc/php8/conf.d/session-strict.ini; \
  \
  { \
      echo 'allow_url_fopen=Off'; \
      echo 'max_execution_time=${MAX_EXECUTION_TIME}'; \
      echo 'max_input_vars=10000'; \
      echo 'memory_limit=${MEMORY_LIMIT}'; \
      echo 'post_max_size=${UPLOAD_LIMIT}'; \
      echo 'upload_max_filesize=${UPLOAD_LIMIT}'; \
  } > /etc/php8/conf.d/phpmyadmin-misc.ini && \
  echo "**** install phpmyadmin ****" && \
  mkdir -p /app/www/public && \
  if [ -z ${PHPMYADMIN_VERSION+x} ]; then \
    PHPMYADMIN_VERSION=$(curl -sL 'https://www.phpmyadmin.net/home_page/version.txt' \
    | head -n 1 | cut -d ' ' -f 1); \
  fi && \
  curl -s -o \
    /tmp/phpmyadmin.tar.xz -L \
    "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.xz" && \
  curl -s -o \
    "/tmp/phpmyadmin.tar.xz.asc" -L \
    "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.xz.asc" && \
  export GNUPGHOME="$(mktemp -d)" && \
  gpg --batch -q --keyserver keyserver.ubuntu.com --recv-keys "$PHPMYADMIN_RELEASE_GPG_KEY" \
      || gpg --batch -q --keyserver pgp.mit.edu --recv-keys "$PHPMYADMIN_RELEASE_GPG_KEY" \
      || gpg --batch -q --keyserver keyserver.pgp.com --recv-keys "$PHPMYADMIN_RELEASE_GPG_KEY" \
      || gpg --batch -q --keyserver keys.openpgp.org --recv-keys "$PHPMYADMIN_RELEASE_GPG_KEY" && \
  if ! gpg --batch -q --verify "/tmp/phpmyadmin.tar.xz.asc" "/tmp/phpmyadmin.tar.xz"; then \
    echo "File signature mismatch" \
    exit 1; \
  fi && \
  tar xf \
    /tmp/phpmyadmin.tar.xz -C \
    /app/www/public/ --strip-components=1 && \
  sed -i "s@'configFile' =>.*@'configFile' => '/config/phpmyadmin/config.inc.php',@" "/app/www/public/libraries/vendor_config.php" && \    
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* \
    /app/www/public/setup

COPY root/ /

EXPOSE 80 443
