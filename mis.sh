#!/bin/bash

# This is free and unencumbered software released into the public domain.

# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.

# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# For more information, please refer to <https://unlicense.org>

print_status() {
  echo -ne "\r\t[ ] $1"
}

print_success() {
  echo -e "\t[x] $1"
}

echo ">>===========================================<<
||                                           ||
||                                           ||
||               _                   _       ||
||   _ __ ___   (_)  ___       ___  | |__    ||
||  | '_ \` _ \\  | | / __|     / __| | '_ \\   ||
||  | | | | | | | | \\__ \\  _  \\__ \\ | | | |  ||
||  |_| |_| |_| |_| |___/ (_) |___/ |_| |_|  ||
||                                           ||
||                                           ||
>>===========================================<<

Automates the installation of Jellyfin on a Debian-based Linux server,
including necessary Docker services for optimal media server functionality.

GitHub Repository: https://github.com/n0bta/media-server-install
"

print_status "debian-based system"
# Check if the system is Debian-based
if ! command -v apt &> /dev/null; then
  exit 1
fi
print_success "debian-based system"

print_status "run as root"
# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    exit 1
fi
print_success "run as root"

print_status "configuration"
while true; do
  # Allowed IP addr in CIDR notation for Jellyfin
  read -p "[1/5] Allowed IP addr in CIDR notation (e.g., 192.168.1.0/24): " cidr
  # Username for runnning Docker containers
  read -p "[2/5] Docker user username: " docker_user
  # Timezone for docker containers
  # https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  read -p "[3/5] Timezone (e.g., America/New_York): " timezone
  # SSH tunnel-only user username for maintaining the docker containers
  read -p "[4/5] SSH tunnel-only user username: " tunnel_user
  read -s -p "[4.5/5] SSH tunnel-only user password: " tunnel_user_password
  # Path to the message of the day file
  read -p "[5/5] MOTD path: (e.g., /etc/motd): " motd_path
  sleep 0.5
  echo -e "\nConfiguration summary:"
  echo -e "[1/5] Allowed IP addr: $cidr"
  echo -e "[2/5] Docker user username: $docker_user"
  echo -e "[3/5] Timezone: $timezone"
  echo -e "[4/5] SSH tunnel-only user username: $tunnel_user"
  echo -e "[5/5] MOTD path: $motd_path\n"
  echo "Please review the configuration above. The script might not work as"
  echo "expected if the configuration is incorrect."
  read -p "Proceed with the configuration above? (y/n): " config_yn
  if [ "$config_yn" == "y" ]; then
    break
  fi
done
print_success "configuration"

print_status "system updates"
apt update -y > /dev/null 2>&1
apt upgrade -y  > /dev/null 2>&1
if [ $? -ne 0 ]; then
  exit 1
fi
print_success "system updates"
sleep 0.5

print_status "ufw"
apt install ufw -y > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1

# Add custom UFW rule for Jellyfin
cat << EOF > /etc/ufw/applications.d/jellyfin
[Jellyfin]
title=Jellyfin
description=The Free Software Media System
ports=8096/tcp
EOF

# Add UFW rule for SSH and Jellyfin
ufw limit from "$cidr" to any app SSH > /dev/null 2>&1
ufw allow from "$cidr" to any app Jellyfin > /dev/null 2>&1

sleep 0.5
ufw enable > /dev/null 2>&1

# Check if UFW is enabled
if ufw status | grep -q "Status: active" > /dev/null 2>&1; then
    print_success "ufw"
else
    exit 1
fi

sleep 1

print_status "openssh server"
apt install openssh-server -y > /dev/null 2>&1

# Add SSH tunnel-only user for accessing docker services
useradd -m -p "$tunnel_user_password" -s /bin/false "$tunnel_user" > /dev/null 2>&1

# MOTD
mkdir -p "/home/$tunnel_user" > /dev/null 2>&1
if [ -f "$motd_path" ]; then
  cp "$motd_path" "/home/$tunnel_user/motd" > /dev/null 2>&1
else
  sleep 0.5
  echo "Please remember to use system resources responsibly and adhere to all
applicable policies. Unauthorized access to data is strictly prohibited.

Thank you." > "/home/$tunnel_user/motd"
fi

# Set correct permissions for the MOTD
chown "$tunnel_user:$tunnel_user" "/home/$tunnel_user/motd" > /dev/null 2>&1
chmod 0755 "/home/$tunnel_user" > /dev/null 2>&1
chmod 0644 "/home/$tunnel_user/motd" > /dev/null 2>&1

# Configure SSH to restrict tunnel user's access
cat << EOF >> /etc/ssh/sshd_config
Match User $tunnel_user
  PermitOpen 127.0.0.1:6767 127.0.0.1:7878 127.0.0.1:8080 127.0.0.1:8989 127.0.0.1:9696
  X11Forwarding no
  AllowAgentForwarding no
  ForceCommand /bin/false
  Banner /home/$tunnel_user/motd
  PasswordAuthentication yes
EOF
print_success "openssh server"
sleep 2

print_status "docker"
apt install curl ca-certificates -y > /dev/null 2>&1

sleep 0.5

