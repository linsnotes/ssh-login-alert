#!/usr/bin/env bash

# This script sets up msmtp and configures it to send email alerts on SSH login.
# It performs the following actions:
# - Installs the msmtp and msmtp-mta packages if they are not already installed.
# - Creates a log directory at /var/log/msmtp/ with appropriate permissions.
# - Creates a group 'msmtp' for logging and adds the current user to this group.
# - Prompts the user for email configuration details and recipient email address.
# - Creates the msmtp configuration file at /etc/msmtprc with the provided details.
# - Ensures the msmtp configuration file has secure permissions.
# - Creates a symlink from /usr/bin/msmtp to /usr/sbin/sendmail.
# - Creates an SSH login alert script at /usr/local/bin/ssh-login-alert.sh.
# - Configures SSH to trigger the alert script on login by creating a script at /etc/profile.d/ssh-login-alert.sh.
# - Reminds the user to choose 'no' if the system prompts to enable AppArmor for msmtp.
#
# After running this script, users can:
# - Receive email alerts whenever someone logs in to the server via SSH.
# - Modify the msmtp configuration at /etc/msmtprc if needed.
# - Check the log file at /var/log/msmtp/msmtp.log for logging information.
# - Send emails using sendmail and msmtp commands.
#
# To remove all changes made by this script:
# - Run the following commands:
#   sudo apt purge -y msmtp msmtp-mta
#   sudo rm /etc/profile.d/ssh-login-alert.sh
#   sudo rm /usr/local/bin/ssh-login-alert.sh
#   sudo rm -r /var/log/msmtp
#   sudo rm /etc/msmtprc
#   sudo rm /etc/rc.local
#   sudo unlink /usr/sbin/sendmail
#   sudo deluser <username> msmtp
#   sudo usermod -g nogroup msmtp
#   sudo groupdel msmtp
#   sudo userdel msmtp
#   sudo apt autoremove -y
# Note: Replace <username> with the actual username you want to remove from the msmtp group.

# Ensure the script is run with sudo
[[ "$EUID" -ne 0 ]] && { echo "This script must be run as root. Use sudo."; exit 1; }

# Set the non-root user to the user who invoked sudo
NON_ROOT_USER="${SUDO_USER:-$(whoami)}"

LOGDIR="/var/log/msmtp"
LOGFILE="$LOGDIR/msmtp.log"
LOGGROUP="msmtp"

# Ensure the log group exists
if ! getent group $LOGGROUP > /dev/null; then
    groupadd $LOGGROUP
fi

# Create log directory and set permissions
if [[ ! -d "$LOGDIR" ]]; then
    mkdir -p "$LOGDIR"
    chown root:$LOGGROUP "$LOGDIR"
    chmod 2775 "$LOGDIR"
fi

# Create log file if it doesn't exist
if [[ ! -f "$LOGFILE" ]]; then
    touch "$LOGFILE"
    chown root:$LOGGROUP "$LOGFILE"
    chmod 664 "$LOGFILE"
fi

# Add the non-root user to the logging group
usermod -a -G $LOGGROUP $NON_ROOT_USER

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOGFILE"
}

# Trap errors and exit
trap 'log "An error occurred. Exiting."; exit 1' ERR

log "Starting msmtp setup script."

# Reminder to user about AppArmor
while true; do
    echo "If the system prompts you with 'Enable AppArmor support?', select 'No'. Enabling AppArmor support might cause a permission error."
    read -p "Do you understand this instruction? (yes/no): " CONFIRM_APPARMOR
    case "$CONFIRM_APPARMOR" in
        yes ) break;;
        no ) echo "Please ensure you understand this instruction before proceeding.";;
        * ) echo "Please answer yes or no.";;
    esac
done

# Confirm before package installation
echo "The script will install the following packages: msmtp, msmtp-mta."
read -p "Do you want to proceed with the package installation? (yes/no): " CONFIRM_INSTALL
if [[ "$CONFIRM_INSTALL" != "yes" ]]; then
    log "Package installation aborted by user. Exiting."
    exit 1
fi

# Check if msmtp is installed, if not install it
if ! command -v msmtp >/dev/null 2>&1; then
    log "msmtp is not installed. Installing..."
    apt update && apt install -y msmtp
    if [[ $? -ne 0 ]]; then
        log "Failed to install msmtp. Exiting."
        exit 1
    fi
else
    log "msmtp is already installed."
fi

# Check if msmtp-mta is installed, if not install it
if ! dpkg -l | grep -q msmtp-mta; then
    log "msmtp-mta is not installed. Installing..."
    apt install -y msmtp-mta
    if [[ $? -ne 0 ]]; then
        log "Failed to install msmtp-mta. Exiting."
        exit 1
    fi
