# --- Estágio 1: Dependências do PHP ---
# Usa a imagem oficial do Composer para instalar dependências
FROM composer:2 as vendor

WORKDIR /app
# Copia somente os arquivos necessários para o composer
COPY database/ database/
COPY composer.json composer.json
COPY composer.lock composer.lock
# Instala somente dependências de produção de forma otimizada
RUN composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --no-dev \
    --optimize-autoloader


# --- Estágio 2: Assets com Node.js (CSS/JS) ---
# Usa uma imagem do Node para compilar os assets
FROM node:18 as node_assets

WORKDIR /app
COPY package.json package.json
COPY webpack.mix.js webpack.mix.js
COPY resources/ resources/
RUN npm install
RUN npm run production


# --- Estágio 3: Imagem Final de Produção ---
# Usa uma imagem leve do PHP-FPM com Alpine Linux
FROM php:8.2-fpm-alpine

# Instala dependências do sistema e extensões do PHP necessárias para o Krayin/Laravel
RUN apk add --no-cache \
        libpng-dev \
        libzip-dev \
        jpeg-dev \
        freetype-dev \
        nginx \
        supervisor \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql zip

# Copia os arquivos da aplicação e dos estágios anteriores
WORKDIR /app
COPY --from=vendor /app/vendor/ vendor/
COPY --from=node_assets /app/public/ public/
COPY . .

# Copia os arquivos de configuração para Nginx e Supervisor
COPY .docker/nginx.conf /etc/nginx/nginx.conf
COPY .docker/supervisord.conf /etc/supervisord.conf

# Ajusta as permissões das pastas que o Laravel precisa escrever
RUN chown -R www-data:www-data /app \
    && chmod -R 775 /app/storage /app/bootstrap/cache

# Expor a porta 80, que o Nginx usará
EXPOSE 80

# Comando para iniciar o Supervisor, que vai gerenciar o Nginx e o PHP-FPM
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]