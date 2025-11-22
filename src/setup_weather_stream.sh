#!/bin/bash
set -e

echo "=== Weather streaming setup (RPi + ffmpeg + nginx + ngrok) ==="

# --- CONFIGURATION (ADJUST ACCORDING TO YOUR SETUP) -------------------------------

# RTSP URL of the camera (including login/password)
RTSP_URL="rtsp://user:pasword@192.168.1.50:8554/Streaming/Channels/101"

# NGROK authtoken (from ngrok dashboard)
NGROK_TOKEN="YOUR_NGROK_TOKEN"

# Base directory for the application
BASE_DIR="/home/YOUREUSERNAME/myapps/weather-streaming"
HLS_DIR="$BASE_DIR/hls"

# Port on which nginx will run (you're already using 8089)
NGINX_PORT=8089

# -----------------------------------------------------------------

if [ "$NGROK_TOKEN" = "SEM_VLOZ_SVUJ_NGROK_TOKEN" ]; then
  echo "!!! Did you forget to set NGROK_TOKEN in the script? !!!"
  exit 1
fi

USER_NAME=${SUDO_USER:-$(whoami)}

echo ">> Installing ffmpeg + nginx (if not already installed)..."
apt-get update
apt-get install -y ffmpeg nginx

# Install ngrok if not present
if ! command -v ngrok >/dev/null 2>&1; then
  echo ">> Ngrok is not installed, installing ..."
  wget -O /tmp/ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz
  tar xvzf /tmp/ngrok.tgz -C /usr/local/bin
  rm /tmp/ngrok.tgz
fi

NGROK_BIN=$(command -v ngrok)
FFMPEG_BIN=$(command -v ffmpeg)

echo ">> Setting ngrok authtoken ..."
$NGROK_BIN config add-authtoken "$NGROK_TOKEN" || true

echo ">> Creating directories: $HLS_DIR ..."
mkdir -p "$HLS_DIR"
chown -R "$USER_NAME":"$USER_NAME" "$BASE_DIR"

echo ">> Checking /var/www/html/live symlink ..."
if [ -L /var/www/html/live ] || [ -e /var/www/html/live ]; then
  rm -rf /var/www/html/live
fi
ln -s "$HLS_DIR" /var/www/html/live

echo ">> Modifying nginx default server to port $NGINX_PORT ..."
DEFAULT_SITE="/etc/nginx/sites-available/default"
if [ -f "$DEFAULT_SITE" ]; then
  cp "$DEFAULT_SITE" "${DEFAULT_SITE}.bak.$(date +%s)" || true
  sed -i "s/listen 80 default_server;/listen $NGINX_PORT default_server;/" "$DEFAULT_SITE" || true
  sed -i "s/listen \[::\]:80 default_server;/listen \[::\]:$NGINX_PORT default_server;/" "$DEFAULT_SITE" || true
else
  echo "!! Warning: $DEFAULT_SITE does not exist, nginx may have a different configuration."
fi

echo ">> Testing nginx configuration ..."
nginx -t

echo ">> Enabling and restarting nginx ..."
systemctl enable nginx
systemctl restart nginx

echo ">> Creating / updating weather-hls.service ..."
cat <<EOF >/etc/systemd/system/weather-hls.service
[Unit]
Description=Weather camera HLS stream (RTSP -> HLS, no audio)
After=network-online.target
Wants=network-online.target

[Service]
User=$USER_NAME
WorkingDirectory=$BASE_DIR
ExecStart=$FFMPEG_BIN -rtsp_transport tcp -i "$RTSP_URL" -c:v copy -an -f hls -hls_time 1 -hls_list_size 5 -hls_flags delete_segments "$HLS_DIR/index.m3u8"
Restart=always
RestartSec=5
Nice=5

[Install]
WantedBy=multi-user.target
EOF

echo ">> Creating / updating weather-ngrok.service (port $NGINX_PORT) ..."
cat <<EOF >/etc/systemd/system/weather-ngrok.service
[Unit]
Description=Ngrok tunnel for weather stream (HTTP $NGINX_PORT)
After=network-online.target
Wants=network-online.target

[Service]
User=$USER_NAME
WorkingDirectory=$BASE_DIR
ExecStart=$NGROK_BIN http $NGINX_PORT --log=stdout
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo ">> Reloading systemd and starting services ..."
systemctl daemon-reload
systemctl enable weather-hls.service
systemctl enable weather-ngrok.service
systemctl restart weather-hls.service
systemctl restart weather-ngrok.service

echo
echo "=== DONE ==="
echo "nginx is running on port $NGINX_PORT"
echo "HLS is being generated to: $HLS_DIR"
echo "Symlink: /var/www/html/live -> $HLS_DIR"
echo
echo "Service status:"
echo "  sudo systemctl status weather-hls.service"
echo "  sudo systemctl status weather-ngrok.service"
echo
echo "Local HLS test:"
echo "  curl http://localhost:$NGINX_PORT/live/index.m3u8"
echo
echo "Ngrok dashboard (on RPi):  http://localhost:4040"
echo "Public URL will be: https://NECO.ngrok-free.app/live/index.m3u8"
echo
echo "After RPi reboot, everything will start automatically."
