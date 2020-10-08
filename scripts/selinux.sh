#!/bin/bash

# Авторизуемся для получения root прав
mkdir -p ~root/.ssh
cp ~vagrant/.ssh/auth* ~root/.ssh

# Установим необходимые пакеты
yum install -y epel-release
yum install -y mc vim nginx setroubleshoot-server setools-console policycoreutils-python policycoreutils-newrole selinux-policy-mls

# Изменим порт nginx в конфигурационном файле
sed -i 's/80/3200/g' /etc/nginx/nginx.conf

# Добавим нужный нам порт в http_port_t
semanage port -a -t http_port_t -p tcp 3200

# Запустим nginx
systemctl start nginx
systemctl enable nginx