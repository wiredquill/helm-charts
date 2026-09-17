#!/usr/bin/env python3
"""Resumable, size-verified model downloader for the ComfyUI Video Lab.

Reads the manifest from MANIFEST_FILE (a ConfigMap-mounted text file). Each
line: <expected_bytes> <hf_repo> <hf_path> <dest_dir>. Gated repos (LTX-2.5)
use the HF_TOKEN env var. Files are written to <STORE>/<dest_dir>/<basename>.
Idempotent: a file present at the exact expected size is skipped; a partial
file is resumed via HTTP Range.
"""
import os, sys, time, hashlib

try:
    import requests
except ImportError:  # fall back to urllib if requests is unavailable
    requests = None
    import urllib.request

STORE = os.environ.get("COMFY_STORE", "/comfyui-store")
MANIFEST = os.environ.get("COMFY_MANIFEST", "/opt/manifest/manifest.txt")
TOKEN = os.environ.get("HF_TOKEN", "")
HDRS = {"User-Agent": "comfyui-video-lab-init/0.1"}
if TOKEN:
    HDRS["Authorization"] = "Bearer " + TOKEN

def log(*a):
    print("[init-models]", *a, flush=True)

def get_size(repo, path):
    """Return the remote file size (int) or None on error."""
    url = f"https://huggingface.co/{repo}/resolve/main/{path}"
    h = dict(HDRS)
    try:
        if requests is not None:
            r = requests.head(url, headers=h, allow_redirects=True, timeout=30)
            r.raise_for_status()
            return int(r.headers.get("Content-Length", 0))
        req = urllib.request.Request(url, method="HEAD", headers=h)
        with urllib.request.urlopen(req, timeout=30) as resp:
            return int(resp.headers.get("Content-Length", 0))
    except Exception as e:
        log("HEAD failed for %s/%s: %s" % (repo, path, e))
        return None

def download(url, dest, expected):
    """Download url -> dest, resuming. Returns True on success."""
    h = dict(HDRS)
    pos = 0
    if os.path.exists(dest):
        pos = os.path.getsize(dest)
        if pos == expected:
            log("already complete (%d bytes): %s" % (pos, os.path.basename(dest)))
            return True
        if pos > expected:
            log("existing file larger than expected; re-downloading")
            pos = 0
        else:
            log("resuming %s from byte %d / %d" % (os.path.basename(dest), pos, expected))
            h["Range"] = "bytes=%d-" % pos
    tmp = dest + ".part"
    mode = "ab" if (pos > 0 and os.path.exists(tmp)) else "wb"
    if pos == 0:
        tmp = dest + ".part"
    try:
        if requests is not None:
            with requests.get(url, headers=h, stream=True, timeout=60,
                              allow_redirects=True) as r:
                if r.status_code == 416:  # range not satisfiable -> restart
                    log("server rejected range; restarting")
                    return download(url, dest, expected)
                r.raise_for_status()
                with open(tmp, mode) as f:
                    for chunk in r.iter_content(1 << 20):
                        if chunk:
                            f.write(chunk)
        else:
            req = urllib.request.Request(url, headers=h)
            with urllib.request.urlopen(req, timeout=60) as resp, open(tmp, mode) as f:
                while True:
                    chunk = resp.read(1 << 20)
                    if not chunk:
                        break
                    f.write(chunk)
        final = os.path.getsize(tmp)
        if final != expected:
            log("size mismatch for %s: got %d want %d — keeping .part for resume"
                % (os.path.basename(dest), final, expected))
            return False
        os.replace(tmp, dest)
        return True
    except Exception as e:
        log("download error for %s: %s (will resume next run)" % (os.path.basename(dest), e))
        return False

def main():
    lines = []
    with open(MANIFEST) as f:
        for raw in f:
            s = raw.strip()
            if not s or s.startswith("#"):
                continue
            parts = s.split()
            if len(parts) == 4:
                lines.append(parts)
    log("manifest has %d model entries" % len(lines))
    ok = 0
    for expected_s, repo, path, dest_dir in lines:
        expected = int(expected_s)
        name = os.path.basename(path)
        ddir = os.path.join(STORE, dest_dir)
        os.makedirs(ddir, exist_ok=True)
        dest = os.path.join(ddir, name)
        url = f"https://huggingface.co/{repo}/resolve/main/{path}"
        log("fetching %s (%d bytes) -> %s" % (name, expected, ddir))
        # verify remote size matches manifest (catches repo drift)
        rs = get_size(repo, path)
        if rs is not None and rs != expected and os.path.exists(dest):
            log("WARNING remote size %d != manifest %d for %s (continuing)" % (rs, expected, name))
        for attempt in range(1, 6):
            if download(url, dest, expected):
                ok += 1
                break
            log("retry %d/5 after 30s" % attempt)
            time.sleep(30)
        else:
            log("FAILED to fetch %s after 5 attempts" % name)
            sys.exit(1)
    log("done: %d/%d model files present" % (ok, len(lines)))
    # write a completion marker the deployment's readiness check can use
    marker = os.path.join(STORE, ".models-complete")
    with open(marker, "w") as f:
        f.write(time.strftime("%Y-%m-%dT%H:%M:%SZ"))

if __name__ == "__main__":
    main()
