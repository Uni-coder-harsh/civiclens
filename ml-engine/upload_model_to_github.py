#!/usr/bin/env python3
"""
Upload best.onnx to GitHub Releases using the GitHub REST API.

Usage:
    GITHUB_TOKEN=your_token python3 upload_model_to_github.py

The script will:
  1. Create a GitHub Release tagged v1.0.0-model (if not already existing)
  2. Upload ml-engine/best.onnx as a release asset
  3. Print the direct download URL to set as MODEL_DOWNLOAD_URL on Railway
"""

import os
import sys
import json
import urllib.request
import urllib.parse
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────
REPO_OWNER  = "Uni-coder-harsh"
REPO_NAME   = "civiclens"
TAG_NAME    = "v1.0.0-model"
RELEASE_TITLE = "CivicLens ONNX Model v1.0"
RELEASE_NOTES = (
    "YOLO11m ONNX crack detection model (99 MB)\n\n"
    "Detected classes:\n"
    "- D00_Longitudinal_Crack\n"
    "- D10_Transverse_Crack\n"
    "- D20_Alligator_Crack\n"
    "- D30_Other_Corruption\n"
    "- D40_Pothole\n\n"
    "Set MODEL_DOWNLOAD_URL to the best.onnx asset URL on your Railway service."
)
MODEL_PATH  = Path(__file__).resolve().parent / "ml-engine" / "best.onnx"
ASSET_NAME  = "best.onnx"

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
if not GITHUB_TOKEN:
    print("ERROR: Set GITHUB_TOKEN environment variable first.")
    print("  export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx")
    sys.exit(1)

HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "civiclens-model-uploader",
}

API_BASE = "https://api.github.com"


def api_request(method, path, data=None, headers=None):
    url = f"{API_BASE}{path}"
    h = {**HEADERS, **(headers or {})}
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=h, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read()), resp.status
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"HTTP {e.code}: {body}")
        return json.loads(body) if body else {}, e.code


def get_or_create_release():
    print(f"Looking for existing release tag: {TAG_NAME} ...")
    resp, status = api_request("GET", f"/repos/{REPO_OWNER}/{REPO_NAME}/releases/tags/{TAG_NAME}")
    if status == 200:
        print(f"  Found existing release: {resp['html_url']}")
        return resp

    print(f"  Creating new release...")
    resp, status = api_request("POST", f"/repos/{REPO_OWNER}/{REPO_NAME}/releases", {
        "tag_name": TAG_NAME,
        "name": RELEASE_TITLE,
        "body": RELEASE_NOTES,
        "draft": False,
        "prerelease": False,
    })
    if status not in (200, 201):
        print(f"  Failed to create release: {resp}")
        sys.exit(1)
    print(f"  Created: {resp['html_url']}")
    return resp


def upload_asset(release, asset_path):
    upload_url = release["upload_url"].split("{")[0]  # strip template part
    file_size  = asset_path.stat().st_size
    print(f"Uploading {asset_path.name} ({file_size // 1024 // 1024} MB) ...")

    url = f"{upload_url}?name={urllib.parse.quote(ASSET_NAME)}"
    h = {
        **HEADERS,
        "Content-Type": "application/octet-stream",
        "Content-Length": str(file_size),
    }

    with open(asset_path, "rb") as f:
        req = urllib.request.Request(url, data=f, headers=h, method="POST")
        try:
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read())
                return data
        except urllib.error.HTTPError as e:
            if e.code == 422:
                # Asset already exists — find its existing URL
                print("  Asset already uploaded. Fetching existing URL...")
                release_data, _ = api_request("GET", f"/repos/{REPO_OWNER}/{REPO_NAME}/releases/tags/{TAG_NAME}")
                for asset in release_data.get("assets", []):
                    if asset["name"] == ASSET_NAME:
                        return asset
            body = e.read().decode()
            print(f"  Upload failed: HTTP {e.code} — {body}")
            sys.exit(1)


def main():
    if not MODEL_PATH.exists():
        print(f"ERROR: Model not found at {MODEL_PATH}")
        sys.exit(1)

    print(f"\n{'='*60}")
    print("  CIVICLENS ONNX MODEL — GITHUB RELEASE UPLOAD")
    print(f"{'='*60}\n")

    release = get_or_create_release()
    asset   = upload_asset(release, MODEL_PATH)
    url     = asset["browser_download_url"]

    print(f"\n{'='*60}")
    print("  ✅ UPLOAD COMPLETE")
    print(f"{'='*60}")
    print(f"\n  Download URL:")
    print(f"  {url}")
    print(f"\n  Set these env vars on Railway:")
    print(f"  MODEL_DOWNLOAD_URL={url}")
    print(f"  MODEL_PATH=/tmp/best.onnx")
    print(f"\n{'='*60}\n")


if __name__ == "__main__":
    main()
