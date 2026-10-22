#!/usr/bin/env bash
# build-lock.sh — 무거운 빌드를 이 맥 전체에서 한 번에 하나만 돌린다.
#
# 여러 프로젝트를 한 맥에서 동시에 돌리면 Gradle 데몬·메모리·CPU를 나눠 쓴다. 안드로이드 빌드·iOS 빌드·
# 골든 테스트가 두 벌 겹치면 빌드가 매우 느려지거나 데몬이 죽는다. 세션끼리는 서로의 상태를 모르니,
# 이 스크립트가 맥 전체에 하나뿐인 잠금을 잡은 뒤에 명령을 돌린다.
#
# 쓰는 법 (프로젝트 최상위 폴더에서, 명령 앞에 붙인다):
#   .claude/scripts/build-lock.sh fvm flutter build apk --debug --flavor dev -t lib/main_dev.dart
#   .claude/scripts/build-lock.sh fvm flutter test --tags golden
#   .claude/scripts/build-lock.sh --status      지금 누가 잠금을 잡고 있는지만 보여 준다
#
# 잠금 자리: ~/.config/harness/locks/build  (폴더 하나 — mkdir가 한 번에 하나만 성공하는 것으로 잡는다.
#            맥에는 flock이 기본으로 없다). 안의 owner 파일에 주인 PID·프로젝트 폴더·명령·시작 시각을 적는다.
# 풀기:      명령이 끝나면(성공·실패·Ctrl+C·종료 신호 모두) 푼다. 종료 코드는 명령의 것을 그대로 돌려준다.
# 남은 잠금: 주인 프로세스가 죽어(강제 종료·맥 재시동) 남은 잠금은, 기다리는 쪽이 주인 PID가 살아 있는
#            build-lock.sh인지 확인해 아니면 걷어 내고 잡는다.
# 기다리기:  다른 쪽이 잡고 있으면 「다른 프로젝트가 빌드 중이라 기다립니다」 한 줄을 내고 기다린다.
#            상한(기본 60분)을 넘기면 명령을 돌리지 않고 75로 끝난다.
#
# 환경변수 (시험용 — 평소에는 쓰지 않는다):
#   HARNESS_LOCK_DIR    잠금 폴더가 들어갈 곳 (기본 ~/.config/harness/locks)
#   BUILD_LOCK_POLL     기다릴 때 다시 볼 간격(초, 기본 2)
#   BUILD_LOCK_TIMEOUT  기다리는 상한(초, 기본 3600)
#
# 맥 기본 bash 3.2에서 돈다.

set -uo pipefail

LOCK_ROOT="${HARNESS_LOCK_DIR:-$HOME/.config/harness/locks}"
LOCK="$LOCK_ROOT/build"
POLL="${BUILD_LOCK_POLL:-2}"
TIMEOUT="${BUILD_LOCK_TIMEOUT:-3600}"
# 폴더는 있는데 owner 파일이 아직 없는 잠금 — 잡는 쪽이 적는 사이라면 금방 생긴다. 이만큼(초) 지나도 없으면 남은 잠금으로 본다
EMPTY_GRACE=10

say() { printf 'build-lock: %s\n' "$*" >&2; }

owner_field() { # owner_field <owner 파일> <이름>
  sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1
}

# 주인이 살아 있는 build-lock.sh인가 — PID가 다른 프로그램에 다시 쓰였으면 아니다
holder_alive() { # holder_alive <pid>
  local pid="$1" cmd
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$pid" 2>/dev/null || return 1
  cmd=$(ps -p "$pid" -o command= 2>/dev/null) || return 1
  case "$cmd" in *build-lock*) return 0 ;; *) return 1 ;; esac
}

