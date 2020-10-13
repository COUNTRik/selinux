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

Самый легкий и на мой взгляд самый грубый способ это воспользоваться *audit2allow*

	# ausearch -c 'isc-worker0000' --raw | audit2allow -M my-iscworker0000
	# semodule -i my-iscworker0000.pp

Попробуем пойти другим путем, рассмотрим проблему глубже. Взглянем на *man named*, в частности обратим внимание на вот эту часть:

	       The Red Hat BIND distribution and SELinux policy creates three directories
	       where named is allowed to create and modify files: /var/named/slaves,
	       /var/named/dynamic /var/named/data. By placing files you want named to
	       modify, such as slave or DDNS updateable zone files and database /
	       statistics dump files in these directories, named will work normally and no
	       further operator action is required. Files in these directories are
	       automatically assigned the 'named_cache_t' file context, which SELinux
	       allows named to write.

То есть по умолчанию selinux разрешает создавать и редактировать файлы процессу *named* только в трех каталогах: *var/named/slaves, /var/named/dynamic /var/named/data.*

Теперь взглянем на */etc/name.conf*

	// ZONE TRANSFER WITH TSIG
	include "/etc/named.zonetransfer.key"; 

	view "view1" {
	    match-clients { "view1"; };

	    // root zone
	    zone "." IN {
	    	type hint;
	    	file "named.ca";
	    };

	    // zones like localhost
	    include "/etc/named.rfc1912.zones";
	    // root DNSKEY
	    include "/etc/named.root.key";

	    // labs dns zone
	    zone "dns.lab" {
	        type master;
	        allow-transfer { key "zonetransfer.key"; };
	        file "/etc/named/named.dns.lab.view1";
	    };

	    // labs ddns zone
	    zone "ddns.lab" {
	        type master;
	        allow-transfer { key "zonetransfer.key"; };
	        allow-update { key "zonetransfer.key"; };
	        file "/etc/named/dynamic/named.ddns.lab.view1";
	    };

	    // labs newdns zone
	    zone "newdns.lab" {
	        type master;
	        allow-transfer { key "zonetransfer.key"; };
	        file "/etc/named/named.newdns.lab";
	    };

	    // labs zone reverse
	    zone "50.168.192.in-addr.arpa" {
	        type master;
	        allow-transfer { key "zonetransfer.key"; };
	        file "/etc/named/named.50.168.192.rev";
	    };
	};

	view "default" {
	    match-clients { any; };

	    // root zone
	    zone "." IN {
	    	type hint;
	    	file "named.ca";
	    };

	    // zones like localhost
	    include "/etc/named.rfc1912.zones";
	    // root DNSKEY
	    include "/etc/named.root.key";

	    // labs dns zone
	    zone "dns.lab" {
	        type master;
	        allow-transfer { key "zonetransfer.key"; };
	        file "/etc/named/named.dns.lab";
	    };

	    // labs ddns zone
	    zone "ddns.lab" {
	        type master;
	        allow-transfer { key "zonetransfer.key"; };
	        allow-update { key "zonetransfer.key"; };
	        file "/etc/named/dynamic/named.ddns.lab";
	    };

	    // labs newdns zone
	    zone "newdns.lab" {
	        type master;
	        allow-transfer { key "zonetransfer.key"; };
	        file "/etc/named/named.newdns.lab";
	    };

	    // labs zone reverse
	    zone "50.168.192.in-addr.arpa" {
	        type master;
	        allow-transfer { key "zonetransfer.key"; };
	        file "/etc/named/named.50.168.192.rev";
	    };
	};

