#!/bin/bash

# Define the sshd_config file location
SSHD_CONFIG="/etc/ssh/sshd_config"

# Function to create a backup with an incrementing suffix
create_backup() {
    local base_file="sshd_config"
    local suffix=""
    local count=1

    while [ -f "${base_file}${suffix}.bak" ]; do
        suffix="_new${count}"
        count=$((count + 1))
    done

    cp "$base_file" "${base_file}${suffix}.bak"
}

# Create a backup of the original sshd_config file with an incrementing suffix if needed
create_backup "$SSHD_CONFIG"

# Set all configuration values in variables for easier modification and understanding

# Unconventional port number for SSH
SSH_PORT=${1:-6391}

# Security settings
PERMIT_ROOT_LOGIN="no"
MAX_AUTH_TRIES=6
MAX_SESSIONS=5
LOGIN_GRACE_TIME=20
PASSWORD_AUTHENTICATION="no"
PERMIT_EMPTY_PASSWORDS="no"
CHALLENGE_RESPONSE_AUTHENTICATION="no"
KERBEROS_AUTHENTICATION="no"
GSSAPI_AUTHENTICATION="no"
X11_FORWARDING="no"
PERMIT_USER_ENVIRONMENT="no"
ALLOW_AGENT_FORWARDING="no"
ALLOW_TCP_FORWARDING="no"
PERMIT_TUNNEL="no"
DEBIAN_BANNER="no"


# Additional hardening settings
PROTOCOL="2"
HOSTBASED_AUTHENTICATION="no"
CIPHERS="aes256-ctr,aes192-ctr,aes128-ctr"
MACS="hmac-sha2-512,hmac-sha2-256"
KEX_ALGORITHMS="diffie-hellman-group-exchange-sha256"
CLIENT_ALIVE_INTERVAL=300
CLIENT_ALIVE_COUNT_MAX=0
ALLOW_GROUPS="sshusers"

# Parameters for new user creation
NEW_USER=${2:-sshuser}
NEW_USER_PASSWORD=${3:-password}

ALLOW_USERS="$NEW_USER@*"

# Create SSH allowed group if it doesn't exist
SSH_ALLOWED_GROUP="sshusers"
if ! getent group "$SSH_ALLOWED_GROUP" > /dev/null; then
    groupadd "$SSH_ALLOWED_GROUP"
    echo "Group $SSH_ALLOWED_GROUP created."
else
    echo "Group $SSH_ALLOWED_GROUP already exists."
fi

# Create a new user and add to the SSH allowed group
if ! id -u "$NEW_USER" > /dev/null 2>&1; then
    useradd -m -G "$SSH_ALLOWED_GROUP" -s /bin/bash "$NEW_USER"
    echo "User $NEW_USER created and added to group $SSH_ALLOWED_GROUP."
    # Set password for the new user
    echo "$NEW_USER:$NEW_USER_PASSWORD" | chpasswd
    # Grant sudo permissions to the new user
    usermod -aG sudo "$NEW_USER"
    echo "User $NEW_USER added to sudo group."

    # Create .ssh directory and authorized_keys file
    sudo -u "$NEW_USER" mkdir -p /home/"$NEW_USER"/.ssh
    sudo -u "$NEW_USER" touch /home/"$NEW_USER"/.ssh/authorized_keys

    # Copy the SSH public key from root's authorized_keys to the new user's authorized_keys
    if [ -f /root/.ssh/authorized_keys ]; then
        cat /root/.ssh/authorized_keys | sudo -u "$NEW_USER" tee -a /home/"$NEW_USER"/.ssh/authorized_keys > /dev/null
        echo "SSH public key added to /home/$NEW_USER/.ssh/authorized_keys."
    else
        echo "Root's authorized_keys file not found."
    fi

    # Set appropriate permissions
    sudo -u "$NEW_USER" chmod 700 /home/"$NEW_USER"/.ssh
    sudo -u "$NEW_USER" chmod 600 /home/"$NEW_USER"/.ssh/authorized_keys
    chown -R "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.ssh
