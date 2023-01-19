FROM php:7.4.7-fpm-alpine3.12
ADD https://raw.githubusercontent.com/mlocati/docker-php-extension-installer/master/install-php-extensions /usr/local/bin/
RUN apk add --no-cache composer git
RUN /usr/local/bin/docker-php-ext-install intl opcache mysqli
RUN chmod uga+x /usr/local/bin/install-php-extensions && sync && \
    install-php-extensions memcached redis