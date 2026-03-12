FROM php:5.6-fpm

LABEL maintainer="Laravel Docker Platform"
LABEL php.version="5.6"

# PHP 5.6 requires Debian-based image for full extension compatibility
RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libssl-dev \
        libzip-dev \
        mariadb-client \
        unzip \
        git \
        curl \
        zip \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        exif \
        gd \
        intl \
        mbstring \
        mcrypt \
        opcache \
        pdo \
        pdo_mysql \
        pcntl \
        sockets \
        zip

RUN pecl install redis-4.3.0 && docker-php-ext-enable redis
RUN pecl install xdebug-2.5.5 && docker-php-ext-enable xdebug

# PHP 5.6 requires Composer 1.x
COPY --from=composer:1 /usr/bin/composer /usr/bin/composer

COPY www.conf /usr/local/etc/php-fpm.d/www.conf

WORKDIR /var/www

EXPOSE 9000

CMD ["php-fpm"]
