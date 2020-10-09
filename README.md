# selinux

## Смена порта в NGINX
Изменим порт в */etc/nginx/nginx.conf*

	# sed -i 's/80/3200/g' /etc/nginx/nginx.conf

Selinux не даст нам запустить на нестандартном порту nginx.

	[root@selinux nginx]# systemctl start nginx.service 
	Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.


Утилита *sealert* предлагает нам три рекомендации

	[root@selinux nginx]# sealert -a /var/log/audit/audit.log 
	100% done
	found 1 alerts in /var/log/audit/audit.log
	--------------------------------------------------------------------------------

	SELinux запрещает /usr/sbin/nginx доступ name_bind к tcp_socket port 3200.

	*****  Модуль bind_ports предлагает (точность 92.2)  *************************

	Если вы хотите разрешить /usr/sbin/nginx для привязки к сетевому порту $PORT_ЧИСЛО
	То you need to modify the port type.
	Сделать
	# semanage port -a -t PORT_TYPE -p tcp 3200
	    где PORT_TYPE может принимать значения: http_cache_port_t, http_port_t, jboss_management_port_t, jboss_messaging_port_t, ntop_port_t, puppet_port_t.

	*****  Модуль catchall_boolean предлагает (точность 7.83)  *******************

	Если хотите allow nis to enabled
	То вы должны сообщить SELinux об этом, включив переключатель «nis_enabled».

	Сделать
	setsebool -P nis_enabled 1

	*****  Модуль catchall предлагает (точность 1.41)  ***************************

	Если вы считаете, что nginx должно быть разрешено name_bind доступ к port 3200 tcp_socket по умолчанию.
	То рекомендуется создать отчет об ошибке.
	Чтобы разрешить доступ, можно создать локальный модуль политики.
	Сделать
	allow this access for now by executing:
	# ausearch -c 'nginx' --raw | audit2allow -M my-nginx
	# semodule -i my-nginx.pp


### semanage
Используем команду *semanage*.

Посмотрим разрешенные порты для http.


	[root@selinux etc]# semanage port -l | grep http
	http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
	http_cache_port_t              udp      3130
	http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
	pegasus_http_port_t            tcp      5988
	pegasus_https_port_t           tcp      5989

Добавим наш порт в список разрешенных и снова посмотрим список разрешенных портов.

	[root@selinux etc]# semanage port -a -t http_port_t -p tcp 3200
	[root@selinux etc]# semanage port -l | grep http
	http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
	http_cache_port_t              udp      3130
	http_port_t                    tcp      3200, 80, 81, 443, 488, 8008, 8009, 8443, 9000
	pegasus_http_port_t            tcp      5988
	pegasus_https_port_t           tcp      5989

Запустим наш nginx

	[root@selinux etc]# systemctl start nginx


### setbool

Найдем параметризованную политику, которую нам предлагает *sealert*

	[root@selinux vagrant]# getsebool -a | grep nis
	nis_enabled --> off
	varnishd_connect_any --> off


Разрешим эту параметризованную политику NIS (Network Information Service)командой

	[root@selinux vagrant]# setsebool -P nis_enabled 1

Запустим наш nginx

	[root@selinux vagrant]# systemctl start nginx

### audit

Утилита *sealert* также нам предлагает создать модуль локальной политики для разрешенных действий.

Посмотрим с помощью утилиты *audit2why* логи в человеческом формате

	[root@selinux vagrant]# audit2why < /var/log/audit/audit.log
	type=AVC msg=audit(1602164546.373:1011): avc:  denied  { name_bind } for  pid=4019 comm="nginx" src=3200 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

Создадим необходимый нам модуль

	[root@selinux vagrant]# ausearch -c 'nginx' --raw | audit2allow -M my-nginx

Посмотрим файл *my-nginx.te*

	[root@selinux vagrant]# cat my-nginx.te
	module my-nginx 1.0;
	require {
		type httpd_t;
		type unreserved_port_t;
		class tcp_socket name_bind;
	}
	#============= httpd_t ==============
	#!!!! This avc can be allowed using the boolean 'nis_enabled'
	allow httpd_t unreserved_port_t:tcp_socket name_bind;

