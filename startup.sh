#!/bin/bash
set -e

USER_NAME="developer"
USER_HOME="/home/$USER_NAME"
STORAGE_DIR="/storage"

echo "Running startup script as $(whoami)"

# 1️⃣ Create developer user if not exists
if ! id "$USER_NAME" &>/dev/null; then
    echo "Creating user '$USER_NAME' with home $USER_HOME and shell /bin/zsh..."
    adduser -D -h "$USER_HOME" -s /bin/zsh "$USER_NAME"
    # Optional: give sudo rights
    echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

# 2️⃣ Ensure directories exist and are owned by developer
mkdir -p "$USER_HOME" "$STORAGE_DIR" "$USER_HOME/bin" "$USER_HOME/npm-global"
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME" "$STORAGE_DIR"

# 3️⃣ Install Oh My Zsh for developer
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sudo -u "$USER_NAME" sh -c "export HOME=$USER_HOME; export RUNZSH=no; \
        sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
fi

# 4️⃣ Install NVM for developer
if [ ! -d "$USER_HOME/.nvm" ]; then
    echo "Installing NVM..."
    sudo -u "$USER_NAME" sh -c "export HOME=$USER_HOME; \
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
fi

# 5️⃣ Set environment variables for developer session
NVM_DIR="$USER_HOME/.nvm"
ZSH_DIR="$USER_HOME/.oh-my-zsh"
NPM_GLOBAL="$USER_HOME/npm-global"
PATH="$NPM_GLOBAL/bin:$USER_HOME/bin:$PATH"

# 6️⃣ Append necessary exports to .zshrc if not already present
ZSHRC="$USER_HOME/.zshrc"
sudo -u "$USER_NAME" sh -c "touch $ZSHRC"

grep -q "NVM_DIR" "$ZSHRC" || cat << EOF | sudo -u "$USER_NAME" tee -a "$ZSHRC"
export NVM_DIR="$NVM_DIR"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"
export PATH="$NPM_GLOBAL/bin:$USER_HOME/bin:\$PATH"
export ZSH="$ZSH_DIR"
plugins=(git nvm pnpm)
EOF

# 7️⃣ Install pnpm globally for developer
sudo -u "$USER_NAME" sh -c "export HOME=$USER_HOME; export PATH=$PATH; \
    npm config set prefix $NPM_GLOBAL; npm install -g pnpm --silent"

# 8️⃣ Install cloudflared for developer
if [ ! -f "$USER_HOME/bin/cloudflared" ]; then
    echo "Installing cloudflared..."
    sudo -u "$USER_NAME" sh -c "curl -L --fail --silent --show-error \
        https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
        -o $USER_HOME/bin/cloudflared && chmod +x $USER_HOME/bin/cloudflared"
fi

# 9️⃣ Ensure developer owns all files
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME" "$STORAGE_DIR"

# 🔟 Force default shell for SSH and HOME for developer
usermod -s /bin/zsh "$USER_NAME"
echo 'export HOME=/home/developer' >> "$USER_HOME/.zshrc"

echo -e 'export HOME=/home/developer\nexec zsh' > /etc/profile.d/developer_home.sh
chmod +x /etc/profile.d/developer_home.sh

 
 
echo 'export PATH=$PATH:/home/developer/npm-global/bin' | sudo -u "$USER_NAME" tee -a "$ZSHRC" >/dev/null
echo 'export PATH=$PATH:/home/developer/bin' | sudo -u "$USER_NAME" tee -a "$ZSHRC" >/dev/null
echo 'alias cloudflared="/home/developer/bin/cloudflared"' | sudo -u "$USER_NAME" tee -a "$ZSHRC" >/dev/null
echo 'alias pnpm="/home/developer/npm-global/bin/pnpm"' | sudo -u "$USER_NAME" tee -a "$ZSHRC" >/dev/null
echo 'alias pp="/home/developer/npm-global/bin/pnpm"' | sudo -u "$USER_NAME" tee -a "$ZSHRC" >/dev/null  

# 1️⃣1️⃣ Ensure SSH allows TCP forwarding
SSHD_CONFIG="/config/sshd/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    echo "Setting AllowTcpForwarding yes in $SSHD_CONFIG..."
    if grep -q "^AllowTcpForwarding" "$SSHD_CONFIG"; then
        sed -i 's/^AllowTcpForwarding.*/AllowTcpForwarding yes/' "$SSHD_CONFIG"
    else
        echo "AllowTcpForwarding yes" >> "$SSHD_CONFIG"
    fi
    # Restart SSH to apply changes
    if command -v rc-service &>/dev/null; then
        rc-service sshd restart || true
    elif command -v systemctl &>/dev/null; then
        systemctl restart sshd || true
    else
        echo "SSH service restart command not found. Restart SSH manually."
    fi
fi

echo "Startup script completed successfully for $USER_NAME!"
echo "Developer home: $USER_HOME"
echo "To use NVM or pnpm immediately, run: source ~/.zshrc"
