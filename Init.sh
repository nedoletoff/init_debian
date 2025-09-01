#!/bin/bash

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "Запустите скрипт с правами root (sudo)"
    exit 1
fi

# Обновление системы
apt update && apt upgrade -y

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
    lsb-release

# Добавление пользователя в sudo (замените 'username' на ваше имя пользователя)
USERNAME="your_username"  # Измените это!
usermod -aG sudo $USERNAME

# Установка и настройка Vim
apt install -y vim
# Базовая конфигурация Vim
cat > /etc/vim/vimrc.local << EOF
syntax on
set tabstop=4
set shiftwidth=4
set expandtab
set number
set cursorline
set nobackup
set nowritebackup
set noswapfile
EOF

# Установка дополнительных инструментов DevOps
# Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io

# Docker-compose
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Kubernetes tools
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt update
apt install -y terraform

# Ansible
apt install -y ansible

# Python и основные инструменты
apt install -y python3 python3-pip python3-venv

# Очистка кеша
apt autoremove -y
apt clean

echo "Установка завершена!"
echo "Не забудьте:"
echo "1. Сменить пароль для пользователя (если нужно)"
echo "2. Настроить SSH-ключи"
echo "3. Перезайти в систему для применения изменений групп"
