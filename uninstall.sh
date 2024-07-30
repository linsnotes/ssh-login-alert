#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Get the username of the user running the script with sudo
USERNAME="$SUDO_USER"

# Remove msmtp and msmtp-mta packages
echo "Removing msmtp and msmtp-mta packages..."
apt-get purge -y msmtp msmtp-mta

# Remove specific files and directories
echo "Removing specific files and directories..."
rm -f /etc/profile.d/ssh-login-alert.sh
rm -f /usr/local/bin/ssh-login-alert.sh
rm -rf /var/log/msmtp
rm -f /etc/msmtprc

# Remove AppArmor profiles and symlink
echo "Removing AppArmor profiles and symlink for msmtp..."
rm -f /etc/apparmor.d/disable/usr.bin.msmtp
rm -f /etc/apparmor.d/usr.bin.msmtp
rm -f /etc/apparmor.d/local/usr.bin.msmtp

# Restart AppArmor to apply changes
echo "Restarting AppArmor..."
systemctl restart apparmor

# Unlink sendmail
echo "Unlinking sendmail..."
unlink /usr/sbin/sendmail

# Remove the user from the msmtp group
echo "Removing user $USERNAME from msmtp group..."
deluser "$USERNAME" msmtp

# Change msmtp user's primary group to nogroup
echo "Changing msmtp user's primary group to nogroup..."
usermod -g nogroup msmtp

# Delete the msmtp group
echo "Deleting the msmtp group..."
groupdel msmtp

# Delete the msmtp user
echo "Deleting the msmtp user..."
userdel msmtp

# Remove apparmor-utils package
echo "Removing apparmor-utils package..."
apt-get remove -y apparmor-utils

# Remove unnecessary packages
echo "Removing unnecessary packages..."
apt-get autoremove -y

echo "All specified tasks have been completed. A reboot is recommended to fully reset AppArmor state."
