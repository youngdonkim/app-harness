#!/usr/bin/env bash
# stage-shots.sh — 지난 단계 이름표(stage/<이름> 태그)의 코드로 목업 캔버스 화면 그림을 찍어 .canvas-stages/<이름>/ 에 둔다.
#
# 왜 필요한가: 단계가 지나 사람이 판을 고르면 그 단계의 화면 코드는 고른 판에 덮여 지금 앱에 없다. 캔버스 「단계」 보기는
# 단계마다 한 띠로 그때 화면을 보여 줘야 하니, 이름표가 가리키는 그때 코드를 임시 폴더(git worktree)에 꺼내
# 골든 테스트로 그림만 찍어 둔다. 캔버스는 그 그림을 보여 주고(코멘트 서버가 /stages 로 내준다), 코드는 건드리지 않는다.
#
# 쓰는 법 (프로젝트 최상위 폴더에서):
#   .claude/scripts/stage-shots.sh <이름>         예: 2-3-drafts  (stage/2-3-drafts 처럼 stage/ 를 붙여도 된다). 이미 찍은 단계도 다시 찍는다
#   .claude/scripts/stage-shots.sh --all          로컬·원격의 stage/2-* 이름표 중 .canvas-stages/<이름>/ 이 아직 없는 것만 차례로 찍는다
#
# 하는 일 (이름표 하나마다):
#   ① 이름표가 로컬에 없으면 GitHub에서 이름표를 한 번 받아 온다.
#   ② 그 이름표 코드에 lib/dev/canvas/ 가 없으면(1단계·2-0처럼 캔버스 전) 찍을 것이 없다고 알리고 0으로 끝낸다.
#   ③ 임시 폴더에 그 이름표의 코드를 꺼낸다(git worktree add --detach) → ④ fvm flutter pub get.
#   ⑤ 옛 코드의 골든 테스트를 지금 하네스의 골든 테스트(.claude/templates/mockup-canvas/test/goldens/canvas_golden_test.dart.template)
#      로 덮어 쓴다. 옛 골든 테스트에는 늦게 그려지는 사진이 빈 자리로 찍히던 버그가 남은 판이 있어서다(진행 중 프로젝트에서 실제로 겪음).
#      덮어 쓴 테스트가 옛 코드와 맞지 않아 컴파일이 안 되면, 그 이름표의 원래 골든 테스트로 한 번 더 찍고 빈 자리 사진 경고를 낸다.
#   ⑥ 임시 폴더의 옛 그림을 비우고 → ⑦ 빌드 잠금(build-lock.sh)을 거쳐 골든을 새로 찍는다.
#      찍는 범위는 주요 화면 × 평소 모습(기본 상태)뿐이다 — 상태 창까지 찍으면 장수·시간만 늘고 단계 보기에는 필요 없다.
#      이름이 -drafts(또는 -drafts-2 …)로 끝나는 비교안 단계는 비교안 창만 찍는다.
#   ⑧ 찍힌 png와 stage.json(이름·태그·설명·짧은 커밋 번호·커밋 시각)을 .canvas-stages/<이름>.tmp 에 모았다가 옛 폴더와 바꿔 끼운다.
#   ⑨ 끝나면(실패·중단 포함) 임시 폴더와 worktree를 걷는다.
#
# 그림 자리: 프로젝트 최상위 .canvas-stages/<이름>/<창 열쇠>.png + stage.json (git에 올리지 않는다 — gitignore에 있다.
#            이름표가 GitHub에 있어 언제든 다시 찍을 수 있다). 캔버스는 켤 때 받으니 다시 찍은 뒤에는 캔버스를 R(hot restart)로 다시 켠다.
#
# stage-tag.sh 안에 넣지 않은 이유: 이름표 올리기를 몇 분 걸리는 빌드와 골든 실패에 묶지 않으려는 것이고,
#   1단계·2-0 이름표에는 캔버스가 아직 없어 찍을 것이 없기 때문이다. 대신 stage-tag.sh 가 2-로 시작하는 이름표 끝에 이 스크립트를 안내한다.
#
# 종료 코드: 0 찍었거나(경고가 있을 수 있다) 캔버스 전 단계라 찍을 것이 없음 · 1 찍지 못함(--all은 하나라도 실패) · 2 쓰는 법이 틀림
#
# 맥 기본 bash 3.2에서 돈다. 몇 분 걸리니 백그라운드로 돌린다.

