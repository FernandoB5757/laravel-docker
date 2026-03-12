FROM php:7.0-fpm-alpine

LABEL maintainer="Laravel Docker Platform"
LABEL php.version="7.0"

RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
    && apk add --no-cache \
        bash curl freetype-dev git icu-dev jpeg-dev \
        libjpeg-turbo-dev libpng-dev \
        mariadb-client openssh-client openssl-dev unzip zip zlib-dev

RUN docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr \
    && docker-php-ext-install -j$(nproc) \
        bcmath exif gd intl mbstring opcache pdo pdo_mysql pcntl sockets zip

RUN pecl install redis-4.3.0 && docker-php-ext-enable redis
RUN pecl install xdebug-2.7.2 && docker-php-ext-enable xdebug

COPY --from=composer:1 /usr/bin/composer /usr/bin/composer
RUN apk del .build-deps && rm -rf /var/cache/apk/* /tmp/*
COPY php70/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
WORKDIR /var/www
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
