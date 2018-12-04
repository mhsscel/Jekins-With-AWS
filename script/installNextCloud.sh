#!/bin/bash

# Script Instalação do NextCloud para Ubuntu 16.04
# Murillo Henrique Silva Soares
# Engenharia de Software  - IFMT 

nextcloud_url='' # URL da instancia NextCloud
nextcloud_version='12.0.3' # NextCloud version
db_root_password='infosize' # MySQL senha root
db_user_password='infosize' # MySQL senha user
datapath='/cloud' # Pasta de armazenamento para arquivos de usuario

ocpath='/var/www/nextcloud' # Pasta de instalação NextCloud
htuser='www-data' # Configuração para 
htgroup='www-data' # Apache
rootuser='root'

# Check se esta executando como usuario root
if [ "$(id -u)" != "0" ]; then
   echo "Este script deve ser executado como root" 1>&2
   exit 1
fi

# Atualiza Repositorios e instala pacotes

# Add PHP 7.0 Repositorio
add-apt-repository ppa:ondrej/php -y
apt-get update

# Instala Apache, Redis e extensoes PHP
apt-get install apache2 -y
apt-get install php7.0 php7.0-curl php7.0-gd php7.0-fpm php7.0-cli php7.0-opcache php7.0-mbstring php7.0-xml php7.0-zip -y
apt-get install redis-server php-redis -y

# Instala servidor de banco de dados MySQL
export DEBIAN_FRONTEND="noninteractive"
debconf-set-selections <<< "mysql-server mysql-server/root_password password $db_root_password"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $db_root_password"
apt-get install mysql-server php7.0-mysql -y

# Ativa extensoes Apache
a2enmod proxy_fcgi setenvif
a2enconf php7.0-fpm
service apache2 reload
apt-get install libxml2-dev php7.0-zip php7.0-xml php7.0-gd php7.0-curl php7.0-mbstring -y
a2enmod rewrite
service apache2 reload

# Faz o download do Nextcloud no diretório web
printf '<meta http-equiv="refresh" content="0;URL='"'""$nextcloud_url"'/nextcloud'"'"'" />' > /var/www/html/index.html
wget https://download.nextcloud.com/server/releases/nextcloud-$nextcloud_version.zip
apt-get install unzip -y
unzip nextcloud-$nextcloud_version.zip -d /var/www
rm nextcloud-$nextcloud_version.zip

# Cria diretorio de dados se ainda nao existe
mkdir -p $datapath

# Seta permissoes de arquivos e pastas
printf "Criando diretorios necessarios\n"
mkdir -p $ocpath/data
mkdir -p $ocpath/assets
mkdir -p $ocpath/updater

printf "Chmod (Permissoes) Arquivos e Diretorios\n"
find ${ocpath}/ -type f -print0 | xargs -0 chmod 0640
find ${ocpath}/ -type d -print0 | xargs -0 chmod 0750

printf "Chown (Permissoes) Diretorios\n"
chown -R ${rootuser}:${htgroup} ${ocpath}/
chown -R ${htuser}:${htgroup} ${ocpath}/apps/
chown -R ${htuser}:${htgroup} ${ocpath}/assets/
chown -R ${htuser}:${htgroup} ${ocpath}/config/
chown -R ${htuser}:${htgroup} ${ocpath}/data/
chown -R ${htuser}:${htgroup} ${datapath}/
chown -R ${htuser}:${htgroup} ${ocpath}/themes/
chown -R ${htuser}:${htgroup} ${ocpath}/updater/
chown -R ${htuser}:${htgroup} /tmp
chmod +x ${ocpath}/occ

printf "chmod/chown .htaccess\n"
if [ -f ${ocpath}/.htaccess ]
then
 chmod 0644 ${ocpath}/.htaccess
 chown ${rootuser}:${htgroup} ${ocpath}/.htaccess
fi

if [ -f ${ocpath}/data/.htaccess ]
then
 chmod 0644 ${ocpath}/data/.htaccess
 chown ${rootuser}:${htgroup} ${ocpath}/data/.htaccess
fi

# Configura Apache
touch /etc/apache2/sites-available/nextcloud.conf
printf "Alias /nextcloud "/var/www/nextcloud/"\n\n<Directory /var/www/nextcloud/>\n Options +FollowSymlinks\n AllowOverride All\n\n<IfModule mod_dav.c>\n Dav off\n</IfModule>\n\nSetEnv HOME /var/www/nextcloud\nSetEnv HTTP_HOME /var/www/nextcloud\n\n</Directory>" > /etc/apache2/sites-available/nextcloud.conf
ln -s /etc/apache2/sites-available/nextcloud.conf /etc/apache2/sites-enabled/nextcloud.conf
a2enmod headers
a2enmod env
a2enmod dir
a2enmod mime
service apache2 reload

# Configura banco de dados MySQL
mysql -uroot -p$db_root_password <<QUERY_INPUT
CREATE DATABASE nextcloud;
CREATE USER 'nextclouduser'@'localhost' IDENTIFIED BY '$db_user_password';
GRANT ALL PRIVILEGES ON nextcloud.* TO nextclouduser@localhost;
FLUSH PRIVILEGES;
EXIT
QUERY_INPUT

# Ativa agendador de tarefa a cada 15 minutes
crontab -u www-data -l > cron
echo "*/15  *  *  *  * php -f /var/www/nextcloud/cron.php" >> cron
crontab -u www-data cron
rm cron

# Instalacao completa
printf "\n\nInstalacao completa.\nNavegue até a instância do NextCloud a partir do navegador para concluir o assistente de configuração.\n\n"
