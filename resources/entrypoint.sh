#!/bin/sh

if [ ! -d /usr/src/phpMyAdmin ]; then
    mkdir -p /usr/src/phpMyAdmin
    tar -xf /usr/src/phpMyAdmin.tar.xz -C /usr/src/phpMyAdmin --exclude-from=/usr/src/phpMyAdmin.exclude --strip-components=1
fi

if [ ! -e index.php ]; then
	rsync -rlD --delete /usr/src/phpMyAdmin/ /usr/local/phpmyadmin
else
	rsync -rlD --delete --exclude-from /usr/src/phpMyAdmin.exclude /usr/src/phpMyAdmin/ /usr/local/phpmyadmin
fi

if [ ! -f /etc/phpmyadmin/config.secret.inc.php ]; then
   cat > /etc/phpmyadmin/config.secret.inc.php <<EOT
<?php
\$cfg['blowfish_secret'] = '$(tr -dc 'a-zA-Z0-9~!@#$%^&*_()+}{?></";.,[]=-' < /dev/urandom | fold -w 32 | head -n 1)';
EOT
fi

sed -i "s@'configFile' => .*@'configFile' => '/etc/phpmyadmin/config.inc.php',@" /usr/local/phpmyadmin/libraries/vendor_config.php
mkdir -p /usr/local/phpmyadmin/tmp; chown www-data:www-data /usr/local/phpmyadmin/tmp

sed -i "s/\[www\]/\[$PHP_FPM_POOL\]/g" /usr/local/etc/php-fpm.d/docker.conf
sed -i "s/\[www\]/\[$PHP_FPM_POOL\]/g" /usr/local/etc/php-fpm.d/www.conf

envsubst < "/usr/local/etc/php-fpm.conf.docker" > "/usr/local/etc/php-fpm.d/zz-docker.conf"

exec "$@"
