#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ==================================================
# Параметры и проверки
# ==================================================

if [ $# -eq 0 ]; then
    echo "Использование: $0 username [domain]"
    echo "Укажите имя пользователя в качестве аргумента"
    echo "Опционально: доменное имя для виртуального хоста"
    exit 1
fi

USERNAME="$1"
DOMAIN="${2:-example.com}"

if [ "$EUID" -ne 0 ]; then
    echo "Запустите скрипт с правами root (sudo)"
    exit 1
fi

if ! id "$USERNAME" &>/dev/null; then
    echo "Пользователь $USERNAME не существует!"
    exit 1
fi

# ==================================================
# Функции
# ==================================================

check_error() {
    if [ $? -ne 0 ]; then
        echo "Ошибка при выполнении: $1"
        exit 1
    fi
}

check_nginx_config() {
    echo "Проверка конфигурации Nginx..."
    nginx -t 2>&1 | tee /tmp/nginx_test.log
    local status=$?
    
    if [ $status -ne 0 ]; then
        echo "❌ Ошибка конфигурации Nginx:"
        grep -i error /tmp/nginx_test.log
        echo "📋 Полный лог проверки: /tmp/nginx_test.log"
        return 1
    else
        echo "✅ Конфигурация Nginx корректна"
        return 0
    fi
}

# ==================================================
# Основная установка
# ==================================================

echo "Обновление системы..."
apt update && apt upgrade -y
check_error "Обновление системы"

echo "Установка базовых утилит..."
apt install -y \
    sudo curl wget git htop tree tmux mc ncdu jq \
    ripgrep fzf dnsutils net-tools iputils-ping \
    traceroute mtr-tiny tcpdump nmap sshfs rsync \
    unzip p7zip-full ca-certificates gnupg lsb-release \
    zsh tar build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev \
    libncursesw5-dev xz-utils tk-dev libxml2-dev \
    libxmlsec1-dev libffi-dev liblzma-dev sysstat \
    iotop cifs-utils vim expect xclip 
check_error "Установка базовых утилит"

echo "Обновление репозиториев перед установкой Nginx..."
apt update
check_error "Обновление репозиториев"

echo "Установка Nginx и сопутствующих пакетов..."
apt install -y \
    nginx nginx-extras \
    openssl certbot python3-certbot-nginx \
    php php-cli php-fpm php-curl php-gd \
    php-mysql php-mbstring php-xml php-zip \
    php-json php-bcmath php-intl php-soap \
    php-xmlrpc mariadb-server mariadb-client \
    postfix mailutils
check_error "Установка Nginx и сопутствующих пакетов"

# ==================================================
# Определение версии PHP
# ==================================================

echo "Определение версии PHP..."
PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "Обнаружена версия PHP: $PHP_VERSION"

# ==================================================
# Настройка пользователя
# ==================================================

echo "Добавление пользователя в группы..."
usermod -aG sudo "$USERNAME"
usermod -aG www-data "$USERNAME"
check_error "Добавление пользователя в группы"

# ==================================================
# Настройка Nginx
# ==================================================

echo "Настройка Nginx..."
mkdir -p /var/www/$DOMAIN/{public_html,logs,backups}
chown -R $USERNAME:www-data /var/www/$DOMAIN
chmod -R 755 /var/www/$DOMAIN

echo "Создание виртуального хоста Nginx..."
cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN www.$DOMAIN;
    root /var/www/$DOMAIN/public_html;
    index index.php index.html index.htm;

    access_log /var/www/$DOMAIN/logs/access.log;
    error_log /var/www/$DOMAIN/logs/error.log;

    # Безопасность
    server_tokens off;

    # Основная директория
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # Обработка PHP
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Безопасность для PHP
        fastcgi_param PHP_ADMIN_VALUE "open_basedir=/var/www/$DOMAIN/public_html:/usr/share/phpmyadmin:/tmp";
    }

    # Запрет доступа к скрытым файлам
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Запрет доступа к файлам логов
    location ~* \.(log|sql|tar|gz)$ {
        deny all;
    }

    # Кэширование статических файлов
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # phpMyAdmin 5.2.3
    location /phpmyadmin {
        root /usr/share/;
        index index.php index.html index.htm;

        location ~ ^/phpmyadmin/(.+.php)\$ {
            try_files \$uri =404;
            root /usr/share/;
            fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
            
            # Безопасность для phpMyAdmin
            fastcgi_param PHP_ADMIN_VALUE "open_basedir=/usr/share/phpmyadmin/:/etc/phpmyadmin/:/var/lib/phpmyadmin/:/tmp/";
        }

        location ~* ^/phpmyadmin/(.+.(jpg|jpeg|png|gif|ico|css|js|pdf|txt))\$ {
            root /usr/share/;
            expires 30d;
            access_log off;
        }
        
        # Запрет доступа к чувствительным файлам
        location ~ ^/phpmyadmin/(tmp|sql|vendor|libraries|setup) {
            deny all;
            access_log off;
            log_not_found off;
        }
    }

    # Редирект с /phpMyAdmin на /phpmyadmin
    location /phpMyAdmin {
        return 301 /phpmyadmin;
    }
}

