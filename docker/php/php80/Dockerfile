FROM php:8.0-fpm-alpine

LABEL maintainer="Laravel Docker Platform"
LABEL php.version="8.0"

RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        linux-headers \
    && apk add --no-cache \
        bash curl freetype-dev git icu-dev imagemagick-dev jpeg-dev \
        libjpeg-turbo-dev libpng-dev libwebp-dev libzip-dev \
        mariadb-client oniguruma-dev openssh-client openssl-dev unzip zip zlib-dev

RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        bcmath exif gd intl mbstring opcache pdo pdo_mysql pcntl sockets zip

RUN pecl install redis-5.3.7 && docker-php-ext-enable redis
RUN pecl install imagick && docker-php-ext-enable imagick
RUN pecl install xdebug && docker-php-ext-enable xdebug

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN apk del .build-deps && rm -rf /var/cache/apk/* /tmp/*
COPY php80/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
WORKDIR /var/www
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
