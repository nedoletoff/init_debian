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
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
    fontconfig
check_error "Установка базовых утилит"

# ==================================================
# Установка Lilex Nerd Font
# ==================================================

echo "Установка Lilex Nerd Font..."
mkdir -p /tmp/nerd-fonts
cd /tmp/nerd-fonts

# Скачиваем Lilex Nerd Font
wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/LilexNerdFont.zip" -O LilexNerdFont.zip
check_error "Скачивание Lilex Nerd Font"

# Создаем директории для шрифтов
mkdir -p /usr/local/share/fonts/
mkdir -p "/home/$USERNAME/.local/share/fonts"

# Распаковываем шрифт
unzip -q LilexNerdFont.zip -d /usr/local/share/fonts/
unzip -q LilexNerdFont.zip -d "/home/$USERNAME/.local/share/fonts"

# Обновляем кэш шрифтов
fc-cache -f -v
check_error "Обновление кэша шрифтов"

# Чистим временные файлы
cd /
rm -rf /tmp/nerd-fonts

echo "Lilex Nerd Font установлен"

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
su - "$USERNAME" -c 'git clone https://github.com/p1r473/zsh-color-logging.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-color-logging'

echo "Настройка Zsh..."
cat > "/home/$USERNAME/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="tjkirch"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting ssh-agent k9s debian lol man sudo zsh-color-logging)
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
echo "   ✅ Lilex Nerd Font"
echo "   ✅ Zsh + Oh My Zsh + плагины"
echo "   ✅ NeoVim с конфигом из репозитория"
echo "🔧 Дополнительные настройки:"
echo "   ✅ Midnight Commander с конфигурацией"
echo "   ✅ Tmux с улучшенной конфигурацией"
echo " "
echo "💡 Новые возможности:"
echo "   mc                         - запуск midnight commander"
echo "   tmux                       - запуск tmux с улучшенной конфигурацией"
echo "   Ctrl+a затем ?             - просмотр сочетаний клавиш tmux"
echo " "
echo "🔤 Шрифт Lilex Nerd Font установлен в систему."
echo "   Чтобы использовать его в терминале:"
echo "   1. Откройте настройки вашего терминала"
echo "   2. Найдите раздел со шрифтами"
echo "   3. Выберите 'Lilex Nerd Font' или 'Lilex Nerd Font Mono'"
echo " "
echo "🔧 Полезные команды:"
echo "   nvim --version              - проверить установку NeoVim"
echo "   nvim +PackerSync            - установить плагины NeoVim"
echo " "
echo "💻 Для применения изменений выполните:"
echo "   su - $USERNAME"
echo " "
echo "📝 Не забудьте:"
echo "   1. Настроить терминал на использование Lilex Nerd Font"
echo "   2. Запустить nvim и выполнить :PackerSync для установки плагинов"
echo "   3. Перезайти в систему для применения изменений"
echo " "