Применим этот модуль
	
	semodule -i my-nginx.pp

Запустим наш nginx

	[root@selinux vagrant]# systemctl start nginx

### Примечание

Наиболее оптимальным способом в данной ситуации лучше подходит первый вариатн с *semanage*, который и реализован в *scripts/selinux.sh*, так как он наиболее точечный. Второй вариант довольно радикальный и дает разрешение всем сервисам работающим через политику NIS. Третий вариант тоже довольно грубый, так как создавая модуль мы точно не знаем (хотя можно перед применением посмотреть созданный модуль), что именно утилита *audit2allow* разрешит нашему ПО в данном модуле делать на нашей машине.


## selinux dns problems

Запустив оба стенда, введм команду *sealert* в *ns01*

	[root@ns01 named]# sealert -a /var/log/audit/audit.log 
	100% done
	found 1 alerts in /var/log/audit/audit.log
	--------------------------------------------------------------------------------

	SELinux запрещает /usr/sbin/named доступ create к файл named.ddns.lab.view1.jnl.

	*****  Модуль catchall_labels предлагает (точность 83.8)  ********************

	Если вы хотите разрешить named иметь create доступ к named.ddns.lab.view1.jnl $TARGET_УЧЕБНЫЙ КЛАСС
	То необходимо изменить метку на named.ddns.lab.view1.jnl
	Сделать
	# semanage fcontext -a -t FILE_TYPE 'named.ddns.lab.view1.jnl'
	где FILE_TYPE может принимать значения: dnssec_trigger_var_run_t, ipa_var_lib_t, krb5_host_rcache_t, krb5_keytab_t, named_cache_t, named_log_t, named_tmp_t, named_var_run_t, named_zone_t. 
	Затем выполните: 
	restorecon -v 'named.ddns.lab.view1.jnl'


	*****  Модуль catchall предлагает (точность 17.1)  ***************************

	Если вы считаете, что named должно быть разрешено create доступ к named.ddns.lab.view1.jnl file по умолчанию.
	То рекомендуется создать отчет об ошибке.
	Чтобы разрешить доступ, можно создать локальный модуль политики.
	Сделать
	allow this access for now by executing:
	# ausearch -c 'isc-worker0000' --raw | audit2allow -M my-iscworker0000
	# semodule -i my-iscworker0000.pp

Как я понимаю, объекту */usr/sbin/named* отказано в доступе к файлам с типом *etc_t*, в частности к папке */etc/named*.

	[root@ns01 named]# ls -Z
	drw-rwx---. root named unconfined_u:object_r:etc_t:s0   dynamic
	-rw-rw----. root named system_u:object_r:etc_t:s0       named.50.168.192.rev
	-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab
	-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab.view1
	-rw-rw----. root named system_u:object_r:etc_t:s0       named.newdns.lab

Смотрим вывод для объекта

	-rwxr-xr-x. root root system_u:object_r:named_exec_t:s0 /usr/sbin/named

Самый легкий и на мой взгляд самый грубый это воспользоваться *audit2allow*

	# ausearch -c 'isc-worker0000' --raw | audit2allow -M my-iscworker0000
	# semodule -i my-iscworker0000.pp

Попробуем пойти другим путем, добавим новый тип для каталога */etc/named/*

	[root@ns01 named]# chcon -R -t named_zone_t /etc/named
	[root@ns01 named]# ls -Z
	drw-rwx---. root named unconfined_u:object_r:named_zone_t:s0 dynamic
	-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.50.168.192.rev
	-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab
	-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab.view1
	-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.newdns.lab

Проверим на *client*

	[vagrant@client ~]$ ls
	rndc.conf
	[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
	> server 192.168.50.10
	> zone ddns.lab
	> update add www.ddns.lab. 60 A 192.168.50.15
	> send
	update failed: SERVFAIL
	> server 192.168.50.10
	> zone ddns.lab
	> update add www.ddns.lab. 60 A 192.168.50.15
	> send
	> 