# HTTPS конфигурация (будет активирована после certbot)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name $DOMAIN www.$DOMAIN;
    root /var/www/$DOMAIN/public_html;
    index index.php index.html index.htm;

    # Временные самоподписанные сертификаты
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    # Настройки SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    access_log /var/www/$DOMAIN/logs/ssl_access.log;
    error_log /var/www/$DOMAIN/logs/ssl_error.log;

    # Безопасность
    server_tokens off;

    # Заголовки безопасности
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Основная директория
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # Обработка PHP
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Безопасность для PHP
        fastcgi_param PHP_ADMIN_VALUE "open_basedir=/var/www/$DOMAIN/public_html:/usr/share/phpmyadmin:/tmp";
    }

    # Запрет доступа к скрытым файлам
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Запрет доступа к файлам логов
    location ~* \.(log|sql|tar|gz)$ {
        deny all;
    }

    # Кэширование статических файлов
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # phpMyAdmin 5.2.3
    location /phpmyadmin {
        root /usr/share/;
        index index.php index.html index.htm;

        location ~ ^/phpmyadmin/(.+.php)\$ {
            try_files \$uri =404;
            root /usr/share/;
            fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
            
            # Безопасность для phpMyAdmin
            fastcgi_param PHP_ADMIN_VALUE "open_basedir=/usr/share/phpmyadmin/:/etc/phpmyadmin/:/var/lib/phpmyadmin/:/tmp/";
        }

        location ~* ^/phpmyadmin/(.+.(jpg|jpeg|png|gif|ico|css|js|pdf|txt))\$ {
            root /usr/share/;
            expires 30d;
            access_log off;
        }
        
        # Запрет доступа к чувствительным файлам
        location ~ ^/phpmyadmin/(tmp|sql|vendor|libraries|setup) {
            deny all;
            access_log off;
            log_not_found off;
        }
    }

    # Редирект с /phpMyAdmin на /phpmyadmin
    location /phpMyAdmin {
        return 301 /phpmyadmin;
    }
}
EOF

# Активация сайта
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
check_error "Настройка виртуального хоста Nginx"

echo "Настройка безопасности Nginx..."
# Удаляем старый конфиг если существует
rm -f /etc/nginx/conf.d/security.conf

cat > /etc/nginx/conf.d/security.conf << 'EOF'
# Базовые настройки безопасности

# Ограничение размеров запросов
client_max_body_size 10M;

# Таймауты
client_body_timeout 10;
client_header_timeout 10;
keepalive_timeout 30;
send_timeout 10;

# Буферизация
client_body_buffer_size 128K;
client_header_buffer_size 1k;
large_client_header_buffers 4 4k;
output_buffers 1 32k;
postpone_output 1460;

# Заголовки безопасности по умолчанию
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
EOF

# Немедленная проверка конфигурации
echo "Проверка конфигурации Nginx после настройки безопасности..."
if ! check_nginx_config; then
    echo "❌ Критическая ошибка в конфигурации Nginx"
    echo "⚠️ Проверьте файл: /etc/nginx/conf.d/security.conf"
    exit 1
fi

# ==================================================
# Настройка PHP-FPM
# ==================================================

echo "Настройка PHP-FPM..."
mkdir -p /var/log/php
chown www-data:www-data /var/log/php

