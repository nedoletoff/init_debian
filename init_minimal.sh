#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ==================================================
# Параметры и проверки
# ==================================================

if [ $# -eq 0 ]; then
    echo "Использование: $0 username"
    echo "Укажите имя пользователя в качестве аргумента"
    exit 1
fi

USERNAME="$1"

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
    traceroute rsync unzip p7zip-full ca-certificates \
    gnupg lsb-release zsh vim build-essential \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
check_error "Установка базовых утилит"

# ==================================================
# Настройка пользователя
# ==================================================

echo "Добавление пользователя $USERNAME в sudo..."
usermod -aG sudo "$USERNAME"
check_error "Добавление пользователя в sudo"

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
cat > "/home/$USERNAME/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="tjkirch"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting ssh-agent k9s debian lol man sudo )
source $ZSH/oh-my-zsh.sh

# Полезные алиасы
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias h='history'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# DevOps алиасы
alias status='systemctl status'
alias start='systemctl start'
alias stop='systemctl stop'
alias restart='systemctl restart'
alias reload='systemctl reload'
alias logs='journalctl -u'

# Добавление путей к бинарникам
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/nvim/bin:$PATH"
EOF

# ==================================================
# Установка NeoVim
# ==================================================

echo "Установка NeoVim..."
mkdir -p /opt/nvim
cd /opt/nvim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
check_error "Загрузка NeoVim"
tar xzf nvim-linux-x86_64.tar.gz
check_error "Распаковка NeoVim"
mv nvim-linux-x86_64 nvim
ln -sf /opt/nvim/nvim/bin/nvim /usr/local/bin/nvim

echo "Установка зависимостей для NeoVim..."
apt install -y python3-pip python3-venv nodejs npm
check_error "Установка зависимостей для NeoVim"

apt install -y python3-pynvim
check_error "Установка pynvim"

su - "$USERNAME" -c "mkdir -p ~/.npm-global"
su - "$USERNAME" -c "npm config set prefix '~/.npm-global'"
echo 'export PATH=~/.npm-global/bin:$PATH' >> "/home/$USERNAME/.zshrc"

su - "$USERNAME" -c "npm install -g neovim"
check_error "Установка neovim npm package"

echo "Установка конфигурации NeoVim..."
su - "$USERNAME" -c "mkdir -p /home/$USERNAME/.config"
su - "$USERNAME" -c "git clone https://github.com/nedoletoff/nvim_config.git /home/$USERNAME/.config/nvim/"
check_error "Клонирование конфигурации NeoVim"

su - "$USERNAME" -c "mkdir -p ~/.local/share/nvim/swap"

# ==================================================
# Финальная настройка
# ==================================================

echo "Настройка прав доступа..."
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

#echo "Смена оболочки на Zsh..."
#chsh -s /bin/zsh "$USERNAME"

echo "Очистка..."
apt autoremove -y
apt clean

# ==================================================
# Вывод информации
# ==================================================

echo " "
echo "=================================================="
echo "🎉 Настройка завершена!"
echo "=================================================="
echo " "
echo "📦 Установленные компоненты:"
echo "   ✅ Базовые утилиты"
echo "   ✅ Zsh + Oh My Zsh + плагины"
echo "   ✅ NeoVim с конфигом из репозитория"
echo " "
echo "🔧 Полезные команды:"
echo "   nvim --version              - проверить установку NeoVim"
echo "   nvim +PackerSync            - установить плагины NeoVim"
echo " "
echo "💻 Для применения изменений выполните:"
echo "   su - $USERNAME"
echo " "
echo "📝 Не забудьте:"
echo "   1. Запустить nvim и выполнить :PackerSync для установки плагинов"
echo "   2. Перезайти в систему для применения изменений"
echo " "
