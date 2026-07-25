# Security Notes

## Live ISO Default Credentials

The Zurvan Linux live ISO is designed for testing and installation. The
following defaults are intentionally baked in for usability:

| Setting | Default | Configured in |
|---|---|---|
| Live user | `user` | `config/includes.chroot/` + user-setup |
| Live user password | `zurvan` | `config/hooks/normal/02-openssh-fix.hook.chroot` |
| SSH password auth | **enabled** | `config/hooks/normal/02-openssh-fix.hook.chroot` |
| Root login (SSH) | disabled (systemd default) | — |

### Why these defaults exist

- **SSH password auth on**: Enables `ssh-copy-id` and password-based access
  during testing without requiring key provisioning beforehand.
- **Known password**: Allows reproducible testing and Calamares installation
  flows without interactive password prompts during build.

### What happens after install

Calamares (the installer) prompts for a **new user and password**, overwriting
the live-user defaults. SSH password auth is **not** carried into the installed
system unless the user explicitly enables it.

### Recommendations for production deployments

After installing Zurvan Linux:

1. Disable SSH password authentication:
   ```sh
   sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```
2. Set up SSH key-based authentication.
3. Review the firewall (`ufw`) configuration.
