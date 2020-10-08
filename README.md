# selinux

## Смена порта в NGINX
Изменив порт в */etc/nginx/nginx.conf* selinux не даст нам запустить на нестандартном порту nginx.

Утилита *sealert* предлагает нам три рекомендации

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

	[root@selinux etc]# systemctl status nginx


### setbool

Найдем параметризованную политику, которую нам предлагает *sealert*

	[root@selinux vagrant]# getsebool -a | grep nis
	nis_enabled --> off
	varnishd_connect_any --> off


Разрешим параметризованную политику NIS (Network Information Service)командой

	setsebool -P nis_enabled 1


### audit

Утилита *sealert* также нам предлагает создать модуль локальной политики для разрешенных действий.

Создадим необходимый нам модуль

	ausearch -c 'nginx' --raw | audit2allow -M my-nginx

Применим этот модуль
	
	semodule -i my-nginx.pp

### Примечание

Наиболее оптимальным способом в данной ситуации лучше подходит первый вариатн с *semanage*. Второй вариант довольно радикальный и дает разрешение всем сервисам работающим через политику NIS. Третий вариант тоже довольно грубый, так как создавая модуль мы точно не знаем (можно перед применением посмотреть созданный модуль), что именно утилита *audit2allow* разрешит нашему ПО в данном модуле. 