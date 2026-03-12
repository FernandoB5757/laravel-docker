FROM php:8.3-fpm-alpine

LABEL maintainer="Laravel Docker Platform"
LABEL php.version="8.3"

# Build dependencies
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        linux-headers \
    && apk add --no-cache \
        bash \
        curl \
        freetype-dev \
        git \
        icu-dev \
        imagemagick-dev \
        jpeg-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libxpm-dev \
        libzip-dev \
        mariadb-client \
        oniguruma-dev \
        openssl-dev \
        unzip \
        zip \
        zlib-dev

# Install PHP extensions
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        exif \
        gd \
        intl \
        mbstring \
        opcache \
        pdo \
        pdo_mysql \
        pcntl \
        sockets \
        zip

# Redis extension
RUN pecl install redis && docker-php-ext-enable redis

# Imagick extension
RUN pecl install imagick && docker-php-ext-enable imagick

# Xdebug
RUN pecl install xdebug && docker-php-ext-enable xdebug

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Cleanup build dependencies
RUN apk del .build-deps && rm -rf /var/cache/apk/* /tmp/*

# Configure PHP-FPM
COPY www.conf /usr/local/etc/php-fpm.d/www.conf

WORKDIR /var/www

EXPOSE 9000

CMD ["php-fpm"]
