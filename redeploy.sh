#!/bin/bash
# One-command redeploy script for the Online Resume System.
# Run this on the EC2 instance (or via SSH) after pushing changes to GitHub.
set -e
REPO_URL="https://github.com/fendi-321/Serverless-Architecture.git"
TMP_DIR="/tmp/repo_deploy_$(date +%s)"

echo "==> Cloning latest code..."
git clone --depth 1 "$REPO_URL" "$TMP_DIR"

echo "==> Copying application files to /var/www/html (preserving uploaded images)..."
sudo mkdir -p /tmp/images_backup
sudo cp -r /var/www/html/assets/images/. /tmp/images_backup/ 2>/dev/null || true
sudo cp -r "$TMP_DIR/newCVproject/." /var/www/html/
sudo cp -r /tmp/images_backup/. /var/www/html/assets/images/ 2>/dev/null || true
sudo rm -rf /tmp/images_backup


echo "==> Re-applying any pending SQL updates (safe to re-run)..."
if [ -f "$TMP_DIR/newCVproject/update_my_cv.sql" ]; then
  sudo mysql -u root online_resume_system < "$TMP_DIR/newCVproject/update_my_cv.sql"
fi

echo "==> Fixing permissions..."
sudo chown -R apache:apache /var/www/html
sudo chmod -R 755 /var/www/html
sudo chmod -R 775 /var/www/html/assets/images

echo "==> Restarting services..."
sudo systemctl restart php-fpm httpd

echo "==> Cleaning up..."
rm -rf "$TMP_DIR"

echo "==> Redeploy complete!"