# Настройка основного пула PHP-FPM (www.conf)
PHP_FPM_POOL_DIR="/etc/php/$PHP_VERSION/fpm/pool.d"
if [ -d "$PHP_FPM_POOL_DIR" ]; then
    echo "Настройка пула PHP-FPM в $PHP_FPM_POOL_DIR/www.conf"
    
    # Создаем бэкап оригинального конфига
    cp "$PHP_FPM_POOL_DIR/www.conf" "$PHP_FPM_POOL_DIR/www.conf.backup"
    
    # Обновляем настройки пула
    sed -i "s/^listen = .*/listen = \/var\/run\/php\/php$PHP_VERSION-fpm.sock/" "$PHP_FPM_POOL_DIR/www.conf"
    sed -i "s/^;listen.owner.*/listen.owner = www-data/" "$PHP_FPM_POOL_DIR/www.conf"
    sed -i "s/^;listen.group.*/listen.group = www-data/" "$PHP_FPM_POOL_DIR/www.conf"
    sed -i "s/^;listen.mode.*/listen.mode = 0660/" "$PHP_FPM_POOL_DIR/www.conf"
    
    # Обновляем настройки процесса
    sed -i "s/^pm = .*/pm = dynamic/" "$PHP_FPM_POOL_DIR/www.conf"
    sed -i "s/^pm.max_children = .*/pm.max_children = 5/" "$PHP_FPM_POOL_DIR/www.conf"
    sed -i "s/^pm.start_servers = .*/pm.start_servers = 2/" "$PHP_FPM_POOL_DIR/www.conf"
    sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = 1/" "$PHP_FPM_POOL_DIR/www.conf"
    sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = 3/" "$PHP_FPM_POOL_DIR/www.conf"
    
    # Добавляем настройки безопасности
    echo "; Настройки безопасности" >> "$PHP_FPM_POOL_DIR/www.conf"
    echo "php_admin_value[upload_max_filesize] = 10M" >> "$PHP_FPM_POOL_DIR/www.conf"
    echo "php_admin_value[post_max_size] = 10M" >> "$PHP_FPM_POOL_DIR/www.conf"
    echo "php_admin_value[max_execution_time] = 30" >> "$PHP_FPM_POOL_DIR/www.conf"
    echo "php_admin_value[memory_limit] = 128M" >> "$PHP_FPM_POOL_DIR/www.conf"
    echo "php_admin_value[error_log] = /var/log/php/php-error.log" >> "$PHP_FPM_POOL_DIR/www.conf"
    echo "php_admin_flag[log_errors] = on" >> "$PHP_FPM_POOL_DIR/www.conf"
    
    echo "Пул PHP-FPM успешно настроен"
else
    echo "Предупреждение: Директория PHP-FPM $PHP_FPM_POOL_DIR не найдена"
fi

# ==================================================
# Установка и настройка phpMyAdmin 5.2.3
# ==================================================

echo "Установка phpMyAdmin 5.2.3..."
cd /tmp

# Функция для загрузки phpMyAdmin
download_phpmyadmin() {
    local url="$1"
    local description="$2"
    
    echo "Попытка загрузки с: $description"
    if wget --timeout=30 --tries=3 -O phpmyadmin.tar.gz "$url"; then
        echo "Успешно загружено с: $description"
        return 0
    else
        echo "Ошибка загрузки с: $description"
        return 1
    fi
}

# Загрузка phpMyAdmin 5.2.3
echo "Загрузка phpMyAdmin версии 5.2.3..."
if download_phpmyadmin "https://files.phpmyadmin.net/phpMyAdmin/5.2.3/phpMyAdmin-5.2.3-all-languages.tar.gz" "официальный сайт (версия 5.2.3)"; then
    echo "✅ phpMyAdmin 5.2.3 успешно загружен"
    
    echo "Распаковка phpMyAdmin..."
    tar xzf phpmyadmin.tar.gz
    
    # Определяем имя распакованной директории для версии 5.2.3
    if [ -d "phpMyAdmin-5.2.3-all-languages" ]; then
        mv phpMyAdmin-5.2.3-all-languages /usr/share/phpmyadmin
        echo "✅ phpMyAdmin установлен в /usr/share/phpmyadmin"
    else
        echo "❌ Не удалось найти распакованную директорию phpMyAdmin-5.2.3-all-languages"
        echo "Содержимое /tmp:"
        ls -la /tmp | grep -i phpmyadmin
        exit 1
    fi
    
    # Настройка прав доступа
    mkdir -p /usr/share/phpmyadmin/tmp
    chown -R www-data:www-data /usr/share/phpmyadmin
    chmod 755 /usr/share/phpmyadmin
    chmod 755 /usr/share/phpmyadmin/tmp
    
    # Создание конфигурационного файла phpMyAdmin
    echo "Создание конфигурации phpMyAdmin..."
    cat > /usr/share/phpmyadmin/config.inc.php << 'EOF'
