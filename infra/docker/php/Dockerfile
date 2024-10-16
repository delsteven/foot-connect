ARG PHP_VERSION=1-php8.3.12-alpine
ARG NODE_VERSION=20.18.0-alpine3.20
ARG COMPOSER_VERSION=2.8.1

# PHP CONTAINER
FROM composer:${COMPOSER_VERSION} AS composer
FROM dunglas/frankenphp:${PHP_VERSION} AS builder
ARG BUILD_PATH=.
USER root

# GD INSTALLATION
#RUN apk add --no-cache findutils gd freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev perl && \
#  docker-php-ext-configure gd --with-freetype --with-jpeg && \
#  NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
#  docker-php-ext-install -j${NPROC} gd && \
#  apk del --no-cache freetype-dev libpng-dev libjpeg-turbo-dev

# SUPERVISOR INSTALLATION
# RUN apk add --no-cache tzdata supervisor && mkdir /etc/supervisor.d/
# COPY ${BUILD_PATH}/infra/docker/php/conf/supervisor.ini /etc/supervisor.d/supervisor.ini
# CMD /usr/bin/supervisord --pidfile=/run/supervisord.pid -n -c /etc/supervisord.conf

## Dev application
FROM builder AS dev
ARG BUILD_PATH=.

RUN apk add --no-cache --virtual .build-deps  $PHPIZE_DEPS  \
    && apk add --no-cache git \
    && pecl install pcov apcu \
    && apk add --no-cache \
    postgresql-dev \
    && docker-php-ext-enable pcov apcu \
    && pecl clear-cache \
    && apk del .build-deps \
    && rm -rf /tmp/*

COPY ${BUILD_PATH}/infra/docker/php/conf/symfony.ini /usr/local/etc/php/conf.d/symfony.ini

RUN docker-php-ext-install opcache pdo pdo_pgsql
COPY ${BUILD_PATH}/infra/docker/php/conf/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

COPY --from=composer /usr/bin/composer /usr/bin/composer

COPY ${BUILD_PATH}/infra/docker/php/scripts/install-symfony.sh /usr/local/bin/
RUN git config --global --add safe.directory /app

# BUILD ASSETS
FROM node:${NODE_VERSION} AS node-builder
ARG APP_PATH=.
WORKDIR /app

### Production
#FROM builder AS prod
#ENV APP_ENV prod
#RUN  sed -i 's/opcache.validate_timestamps.*/opcache.validate_timestamps=0/' /usr/local/etc/php/conf.d/symfony.ini
#COPY --from=node-builder /app/public /app/public
#COPY --chown=www-data . /app
#RUN composer install -o -a --no-dev && chown -R www-data .
#RUN rm -rf infra/ /usr/bin/composer
#USER appuser
