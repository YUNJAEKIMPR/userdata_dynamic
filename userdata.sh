
# delete parameter store if exists
for PNAME in /wp/DB_HOST /wp/DB_NAME /wp/DB_USER /wp/DB_PASSWORD; do
ISTHERE=$(aws ssm get-parameters --names $PNAME --query 'Parameters[0].[Value]' --output text)
if [ "$ISTHERE" == "None" ]; then
	:
else
	echo deleting previous value $PNAME
	aws ssm delete-parameter --name $PNAME
fi
done

# put values in parameter store
aws ssm put-parameter --name "/wp/DB_HOST" --value "db.s3891941.store" --type "String" --overwrite
aws ssm put-parameter --name "/wp/DB_NAME" --value "wpdb" --type "String" --overwrite
aws ssm put-parameter --name "/wp/DB_USER" --value "admin" --type "String" --overwrite
aws ssm put-parameter --name "/wp/DB_PASSWORD" --value "admin0000" --type "SecureString" --overwrite


dnf install httpd php php-common php-mysqlnd -y


cd /srv
wget https://wordpress.org/latest.zip
unzip latest.zip

chown apache. wordpress -R
cd wordpress

#aws s3 cp s3://s3891941-bucket-1/userdata/wp-config.php .

# get value from parameter store
MYDBNAME=$(aws ssm get-parameters --names /wp/DB_NAME --query 'Parameters[0].[Value]' --output text)
MYUSER=$(aws ssm get-parameters --names /wp/DB_USER --query 'Parameters[0].[Value]' --output text)
MYPASSWORD=$(aws ssm get-parameters --names /wp/DB_PASSWORD --query 'Parameters[0].[Value]' --with-decryption --output text)
MYHOST=$(aws ssm get-parameters --names /wp/DB_HOST --query 'Parameters[0].[Value]' --output text)

echo === dropping previous db . .
MYSQL_PWD=$MYPASSWORD mysql --connect-expired-password -h $MYHOST -u $MYUSER -e "drop database $MYDBNAME"

echo === creating db . .
MYSQL_PWD=$MYPASSWORD mysql --connect-expired-password -h $MYHOST -u $MYUSER -e "create database $MYDBNAME"
MYSQL_PWD=$MYPASSWORD mysql --connect-expired-password -h $MYHOST -u $MYUSER -e "show databases"

# insert each value in wp-config.php
mv wp-config-sample.php wp-config.php
sed -i s/database_name_here/$MYDBNAME/ wp-config.php
sed -i s/username_here/$MYUSER/ wp-config.php
sed -i s/password_here/$MYPASSWORD/ wp-config.php
sed -i s/localhost/$MYHOST/ wp-config.php
echo "define('FS_METHOD', 'direct');" >> wp-config.php


systemctl enable --now httpd

MYIP=$(curl ifconfig.me --silent)

# wordpress silent install
curl "http://${MYIP}/wp-admin/install.php?step=2" \
  --data-urlencode "weblog_title=Wordpress"\
  --data-urlencode "user_name=admin" \
  --data-urlencode "admin_email=s3891941@rmit.edu.vn" \
  --data-urlencode "admin_password=admin0000" \
  --data-urlencode "admin_password2=admin0000" \
  --data-urlencode "pw_weak=1"  

cd /var/www
rm -rf html
ln -s /srv/wordpress html