# Install Docker
install -m 0755 -d /etc/apt/keyrings > /dev/null 2>&1
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc > /dev/null 2>&1
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update > /dev/null 2>&1
apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y > /dev/null 2>&1
print_success "docker"

sleep 2

# Docker services

# Get the current user's home directory
HOME_DIR="/home/$docker_user" #$(eval echo "~")

# Define the Docker directory
DOCKER_DIR="$HOME_DIR/docker"
MEDIA_DIR="$HOME_DIR/media"
ENV_FILE="$DOCKER_DIR/.env"

PUID=1000
PGID=1000

## Directories setup
# Create directories for each service's config
mkdir -p "$DOCKER_DIR/prowlarr/config" "$DOCKER_DIR/sonarr/config" "$DOCKER_DIR/radarr/config" "$DOCKER_DIR/bazarr/config" "$DOCKER_DIR/qbittorrent/config" > /dev/null 2>&1

# Create directories for media files
mkdir -p "$MEDIA_DIR/movies" "$MEDIA_DIR/shows" "$MEDIA_DIR/downloads" > /dev/null 2>&1

# Set appropriate permissions
chmod 755 "$HOME_DIR" > /dev/null 2>&1
chmod -R 755 "$DOCKER_DIR" "$MEDIA_DIR" > /dev/null 2>&1
chown -R "$docker_user:$docker_user" "$DOCKER_DIR" "$MEDIA_DIR" > /dev/null 2>&1

## .env setup
# Check if the .env file already exists, and create it if not
if [ ! -e "$ENV_FILE" ]; then
    touch "$ENV_FILE" > /dev/null 2>&1
    chown -R "$docker_user:$docker_user" "$ENV_FILE" > /dev/null 2>&1
fi

# Update or append the variables in the .env file
echo "PUID=$PUID" >> "$ENV_FILE"
echo "PGID=$PGID" >> "$ENV_FILE"
echo "TZ=$timezone" >> "$ENV_FILE"
echo "MEDIA_DIR=$MEDIA_DIR" >> "$ENV_FILE"

# Add docker-compose.yml
cat << EOF > "$DOCKER_DIR/docker-compose.yml"
services:
  # "admin-only" services
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - "PUID=${PUID}"
      - "PGID=${PGID}"
      - "TZ=${timezone}"
    volumes:
      - ./prowlarr/config:/config
    networks:
      - media_network
    ports:
      - "127.0.0.1:9696:9696"
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - "PUID=${PUID}"
      - "PGID=${PGID}"
      - "TZ=${timezone}"
    volumes:
      - ./sonarr/config:/config
      - "${MEDIA_DIR}:/media"
    networks:
      - media_network
    ports:
      - "127.0.0.1:8989:8989"
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - "PUID=${PUID}"
      - "PGID=${PGID}"
      - "TZ=${timezone}"
    volumes:
      - ./radarr/config:/config
      - "${MEDIA_DIR}:/media"
    networks:
      - media_network
    ports:
      - "127.0.0.1:7878:7878"
    restart: unless-stopped

  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    environment:
      - "PUID=${PUID}"
      - "PGID=${PGID}"
      - "TZ=${timezone}"
    volumes:
      - ./bazarr/config:/config
      - "${MEDIA_DIR}:/media"
    networks:
      - media_network
    ports:
      - "127.0.0.1:6767:6767"
    restart: unless-stopped

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - "PUID=${PUID}"
      - "PGID=${PGID}"
      - "TZ=${timezone}"
      - WEBUI_PORT=8080
    volumes:
      - ./qbittorrent/config:/config
      - "${MEDIA_DIR}:/media"
    networks:
      - media_network
    ports:
      - "127.0.0.1:8080:8080"
    restart: unless-stopped

networks:
  media_network:
    driver: bridge
EOF

sleep 1

docker compose -f "$DOCKER_DIR/docker-compose.yml" pull && docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d --remove-orphans && docker image prune -f > /dev/null 2>&1

sleep 1

print_success "docker"

sleep 0.25

# Maintenance script
print_status "easyupdate.sh"
cat << EOF > "$HOME_DIR/easyupdate.sh"
#!/bin/bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove --purge -y && sudo docker compose -f "$DOCKER_DIR/docker-compose.yml" pull && sudo docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d --remove-orphans && sudo docker image prune -f
EOF
chmod +x "$HOME_DIR/easyupdate.sh" > /dev/null 2>&1
print_success "easyupdate.sh"

sleep 1

# Jellyfin
print_status "jellyfin"
sleep 3
curl -fsSL https://repo.jellyfin.org/install-debuntu.sh | bash
print_success "jellyfin"

echo "\nYou should use something like the following command to access docker services through a tunnel:"
echo "ssh -N -L 127.0.0.1:6767:127.0.0.1:6767 -L 127.0.0.1:7878:127.0.0.1:7878 -L 127.0.0.1:8989:127.0.0.1:8989 -L 127.0.0.1:9696:127.0.0.1:9696 -L 127.0.0.1:8080:127.0.0.1:8080 $tunnel_user@mediaserverip"
echo "You can use '$HOME_DIR/easyupdate.sh' to easily update your media server"
sleep 2.5
echo "\nMedia server setup complete. Bye!"
sleep 1
exit 0