<?php
/* Конфигурация phpMyAdmin 5.2.3 */
$cfg['blowfish_secret'] = '$(openssl rand -base64 32)';
$cfg['DefaultLang'] = 'ru';
$cfg['ServerDefault'] = 1;
$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
$cfg['TempDir'] = '/usr/share/phpmyadmin/tmp';

/* Сервер MySQL */
$i = 1;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['host'] = 'localhost';
$cfg['Servers'][$i]['connect_type'] = 'tcp';
$cfg['Servers'][$i]['compress'] = false;
$cfg['Servers'][$i]['AllowNoPassword'] = false;

/* Дополнительные настройки */
$cfg['ForceSSL'] = false;
$cfg['ShowPhpInfo'] = false;
$cfg['ShowChgPassword'] = true;
$cfg['ShowCreateDb'] = true;
$cfg['SuggestDBName'] = true;

/* Настройки интерфейса */
$cfg['NavigationTreeEnableGrouping'] = true;
$cfg['NavigationTreeDbSeparator'] = '_';
$cfg['NavigationTreeTableSeparator'] = '__';
$cfg['MaxNavigationItems'] = 200;

/* Безопасность */
$cfg['LoginCookieValidity'] = 14400;
$cfg['AllowUserDropDatabase'] = false;
?>
EOF

    # Создание симлинка для доступа через веб
    ln -sf /usr/share/phpmyadmin /var/www/$DOMAIN/public_html/phpmyadmin
    
    echo "✅ phpMyAdmin 5.2.3 успешно установлен и настроен"
    
else
    echo "❌ Ошибка загрузки phpMyAdmin 5.2.3"
    echo "Попытка установки из репозитория..."
    if apt-cache show phpmyadmin > /dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
        echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
        
        apt install -y phpmyadmin
        if [ $? -eq 0 ]; then
            echo "✅ phpMyAdmin успешно установлен из репозитория"
            ln -sf /usr/share/phpmyadmin /var/www/$DOMAIN/public_html/phpmyadmin
        else
            echo "❌ Ошибка установки phpMyAdmin из репозитория"
            echo "Продолжаем без phpMyAdmin"
        fi
    else
        echo "❌ Пакет phpmyadmin не найден в репозиториях"
        echo "Продолжаем без phpMyAdmin"
    fi
fi

# ==================================================
# Настройка MariaDB
# ==================================================

echo "Настройка MariaDB..."
# Безопасная настройка MySQL
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'RootPassword123!';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

echo "Создание базы данных и пользователя для сайта..."
DB_NAME="${DOMAIN//./_}_db"
DB_USER="${DOMAIN//./_}_user"
DB_PASS="SitePassword123!"

mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Создание пользователя для phpMyAdmin
mysql -e "CREATE USER IF NOT EXISTS 'pma_user'@'localhost' IDENTIFIED BY 'PmaPassword123!';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'pma_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# ==================================================
# Настройка firewall
# ==================================================

echo "Настройка firewall..."
apt install -y ufw
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable
check_error "Настройка firewall"

# ==================================================
# Установка Zsh и плагинов
# ==================================================

echo "Установка и настройка Zsh..."
apt install -y zsh
check_error "Установка Zsh"

echo "Установка Oh My Zsh..."
su - "$USERNAME" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
check_error "Установка Oh My Zsh"

echo "Установка плагинов Zsh..."
su - "$USERNAME" -c 'git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'
su - "$USERNAME" -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'

echo "Настройка Zsh..."
cat > "/home/$USERNAME/.zshrc" << EOF
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="tjkirch"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting ssh-agent k9s debian kubectl lol man sudo )
source \$ZSH/oh-my-zsh.sh

