# Weather Stream Setup Guide (NGINX + FFmpeg + Ngrok)

This guide describes how to deploy a Raspberry Pi live camera stream
using: - **RTSP camera** - **FFmpeg (RTSP → HLS)** - **NGINX (serving
HLS)** - **Ngrok (public tunnel)**

The goal: produce an HLS stream available at:\
`https://<your-ngrok>.ngrok-free.app/live/index.m3u8`

------------------------------------------------------------------------

## 1. Prepare the Setup Script

Create this file:

    /home/michal1609/setup_weather_stream.sh

Insert the full installer script (the latest working version you
generated earlier).\
Modify:

-   `RTSP_URL`
-   `NGROK_TOKEN`
-   paths if needed
-   port (`NGINX_PORT=8089`)

Then make executable:

    chmod +x /home/michal1609/setup_weather_stream.sh

------------------------------------------------------------------------

## 2. Run the Installer

    sudo /home/michal1609/setup_weather_stream.sh

This script will: - install **ffmpeg**, **nginx**, **ngrok** - create
`/home/michal1609/myapps/weather-streaming/hls` - create symlink
`/var/www/html/live -> hls` - configure nginx on **port 8089** - create
& activate systemd services: - `weather-hls.service` -
`weather-ngrok.service` - start everything automatically

Check service status:

    sudo systemctl status weather-hls.service
    sudo systemctl status weather-ngrok.service
    sudo systemctl status nginx

------------------------------------------------------------------------

## 3. Fix Directory Permissions (Required Once)

NGINX runs as `www-data` and needs execute permission on all directories
leading to HLS:

    chmod o+x /home/michal1609
    chmod o+x /home/michal1609/myapps
    chmod o+x /home/michal1609/myapps/weather-streaming
    chmod o+x /home/michal1609/myapps/weather-streaming/hls

Confirm HLS exists:

    ls -l /home/michal1609/myapps/weather-streaming/hls

Test nginx access:

    curl -v http://localhost:8089/live/index.m3u8

You should see `#EXTM3U`.

------------------------------------------------------------------------

## 4. Add CORS + OPTIONS to NGINX

Open:

    sudo nano /etc/nginx/sites-available/default

Inside the `server { ... }` block, add:

    location /live/ {
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
        add_header Access-Control-Allow-Headers "Range,ngrok-skip-browser-warning,Origin,Accept,Content-Type" always;

        if ($request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, OPTIONS";
            add_header Access-Control-Allow-Headers "Range,ngrok-skip-browser-warning,Origin,Accept,Content-Type";
            add_header Access-Control-Max-Age 1728000;
            add_header Content-Type "text/plain; charset=utf-8";
            add_header Content-Length 0;
            return 204;
        }
    }

Test and restart:

    sudo nginx -t
    sudo systemctl restart nginx

------------------------------------------------------------------------

## 5. Check Ngrok Public URL

    journalctl -u weather-ngrok.service --since "10 minutes ago" | grep started

or open:

    http://localhost:4040

Your public stream:

    https://<something>.ngrok-free.app/live/index.m3u8

------------------------------------------------------------------------

## 6. Test the Stream in Browser

Create `test.html`:

``` html
<!doctype html>
<html>
  <body>
    <video id="cam" controls autoplay muted playsinline style="max-width:100%;"></video>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
    <script>
      const url = 'https://YOUR-NGROK/live/index.m3u8';
      const video = document.getElementById('cam');

      if (Hls.isSupported()) {
        const hls = new Hls({
          xhrSetup: function (xhr, url) {
            xhr.setRequestHeader('ngrok-skip-browser-warning', '1');
          }
        });
        hls.loadSource(url);
        hls.attachMedia(video);
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = url;
      }
    </script>
  </body>
</html>
```

Do **not** open via `file://`.\
Instead run:

    python3 -m http.server 8001

Then open:

    http://localhost:8001/test.html

You should see the live stream.

------------------------------------------------------------------------

## 7. Behavior on Reboot and Fresh Installation

### After reboot:

-   all services auto‑start
-   nginx listens on 8089
-   ngrok gets a new public URL

### After reinstalling Raspberry Pi:

1.  copy `setup_weather_stream.sh`
2.  modify RTSP and NGROK_TOKEN
3.  run installer
4.  fix directory permissions
5.  insert NGINX CORS location block
6.  restart nginx
7.  get new ngrok URL
8.  test stream

------------------------------------------------------------------------

## This completes the installation procedure.

You now have: - a persistent RTSP → HLS transcoding service\
- nginx hosting `/live/index.m3u8`\
- ngrok exposing it publicly\
- working CORS and OPTIONS for HLS.js\
- auto-starting services across reboots
