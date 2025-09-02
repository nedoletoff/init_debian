#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Проверка аргументов
if [ $# -eq 0 ]; then
    echo "Использование: $0 username"
    echo "Укажите имя пользователя в качестве аргумента"
    exit 1
fi

USERNAME="$1"

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
    postgresql \
    postgresql-contrib \
    tar \
    dpkg \
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
    expect \
    containerd \
    docker.io

check_error "Установка базовых утилит"
apt install -y software-properties-common


# Добавление пользователя в sudo
sudo usermod -aG sudo "$USERNAME"
check_error "Добавление пользователя в sudo"

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

# Установка Go
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

# Установка asdf (правильным способом)
su - "$USERNAME" -c 'git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1'
echo '. "$HOME/.asdf/asdf.sh"' >> "/home/$USERNAME/.zshrc"
echo '. "$HOME/.asdf/completions/asdf.bash"' >> "/home/$USERNAME/.zshrc"

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

# Установка Docker
# Определяем дистрибутив
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io
check_error "Установка Docker"
usermod -aG docker "$USERNAME"
check_error "Добавление пользователя в группу docker"

# Установка Kubernetes tools
# Добавление репозитория Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
apt update
apt install -y kubelet kubeadm kubectl
check_error "Установка Kubernetes tools"
apt-mark hold kubelet kubeadm kubectl

# Установка Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
check_error "Установка Helm"

# Установка дополнительных инструментов DevOps
# Docker-compose
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
check_error "Установка Docker Compose"

# Настройка прав доступа
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

# Создание директории для swap файлов NeoVim
su - "$USERNAME" -c "mkdir -p ~/.local/share/nvim/swap"

# Очистка кеша
apt autoremove -y
apt clean

echo "Настройка завершена!"
echo "Не забудьте:"
echo "1. Перезайти в систему для применения изменений"
echo "2. Настроить SSH-ключи в ~/.ssh/"
echo "3. Запустить nvim для установки плагинов: nvim +PackerSync"
echo "4. Для применения изменений групп выполните: newgrp docker"
echo "5. Проверить работу NeoVim: nvim --version"

echo "Смена оболочки на zsh"
# Смена оболочки по умолчанию на zsh
chsh -s /bin/zsh "$USERNAME"
check_error "Смена оболочки на Zsh"
echo "Успешно"
