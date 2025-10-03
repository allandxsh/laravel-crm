# --- Estágio 1: Dependências do PHP ---
FROM composer:2 as vendor

WORKDIR /app
COPY database/ database/
COPY composer.json composer.json
COPY composer.lock composer.lock
RUN composer install --no-dev --no-scripts --prefer-dist --optimize-autoloader


# --- Estágio 2: Assets com Node.js (usando Vite) ---
FROM node:18 as node_assets

WORKDIR /app
COPY package.json package.json
# Correção: Procura pelo vite.config.js
COPY vite.config.js vite.config.js
# Correção: Copia a pasta public que contém os assets iniciais
COPY public/ public/
RUN npm install
RUN npm run build


# --- Estágio 3: Imagem Final de Produção ---
FROM php:8.2-fpm-alpine

# Instala dependências do sistema e extensões do PHP
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
# Correção: Copia os assets compilados pelo Vite
COPY --from=node_assets /app/public/ public/
COPY . .

# Copia as configurações do Nginx e Supervisor
COPY .docker/nginx.conf /etc/nginx/nginx.conf
COPY .docker/supervisord.conf /etc/supervisord.conf

# Ajusta permissões
RUN chown -R www-data:www-data /app \
    && chmod -R 775 /app/storage /app/bootstrap/cache

# Expor porta
EXPOSE 80

# Comando para iniciar o Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]