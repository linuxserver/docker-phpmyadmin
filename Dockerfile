FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.14

ARG BUILD_DATE
ARG VERSION
ARG PHPMYADMIN_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="TheSpad"

ENV MAX_EXECUTION_TIME 600
ENV MEMORY_LIMIT 512M
ENV UPLOAD_LIMIT 8192K

RUN \
  apk add -U --upgrade --no-cache \
    curl \
    jq \
    php7-gd \
    php7-bz2 \
    php7-mysqli \
    php7-opcache \
    php7-iconv \
    php7-dom \
    php7-tokenizer \
    php7-curl \
    php7-zip && \
  { \
      echo 'opcache.memory_consumption=128'; \
      echo 'opcache.interned_strings_buffer=8'; \
      echo 'opcache.max_accelerated_files=4000'; \
      echo 'opcache.revalidate_freq=2'; \
      echo 'opcache.fast_shutdown=1'; \
  } > /etc/php7/conf.d/opcache-recommended.ini; \
  \
  { \
      echo 'session.cookie_httponly=1'; \
      echo 'session.use_strict_mode=1'; \
  } > /etc/php7/conf.d/session-strict.ini; \
  \
  { \
      echo 'allow_url_fopen=Off'; \
      echo 'max_execution_time=${MAX_EXECUTION_TIME}'; \
      echo 'max_input_vars=10000'; \
      echo 'memory_limit=${MEMORY_LIMIT}'; \
      echo 'post_max_size=${UPLOAD_LIMIT}'; \
      echo 'upload_max_filesize=${UPLOAD_LIMIT}'; \
  } > /etc/php7/conf.d/phpmyadmin-misc.ini && \
  echo "**** install phpmyadmin ****" && \
  mkdir -p /app/phpmyadmin && \
  if [ -z ${PHPMYADMIN_VERSION+x} ]; then \
    PHPMYADMIN_VERSION=$(curl -sX GET 'https://api.github.com/repos/phpmyadmin/phpmyadmin/releases' \
    | jq -r '.[] | select (.prerelease==false)' \
    | jq -rs 'max_by(.name | split(".") | map(tonumber)) | .name'); \
  fi && \
  curl -s -o \
    /tmp/phpmyadmin.tar.xz -L \
    "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.xz" && \
  tar xf \
    /tmp/phpmyadmin.tar.xz -C \
    /app/phpmyadmin/ --strip-components=1 && \
  sed -i "s@'configFile' =>.*@'configFile' => '/config/phpmyadmin/config.inc.php',@" "/app/phpmyadmin/libraries/vendor_config.php" && \
  sed -i 's@;clear_env = no@clear_env = no@' "/etc/php7/php-fpm.d/www.conf" && \
  rm -rf \
    /tmp/*

COPY root/ /

EXPOSE 80

VOLUME /config