#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Проверка аргументов
if [ $# -eq 0 ]; then
    echo "Использование: $0 username [domain]"
    echo "Укажите имя пользователя в качестве аргумента"
    echo "Опционально: доменное имя для виртуального хоста"
    exit 1
fi

USERNAME="$1"
DOMAIN="${2:-example.com}"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "Запустите скрипт с правами root (sudo)"
    exit 1
fi

# Проверка существования пользователя
if ! id "$USERNAME" &>/dev/null; then
    echo "Пользователь $USERNAME не существует!"
    exit 1
fi

# Функция для проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo "Ошибка при выполнении: $1"
        exit 1
    fi
}

# Обновление системы
apt update && apt upgrade -y
check_error "Обновление системы"

# Установка базовых утилит
apt install -y \
    sudo \
    curl \
    wget \
    git \
    htop \
    tree \
    tmux \
    mc \
    ncdu \
    jq \
    ripgrep \
    fzf \
    dnsutils \
    net-tools \
    iputils-ping \
    traceroute \
    mtr-tiny \
    tcpdump \
    nmap \
    sshfs \
    rsync \
    unzip \
    p7zip-full \
    ca-certificates \
    gnupg \
    lsb-release \
    zsh \
    tar \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    sysstat \
    iotop \
    cifs-utils \
    vim \
    expect

check_error "Установка базовых утилит"

# Установка Apache и сопутствующих пакетов
apt install -y \
    apache2 \
    apache2-utils \
    apache2-doc \
    libapache2-mod-ssl \
    libapache2-mod-security2 \
    openssl \
    certbot \
    python3-certbot-apache \
    php \
    php-cli \
    php-fpm \
    php-curl \
    php-gd \
    php-mysql \
    php-mbstring \
    php-xml \
    php-zip \
    php-json \
    php-bcmath \
    php-intl \
    php-soap \
    php-xmlrpc \
    mariadb-server \
    mariadb-client \
    postfix \
    mailutils

check_error "Установка Apache и сопутствующих пакетов"

# Добавление пользователя в sudo и www-data
sudo usermod -aG sudo "$USERNAME"
sudo usermod -aG www-data "$USERNAME"
check_error "Добавление пользователя в группы"

# Настройка Apache
a2enmod rewrite
a2enmod ssl
a2enmod headers
a2enmod security2

# Создание директорий для сайтов
mkdir -p /var/www/$DOMAIN/{public_html,logs,backups}
chown -R $USERNAME:www-data /var/www/$DOMAIN
chmod -R 755 /var/www/$DOMAIN

# Создание виртуального хоста
cat > /etc/apache2/sites-available/$DOMAIN.conf << EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    ServerAdmin webmaster@$DOMAIN
    DocumentRoot /var/www/$DOMAIN/public_html

    ErrorLog /var/www/$DOMAIN/logs/error.log
    CustomLog /var/www/$DOMAIN/logs/access.log combined

    <Directory /var/www/$DOMAIN/public_html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Security headers
        Header always set X-Content-Type-Options nosniff
        Header always set X-Frame-Options DENY
        Header always set X-XSS-Protection "1; mode=block"
        Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    </Directory>

    # PHP configuration
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php-fpm.sock|fcgi://localhost"
    </FilesMatch>
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot /var/www/$DOMAIN/public_html

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key

    ErrorLog /var/www/$DOMAIN/logs/ssl_error.log
    CustomLog /var/www/$DOMAIN/logs/ssl_access.log combined

    <Directory /var/www/$DOMAIN/public_html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Security headers
        Header always set X-Content-Type-Options nosniff
        Header always set X-Frame-Options DENY
        Header always set X-XSS-Protection "1; mode=block"
        Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    </Directory>

    # PHP configuration
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php-fpm.sock|fcgi://localhost"
    </FilesMatch>
</VirtualHost>
EOF

# Активация виртуального хоста
a2dissite 000-default.conf
a2ensite $DOMAIN.conf
check_error "Настройка виртуального хоста"

# Настройка безопасности Apache
cat > /etc/apache2/conf-available/security.conf << EOF
ServerTokens Prod
ServerSignature Off
TraceEnable Off
FileETag None

<Directory />
    Options -Indexes -Includes
    AllowOverride None
    Require all denied
</Directory>

<Directory /var/www/>
    Options -Indexes
    AllowOverride None
    Require all granted
</Directory>
EOF