# Nginx aliases
alias nginx-start='sudo systemctl start nginx'
alias nginx-stop='sudo systemctl stop nginx'
alias nginx-restart='sudo systemctl restart nginx'
alias nginx-reload='sudo systemctl reload nginx'
alias nginx-status='sudo systemctl status nginx'
alias nginx-logs='sudo tail -f /var/log/nginx/*.log'
alias nginx-error='sudo tail -f /var/log/nginx/error.log'
alias nginx-access='sudo tail -f /var/log/nginx/access.log'
alias nginx-test='sudo nginx -t'

# MySQL aliases
alias mysql-start='sudo systemctl start mariadb'
alias mysql-stop='sudo systemctl stop mariadb'
alias mysql-restart='sudo systemctl restart mariadb'
alias mysql-status='sudo systemctl status mariadb'

# PHP aliases
alias php-restart='sudo systemctl restart php$PHP_VERSION-fpm'

# phpMyAdmin aliases
alias pma-logs='sudo tail -f /var/log/php/*.log'
alias pma-dir='echo "phpMyAdmin расположен в /usr/share/phpmyadmin"'

# Website management
alias www-logs='cd /var/www'
alias www-edit='sudo vim /etc/nginx/sites-available/'

# Добавление путей к бинарникам
export PATH="\$HOME/.local/bin:\$PATH"
export PATH="/opt/nvim/bin:\$PATH"
EOF

chown "$USERNAME:$USERNAME" "/home/$USERNAME/.zshrc"

# ==================================================
# Настройка Midnight Commander
# ==================================================

echo "Настройка Midnight Commander..."
su - "$USERNAME" -c "mkdir -p ~/.config/mc"
cat > "/home/$USERNAME/.config/mc/ini" << 'EOF'
[Midnight-Commander]
confirm_exit=1
use_internal_edit=0
editor_edit_confirm_save=1

[Layout]
message_visible=0
command_prompt=1
keybar_visible=1
horizontal_split=0

[Panels]
auto_save_setup_panels=1
EOF

chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config/mc"

# ==================================================
# Настройка Tmux
# ==================================================

echo "Настройка Tmux..."
cat > "/home/$USERNAME/.tmux.conf" << 'EOF'
# ===== БАЗОВЫЕ НАСТРОЙКИ =====
# Установка префикса на Ctrl+a (вместо стандартного Ctrl+b)
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Нумерация окон с 1 вместо 0
set -g base-index 1
set -g pane-base-index 1

# Время отображения сообщений (мс)
set -g display-time 4000

# ===== МЫШЬ =====
# Включение поддержки мыши (включая прокрутку и выделение)
set -g mouse on

# Прокрутка мышью в режиме копирования
bind -T copy-mode-vi WheelUpPane send -N1 -X scroll-up
bind -T copy-mode-vi WheelDownPane send -N1 -X scroll-down

# ===== КОПИРОВАНИЕ И ВСТАВКА =====
# Использование системного буфера обмена
set -g set-clipboard on

# Копирование в буфер обмена Linux (xclip должен быть установлен)
bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -i -f -selection primary | xclip -i -selection clipboard"

# Включение режима vi для копирования
set-window-option -g mode-keys vi

# Копирование с помощью мыши (выделил - скопировал в буфер)
bind -T root DoubleClick1Pane select-pane -t= \; copy-mode -M \; send-keys -X select-word \; run-shell "sleep 0.1" \; send-keys -X copy-pipe-and-cancel "xclip -i -f -selection primary | xclip -i -selection clipboard"

# ===== ВНЕШНИЙ ВИД =====
# Цветовая схема (256 цветов)
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"

# Статус бар
set -g status on
set -g status-interval 1
set -g status-justify left
set -g status-bg black
set -g status-fg white
set -g status-left-length 20
set -g status-left "#[fg=green]#S #[fg=white]» "
set -g status-right "#[fg=white]%H:%M:%S #[fg=yellow]%d.%m.%Y"

# Цвет активной панели
set -g pane-border-style fg=colour8
set -g pane-active-border-style fg=green

# ===== УДОБНЫЕ СОЧЕТАНИЯ =====
# Перезагрузка конфигурации
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Разделение панелей (более интуитивные сочетания)
bind | split-window -h
bind - split-window -v

# Переключение панелей с помощью Alt+стрелок (удобно в SSH)
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Изменение размера панелей с помощью Ctrl+стрелок
bind -n C-Left resize-pane -L 5
bind -n C-Right resize-pane -R 5
bind -n C-Up resize-pane -U 5
bind -n C-Down resize-pane -D 5

