# SSH Login Alert Script

This script sets up `msmtp` and configures it to send email alerts on SSH login. It performs several actions to ensure the proper installation and configuration of required packages, as well as the creation of necessary scripts and configurations to enable email notifications.

## Features
- Sends an email notification upon every SSH login
- Configurable email recipient
- Easy setup and installation

## The script will do the following

- Installs `msmtp`, `msmtp-mta`, and `apparmor-utils` packages if not already installed.
- Creates a log directory at `/var/log/msmtp/` with appropriate permissions.
- Creates a group `msmtp` for logging and adds the current user to this group.
- Prompts the user for email configuration details and recipient email address.
- Creates the `msmtp` configuration file at `/etc/msmtprc` with the provided details.
- Ensures the `msmtp` configuration file has secure permissions.
- Creates a symlink from `/usr/bin/msmtp` to `/usr/sbin/sendmail`.
- Creates an SSH login alert script at `/usr/local/bin/ssh-login-alert.sh`.
- Configures SSH to trigger the alert script on login by creating a script at `/etc/profile.d/ssh-login-alert.sh`.
- Ensures that AppArmor is set to complain mode for `msmtp` and makes this change permanent by creating or updating `/etc/rc.local`.

## Prerequisites

- Ensure you have `sudo` privileges to run this script as it requires root access.

## Usage

1. **Download the script:**

    ```bash
    wget https://raw.githubusercontent.com/linsnotes/ssh-login-alert/main/ssh-login-alert.sh
    ```

2. **Make the Script Executable:**

    ```bash
    sudo chmod +x ssh-login-alert.sh
    ```
3. **Run the Script:**
    ```bash
    sudo ./ssh-login-alert.sh
    ```
5. **Follow the Prompts:**

    - The script will prompt you for the following:
        - 'from' email address
        - 'user' email address
        - Email password (input securely)
        - Recipient email address

6. **Confirm Critical Actions:**

    - You will be prompted to confirm the installation of packages, modifications to AppArmor.

7. **Uninstall**
    ```bash
    wget https://raw.githubusercontent.com/linsnotes/ssh-login-alert/main/uninstall.sh
    ```

   ```bash
    sudo chmod +x uninstall.sh
    ```

   ```bash
    sudo ./uninstall.sh
    ```

## Additional AppArmor Instructions

If you encounter a permission error such as:

```
sendmail: cannot log to /var/log/msmtp/msmtp.log: cannot open: Permission denied
```

It is likely caused by AppArmor. To resolve this, you can temporarily disable the AppArmor profile for msmtp. Follow these steps to configure AppArmor for `msmtp`:

```bash
# Install AppArmor Utilities
sudo apt-get install apparmor-utils

# Create a symlink in the disable directory:
sudo ln -s /etc/apparmor.d/usr.bin.msmtp /etc/apparmor.d/disable/usr.bin.msmtp

# Reload the AppArmor profiles:
sudo apparmor_parser -R /etc/apparmor.d/usr.bin.msmtp
-----------------------------------------------------
# To enable the profile again:
# Remove the symlink from the disable directory:
sudo rm /etc/apparmor.d/disable/usr.bin.msmtp

# Reload the AppArmor profile:
sudo apparmor_parser -r /etc/apparmor.d/usr.bin.msmtp

# Set the profile to enforce mode:
sudo aa-enforce /etc/apparmor.d/usr.bin.msmtp
```


## Removal Instructions

To remove all changes made by this script, run the following commands:

```bash
sudo apt-get remove msmtp msmtp-mta apparmor-utils
sudo rm /etc/profile.d/ssh-login-alert.sh
sudo rm -r /var/log/msmtp
sudo rm /etc/msmtprc
sudo rm /etc/rc.local
sudo deluser <username> msmtp
sudo usermod -g nogroup msmtp
sudo groupdel msmtp
sudo userdel msmtp
```

Replace `<username>` with the actual username you want to remove from the `msmtp` group.

## Security Considerations

- **Password Handling:** The script prompts for the email password and stores it in the `msmtp` configuration file. Ensure the configuration file is securely handled and permissions are correctly set.
- **AppArmor Mode:** The script sets AppArmor to complain mode for `msmtp`, reducing its enforcement effectiveness. AppArmor is a security module that restricts the actions of programs based on predefined profiles. By default, AppArmor may prevent `msmtp` (the mail sending utility) from writing logs to `/var/log/msmtp/msmtp.log`, which can interfere with the script's ability to log email sending actions. To ensure `msmtp` can log its activities, the script sets AppArmor to complain mode. In this mode, AppArmor allows `msmtp` to perform all actions but logs any actions that would have been blocked in enforcing mode. This ensures `msmtp` can write to the log file without issues. You will be asked to confirm this action during the script execution.

- **Symlink Creation:** Overwriting the `sendmail` binary with a symlink may cause unintended side effects. Understand the implications and confirm this action during the script execution.

## License

This project is licensed under the MIT License.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

Feel free to modify the documentation as per your project's specific requirements and details.
