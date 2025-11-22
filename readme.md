# Raspberry Pi RTSP → HLS → Ngrok Streaming Pipeline

This project provides a full end-to-end solution for streaming a private RTSP camera feed to the public web using Raspberry Pi, FFmpeg, NGINX, and Ngrok.

The final result is a publicly accessible HLS stream:

```
https://<ngrok>.ngrok-free.app/live/index.m3u8
```

It is designed for weather monitoring dashboards, outdoor camera feeds, or any scenario where:

- the camera is on a private network  
- no public IP is available  
- no port forwarding is possible  
- zero-cost operation is required  

The system is stable, self-recovering, and restarts automatically after reboot.

---

## ✨ Features

- **RTSP → HLS conversion** using FFmpeg (no transcoding, video-only)
- **NGINX static hosting** of HLS segments
- **Public tunnel** via Ngrok (free tier supported)
- **Automatic URL sync**: Raspberry Pi sends the current public stream URL to a remote API
- **Systemd services** ensure everything runs automatically on boot
- **CORS and streaming headers** properly configured for HLS.js
- **Folder permissions fixed** so NGINX can access user directories

---

## 🧩 Architecture Overview

```
   [RTSP Camera]
          │
          ▼
     FFmpeg (HLS)
  /myapps/weather-streaming/hls
          │
          ▼
      NGINX (8089)
  http://rpi:8089/live/index.m3u8
          │
          ▼
    Ngrok Tunnel (HTTPS)
 https://xxxx.ngrok-free.app/live/index.m3u8
          │
          ▼
     Your Website / HLS Player
```

A Python daemon (`ngrok_sync.py`) monitors Ngrok’s local API and automatically reports the current public URL to your backend:

```
POST https://your-api/sky-image/hls-stream-url
Header: x-api-key: ...
Body: { "url": "https://ngrok/live/index.m3u8" }
```

---

## 📦 Components

| Component | Purpose |
|----------|---------|
| **FFmpeg** | Converts RTSP → HLS segments |
| **NGINX**  | Serves `/live/` static files |
| **Ngrok**  | Exposes local NGINX to the public web |
| **Python sync service** | Pushes Ngrok URL to your external API |
| **SystemD services** | Autostart, autorestart, 24/7 uptime |

---

## 📘 Installation

Full installation instructions are provided in:

```
install.md
```

---

## 📝 Requirements

- Raspberry Pi (any with enough CPU for FFmpeg copy-mode)
- RTSP-compatible camera
- Ngrok account + token
- Your backend endpoint for URL sync (optional)

---

## 🚀 Usage

After installation:

- Your HLS feed is live as soon as ngrok starts.
- The stream updates automatically even if the ngrok URL changes.
- The Pi recovers after reboot.

Example stream URL inside your frontend:

```js
const streamUrl = "https://<ngrok>.ngrok-free.app/live/index.m3u8";
```

---

## 📺 Embedding into Websites

The simplest player uses HLS.js:

```html
<video id="cam" controls autoplay muted playsinline style="max-width:100%;"></video>
<script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
<script>
  const url = 'https://heartily-touchiest-raylene.ngrok-free.dev/live/index.m3u8';
  const video = document.getElementById('cam');

  if (Hls.isSupported()) {
    const hls = new Hls({
      xhrSetup: function (xhr, url) {
        // Tohle obejde ngrok warning page
        xhr.setRequestHeader('ngrok-skip-browser-warning', '1');
      }
    });
    hls.loadSource(url);
    hls.attachMedia(video);
  } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
    video.src = url;
  } else {
    video.src = url;
  }
</script>

```

---

## 🧰 Useful Commands

### Check HLS directory:
```
ls -l /home/.../weather-streaming/hls
```

### Restart services:
```
sudo systemctl restart weather-hls.service
sudo systemctl restart weather-ngrok.service
sudo systemctl restart ngrok-sync.service
```

### View ngrok URL:
```
journalctl -u weather-ngrok.service | grep "started tunnel"
```

---

## 📄 License

MIT License.