# Настройка ModSecurity
cat > /etc/modsecurity/modsecurity.conf << 'EOF'
SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess On 
SecResponseBodyMimeType text/plain text/html text/xml
SecDebugLog /var/log/apache2/modsec_debug.log
SecDebugLogLevel 0
SecAuditEngine RelevantOnly
SecAuditLogRelevantStatus "^(?:5|4(?!04))"
SecAuditLogParts ABIJDEFHZ
SecAuditLogType Serial
SecAuditLog /var/log/apache2/modsec_audit.log
SecArgumentSeparator &
SecCookieFormat 0
SecTmpDir /tmp/
SecDataDir /tmp/
SecUploadDir /tmp/
SecUploadKeepFiles Off
EOF

# Настройка PHP
cat > /etc/php/8.?/fpm/php.ini << 'EOF'
[PHP]
engine = On
expose_php = Off
max_execution_time = 30
memory_limit = 256M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
log_errors = On
error_log = /var/log/php/error.log
post_max_size = 64M
upload_max_filesize = 64M
max_file_uploads = 20
date.timezone = Europe/Moscow
opcache.enable = 1
opcache.memory_consumption = 128
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
EOF

# Создание директории для логов PHP
mkdir -p /var/log/php
chown www-data:www-data /var/log/php

# Настройка MariaDB
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root_password';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Создание базы данных и пользователя для сайта
mysql -e "CREATE DATABASE IF NOT EXISTS ${DOMAIN//./_}_db;"
mysql -e "CREATE USER IF NOT EXISTS '${DOMAIN//./_}_user'@'localhost' IDENTIFIED BY 'secure_password';"
mysql -e "GRANT ALL PRIVILEGES ON ${DOMAIN//./_}_db.* TO '${DOMAIN//./_}_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Настройка firewall
apt install -y ufw
ufw allow ssh
ufw allow 'Apache Full'
ufw --force enable
check_error "Настройка firewall"

# Установка и настройка Zsh
apt install -y zsh
check_error "Установка Zsh"

# Установка Oh My Zsh
su - "$USERNAME" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
check_error "Установка Oh My Zsh"

# Установка плагинов Zsh
su - "$USERNAME" -c 'git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'
su - "$USERNAME" -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'

# Настройка Zsh для пользователя
cat > "/home/$USERNAME/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting ssh-agent)
source $ZSH/oh-my-zsh.sh

# Apache aliases
alias apache-start='sudo systemctl start apache2'
alias apache-stop='sudo systemctl stop apache2'
alias apache-restart='sudo systemctl restart apache2'
alias apache-reload='sudo systemctl reload apache2'
alias apache-status='sudo systemctl status apache2'
alias apache-logs='sudo tail -f /var/log/apache2/*.log'
alias apache-error='sudo tail -f /var/log/apache2/error.log'
alias apache-access='sudo tail -f /var/log/apache2/access.log'

# MySQL aliases
alias mysql-start='sudo systemctl start mariadb'
alias mysql-stop='sudo systemctl stop mariadb'
alias mysql-restart='sudo systemctl restart mariadb'
alias mysql-status='sudo systemctl status mariadb'

# PHP aliases
alias php-restart='sudo systemctl restart php8.2-fpm'

# Website management
alias www-logs='cd /var/www'
alias www-edit='sudo vim /etc/apache2/sites-available/'

# Добавление путей к бинарникам
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/nvim/bin:$PATH"

EOF

# Установка и настройка NeoVim
mkdir -p /opt/nvim
cd /opt/nvim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
check_error "Загрузка NeoVim"
tar xzf nvim-linux-x86_64.tar.gz
check_error "Распаковка NeoVim"
# Переименование директории для удобства
mv nvim-linux-x86_64 nvim
# Создаем симлинк для доступа из PATH
ln -sf /opt/nvim/nvim/bin/nvim /usr/local/bin/nvim
# Добавляем путь в системный PATH
# echo 'export PATH="/opt/nvim/nvim/bin:$PATH"' >> /etc/environment

# Установка конфигурации NeoVim из вашего репозитория
su - "$USERNAME" -c "mkdir -p /home/$USERNAME/.config"
su - "$USERNAME" -c "git clone https://github.com/nedoletoff/nvim_config.git ~/.config"
check_error "Клонирование конфигурации NeoVim"

# Установка зависимостей для NeoVim
apt install -y python3-pip python3-venv nodejs npm
check_error "Установка зависимостей для NeoVim"

# Установка pip и neovim Python package
apt install -y python3-pynvim
check_error "Установка pynvim"

