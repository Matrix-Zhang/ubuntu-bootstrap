#!/usr/bin/env bash
set -x

install_base_packages() {
    sudo apt update && sudo apt dist-upgrade -y && sudo apt --fix-broken install
    sudo apt install build-essential curl fcitx fonts-liberation jq libssl-dev pkg-config proxychains4 python3-pip software-properties-common -y
    sudo add-apt-repository ppa:fish-shell/release-3 -y && sudo add-apt-repository ppa:git-core/ppa -y && sudo apt install fish git -y && chsh -s /usr/bin/fish
    sudo add-apt-repository ppa:appimagelauncher-team/stable -y && sudo apt install appimagelauncher -y
    sudo add-apt-repository ppa:linuxuprising/guake -y && sudo apt install guake -y
    sudo add-apt-repository ppa:agornostal/ulauncher -y && sudo apt install ulauncher -y
}

install_docker() {
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  # shellcheck source=/dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. "/etc/os-release" && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update && sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
}

install_clash() {
  local CLASH_VERSION
  CLASH_VERSION=$(curl --location 'https://api.github.com/repos/Dreamacro/clash/releases/latest' \
    --header 'Accept: application/vnd.github+json' \
    --header 'X-GitHub-Api-Version: 2022-11-28' | jq '.tag_name' | tr -d '"')

  proxychains wget -O clash.gz "https://github.com/Dreamacro/clash/releases/download/${CLASH_VERSION}/clash-linux-amd64-${CLASH_VERSION}.gz" && gunzip clash.gz && chmod +x clash && sudo mv clash /usr/local/bin

  local CLASH_CONFIG_PATH="$HOME/.config/clash"
  local CLASH_CONFIG_FILE="$CLASH_CONFIG_PATH/config.yaml"

  mkdir -p "$CLASH_CONFIG_PATH"
  echo "[Unit]
Description=clash service
After=network.target
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
ExecStart=/usr/local/bin/clash -f $CLASH_CONFIG_FILE

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/clash.service
sudo systemctl daemon-reload && sudo systemctl enable clash.service && sudo systemctl start clash.service
sudo sed -E -i 's/^#(quiet_mode)/\1/g;s/socks4/socks5/g;s/9050/7890/g' /etc/proxychains4.conf
    
}

install_rust() {
  curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s - -y
}

install_rust_bins() {
  # shellcheck source=/dev/null
  source "$HOME/.cargo/env" && proxychains cargo install bat cargo-update fd-find ripgrep
}

install_golang() {
  sudo proxychains add-apt-repository ppa:longsleep/golang-backports -y
  sudo proxychains apt install golang-1.21 -y
  sudo ln -s /usr/lib/go-1.21/bin/go /usr/bin/go
}

install_spacevim() {
  sudo proxychains add-apt-repository ppa:neovim-ppa/unstable -y && sudo proxychains apt-get install neovim -y
  curl -sLf https://spacevim.org/install.sh | proxychains bash
  ln -s ~/.SpaceVim ~/.config/nvim
  proxychains pip3 install neovim
}

install_nodejs() {
  local NODE_MAJOR=20
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
  sudo apt-get update && sudo apt-get install nodejs -y
}

install_sogoupinyin() {
  local DEB_NAME="sogoupinyin.deb"
  if ! sudo dpkg -i $DEB_NAME; then
    sudo apt install -fy && sudo dpkg -i $DEB_NAME
  fi
  sudo apt-get remove ibus scim -y && sudo apt autoremove -y && sudo apt install switchboard-plug-keyboard -y
  sudo apt install libqt5qml5 libqt5quick5 libqt5quickwidgets5 qml-module-qtquick2 libgsettings-qt1 -y
}

install_pulumi() {
  curl -fsSL https://get.pulumi.com | proxychains sh
}

install_awscli() {
  proxychains curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install && rm -rf "aws" "awscliv2.zip"
}

install_jdk() {
  sudo mkdir -p /var/cache/oracle-jdk11-installer-local
  sudo add-apt-repository ppa:linuxuprising/java -y && sudo proxychains apt install oracle-java11-set-default-local -y
}

install_k8s_tools() {
  local JSONNET_VERSION
  JSONNET_VERSION=$(curl --location 'https://api.github.com/repos/google/jsonnet/releases/latest' \
    --header 'Accept: application/vnd.github+json' \
    --header 'X-GitHub-Api-Version: 2022-11-28' | jq '.tag_name' | tr -d 'v"')
  if [[ ! -f /usr/local/bin/jsonnet ]]; then
    proxychains wget -O jsonnet.tar.gz "https://github.com/google/go-jsonnet/releases/download/v${JSONNET_VERSION}/go-jsonnet_${JSONNET_VERSION}_Linux_x86_64.tar.gz" && tar -xvf jsonnet.tar.gz && rm jsonnet.tar.gz
    sudo mv jsonnet* /usr/local/bin/
  fi

  if [[ ! -f /usr/bin/jb ]]; then
    proxychains curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
    sudo proxychains curl -Lo /usr/local/bin/tk https://github.com/grafana/tanka/releases/latest/download/tk-linux-amd64 && sudo chmod a+x /usr/local/bin/tk
    wget -O "jb" 'https://github.com/jsonnet-bundler/jsonnet-bundler/releases/latest/download/jb-linux-amd64' && chmod +x jb && sudo mv jb /usr/bin
  fi
}

crack_smartgit() {
  local SMARTGIT_CFG_PATH="$HOME/.config/smartgit"
  mkdir -p "$SMARTGIT_CFG_PATH"
  cp ./smartgit-agent/smartgit-agent.jar ./smartgit-agent/license.zip "$SMARTGIT_CFG_PATH/"
  echo "-javaagent:$SMARTGIT_CFG_PATH/smartgit-agent.jar" >"$SMARTGIT_CFG_PATH/smartgit.vmoptions"
  sudo rm -rf /usr/share/smartgit/jre
}

prepare_opt() {
  sudo mkdir -p /opt/tools/jetbrains && sudo chown -R "$USER:$USER" /opt/tools
  cp -r jetbra /opt/tools/jetbrains
}

setup_path() {
  echo "set -x PATH \$PATH \$HOME/.cargo/bin \$HOME/.pulumi/bin" >>"$HOME/.config/fish/config.fish"
}

setup_clean() {
    sudo apt autoremove -y
}

if [[ $UID -eq 0 ]]; then
    echo "you should not run this script as root or with sudo."
    exit 1
fi

#install_base_packages
#install_clash
#install_rust
#install_rust_bins
#install_golang
#install_spacevim
#install_nodejs
#install_sogoupinyin
#install_pulumi
#install_awscli
#install_jdk
install_k8s_tools
crack_smartgit
#prepare_opt
setup_path
setup_clean
