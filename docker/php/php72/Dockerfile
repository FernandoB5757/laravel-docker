FROM php:7.2-fpm-alpine

LABEL maintainer="Laravel Docker Platform"
LABEL php.version="7.2"

RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
    && apk add --no-cache \
        bash curl freetype-dev git icu-dev imagemagick-dev jpeg-dev \
        libjpeg-turbo-dev libpng-dev libzip-dev \
        mariadb-client openssl-dev unzip zip zlib-dev

RUN docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr \
    && docker-php-ext-install -j$(nproc) \
        bcmath exif gd intl mbstring opcache pdo pdo_mysql pcntl sockets zip

RUN pecl install redis-5.3.7 && docker-php-ext-enable redis
RUN pecl install imagick && docker-php-ext-enable imagick
RUN pecl install xdebug-3.1.6 && docker-php-ext-enable xdebug

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN apk del .build-deps && rm -rf /var/cache/apk/* /tmp/*
COPY www.conf /usr/local/etc/php-fpm.d/www.conf
WORKDIR /var/www
EXPOSE 9000
CMD ["php-fpm"]
