#!/bin/bash

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
    lsb-release \
    zsh \
    postgresql \
    postgresql-contrib \
    tar \
    dpkg

# Добавление пользователя в sudo
sudo usermod -aG sudo "$USERNAME"

# Установка и настройка Zsh
apt install -y zsh
# Установка Oh My Zsh
su - "$USERNAME" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
# Установка плагинов Zsh
su - "$USERNAME" -c 'git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'
su - "$USERNAME" -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'

# Настройка Zsh для пользователя
cat > /home/"$USERNAME"/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting ssh-agent)
source $ZSH/oh-my-zsh.sh

# Автодополнение для SSH
zstyle -s ':completion:*:hosts' hosts _ssh_config
[[ -r ~/.ssh/config ]] && _ssh_config+=($(cat ~/.ssh/config | sed -n 's/Host[=\t ]//p'))
zstyle ':completion:*:hosts' hosts $_ssh_config

EOF

su $USERNAME

# Установка Go
mkdir -p downloads
cd downloads
wget https://golang.org/d1/go1.25.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.20.2.linux-amd64.tar.gz
echo "export PATH=/usr/local/go/bin:${PATH}" | sudo tee -a $HOME/.profile
source $HOME/.profile

# Установка asdf
sudo go install github.com/asdf-vm/asdf/cmd/asdf@v0.18.0
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

exit

# Смена оболочки по умолчанию на zsh
chsh -s /bin/zsh "$USERNAME"

# Установка и настройка NeoVim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
chmod u+x nvim-linux-x86_64.appimage
./nvim-linux-x86_64.appimage
mkdir -p /opt/nvim
mv nvim-linux-x86_64.appimage /opt/nvim/nvim
export PATH="$PATH:/opt/nvim/"

# Создание базовой конфигурации, если её нет
if [ ! -d "/home/$USERNAME/.config/nvim" ]; then
    su - "$USERNAME" -c "mkdir -p ~/.config/nvim"
    su - "$USERNAME" -c "git clone https://github.com/nedoletoff/nvim_config.git ~/.config/nvim"  # ЗАМЕНИТЕ НА ВАШ РЕПОЗИТОРИЙ
fi

# Установка Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker "$USERNAME"

# Установка дополнительных инструментов DevOps
# Docker-compose
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Kubernetes tools
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/

# Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt update
apt install -y terraform

# Ansible
apt install -y ansible

# Python и основные инструменты
apt install -y python3 python3-pip python3-venv

# Отключение swap
swapoff -a
sed -i '/swap/s/^\(.*\)$/#\1/g' /etc/fstab
systemctl disable --now swap.target

# Очистка кеша
apt autoremove -y
apt clean

echo "Настройка завершена!"
echo "Не забудьте:"
echo "1. Перезайти в систему для применения изменений"
echo "2. Настроить SSH-ключи в ~/.ssh/"
echo "3. Проверить настройки NeoVim"
echo "4. Для применения изменений групп выполните: newgrp docker"