В конфигурационном файле видно, что пути к файлам *ddns* указан каталог */etc/named/*.

Отсюда я вижу два пути решения:

+ Изменить в конфигурационном файле путь к файлам на */var/named/* и перенести файлы в этот каталог
+ Изменить контекст для каталога */etc/named/*

Попробуем второй вариант. Посмотрим контекст в каталоге */var/named/*

	[root@ns01 vagrant]# ls -la -Z /var/named/
	drwxrwx--T. root  named system_u:object_r:named_zone_t:s0 .
	drwxr-xr-x. root  root  system_u:object_r:var_t:s0       ..
	drwxrwx---. named named system_u:object_r:named_cache_t:s0 data
	drwxrwx---. named named system_u:object_r:named_cache_t:s0 dynamic
	-rw-r-----. root  named system_u:object_r:named_conf_t:s0 named.ca
	-rw-r-----. root  named system_u:object_r:named_zone_t:s0 named.empty
	-rw-r-----. root  named system_u:object_r:named_zone_t:s0 named.localhost
	-rw-r-----. root  named system_u:object_r:named_zone_t:s0 named.loopback
	drwxrwx---. named named system_u:object_r:named_cache_t:s0 slaves

Посмотрим уже имеющиеся политики selinux для *named*

	[root@ns01 vagrant]# semanage fcontext -l | grep named
	/etc/rndc.*                                        regular file       system_u:object_r:named_conf_t:s0 
	/var/named(/.*)?                                   all files          system_u:object_r:named_zone_t:s0 
	/etc/unbound(/.*)?                                 all files          system_u:object_r:named_conf_t:s0 
	/var/run/bind(/.*)?                                all files          system_u:object_r:named_var_run_t:s0 
	/var/log/named.*                                   regular file       system_u:object_r:named_log_t:s0 
	/var/run/named(/.*)?                               all files          system_u:object_r:named_var_run_t:s0 
	/var/named/data(/.*)?                              all files          system_u:object_r:named_cache_t:s0 
	/dev/xen/tapctrl.*                                 named pipe         system_u:object_r:xenctl_t:s0 
	/var/run/unbound(/.*)?                             all files          system_u:object_r:named_var_run_t:s0 
	/var/lib/softhsm(/.*)?                             all files          system_u:object_r:named_cache_t:s0 
	/var/lib/unbound(/.*)?                             all files          system_u:object_r:named_cache_t:s0 
	/var/named/slaves(/.*)?                            all files          system_u:object_r:named_cache_t:s0 
	/var/named/chroot(/.*)?                            all files          system_u:object_r:named_conf_t:s0 
	/etc/named\.rfc1912.zones                          regular file       system_u:object_r:named_conf_t:s0 
	/var/named/dynamic(/.*)?                           all files          system_u:object_r:named_cache_t:s0 
	/var/named/chroot/etc(/.*)?                        all files          system_u:object_r:etc_t:s0 
	/var/named/chroot/lib(/.*)?                        all files          system_u:object_r:lib_t:s0 
	/var/named/chroot/proc(/.*)?                       all files          <<None>>
	/var/named/chroot/var/tmp(/.*)?                    all files          system_u:object_r:named_cache_t:s0 
	/var/named/chroot/usr/lib(/.*)?                    all files          system_u:object_r:lib_t:s0 
	/var/named/chroot/etc/pki(/.*)?                    all files          system_u:object_r:cert_t:s0 
	/var/named/chroot/run/named.*                      all files          system_u:object_r:named_var_run_t:s0 
	/var/named/chroot/var/named(/.*)?                  all files          system_u:object_r:named_zone_t:s0 
	/usr/lib/systemd/system/named.*                    regular file       system_u:object_r:named_unit_file_t:s0 
	/var/named/chroot/var/run/dbus(/.*)?               all files          system_u:object_r:system_dbusd_var_run_t:s0 
	/usr/lib/systemd/system/unbound.*                  regular file       system_u:object_r:named_unit_file_t:s0 
	/var/named/chroot/var/log/named.*                  regular file       system_u:object_r:named_log_t:s0 
	/var/named/chroot/var/run/named.*                  all files          system_u:object_r:named_var_run_t:s0 
	/var/named/chroot/var/named/data(/.*)?             all files          system_u:object_r:named_cache_t:s0 
	/usr/lib/systemd/system/named-sdb.*                regular file       system_u:object_r:named_unit_file_t:s0 
	/var/named/chroot/var/named/slaves(/.*)?           all files          system_u:object_r:named_cache_t:s0 
	/var/named/chroot/etc/named\.rfc1912.zones         regular file       system_u:object_r:named_conf_t:s0 
	/var/named/chroot/var/named/dynamic(/.*)?          all files          system_u:object_r:named_cache_t:s0 
	/var/run/ndc                                       socket             system_u:object_r:named_var_run_t:s0 
	/dev/gpmdata                                       named pipe         system_u:object_r:gpmctl_t:s0 
	/dev/initctl                                       named pipe         system_u:object_r:initctl_t:s0 
	/dev/xconsole                                      named pipe         system_u:object_r:xconsole_device_t:s0 
	/usr/sbin/named                                    regular file       system_u:object_r:named_exec_t:s0 
	/etc/named\.conf                                   regular file       system_u:object_r:named_conf_t:s0 
	/usr/sbin/lwresd                                   regular file       system_u:object_r:named_exec_t:s0 
	/var/run/initctl                                   named pipe         system_u:object_r:initctl_t:s0 
	/usr/sbin/unbound                                  regular file       system_u:object_r:named_exec_t:s0 
	/usr/sbin/named-sdb                                regular file       system_u:object_r:named_exec_t:s0 
	/var/named/named\.ca                               regular file       system_u:object_r:named_conf_t:s0 
	/etc/named\.root\.hints                            regular file       system_u:object_r:named_conf_t:s0 
	/var/named/chroot/dev                              directory          system_u:object_r:device_t:s0 
	/etc/rc\.d/init\.d/named                           regular file       system_u:object_r:named_initrc_exec_t:s0 
	/usr/sbin/named-pkcs11                             regular file       system_u:object_r:named_exec_t:s0 
	/etc/rc\.d/init\.d/unbound                         regular file       system_u:object_r:named_initrc_exec_t:s0 
	/usr/sbin/unbound-anchor                           regular file       system_u:object_r:named_exec_t:s0 
	/usr/sbin/named-checkconf                          regular file       system_u:object_r:named_checkconf_exec_t:s0 
	/usr/sbin/unbound-control                          regular file       system_u:object_r:named_exec_t:s0 
	/var/named/chroot_sdb/dev                          directory          system_u:object_r:device_t:s0 
	/var/named/chroot/var/log                          directory          system_u:object_r:var_log_t:s0 
	/var/named/chroot/dev/log                          socket             system_u:object_r:devlog_t:s0 
	/etc/rc\.d/init\.d/named-sdb                       regular file       system_u:object_r:named_initrc_exec_t:s0 
	/var/named/chroot/dev/null                         character device   system_u:object_r:null_device_t:s0 
	/var/named/chroot/dev/zero                         character device   system_u:object_r:zero_device_t:s0 
	/usr/sbin/unbound-checkconf                        regular file       system_u:object_r:named_exec_t:s0 
	/var/named/chroot/dev/random                       character device   system_u:object_r:random_device_t:s0 
	/var/run/systemd/initctl/fifo                      named pipe         system_u:object_r:initctl_t:s0 
	/var/named/chroot/etc/rndc\.key                    regular file       system_u:object_r:dnssec_t:s0 
	/usr/share/munin/plugins/named                     regular file       system_u:object_r:services_munin_plugin_exec_t:s0 
	/var/named/chroot_sdb/dev/null                     character device   system_u:object_r:null_device_t:s0 
	/var/named/chroot_sdb/dev/zero                     character device   system_u:object_r:zero_device_t:s0 
	/var/named/chroot/etc/localtime                    regular file       system_u:object_r:locale_t:s0 
	/var/named/chroot/etc/named\.conf                  regular file       system_u:object_r:named_conf_t:s0 
	/var/named/chroot_sdb/dev/random                   character device   system_u:object_r:random_device_t:s0 
	/etc/named\.caching-nameserver\.conf               regular file       system_u:object_r:named_conf_t:s0 
	/usr/lib/systemd/systemd-hostnamed                 regular file       system_u:object_r:systemd_hostnamed_exec_t:s0 
	/var/named/chroot/var/named/named\.ca              regular file       system_u:object_r:named_conf_t:s0 
	/var/named/chroot/etc/named\.root\.hints           regular file       system_u:object_r:named_conf_t:s0 
	/var/named/chroot/etc/named\.caching-nameserver\.conf regular file       system_u:object_r:named_conf_t:s0 
	/var/named/chroot/lib64 = /usr/lib
	/var/named/chroot/usr/lib64 = /usr/lib

Изменим контекст в */etc/named/* похожим образом.

	[root@ns01 vagrant]# semanage fcontext -a -t named_zone_t "/etc/named(/.*)?"
	[root@ns01 vagrant]# semanage fcontext -a -t named_cache_t "/etc/named/dynamic(/.*)?"
	[root@ns01 vagrant]# restorecon -R -v /etc/named
	restorecon reset /etc/named context system_u:object_r:etc_t:s0->system_u:object_r:named_zone_t:s0
	restorecon reset /etc/named/named.dns.lab context system_u:object_r:etc_t:s0->system_u:object_r:named_zone_t:s0
	restorecon reset /etc/named/named.dns.lab.view1 context system_u:object_r:etc_t:s0->system_u:object_r:named_zone_t:s0
	restorecon reset /etc/named/dynamic context unconfined_u:object_r:etc_t:s0->unconfined_u:object_r:named_cache_t:s0
	restorecon reset /etc/named/dynamic/named.ddns.lab context system_u:object_r:etc_t:s0->system_u:object_r:named_cache_t:s0
	restorecon reset /etc/named/dynamic/named.ddns.lab.view1 context system_u:object_r:etc_t:s0->system_u:object_r:named_cache_t:s0
	restorecon reset /etc/named/named.newdns.lab context system_u:object_r:etc_t:s0->system_u:object_r:named_zone_t:s0
	restorecon reset /etc/named/named.50.168.192.rev context system_u:object_r:etc_t:s0->system_u:object_r:named_zone_t:s0
	
Проверим изменения контекста для каталога */etc/named/*

	[root@ns01 vagrant]# ls -Z /etc/named
	drw-rwx---. root named unconfined_u:object_r:named_cache_t:s0 dynamic
	-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.50.168.192.rev
	-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab
	-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab.view1
	-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.newdns.lab

Проверим на клиенте

	root@client vagrant]# nsupdate -k /etc/named.zonetransfer.key
	> server 192.168.50.10
	> zone ddns.lab
	> update add www.ddns.lab. 60 A 192.168.50.15
	> send
	> quit
	[root@client vagrant]# 

Смотрим получилось ли *named* создать файл на *ns01*

	[root@ns01 dynamic]# ls -la /etc/named/dynamic/
	total 12
	drw-rwx---. 2 root  named  88 окт 13 07:47 .
	drw-rwx---. 3 root  named 121 окт 12 07:54 ..
	-rw-rw----. 1 named named 509 окт 12 07:54 named.ddns.lab
	-rw-rw----. 1 named named 509 окт 12 07:54 named.ddns.lab.view1
	-rw-r--r--. 1 named named 700 окт 13 07:47 named.ddns.lab.view1.jnl
