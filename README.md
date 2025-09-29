# Init Debian Scripts

Набор bash-скриптов для базовой настройки Debian серверов под различные нужды.

## 📋 Доступные скрипты

### 1. `init_apache_jenkins.sh` - Веб-сервер + CI/CD
Устанавливает и настраивает:
- **Apache2** с виртуальными хостами
- **Jenkins** для CI/CD
- **NeoVim** с готовой конфигурацией
- **Zsh** с Oh My Zsh и плагинами
- Базовые утилиты для разработки

**Использование:**
```bash
./init_apache_jenkins.sh username
```

### 2. `init_apache_mysql.sh` - Веб-сервер + БД
Устанавливает и настраивает:
- **Apache2** с SSL и ModSecurity
- **PHP** с FPM
- **MariaDB/MySQL** 
- **Postfix** для почты
- Автоматические бэкапы
- Firewall и базовую безопасность

**Использование:**
```bash
./init_apache_mysql.sh username [domain]
```

### 3. `init_k8s.sh` - Kubernetes окружение
Устанавливает и настраивает:
- **Docker** и Docker Compose
- **Kubernetes** (kubeadm, kubectl, kubelet)
- **Helm** 
- **Go** и инструменты для разработки
- **asdf** version manager
- **NeoVim** с готовой конфигурацией

**Использование:**
```bash
./init_k8s.sh username
```

## 🚀 Как использовать

1. **Скачайте нужный скрипт**
2. **Сделайте исполняемым:**
   ```bash
   chmod +x script_name.sh
   ```
3. **Запустите от root:**
   ```bash
   sudo ./script_name.sh username [domain]
   ```

## ⚙️ Общие особенности

Все скрипты включают:
- Обновление системы и установку базовых утилит
- Настройку Zsh с Oh My Zsh и полезными плагинами
- Установку NeoVim с конфигурацией из репозитория
- Проверку прав доступа и обработку ошибок
- Очистку системы после установки

## 📝 Дополнительные рекомендации

1. **Для NeoVim:** После установки запустите `nvim +PackerSync` для установки плагинов
2. **Для Docker:** Выполните `newgrp docker` или перезайдите в систему
3. **Для SSH:** Добавьте ваши публичные ключи в `~/.ssh/authorized_keys`
4. **Безопасность:** 
   - Настройте пароли в MySQL/MariaDB
   - Настройте SSL сертификаты через Certbot
   - Проверьте настройки firewall

## ⚠️ Примечания

- Перед использованием в production-средах проверяйте версии устанавливаемых компонентов
- При необходимости фиксируйте версии пакетов
- Скрипты предназначены для свежих установок Debian/Ubuntu
- Рекомендуется запускать на clean-окружении

## 📚 Документация

- [Apache Documentation](https://httpd.apache.org/docs/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)