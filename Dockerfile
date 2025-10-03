# --- Estágio 1: Dependências do PHP ---
# Modificação: Usamos uma imagem base do PHP para poder instalar extensões
FROM php:8.2-cli-alpine as vendor

# Instala o Composer e as extensões necessárias para o 'composer install'
RUN apk add --no-cache libzip-dev gd-dev libpng-dev libjpeg-turbo-dev freetype-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql zip calendar \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /app
COPY database/ database/
COPY composer.json composer.json
COPY composer.lock composer.lock
# Agora o composer install funcionará, pois as extensões existem
RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --no-dev \
    --optimize-autoloader


# --- Estágio 2: Assets com Node.js (usando Vite) ---
FROM node:18 as node_assets

WORKDIR /app
COPY package.json package.json
COPY vite.config.js vite.config.js
COPY public/ public/
RUN npm install
RUN npm run build


# --- Estágio 3: Imagem Final de Produção ---
FROM php:8.2-fpm-alpine

# Instala as mesmas dependências e extensões da imagem final
RUN apk add --no-cache \
        libpng-dev \
        libzip-dev \
        jpeg-dev \
        freetype-dev \
        nginx \
        supervisor \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql zip calendar

# Copia os arquivos da aplicação e dos estágios anteriores
WORKDIR /app
COPY --from=vendor /app/vendor/ vendor/
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