# Быстрое переключение между окнами
bind -n C-PageUp previous-window
bind -n C-PageDown next-window
EOF

chown "$USERNAME:$USERNAME" "/home/$USERNAME/.tmux.conf"

# ==================================================
# Создание тестовых страниц
# ==================================================

echo "Создание тестовой страницы..."
cat > /var/www/$DOMAIN/public_html/index.html << EOF
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Сайт $DOMAIN</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 { color: #2c3e50; }
        .status {
            background: #27ae60;
            color: white;
            padding: 10px;
            border-radius: 5px;
            text-align: center;
        }
        .info {
            background: #3498db;
            color: white;
            padding: 15px;
            border-radius: 5px;
            margin: 10px 0;
        }
        .warning {
            background: #e74c3c;
            color: white;
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Добро пожаловать на $DOMAIN!</h1>
        <div class="status">Nginx сервер успешно настроен и работает</div>

        <div class="info">
            <h3>📊 Информация о сервере:</h3>
            <p><strong>Доменное имя:</strong> $DOMAIN</p>
            <p><strong>Директория сайта:</strong> /var/www/$DOMAIN/public_html</p>
            <p><strong>Веб-сервер:</strong> Nginx с PHP-FPM</p>
            <p><strong>База данных:</strong> MariaDB/MySQL</p>
            <p><strong>Владелец:</strong> $USERNAME</p>
            <p><strong>Время настройки:</strong> $(date)</p>
        </div>

        <div class="info">
            <h3>🔧 Панель управления:</h3>
            <p><strong>phpMyAdmin 5.2.3:</strong> <a href="/phpmyadmin" style="color: white;">/phpmyadmin</a></p>
            <p><em>Для доступа к phpMyAdmin используйте учетные данные MySQL</em></p>
        </div>

        <h3>🔧 Полезные команды:</h3>
        <ul>
            <li><code>nginx-restart</code> - перезапуск Nginx</li>
            <li><code>nginx-logs</code> - просмотр логов Nginx</li>
            <li><code>mysql-restart</code> - перезапуск MySQL</li>
            <li><code>php-restart</code> - перезапуск PHP-FPM</li>
            <li><code>pma-logs</code> - просмотр логов phpMyAdmin</li>
        </ul>

        <div class="warning">
            <h3>⚠️ Важные замечания:</h3>
            <p>• Настройте безопасные пароли для пользователей MySQL</p>
            <p>• Получите SSL сертификаты: <code>certbot --nginx -d $DOMAIN</code></p>
            <p>• Ограничьте доступ к phpMyAdmin по IP при необходимости</p>
        </div>

        <h3>📁 Структура проекта:</h3>
        <pre>
/var/www/$DOMAIN/
├── public_html/     # Корневая директория сайта
├── logs/           # Логи Nginx и PHP
└── backups/        # Резервные копии

/usr/share/phpmyadmin/  # Панель управления БД (версия 5.2.3)
        </pre>
    </div>
</body>
</html>
EOF

echo "Создание PHP info страницы..."
cat > /var/www/$DOMAIN/public_html/phpinfo.php << 'EOF'
<?php
// Ограничиваем доступ только с локального хоста
if ($_SERVER['REMOTE_ADDR'] !== '127.0.0.1' && $_SERVER['REMOTE_ADDR'] !== '::1') {
    header('HTTP/1.0 403 Forbidden');
    echo 'Доступ запрещен';
    exit;
}

phpinfo();
?>
EOF

# ==================================================
# Финальная настройка
# ==================================================

echo "Настройка прав доступа..."
chown -R "$USERNAME:www-data" "/var/www/$DOMAIN"
chmod -R 755 "/var/www/$DOMAIN"
chmod 600 "/var/www/$DOMAIN/public_html/phpinfo.php"

echo "Проверка конфигурации Nginx перед перезагрузкой..."
if ! check_nginx_config; then
    echo "❌ Ошибка конфигурации Nginx. Исправьте ошибки перед продолжением."
    exit 1
fi

echo "Перезагрузка служб..."
systemctl restart nginx
systemctl restart mariadb
systemctl restart php$PHP_VERSION-fpm
systemctl enable nginx
systemctl enable mariadb
systemctl enable php$PHP_VERSION-fpm
check_error "Перезагрузка служб"

echo "Настройка автоматических бэкапов..."
cat > /etc/cron.daily/nginx-backup << EOF
#!/bin/bash
BACKUP_DIR="/var/www/$DOMAIN/backups"
DATE=\$(date +%Y%m%d_%H%M%S)

# Создание бэкапа базы данных
mysqldump -u root -pRootPassword123! ${DOMAIN//./_}_db > \$BACKUP_DIR/db_backup_\$DATE.sql 2>/dev/null

# Создание бэкапа файлов сайта
tar -czf \$BACKUP_DIR/files_backup_\$DATE.tar.gz -C /var/www/$DOMAIN public_html

# Создание бэкапа конфигов Nginx
tar -czf \$BACKUP_DIR/nginx_config_backup_\$DATE.tar.gz -C /etc nginx

# Удаление старых бэкапов (старше 7 дней)
find \$BACKUP_DIR -name "*.sql" -mtime +7 -delete
find \$BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

chown -R $USERNAME:www-data \$BACKUP_DIR
EOF

chmod +x /etc/cron.daily/nginx-backup

echo "Смена оболочки на zsh..."
chsh -s /bin/zsh "$USERNAME"
check_error "Смена оболочки на Zsh"

echo "Очистка кеша..."
apt autoremove -y
apt clean

# ==================================================
# Вывод информации
# ==================================================

echo " "
echo "=================================================="
echo "🎉 Настройка Nginx сервера завершена!"
echo "=================================================="
echo " "
echo "📊 Информация о настройке:"
echo "   Доменное имя: $DOMAIN"
echo "   Пользователь: $USERNAME"
echo "   Директория сайта: /var/www/$DOMAIN/public_html"
echo "   База данных: ${DOMAIN//./_}_db"
echo "   Пользователь БД: ${DOMAIN//./_}_user"
echo "   Версия PHP: $PHP_VERSION"
echo "   phpMyAdmin: http://$DOMAIN/phpmyadmin (версия 5.2.3)"
echo " "
echo "🔧 Полезные команды:"
echo "   systemctl status nginx     - статус Nginx"
echo "   systemctl status mariadb   - статус MySQL"
echo "   systemctl status php$PHP_VERSION-fpm - статус PHP-FPM"
echo "   nginx-logs                 - логи Nginx (alias)"
echo "   mysql -u root -p           - подключение к MySQL"
echo "   pma-logs                   - логи phpMyAdmin (alias)"
echo " "
echo "🔐 Учетные данные MySQL:"
echo "   Root пользователь: root / RootPassword123!"
echo "   Пользователь БД: ${DOMAIN//./_}_user / SitePassword123!"
echo "   phpMyAdmin пользователь: pma_user / PmaPassword123!"
echo " "
echo "⚠️  Важные замечания:"
echo "   1. Смените пароли MySQL на более безопасные!"
echo "   2. Настройте SSL сертификаты: certbot --nginx -d $DOMAIN"
echo "   3. Убедитесь что firewall настроен правильно: ufw status"
echo "   4. Проверьте доступность сайта: curl http://localhost"
echo "   5. Для безопасности ограничьте доступ к phpMyAdmin при необходимости"
echo "   6. Версия phpmyadmin 5.3.2 проверьте ее актуальность на момент установки"
echo " "
echo "🔧 Дополнительные настройки:"
echo "   ✅ Midnight Commander с конфигурацией"
echo "   ✅ Tmux с улучшенной конфигурацией"
echo "   ✅ phpMyAdmin 5.2.3 с базовой конфигурацией"
echo "   ✅ Автоматические бэкапы настроены"
echo " "
echo "💡 Новые возможности:"
echo "   mc                         - запуск midnight commander"
echo "   tmux                       - запуск tmux с улучшенной конфигурацией"
echo "   Ctrl+a затем ?             - просмотр сочетаний клавиш tmux"
echo "   nginx-test                 - проверка конфигурации Nginx"
echo " "
echo "📚 Документация:"
echo "   phpMyAdmin 5.2.3: https://www.phpmyadmin.net/docs/"
echo "   Nginx: https://nginx.org/en/docs/"
echo "   MySQL: https://dev.mysql.com/doc/"
echo "=================================================="