dir_age() { # 잠금 폴더가 만들어진 지 몇 초인가
  local m now
  m=$(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK" 2>/dev/null) || { echo 0; return; }
  now=$(date +%s)
  echo $((now - m))
}

# 남은 잠금을 걷는다. 다른 쪽이 그 사이 새로 잡은 잠금을 지우지 않도록, 먼저 다른 이름으로 옮긴 뒤
# 옮긴 것이 정말 죽은 주인의 것인지 다시 본다. 아니면(살아 있는 새 잠금을 옮겼으면) 되돌린다.
clear_stale() { # clear_stale <죽은 주인 pid 또는 빈 값>
  local dead="$1" moved="$LOCK.stale.$$" pid
  mv "$LOCK" "$moved" 2>/dev/null || return 0
  pid=$(owner_field "$moved/owner" pid)
  if [ "$pid" != "$dead" ] && holder_alive "$pid"; then
    mv "$moved" "$LOCK" 2>/dev/null || true
    return 0
  fi
  rm -rf "$moved"
  say "주인 프로세스(${dead:-기록 없음})가 끝난 뒤 남은 잠금을 걷었습니다."
}

status() {
  if [ ! -d "$LOCK" ]; then
    echo "잠금 없음 — 지금 빌드 중인 프로젝트가 없습니다."
    return 0
  fi
  local pid project
  pid=$(owner_field "$LOCK/owner" pid)
  project=$(owner_field "$LOCK/owner" project)
  if holder_alive "$pid"; then
    echo "잡힘 — ${project:-알 수 없음} (PID $pid, $(owner_field "$LOCK/owner" started) 시작)"
    echo "명령: $(owner_field "$LOCK/owner" command)"
  else
    echo "남은 잠금 — 주인(PID ${pid:-기록 없음})이 끝났습니다. 다음 빌드가 걷어 냅니다."
  fi
}

acquire() {
  local waited=0 told=0 pid project
  mkdir -p "$LOCK_ROOT" 2>/dev/null || { say "잠금 폴더를 만들 수 없습니다: $LOCK_ROOT"; exit 70; }
  while :; do
    if mkdir "$LOCK" 2>/dev/null; then
      {
        echo "pid=$$"
        echo "project=$PWD"
        echo "command=$*"
        echo "started=$(date '+%Y-%m-%d %H:%M:%S')"
      } > "$LOCK/owner"
      return 0
    fi
    pid=$(owner_field "$LOCK/owner" pid)
    if [ -z "$pid" ]; then
      [ "$(dir_age)" -ge "$EMPTY_GRACE" ] && { clear_stale ""; continue; }
    elif ! holder_alive "$pid"; then
      clear_stale "$pid"
      continue
    fi
    if [ "$told" -eq 0 ]; then
      project=$(owner_field "$LOCK/owner" project)
      say "다른 프로젝트가 빌드 중이라 기다립니다 (${project##*/}${project:+, }PID ${pid:-?})"
      told=1
    fi
    if [ "$waited" -ge "$TIMEOUT" ]; then
      say "${TIMEOUT}초를 기다려도 잠금이 풀리지 않아 멈춥니다. 잠금을 지우지 말고 사람에게 알리세요 — 지금 주인은 '$0 --status'로 봅니다."
      exit 75
    fi
    sleep "$POLL"
    waited=$((waited + POLL))
  done
}

release() {
  [ "$(owner_field "$LOCK/owner" pid)" = "$$" ] && rm -rf "$LOCK"
  return 0
}

case "${1:-}" in
  '')
    say "명령이 없습니다. 쓰는 법: $0 <명령...>  또는  $0 --status"
    exit 64 ;;
  --status)
    status
    exit 0 ;;
esac

child=""
on_signal() { # 명령을 먼저 끝내고 잠금을 푼다
  [ -n "$child" ] && kill -TERM "$child" 2>/dev/null && wait "$child" 2>/dev/null
  release
  exit "$1"
}
trap release EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
trap 'on_signal 129' HUP

acquire "$@"

# 앞에서(foreground) 돌리면 bash가 명령이 끝날 때까지 신호 처리를 미루므로, 뒤에서 돌리고 기다린다.
# 입력은 그대로 이어 준다.
"$@" <&0 &
child=$!
wait "$child"
code=$?
child=""
exit "$code"