else
    log "msmtp-mta is already installed."
fi


# Prompt user for email configuration
log "Prompting user for email configuration."

read -p "Enter the 'from' email address: " FROM_EMAIL
read -p "Enter the 'user' email address: " USER_EMAIL

# Prompt for password twice to ensure correctness
while true; do
    read -s -p "Enter the 'password': " EMAIL_PASSWORD
    echo
    read -s -p "Confirm the 'password': " EMAIL_PASSWORD_CONFIRM
    echo
    if [ "$EMAIL_PASSWORD" == "$EMAIL_PASSWORD_CONFIRM" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

# Validate email inputs
if [[ -z "$FROM_EMAIL" || -z "$USER_EMAIL" || -z "$EMAIL_PASSWORD" ]]; then
    log "Email configuration input is invalid. Exiting."
    exit 1
fi

# Prompt user for recipient email
log "Prompting user for recipient email address."
read -p "Enter the recipient email address: " RECIPIENT_EMAIL

# Validate recipient email
if [[ -z "$RECIPIENT_EMAIL" ]]; then
    log "Recipient email input is invalid. Exiting."
    exit 1
fi

# Create the msmtp configuration file
CONFIG_FILE="/etc/msmtprc"

log "Creating msmtp configuration file at $CONFIG_FILE."
cat <<EOL > "$CONFIG_FILE"
# Set default settings for all accounts
defaults
auth           on
tls            on
tls_starttls   off
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        $LOGFILE

# Example account configuration
account        gmail
host           smtp.gmail.com
port           465
from           $FROM_EMAIL
user           $USER_EMAIL
password       "$EMAIL_PASSWORD"

# Set a default account
account default : gmail
EOL
log "Configuration file created."

# Ensure correct permissions for msmtp configuration file
chmod 644 "$CONFIG_FILE"
chown root:root "$CONFIG_FILE"

# Confirm before creating symlink
#echo "The script will create a symlink from /usr/bin/msmtp to /usr/sbin/sendmail."
#echo "Overwriting the sendmail binary with a symlink may cause unintended side effects."
#read -p "Do you want to proceed with creating the symlink? (yes/no): " CONFIRM_SYMLINK
#if [[ "$CONFIRM_SYMLINK" != "yes" ]]; then
#    log "Symlink creation aborted by user. Exiting."
#    exit 1
#fi

# Symlink msmtp to sendmail
#if [[ ! -L /usr/sbin/sendmail ]]; then
#    log "Creating symlink from /usr/bin/msmtp to /usr/sbin/sendmail."
#    ln -sf /usr/bin/msmtp /usr/sbin/sendmail
#else
#    log "Symlink /usr/sbin/sendmail already exists."
#fi

# Create the SSH Login Alert Script
ALERT_SCRIPT="/usr/local/bin/ssh-login-alert.sh"

log "Creating SSH login alert script at $ALERT_SCRIPT."
cat <<EOL > "$ALERT_SCRIPT"
#!/bin/bash

# Getting user and IP information
USER=\$(whoami)
IP=\$(echo \$SSH_CLIENT | awk '{ print \$1 }')

# Message to be sent
MESSAGE="User \$USER logged in to \$(hostname) from \$IP"

# Sending the email
echo -e "Subject: SSH Login Alert\n\n\$MESSAGE" | sendmail -t $RECIPIENT_EMAIL
EOL

# Ensure the script is executable
chmod +x "$ALERT_SCRIPT"

# Configure SSH to trigger the script on login
SSHR_CONFIG="/etc/profile.d/ssh-login-alert.sh"

log "Creating SSH login alert script link at $SSHR_CONFIG."
cat <<EOL > "$SSHR_CONFIG"
#!/bin/bash

if [[ -n "\$SSH_CLIENT" ]]; then
    $ALERT_SCRIPT
fi
EOL

# Ensure the script is executable
chmod +x "$SSHR_CONFIG"

log "msmtp setup script completed successfully."
echo "If you encounter a permission error such as:"
echo " sendmail: cannot log to /var/log/msmtp/msmtp.log: cannot open: Permission denied"
echo "It is likely caused by AppArmor. To resolve this, you can disable the AppArmor profile for msmtp."
echo "Follow these steps to configure AppArmor for msmtp:"
echo "# Create a symlink in the disable directory:"
echo " sudo ln -sf /etc/apparmor.d/usr.bin.msmtp /etc/apparmor.d/disable/usr.bin.msmtp"
echo "# Reload the AppArmor profile:"
echo " sudo apparmor_parser -r /etc/apparmor.d/usr.bin.msmtp"
