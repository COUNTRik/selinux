#!/bin/bash

# Авторизуемся для получения root прав
mkdir -p ~root/.ssh
cp ~vagrant/.ssh/auth* ~root/.ssh

# Установим необходимые пакеты
yum install epel-release
yum install -y mc vim nginx setroubleshoot-server setools-console policycoreutils-python policycoreutils-newrole selinux-policy-mls