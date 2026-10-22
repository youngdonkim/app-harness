#!/usr/bin/env bash
# render.sh — slides.tsv의 줄마다 frame.html을 1080×1920으로 찍어 스토어 스크린샷 폴더에 PNG로 둡니다.
#
# 쓰는 법 (프로젝트 맨 위 폴더에서, 어느 브랜치에서나):
#   bash fastlane/screenshots/render.sh                 # 찍어서 fastlane/metadata/android/ko-KR/images/phoneScreenshots/에
#   bash fastlane/screenshots/render.sh --out <폴더>    # 다른 폴더에(먼저 보고 고를 때)
#   bash fastlane/screenshots/render.sh --locale ko-KR  # 로케일 폴더(기본 ko-KR)
#
# 찍는 도구: 맥의 Google Chrome을 화면 없이(headless) 띄워 찍습니다. Chrome이 없으면
#   npx playwright screenshot(Node 필요, 처음엔 브라우저를 받느라 오래 걸림)으로 찍습니다.
# 찍은 뒤 macOS 기본 도구 sips로 투명 채널을 뺍니다 — 플레이는 투명 채널 없는 PNG(또는 JPEG)만 받습니다.
# 이 스크립트는 그림을 만들기만 합니다. 그림이 괜찮은지는 사람이 봅니다.

set -euo pipefail

LOCALE="ko-KR"
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --locale) LOCALE="$2"; shift 2 ;;
    *) echo "알 수 없는 인자: $1 (쓰는 법은 이 파일 맨 위 주석)"; exit 1 ;;
  esac
done

ROOT="$(pwd)"
HERE="$ROOT/fastlane/screenshots"
[ -f "$HERE/frame.html" ] || { echo "프로젝트 맨 위 폴더에서 돌리세요 — $HERE/frame.html 이 없습니다"; exit 1; }
[ -n "$OUT" ] || OUT="$ROOT/fastlane/metadata/android/$LOCALE/images/phoneScreenshots"
mkdir -p "$OUT"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 주소 질의 값으로 넣을 수 있게 글자를 바꿉니다(python3는 맥 기본).
enc() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }

shoot() { # 주소 결과파일
  if [ -x "$CHROME" ]; then
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
      --window-size=1080,1920 --virtual-time-budget=3000 --screenshot="$2" "$1" >/dev/null 2>&1
  else
    npx --yes playwright screenshot --viewport-size=1080,1920 --wait-for-timeout=1500 "$1" "$2" >/dev/null
  fi
}

n=0
while IFS=$'\t' read -r order img title sub || [ -n "${order:-}" ]; do
  case "${order:-}" in ""|\#*) continue ;; esac
  [ -f "$ROOT/$img" ] || { echo "그림이 없습니다: $img (줄 $order)"; exit 1; }
  url="file://$HERE/frame.html?img=$(enc "file://$ROOT/$img")&title=$(enc "${title:-}")&sub=$(enc "${sub:-}")"
  raw="$TMP/$order.png"
  shoot "$url" "$raw"
  [ -s "$raw" ] || { echo "찍지 못했습니다: 줄 $order"; exit 1; }
  # 투명 채널 빼기: JPEG로 한 번 바꿨다가 PNG로 되돌립니다(JPEG에는 투명 채널이 없음, 품질 최고로).
  sips -s format jpeg -s formatOptions 100 "$raw" --out "$TMP/$order.jpg" >/dev/null
  sips -s format png "$TMP/$order.jpg" --out "$OUT/${order}_${LOCALE}.png" >/dev/null
  w=$(sips -g pixelWidth "$OUT/${order}_${LOCALE}.png" | awk '/pixelWidth/ {print $2}')
  h=$(sips -g pixelHeight "$OUT/${order}_${LOCALE}.png" | awk '/pixelHeight/ {print $2}')
  echo "찍음: ${order}_${LOCALE}.png (${w}×${h})"
  n=$((n + 1))
done < "$HERE/slides.tsv"

echo "모두 ${n}장 → $OUT"
[ "$n" -ge 2 ] || echo "알림: 플레이는 스크린샷이 2장 이상이어야 올릴 수 있습니다"
