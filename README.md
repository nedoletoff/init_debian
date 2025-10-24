# Init Debian Scripts - Flash Forward**

## Версия на русском:


### 🚀 О проекте
Набор автоматизированных bash-скриптов для быстрой настройки Debian-серверов под различные задачи. Версия 2.0 приносит значительные улучшения в работе с терминалом благодаря комплексной настройке Midnight Commander и Tmux.

### 📦 Что нового в v2.0

#### 🛠 Универсальные улучшения для всех скриптов:
- **Расширенная настройка Midnight Commander** - готовый к использованию файловый менеджер с оптимизированным интерфейсом
- **Продвинутая конфигурация Tmux** - значительно улучшенная работа с сессиями
- **Интеграция буфера обмена** - копирование/вставка между терминалом и системой
- **Поддержка мыши** - полная интеграция мыши в Tmux для удобной навигации

#### 🎯 Особенности Tmux:
- **Префикс Ctrl+a** вместо неудобного Ctrl+b
- **Визуальные улучшения** - статус-бар с информацией о времени и сессиях
- **Интуитивные сочетания клавиш**:
  - `Alt+стрелки` - переключение между панелями
  - `Ctrl+стрелки` - изменение размеров панелей
  - `Ctrl+a |` и `Ctrl+a -` - разделение окон
- **Сессии с сохранением состояния** - идеально для долгих SSH-сеансов

### 🗂 Доступные скрипты

#### 1. init_minimal.sh - Базовый рабочий стол
**Для кого:** Разработчики, администраторы, все кто хочет удобное терминальное окружение
**Устанавливает:**
- Базовые утилиты (curl, wget, git, htop, tree, ncdu, jq)
- Zsh + Oh My Zsh + плагины (автодополнение, подсветка синтаксиса)
- NeoVim с готовой конфигурацией из репозитория
- Lilex Nerd Font для терминала
- Midnight Commander и Tmux с расширенными настройками

#### 2. init_apache_jenkins.sh - Веб-разработка + CI/CD
**Для кого:** Веб-разработчики, DevOps инженеры
**Устанавливает:**
- Apache2 с прокси-модулями для Jenkins
- Jenkins для непрерывной интеграции
- Полный набор терминальных инструментов из minimal.sh
- Специальные алиасы для управления Jenkins

#### 3. init_apache_mysql.sh - Полный веб-стек
**Для кого:** Full-stack разработчики, системные администраторы
**Устанавливает:**
- Apache2 с SSL и ModSecurity
- PHP-FPM с расширениями
- MariaDB/MySQL сервер
- Postfix для email-рассылок
- Автоматические бэкапы
- UFW firewall
- Все улучшения терминала из v2.0

#### 4. init_k8s.sh - Контейнеризация и оркестрация
**Для кого:** DevOps, SRE, инженеры облачных платформ
**Устанавливает:**
- Docker + Docker Compose
- Kubernetes (kubeadm, kubectl, kubelet)
- Helm для управления пакетами
- Go и asdf version manager
- Полный набор инструментов для разработки
- Все терминальные улучшения v2.0

### 💡 Почему это удобно
- **Единообразие** - одинаковое окружение на всех серверах
- **Экономия времени** - минуты вместо часов ручной настройки
- **Оптимизированный workflow** - готовые инструменты для продуктивной работы
- **Документированность** - понятные алиасы и сочетания клавиш

---

## English Version:

### 🚀 About the Project
A collection of automated bash scripts for rapid Debian server configuration for various tasks. Version 2.0 brings significant terminal workflow improvements through comprehensive Midnight Commander and Tmux configuration.

### 📦 What's New in v2.0

#### 🛠 Universal Enhancements for All Scripts:
- **Extended Midnight Commander Setup** - file manager ready to use with optimized interface
- **Advanced Tmux Configuration** - significantly improved session management
- **Clipboard Integration** - copy/paste between terminal and system
- **Mouse Support** - full mouse integration in Tmux for convenient navigation

#### 🎯 Tmux Features:
- **Ctrl+a Prefix** instead of inconvenient Ctrl+b
- **Visual Enhancements** - status bar with time and session information
- **Intuitive Key Bindings**:
  - `Alt+arrows` - switch between panes
  - `Ctrl+arrows` - resize panes
  - `Ctrl+a |` and `Ctrl+a -` - split windows
- **Persistent Sessions** - perfect for long SSH sessions

### 🗂 Available Scripts

#### 1. init_minimal.sh - Basic Workstation
**For:** Developers, administrators, anyone wanting a comfortable terminal environment
**Installs:**
- Basic utilities (curl, wget, git, htop, tree, ncdu, jq)
- Zsh + Oh My Zsh + plugins (autosuggestions, syntax highlighting)
- NeoVim with ready configuration from repository
- Lilex Nerd Font for terminal
- Midnight Commander and Tmux with extended settings

#### 2. init_apache_jenkins.sh - Web Development + CI/CD
**For:** Web developers, DevOps engineers
**Installs:**
- Apache2 with proxy modules for Jenkins
- Jenkins for continuous integration
- Full terminal toolset from minimal.sh
- Special aliases for Jenkins management

#### 3. init_apache_mysql.sh - Complete Web Stack
**For:** Full-stack developers, system administrators
**Installs:**
- Apache2 with SSL and ModSecurity
- PHP-FPM with extensions
- MariaDB/MySQL server
- Postfix for email
- Automatic backups
- UFW firewall
- All terminal enhancements from v2.0

#### 4. init_k8s.sh - Containerization & Orchestration
**For:** DevOps, SRE, cloud platform engineers
**Installs:**
- Docker + Docker Compose
- Kubernetes (kubeadm, kubectl, kubelet)
- Helm for package management
- Go and asdf version manager
- Complete development toolset
- All terminal improvements from v2.0

### 💡 Why It's Convenient
- **Consistency** - identical environment across all servers
- **Time Saving** - minutes instead of hours of manual configuration
- **Optimized Workflow** - ready-to-use tools for productive work
- **Documentation** - clear aliases and key combinations

**Perfect for:** Development servers, production environments, learning platforms, and anyone who values efficient terminal workflow!ipts now provide consistent terminal environment setup with improved user experience!m/)