# Установка Node.js поддержки для NeoVim
# Создаем директорию для глобальных npm-пакетов пользователя
su - "$USERNAME" -c "mkdir -p ~/.npm-global"
# Настраиваем npm для использования пользовательской директории
su - "$USERNAME" -c "npm config set prefix '~/.npm-global'"
# Добавляем путь в .zshrc
echo 'export PATH=~/.npm-global/bin:$PATH' >> "/home/$USERNAME/.zshrc"
# Обновляем PATH для текущей сессии
export PATH="/home/$USERNAME/.npm-global/bin:$PATH"

# Теперь устанавливаем neovim
su - "$USERNAME" -c "npm install -g neovim"
check_error "Установка neovim npm package"

# Создание тестовой страницы
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
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Добро пожаловать на $DOMAIN!</h1>
        <div class="status">Apache2 сервер успешно настроен и работает</div>
        
        <div class="info">
            <h3>📊 Информация о сервере:</h3>
            <p><strong>Доменное имя:</strong> $DOMAIN</p>
            <p><strong>Директория сайта:</strong> /var/www/$DOMAIN/public_html</p>
            <p><strong>Владелец:</strong> $USERNAME</p>
            <p><strong>Время настройки:</strong> $(date)</p>
        </div>

        <h3>🔧 Полезные команды:</h3>
        <ul>
            <li><code>apache-restart</code> - перезапуск Apache</li>
            <li><code>apache-logs</code> - просмотр логов</li>
            <li><code>mysql-restart</code> - перезапуск MySQL</li>
            <li><code>php-restart</code> - перезапуск PHP-FPM</li>
        </ul>

        <h3>📁 Структура проекта:</h3>
        <pre>
/var/www/$DOMAIN/
├── public_html/     # Корневая директория сайта
├── logs/           # Логи Apache
└── backups/        # Резервные копии
        </pre>
    </div>
</body>
</html>
EOF

# Создание PHP info страницы
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

# Настройка прав доступа
chown -R "$USERNAME:www-data" "/var/www/$DOMAIN"
chmod -R 755 "/var/www/$DOMAIN"
chmod 600 "/var/www/$DOMAIN/public_html/phpinfo.php"

# Перезагрузка служб
systemctl restart apache2
systemctl restart mariadb
systemctl restart php8.2-fpm
systemctl enable apache2
systemctl enable mariadb
systemctl enable php8.2-fpm

check_error "Перезагрузка служб"

# Настройка автоматических бэкапов
cat > /etc/cron.daily/apache-backup << EOF
#!/bin/bash
BACKUP_DIR="/var/www/$DOMAIN/backups"
DATE=\$(date +%Y%m%d_%H%M%S)

# Создание бэкапа базы данных
mysqldump -u root -proot_password ${DOMAIN//./_}_db > \$BACKUP_DIR/db_backup_\$DATE.sql 2>/dev/null

# Создание бэкапа файлов сайта
tar -czf \$BACKUP_DIR/files_backup_\$DATE.tar.gz -C /var/www/$DOMAIN public_html

# Удаление старых бэкапов (старше 7 дней)
find \$BACKUP_DIR -name "*.sql" -mtime +7 -delete
find \$BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

chown -R $USERNAME:www-data \$BACKUP_DIR
EOF

chmod +x /etc/cron.daily/apache-backup

# Смена оболочки на zsh
chsh -s /bin/zsh "$USERNAME"
check_error "Смена оболочки на Zsh"

# Очистка кеша
apt autoremove -y
apt clean

echo " "
echo "=================================================="
echo "🎉 Настройка Apache сервера завершена!"
echo "=================================================="
echo " "
echo "📊 Информация о настройке:"
echo "   Доменное имя: $DOMAIN"
echo "   Пользователь: $USERNAME"
echo "   Директория сайта: /var/www/$DOMAIN/public_html"
echo "   База данных: ${DOMAIN//./_}_db"
echo "   Пользователь БД: ${DOMAIN//./_}_user"
echo " "
echo "🔧 Полезные команды:"
echo "   systemctl status apache2    - статус Apache"
echo "   systemctl status mariadb    - статус MySQL"
echo "   apache-logs                 - логи Apache (alias)"
echo "   mysql -u root -p            - подключение к MySQL"
echo " "
echo "⚠️  Важные замечания:"
echo "   1. Настройте пароли в MySQL: root_password -> secure password"
echo "   2. Настройте SSL сертификаты: certbot --apache -d $DOMAIN"
echo "   3. Убедитесь что firewall настроен правильно: ufw status"
echo "   4. Проверьте доступность сайта: curl http://localhost"
echo " "
echo "📚 Документация:"
echo "   Apache: https://httpd.apache.org/docs/"
echo "   MySQL: https://dev.mysql.com/doc/"
echo "   PHP: https://www.php.net/docs.php"
echo " "