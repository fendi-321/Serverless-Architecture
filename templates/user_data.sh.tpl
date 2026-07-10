#!/bin/bash
# Online Resume System - EC2 Bootstrap Script (Amazon Linux 2023)
# Installs Apache + PHP + MariaDB (LAMP), deploys app from GitHub,
# imports database, and configures a nightly backup to S3.
set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "==> Updating system packages"
dnf update -y

echo "==> Installing Apache, PHP, MariaDB, Git"
dnf install -y httpd php php-cli php-pdo php-mysqlnd php-mbstring php-xml php-gd php-json git mariadb105-server unzip

echo "==> Starting services"
systemctl enable --now mariadb
systemctl enable --now httpd

echo "==> Configuring MariaDB database and app user"
mysql -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS online_resume_system;
CREATE USER IF NOT EXISTS 'cvapp'@'%' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON online_resume_system.* TO 'cvapp'@'%';
FLUSH PRIVILEGES;
SQL

echo "==> Cloning application repo"
cd /tmp
rm -rf repo
git clone --depth 1 ${repo_url} repo

echo "==> Deploying application files to /var/www/html"
rm -f /var/www/html/index.html
cp -r /tmp/repo/newCVproject/* /var/www/html/

echo "==> Importing database schema and CV data"
mysql -u root online_resume_system < /var/www/html/database.sql
if [ -f /var/www/html/update_my_cv.sql ]; then
  mysql -u root online_resume_system < /var/www/html/update_my_cv.sql
fi

echo "==> Configuring Apache environment variables for the app"
cat > /etc/httpd/conf.d/cvapp-env.conf <<EOF
SetEnv DB_HOST 127.0.0.1
SetEnv DB_NAME online_resume_system
SetEnv DB_USER cvapp
SetEnv DB_PASS ${db_password}
EOF

echo "==> Setting permissions"
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 /var/www/html/assets/images

echo "==> Restarting Apache"
systemctl restart httpd

echo "==> Setting up nightly DB backup to S3"
cat > /usr/local/bin/backup-db.sh <<EOF
#!/bin/bash
TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="/tmp/online_resume_system-\$TIMESTAMP.sql.gz"
mysqldump -u root online_resume_system | gzip > "\$BACKUP_FILE"
aws s3 cp "\$BACKUP_FILE" s3://${backup_bucket}/db-backups/
rm -f "\$BACKUP_FILE"
EOF
chmod +x /usr/local/bin/backup-db.sh

cat > /etc/systemd/system/db-backup.service <<'EOF'
[Unit]
Description=Backup Online Resume System DB to S3

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-db.sh
EOF

cat > /etc/systemd/system/db-backup.timer <<'EOF'
[Unit]
Description=Run DB backup nightly

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now db-backup.timer

echo "==> Bootstrap complete"