set -uo pipefail

usage() {
  echo "쓰는 법: .claude/scripts/stage-shots.sh <이름>   (예: 2-3-drafts)" >&2
  echo "         .claude/scripts/stage-shots.sh --all    (그림이 아직 없는 stage/2-* 이름표 전부)" >&2
}

mode=""
arg=""
case "${1:-}" in
  --all) [ $# -eq 1 ] && mode=all ;;
  ''|-*) ;;
  *) [ $# -eq 1 ] && { mode=one; arg="${1#stage/}"; } ;;
esac
if [ -z "$mode" ]; then usage; exit 2; fi

if ! ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "git 저장소 안이 아니라 그림을 찍지 않았습니다 — 프로젝트 최상위 폴더에서 부르세요." >&2
  exit 1
fi
cd "$ROOT" || exit 1

STAGES_DIR="$ROOT/.canvas-stages"
TEMPLATE="$ROOT/.claude/templates/mockup-canvas/test/goldens/canvas_golden_test.dart.template"
BUILD_LOCK="$ROOT/.claude/scripts/build-lock.sh"

if [ ! -f "$TEMPLATE" ] || [ ! -x "$BUILD_LOCK" ]; then
  echo "이 프로젝트에 하네스의 골든 테스트 틀이나 build-lock.sh 가 없습니다 — project-init 으로 하네스를 먼저 맞추세요." >&2
  exit 1
fi

# fvm을 공식 설치 스크립트로 깔면 ~/fvm/bin 에 생기고 명령 경로(PATH)에는 없다 — build-lock.sh 처럼 찾아 쓴다
FVM="fvm"
if ! command -v fvm >/dev/null 2>&1; then
  if [ -x "$HOME/fvm/bin/fvm" ]; then
    FVM="$HOME/fvm/bin/fvm"
  else
    echo "fvm 을 찾을 수 없어 그림을 찍지 않았습니다." >&2
    exit 1
  fi
fi

say() { printf 'stage-shots: %s\n' "$*"; }
warn() { printf 'stage-shots: %s\n' "$*" >&2; }

fetch_tags() {
  GIT_TERMINAL_PROMPT=0 git fetch -q origin 'refs/tags/stage/*:refs/tags/stage/*' >/dev/null 2>&1
}

# 정리용 상태 — trap 이 읽는다
SCRATCH=""
WT=""
TMP_OUT=""
CHILD=""

cleanup() {
  if [ -n "$WT" ]; then
    git worktree remove --force "$WT" >/dev/null 2>&1
    git worktree prune >/dev/null 2>&1
  fi
  [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"
  [ -n "$TMP_OUT" ] && rm -rf "$TMP_OUT"
  SCRATCH=""; WT=""; TMP_OUT=""
}
on_signal() {
  [ -n "$CHILD" ] && kill -TERM "$CHILD" 2>/dev/null && wait "$CHILD" 2>/dev/null
  cleanup
  exit "$1"
}
trap cleanup EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
trap 'on_signal 129' HUP

# 명령을 뒤에서 돌리고 기다린다 — 앞에서 돌리면 bash 가 명령이 끝날 때까지 신호 처리를 미룬다
run_logged() { # run_logged <폴더> <로그 파일> <명령...>
  local dir="$1" log="$2"; shift 2
  ( cd "$dir" && exec "$@" ) >"$log" 2>&1 &
  CHILD=$!
  wait "$CHILD"
  local code=$?
  CHILD=""
  return "$code"
}

json_escape() { printf '%s' "$1" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# 이름표 하나를 찍는다. 0 찍음 또는 찍을 것 없음 · 1 못 찍음
shoot_one() { # shoot_one <이름>
  local n="$1" tag="stage/$1" started="$SECONDS"

  if ! git check-ref-format "refs/tags/$tag" >/dev/null 2>&1; then
    warn "이름으로 쓸 수 없습니다: $n (예: 2-3-drafts)"
    return 1
  fi
  if ! git rev-parse -q --verify "refs/tags/$tag^{commit}" >/dev/null; then
    if git remote get-url origin >/dev/null 2>&1; then
      say "이름표 $tag 가 로컬에 없어 GitHub에서 받아 옵니다."
      fetch_tags
    fi
    if ! git rev-parse -q --verify "refs/tags/$tag^{commit}" >/dev/null; then
      warn "이름표 $tag 를 찾을 수 없습니다 — 이름이 맞는지 'git tag -l \"stage/*\"' 로 보세요."
      return 1
    fi
  fi

  if ! git cat-file -e "$tag:lib/dev/canvas" 2>/dev/null; then
    say "$tag — 이 이름표에는 목업 캔버스가 아직 없어(1단계·2-0 등) 찍을 그림이 없습니다. 건너뜁니다."
    return 0
  fi

  # 찍는 범위: 평소 모습만. 비교안 단계는 비교안 창만
  local filter='__phone__base$' scope="주요 화면의 평소 모습"
  case "$n" in
    *-drafts|*-drafts-[0-9]*)
      filter='__draft-.+__phone__base$'
      scope="비교안 창의 평소 모습" ;;
  esac

  SCRATCH="$(mktemp -d)" || { warn "임시 폴더를 만들 수 없습니다."; return 1; }
  WT="$SCRATCH/code"
  local log="$SCRATCH/log.txt"

  say "$tag — 그때 코드를 임시 폴더에 꺼냅니다. 찍는 범위: $scope"
  if ! git worktree add -q --detach "$WT" "refs/tags/$tag" >"$log" 2>&1; then
    warn "코드를 꺼내지 못했습니다. 원인(git 출력):"; tail -n 20 "$log" >&2
    WT=""; cleanup; return 1
  fi

  say "패키지를 받습니다(pub get)."
  if ! run_logged "$WT" "$log" "$FVM" flutter pub get; then
    warn "pub get 이 실패했습니다. 끝 부분:"; tail -n 20 "$log" >&2
    cleanup; return 1
  fi

  local app
  app="$(sed -n 's/^name:[[:space:]]*//p' "$WT/pubspec.yaml" | head -n 1 | tr -d '\r"'"'"' ')"
  if [ -z "$app" ]; then
    warn "pubspec.yaml 에서 앱 이름(name:)을 읽지 못했습니다."
    cleanup; return 1
  fi

  # 지금 하네스의 골든 테스트를 덮어 쓰고 옛 그림을 비운다
  mkdir -p "$WT/test/goldens"
  sed "s/<앱>/$app/g" "$TEMPLATE" >"$WT/test/goldens/canvas_golden_test.dart"
  rm -rf "$WT/test/goldens/canvas"; mkdir -p "$WT/test/goldens/canvas"
  # golden 태그를 모르는 태그라는 경고가 안 나오게, 옛 코드에 dart_test.yaml 이 없으면 틀의 것을 둔다
  if [ ! -f "$WT/dart_test.yaml" ] && [ -f "$ROOT/.claude/templates/mockup-canvas/dart_test.yaml.template" ]; then
    cp "$ROOT/.claude/templates/mockup-canvas/dart_test.yaml.template" "$WT/dart_test.yaml"
  fi

  local warned=0 code
  say "골든 그림을 찍습니다(몇 분 걸립니다. 다른 빌드가 돌고 있으면 차례를 기다립니다)."
  run_logged "$WT" "$log" "$BUILD_LOCK" fvm flutter test --tags golden --update-goldens \
    --name "$filter" test/goldens/canvas_golden_test.dart
  code=$?

  # 컴파일이 안 되면(옛 코드와 틀이 맞지 않음) 그 이름표의 원래 골든 테스트로 한 번 더
  if [ "$code" -ne 0 ] && grep -qE 'Failed to load|Compilation failed|\.dart:[0-9]+:[0-9]+: Error' "$log"; then
    if git cat-file -e "$tag:test/goldens/canvas_golden_test.dart" 2>/dev/null; then
      warn "지금 하네스의 골든 테스트가 이 이름표의 옛 코드와 맞지 않습니다(컴파일 실패). 그때의 골든 테스트로 한 번 더 찍습니다."
      git show "$tag:test/goldens/canvas_golden_test.dart" >"$WT/test/goldens/canvas_golden_test.dart"
      rm -rf "$WT/test/goldens/canvas"; mkdir -p "$WT/test/goldens/canvas"
      run_logged "$WT" "$log" "$BUILD_LOCK" fvm flutter test --tags golden --update-goldens \
        --name "$filter" test/goldens/canvas_golden_test.dart
      code=$?
      warned=1
      warn "경고: 옛 골든 테스트로 찍었습니다 — 늦게 그려지는 사진이 빈 자리로 찍혔을 수 있습니다."
    else
      warn "이 이름표에는 골든 테스트가 없어 그림을 찍지 못했습니다."
      cleanup; return 1
    fi
  fi

  local count
  count="$(find "$WT/test/goldens/canvas" -maxdepth 1 -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$count" -eq 0 ]; then
    warn "그림이 한 장도 찍히지 않았습니다($scope). 끝 부분:"; tail -n 25 "$log" >&2
    cleanup; return 1
  fi
  if [ "$code" -ne 0 ]; then
    warned=1
    warn "경고: 일부 창이 찍히지 못했습니다(테스트 실패). 찍힌 $count장만 둡니다. 끝 부분:"; tail -n 15 "$log" >&2
  fi

  # 모아서 바꿔 끼운다
  mkdir -p "$STAGES_DIR"
  TMP_OUT="$STAGES_DIR/$n.tmp"
  rm -rf "$TMP_OUT"; mkdir -p "$TMP_OUT"
  cp "$WT"/test/goldens/canvas/*.png "$TMP_OUT"/

  local desc sha date
  desc="$(git tag -l --format='%(contents:subject)' "$tag" 2>/dev/null | head -n 1)"
  sha="$(git rev-parse --short "refs/tags/$tag^{commit}")"
  date="$(git log -1 --format=%cI "refs/tags/$tag^{commit}")"
  printf '{"name":"%s","tag":"%s","desc":"%s","commit":"%s","date":"%s"}\n' \
    "$(json_escape "$n")" "$(json_escape "$tag")" "$(json_escape "$desc")" "$sha" "$date" >"$TMP_OUT/stage.json"

  rm -rf "$STAGES_DIR/$n.old"
  [ -d "$STAGES_DIR/$n" ] && mv "$STAGES_DIR/$n" "$STAGES_DIR/$n.old"
  mv "$TMP_OUT" "$STAGES_DIR/$n"
  TMP_OUT=""
  rm -rf "$STAGES_DIR/$n.old"

  cleanup
  say "$tag — ${count}장을 .canvas-stages/$n/ 에 두었습니다($((SECONDS - started))초)$([ "$warned" = 1 ] && echo ', 경고 있음'). 캔버스가 떠 있으면 R(hot restart)로 다시 받습니다."
  return 0
}

if [ "$mode" = one ]; then
  shoot_one "$arg"
  exit $?
fi

# --all: 로컬·원격의 stage/2-* 이름표 중 그림이 아직 없는 것만, 오래된 것부터
if git remote get-url origin >/dev/null 2>&1; then
  fetch_tags || warn "GitHub에서 이름표를 받지 못해 로컬 이름표만 봅니다."
fi
todo=""
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  n="${ref#stage/}"
  [ -f "$STAGES_DIR/$n/stage.json" ] && continue
  todo="$todo$n
"
done <<EOF
$(git for-each-ref --sort=creatordate --format='%(refname:short)' 'refs/tags/stage/2-*')
EOF
if [ -z "$todo" ]; then
  say "그림이 아직 없는 stage/2-* 이름표가 없습니다."
  exit 0
fi
failed=0
while IFS= read -r n; do
  [ -z "$n" ] && continue
  shoot_one "$n" || failed=1
done <<EOF
$todo
EOF
exit "$failed"
