FROM php:8.2-fpm-alpine3.21

LABEL maintainer="michal@sotolar.com"

ENV PHPMYADMIN_VERSION=5.2.2
ARG SHA256=f881819a3b11e653b0212afaf0cc105db85c767715cb3f5852670f7fc36c9669
ADD https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMIN_VERSION/phpMyAdmin-$PHPMYADMIN_VERSION-all-languages.tar.xz /usr/src/phpMyAdmin.tar.xz

ENV PHP_MAX_EXECUTION_TIME 600
ENV PHP_MEMORY_LIMIT 512M
ENV PHP_UPLOAD_LIMIT 2048K

WORKDIR /usr/local/phpmyadmin

RUN set -ex; \
    apk add --no-cache \
        rsync \
    ; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        bzip2-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libxpm-dev \
        libzip-dev \
    ; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-xpm; \
    docker-php-ext-install -j "$(nproc)" \
        bz2 \
        gd \
        mysqli \
        opcache \
        zip \
        bcmath \
    ; \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache --virtual .phpmyadmin-rundeps $runDeps; \
    apk del --no-network .build-deps; \
    { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
    } > $PHP_INI_DIR/conf.d/opcache-recommended.ini; \
    \
    { \
        echo 'session.cookie_httponly=1'; \
        echo 'session.use_strict_mode=1'; \
    } > $PHP_INI_DIR/conf.d/session-strict.ini; \
    \
    { \
        echo 'expose_php=off'; \
        echo 'allow_url_fopen=off'; \
        echo 'max_execution_time=${PHP_MAX_EXECUTION_TIME}'; \
        echo 'max_input_vars=10000'; \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
        echo 'post_max_size=${PHP_UPLOAD_LIMIT}'; \
        echo 'upload_max_filesize=${PHP_UPLOAD_LIMIT}'; \
    } > $PHP_INI_DIR/conf.d/phpmyadmin-misc.ini; \
    echo "$SHA256 */usr/src/phpMyAdmin.tar.xz" | sha256sum -c -; \
    rm -rf \
        /usr/src/php.tar.xz \
        /usr/src/php.tar.xz.asc \
        /var/cache/apk/* \
        /var/tmp/* \
        /tmp/*

COPY resources/config.inc.php /etc/phpmyadmin/config.inc.php
COPY resources/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY resources/exclude.txt /usr/src/phpMyAdmin.exclude

VOLUME /usr/local/phpmyadmin

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
