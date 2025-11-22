    #!/usr/bin/env python3
import requests
import time
import json
import sys

# ============ CONFIG ============

API_URL = "https://grznar.eu/api/weather/sky-image/hls-stream-url"
API_KEY = "YOUR_API_KEY_HERE"

NGROK_API = "http://127.0.0.1:4040/api/tunnels"
HLS_SUFFIX = "/live/index.m3u8"

CHECK_INTERVAL = 20   # seconds

# ============ LOGGING ============

def log(msg):
    print(f"[ngrok-sync] {msg}", flush=True)

# ============ MAIN LOOP ============

def get_ngrok_public_url():
    try:
        data = requests.get(NGROK_API).json()

        tunnels = data.get("tunnels", [])
        for t in tunnels:
            if t.get("proto") == "https":
                return t.get("public_url")
    except Exception as e:
        log(f"Error fetching ngrok tunnels: {e}")
    return None

def send_to_api(full_url):
    headers = {
        "x-api-key": API_KEY,
        "Content-Type": "application/json"
    }
    body = { "url": full_url }

    try:
        resp = requests.post(API_URL, headers=headers, json=body)
        if resp.status_code < 300:
            log(f"Successfully synced URL → {full_url}")
        else:
            log(f"API error {resp.status_code}: {resp.text}")
    except Exception as e:
        log(f"Failed to send to API: {e}")

def main():
    last_sent = None

    while True:
        url = get_ngrok_public_url()

        if url:
            full = url + HLS_SUFFIX

            if full != last_sent:
                log(f"New public stream URL detected: {full}")
                send_to_api(full)
                last_sent = full

        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()
