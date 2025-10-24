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
    traceroute mtr-tiny tcpdump nmap sshfs rsync \
    unzip p7zip-full ca-certificates gnupg lsb-release \
    zsh postgresql postgresql-contrib tar dpkg \
    build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncursesw5-dev \
    xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev sysstat iotop cifs-utils \
    vim expect containerd docker.io ipvsadm nfs-common \
    software-properties-common xclip
check_error "Установка базовых утилит"

# ==================================================
# Настройка пользователя
# ==================================================

echo "Добавление пользователя в sudo..."
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
plugins=(git zsh-autosuggestions zsh-syntax-highlighting ssh-agent k9s debian kubectl lol man sudo )
source $ZSH/oh-my-zsh.sh

# Автодополнение для SSH
zstyle -s ':completion:*:hosts' hosts _ssh_config
[[ -r ~/.ssh/config ]] && _ssh_config+=($(cat ~/.ssh/config | sed -n 's/Host[=\t ]//p'))
zstyle ':completion:*:hosts' hosts $_ssh_config

# Добавление путей к бинарникам
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/nvim/bin:$PATH"
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
EOF

# ==================================================
# Установка Go
# ==================================================

echo "Установка Go..."
mkdir -p "/home/$USERNAME/downloads"
cd "/home/$USERNAME/downloads"
wget https://go.dev/dl/go1.25.0.linux-amd64.tar.gz
check_error "Загрузка Go"
tar -C /usr/local -xzf go1.25.0.linux-amd64.tar.gz
check_error "Распаковка Go"
echo 'export PATH=/usr/local/go/bin:$PATH' >> "/home/$USERNAME/.zshrc"
echo 'export GOPATH=$HOME/go' >> "/home/$USERNAME/.zshrc"
echo 'export PATH=$GOPATH/bin:$PATH' >> "/home/$USERNAME/.zshrc"
su - "$USERNAME" -c "mkdir -p ~/go/bin"

# ==================================================
# Установка asdf
# ==================================================

echo "Установка asdf..."
su - "$USERNAME" -c 'git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1'
echo '. "$HOME/.asdf/asdf.sh"' >> "/home/$USERNAME/.zshrc"
echo '. "$HOME/.asdf/completions/asdf.bash"' >> "/home/$USERNAME/.zshrc"

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

echo "Установка конфигурации NeoVim..."
su - "$USERNAME" -c "mkdir -p /home/$USERNAME/.config"
su - "$USERNAME" -c "git clone https://github.com/nedoletoff/nvim_config.git ~/.config/nvim/"
check_error "Клонирование конфигурации NeoVim"

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
# Установка Docker
# ==================================================

echo "Установка Docker..."
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker docker.io
check_error "Установка Docker"
usermod -aG docker "$USERNAME"
check_error "Добавление пользователя в группу docker"

# ==================================================
# Установка Kubernetes
# ==================================================

echo "Установка Kubernetes tools..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
apt update
apt install -y kubelet kubeadm kubectl
check_error "Установка Kubernetes tools"
apt-mark hold kubelet kubeadm kubectl

echo "Установка Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
check_error "Установка Helm"

echo "Установка Docker Compose..."
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
check_error "Установка Docker Compose"

# ==================================================
# Финальная настройка
# ==================================================

echo "Настройка прав доступа..."
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

echo "Создание директории для swap файлов NeoVim..."
su - "$USERNAME" -c "mkdir -p ~/.local/share/nvim/swap"

echo "Очистка кеша..."
apt autoremove -y
apt clean

echo "Смена оболочки на zsh..."
chsh -s /bin/zsh "$USERNAME"
check_error "Смена оболочки на Zsh"

# ==================================================
# Вывод информации
# ==================================================

echo " "
echo "=================================================="
echo "🎉 Настройка Kubernetes окружения завершена!"
echo "=================================================="
echo " "
echo "📦 Установленные компоненты:"
echo "   ✅ Базовые утилиты и инструменты разработки"
echo "   ✅ Zsh + Oh My Zsh + плагины"
echo "   ✅ Go programming language"
echo "   ✅ asdf version manager"
echo "   ✅ NeoVim с конфигом из репозитория"
echo "   ✅ Docker и Docker Compose"
echo "   ✅ Kubernetes (kubelet, kubeadm, kubectl)"
echo "   ✅ Helm"
echo "🔧 Дополнительные настройки:"
echo "   ✅ Midnight Commander с конфигурацией"
echo "   ✅ Tmux с улучшенной конфигурацией"
echo " "
echo "💡 Новые возможности:"
echo "   mc                         - запуск midnight commander"
echo "   tmux                       - запуск tmux с улучшенной конфигурацией"
echo "   Ctrl+a затем ?             - просмотр сочетаний клавиш tmux"
echo " "
echo "🔧 Полезные команды:"
echo "   nvim --version              - проверить установку NeoVim"
echo "   docker --version            - проверить установку Docker"
echo "   kubectl version             - проверить установку Kubernetes"
echo "   helm version                - проверить установку Helm"
echo "   go version                  - проверить установку Go"
echo " "
echo "⚠️  Важные замечания:"
echo "   1. Перезайдите в систему для применения изменений"
echo "   2. Настройте SSH-ключи в ~/.ssh/"
echo "   3. Запустите nvim для установки плагинов: nvim +PackerSync"
echo "   4. Для применения изменений групп выполните: newgrp docker"
echo "   5. Для инициализации Kubernetes кластера используйте: kubeadm init"
echo " "
