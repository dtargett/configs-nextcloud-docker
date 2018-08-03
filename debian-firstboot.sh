#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
 
# Wait for apt-get to be available.
while ! apt-get -qq check; do sleep; done
 
# Install docker-ce and docker-compose.
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian `lsb_release -cs` stable"
apt-get update
apt-get install -y docker-ce
curl -fsSL https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
 
# Check for security updates every night and install them.
apt-get install -y unattended-upgrades
 
# Retrieve configuration files. Lots of explanatory comments inside!
# If you'd rather inspect and install these files yourself, see:
# https://docs.bytemark.co.uk/article/wordpress-on-docker-with-phpmyadmin-ssl-via-traefik-and-automatic-updates/#look-a-bit-deeper
mkdir -p /root/compose
curl -fsSL https://raw.githubusercontent.com/dtargett/configs-nextcloud-docker/master/docker-compose.yml -o /root/compose/docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/dtargett/configs-nextcloud-docker/master/.env -o /root/compose/.env
curl -fsSL https://raw.githubusercontent.com/BytemarkHosting/configs-wordpress-docker/master/traefik.toml -o /root/compose/traefik.toml
curl -fsSL https://raw.githubusercontent.com/BytemarkHosting/configs-wordpress-docker/master/php.ini -o /root/compose/php.ini

# Check for extra disk for users files otherwise create a folder on the root drive for data.
if [ -b /dev/vdb ] ; then {
   apt-get -y install xfsprogs
   mkfs.xfs /dev/vdb
   mkdir /data
   echo "dev/vdb  /data  xfs  defaults  0  2" | tee -a /etc/fstab
   mount -t xfs /dev/vdb /data
} else {
   mkdir /data
}
fi

# Traefik needs a file to store SSL/TLS keys and certificates.
touch /root/compose/acme.json
chmod 0600 /root/compose/acme.json
 
# Use the hostname of the server as the main domain.
sed -i -e "s|^TRAEFIK_DOMAINS=.*|TRAEFIK_DOMAINS=`hostname -f`|" /root/compose/.env
sed -i -e "s|^NEXTCLOUD_DOMAINS=.*|NEXTCLOUD_DOMAINS=`hostname -f`|" /root/compose/.env

# Use the panel username as the nextcloud admin user.
sed -i -e "s|^NEXTCLOUD_ADMIN_USER=.*|NEXTCLOUD_ADMIN_USER=`hostname -f | cut -d "." -f 3`|" /root/compose/.env

# Fill /root/compose/.env with some randomly generated passwords.
sed -i -e "s|^NEXTCLOUD_DB_ROOT_PASSWORD=.*|NEXTCLOUD_DB_ROOT_PASSWORD=`cat /dev/urandom | tr -dc '[:alnum:]' | head -c14`|" /root/compose/.env
sed -i -e "s|^NEXTCLOUD_DB_PASSWORD=.*|NEXTCLOUD_DB_PASSWORD=`cat /dev/urandom | tr -dc '[:alnum:]' | head -c14`|" /root/compose/.env
sed -i -e "s|^NEXTCLOUD_ADMIN_PASSWORD=.*|NEXTCLOUD_ADMIN_PASSWORD=`cat /dev/urandom | tr -dc '[:alnum:]' | head -c14`|" /root/compose/.env
apt-get install -y apache2-utils
BASIC_AUTH_PASSWORD="`cat /dev/urandom | tr -dc '[:alnum:]' | head -c10`"
BASIC_AUTH="`printf '%s\n' "$BASIC_AUTH_PASSWORD" | tee /root/compose/auth-password.txt | htpasswd -in admin`"
sed -i -e "s|^BASIC_AUTH=.*|BASIC_AUTH=$BASIC_AUTH|" /root/compose/.env
 
# Start our containers.
cd /root/compose
docker-compose up -d