else
    echo "User $NEW_USER already exists."
fi


# Function to update or add a configuration setting
update_sshd_config() {
    local setting="$1"
    local value="$2"
    if grep -q "^#\?\s*${setting}" $SSHD_CONFIG; then
        # If the setting exists (commented or uncommented), update it
        sed -i "s|^#\?\s*${setting}.*|${setting} ${value}|g" $SSHD_CONFIG
    else
        # If the setting does not exist, add it
        echo "${setting} ${value}" >> $SSHD_CONFIG
    fi
}

# Update the sshd_config file with the specified settings

# Unconventional port number for SSH
update_sshd_config "Port" "$SSH_PORT"

# Disable root login over SSH
update_sshd_config "PermitRootLogin" "$PERMIT_ROOT_LOGIN"

# Maximum number of authentication attempts per connection
update_sshd_config "MaxAuthTries" "$MAX_AUTH_TRIES"

# Maximum number of open sessions permitted per network connection
update_sshd_config "MaxSessions" "$MAX_SESSIONS"

# Time (in seconds) allowed for successful login
update_sshd_config "LoginGraceTime" "$LOGIN_GRACE_TIME"

# Disable password-based authentication
update_sshd_config "PasswordAuthentication" "$PASSWORD_AUTHENTICATION"

# Disable empty passwords
update_sshd_config "PermitEmptyPasswords" "$PERMIT_EMPTY_PASSWORDS"

# Disable challenge-response authentication
update_sshd_config "ChallengeResponseAuthentication" "$CHALLENGE_RESPONSE_AUTHENTICATION"

# Disable Kerberos authentication
update_sshd_config "KerberosAuthentication" "$KERBEROS_AUTHENTICATION"

# Disable GSSAPI authentication
update_sshd_config "GSSAPIAuthentication" "$GSSAPI_AUTHENTICATION"

# Disable X11 forwarding
update_sshd_config "X11Forwarding" "$X11_FORWARDING"

# Disable user environment configuration
update_sshd_config "PermitUserEnvironment" "$PERMIT_USER_ENVIRONMENT"

# Disable agent forwarding
update_sshd_config "AllowAgentForwarding" "$ALLOW_AGENT_FORWARDING"

# Disable TCP forwarding
update_sshd_config "AllowTcpForwarding" "$ALLOW_TCP_FORWARDING"

# Disable SSH tunneling
update_sshd_config "PermitTunnel" "$PERMIT_TUNNEL"

# Disable the Debian-specific SSH banner
update_sshd_config "DebianBanner" "$DEBIAN_BANNER"

# Allow only specific users to connect
update_sshd_config "AllowUsers" "$ALLOW_USERS"

# Additional hardening settings

# Use SSH protocol 2 only
update_sshd_config "Protocol" "$PROTOCOL"

# Disable host-based authentication
update_sshd_config "HostbasedAuthentication" "$HOSTBASED_AUTHENTICATION"

# Specify strong encryption ciphers
update_sshd_config "Ciphers" "$CIPHERS"

# Specify strong MAC algorithms
update_sshd_config "MACs" "$MACS"

# Specify strong key exchange algorithms
update_sshd_config "KexAlgorithms" "$KEX_ALGORITHMS"

# Set idle timeout interval in seconds (300 seconds = 5 minutes)
update_sshd_config "ClientAliveInterval" "$CLIENT_ALIVE_INTERVAL"

# Set maximum number of alive messages without response (0 to disable)
update_sshd_config "ClientAliveCountMax" "$CLIENT_ALIVE_COUNT_MAX"

# Allow only specific groups to connect
update_sshd_config "AllowGroups" "$ALLOW_GROUPS"

# Restart the SSH service to apply the changes
systemctl restart sshd

echo "SSHD configuration updated and SSH service restarted."
