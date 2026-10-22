#!/bin/bash
# auto-wip-commit.sh — Stop hook
#
# Claude 응답이 끝날 때마다 자동으로 변경된 파일을 wip 커밋으로 저장.
# 푸시는 안 함. main 브랜치에선 작동 안 함.
#
# Skip 조건 (안전 우선):
#   1. 현재 브랜치 = main   → PR 워크플로 강제, 자동 커밋이 main 오염 금지
#   2. merge/rebase 진행 중 → conflict marker가 wip 커밋에 섞이는 사고 방지
#   3. 변경 없음            → 커밋 안 함 (빈 커밋을 만들지 않는다)
#
# 시크릿 파일 처리 (skip이 아니라 제외):
#   커밋 전체를 포기하지 않는다 — .env 등 시크릿 패턴에 걸리는 파일만 staging에서
#   빼고 나머지는 그대로 wip 커밋한다. .gitignore 불완전 시 마지막 안전망.
#   (.env.example/.sample/.template처럼 끝이 예시 이름인 파일은 예외 — 정상 커밋 대상.
#    .env.local.example처럼 중간에 환경 이름이 끼는 형태도 끝을 보므로 예외에 든다)
#
# 커밋 메시지: wip: <힌트> — <파일1>, <파일2> 외 N개 (X files changed, Y insertions(+), Z deletions(-))
#   힌트가 없으면 wip: <파일 목록> (<통계>)
# 백그라운드 에이전트가 도는 중에 턴이 끝나면 이 훅이 에이전트의 작업 중간을 wip 커밋할 수 있다.
# 정상이다 — 되돌리지 않는다. 에이전트 지시서에도 그렇게 알려 둔다.
# 푸시: 절대 안 함 (push는 사용자 명시 지시 시에만)
#
# 힌트 — 이번 턴의 마지막 사용자 입력 하나만 본다:
#   - 하네스가 자동으로 붙인 메시지(대화 기록의 isMeta 표시)는 처음부터 뺀다.
#   - 슬래시 명령 턴이면 명령 이름(+인자)을 힌트로 쓴다 (<command-name> 태그,
#     또는 태그 없이 "Skill /이름 … loaded" 안내문만 오는 재호출 형태).
#   - 사람 입력이 아니면 — 알려진 하네스 태그(<system-reminder>·<task-notification> 등)를
#     지우고 나서 비거나, 남은 글이 '<'로 시작하면(<cross-session-message …> 같은
#     다른 세션·도구가 보낸 메시지) — 힌트를 쓰지 않고 파일 목록만 쓴다.
#     더 앞의 메시지로 거슬러 올라가지 않는다 — 지난 턴의 주제가 이번 커밋 제목이 된다.
#   - 60자에서 자른다. 로케일이 없어도 한글이 깨지지 않게 UTF-8 로케일을 찾아 문자
#     단위로 자르고, 못 찾으면 바이트로 자른 뒤 불완전한 꼬리를 지운다.
#
# 작업 폴더: stdin JSON의 cwd(세션이 실제로 앉은 폴더)가 먼저다. CLAUDE_PROJECT_DIR은
#   세션 시작 폴더에 고정된 값이라 cwd가 없을 때의 폴백으로만 쓴다.
#
# stage 상태와 무관하게 변경 전부를 담는다 — Claude가 도구로 실행한 git mv·git add도
#   stage를 만들어서 사용자의 부분 stage와 구분이 안 된다. 어차피 git add -A로 전부 담는다.
#
# 코드 정리 표시 커밋(chore: 코드 정리 반영 …)은 이 훅이 만들지 않는다 — code-cleanup
#   절차가 반영을 끝낸 뒤 직접 커밋한다. 훅이 만드는 wip 커밋은 표시로 인정받지 않는다.

set -uo pipefail

# Stop hook input
INPUT=$(cat)

# jq가 없으면 작업 폴더·대화 기록을 읽을 수 없다 — 한 줄 알리고 조용히 끝낸다.
if ! command -v jq >/dev/null 2>&1; then
  echo "[auto-wip] jq가 없어 자동 wip 커밋을 건너뜁니다 — github-connect의 jq 단계(③)를 다시 돌리면 jq를 자동으로 깝니다." >&2
  exit 0
fi
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")

# 세션의 현재 작업 폴더 = stdin의 cwd (세션이 실제로 앉은 폴더까지 따라옴).
# CLAUDE_PROJECT_DIR은 세션 시작 폴더에 고정된 값이라 폴백으로만 쓴다.
PROJECT_DIR=""
for d in "$HOOK_CWD" "${CLAUDE_PROJECT_DIR:-}" "$(pwd)"; do
  if [ -n "$d" ] && [ -d "$d" ]; then
    PROJECT_DIR="$d"
    break
  fi
done
[ -n "$PROJECT_DIR" ] || exit 0
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# git repo 아니면 조용히 종료
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# 1. main branch 가드
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ "$current_branch" = "main" ] || [ -z "$current_branch" ]; then
  echo "[auto-wip] main branch 또는 detached HEAD — skip" >&2
  exit 0
fi

# 2. merge/rebase 진행 중 가드
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo ".git")
if [ -f "$GIT_DIR/MERGE_HEAD" ] || [ -f "$GIT_DIR/REBASE_HEAD" ] \
   || [ -d "$GIT_DIR/rebase-merge" ] || [ -d "$GIT_DIR/rebase-apply" ] \
   || [ -f "$GIT_DIR/CHERRY_PICK_HEAD" ]; then
  echo "[auto-wip] merge/rebase/cherry-pick 진행 중 — skip" >&2
  exit 0
fi

# 3. 변경 없음 → 끝
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  exit 0
fi

# 4. 시크릿 패턴 검사 — staging 대상 파일 중 위험 패턴에 걸리는 파일 목록만 구한다.
#    여기서 커밋을 포기하지 않는다 — 의심 파일만 나중에(6번) staging에서 뺀다.
#    단 .example/.sample/.template로 끝나는 이름(값 없는 예시 템플릿)은 예외로 뺀다.
#    끝을 보는 이유: .env.local.example처럼 중간에 환경 이름이 끼는 형태가 흔해서
#    정확히 .env.example 등 세 이름만 보면 놓친다.
#    앱 서명 파일(*.jks·*.keystore·key.properties)과 서비스 계정 키(*service-account*.json·
#    *serviceAccount*.json — 대소문자를 가리지 않아 한 패턴으로 잡는다)도 같이 뺀다.
candidate_files=$(git status --porcelain | sed -E 's/^...//' | awk -F ' -> ' '{print $NF}')
suspicious=$(printf '%s\n' "$candidate_files" \
  | grep -iE '(^\.env$|/\.env$|^\.env\.|/\.env\.|\.key$|\.pem$|secret|credentials\.json$|id_rsa|id_ed25519|\.jks$|\.keystore$|(^|/)key\.properties$|service-?account[^/]*\.json$)' \
  | grep -ivE '\.(example|sample|template)$' \
  || true)

# 5. 이번 턴의 마지막 사용자 입력에서 힌트 추출 (transcript 있을 때만)
#    사람 입력이 아니면 힌트 없이 파일 목록만 쓴다 — 머리 주석 「힌트」 참고.

# 알려진 하네스 블록 태그 제거 + 줄바꿈 공백화 + 공백 정규화.
# (제거 후에도 '<'로 시작하거나 비어 있거나 'Background (from the session'으로 시작하면 호출부에서 하네스 산물로 판단 —
#  마지막은 다른 세션이 보낸 안내문이라 사용자 입력이 아니다)
strip_harness_tags() {
  printf '%s' "$1" \
    | awk 'BEGIN{RS=""} {
        gsub(/<system-reminder>[^<]*<\/system-reminder>/, "");
        gsub(/<task-notification>[^<]*<\/task-notification>/, "");
        gsub(/<local-command-stdout>[^<]*<\/local-command-stdout>/, "");
        gsub(/<local-command-caveat>[^<]*<\/local-command-caveat>/, "");
        gsub(/<command-name>[^<]*<\/command-name>/, "");
        gsub(/<command-message>[^<]*<\/command-message>/, "");
        gsub(/<command-args>[^<]*<\/command-args>/, "");
        print
      }' \
    | tr '\n' ' ' \
    | sed -E 's/  +/ /g; s/^ +//; s/ +$//'
}

# 슬래시 명령 턴이면 명령 이름(+인자)을 힌트로 뽑는다. <command-message>는
# "simplify is running…" 같은 안내문일 뿐 사용자 의도가 아니므로 쓰지 않는다.
# 이름이 없으면(슬래시 명령 턴이 아니면) 빈 출력에 실패(1)를 반환한다.
extract_slash_command() {
  local flat name args
  # 메시지에 줄바꿈이 섞여 있으면 sed가 줄 단위로만 봐서 태그를 놓치므로 먼저 눕힌다.
  flat=$(printf '%s' "$1" | tr '\n' ' ')
  name=$(printf '%s' "$flat" | sed -nE 's/.*<command-name>([^<]*)<\/command-name>.*/\1/p')
  name=$(printf '%s' "$name" | sed -E 's/^ +//; s/ +$//')
  # 태그가 없는 재호출 형태 폴백. 같은 세션에서 스킬을 두 번째로 부르면 태그 대신
  # "Skill /simplify is already loaded above; instructions unchanged" 같은 안내문만 온다.
  # 잡는 폭: 메시지가 `Skill /이름`으로 시작하고, 그 뒤 80자 안에 loaded가 있을 때만.
  # 문구 전체를 적어 두지 않는 이유 — 하네스가 바뀌면 안내문 표현이 달라질 수 있어서다.
  # 그래도 "맨 앞에서 시작" + "loaded가 근처에" 두 조건을 같이 요구하면
  # "Skill /simplify 스킬이 뭐 하는 거야?" 같은 사람 질문은 안 걸린다.
  # 이름에 콜론·하이픈·점을 허용해 /payload:harness-diet 같은 형태도 잡는다.
  if [ -z "$name" ]; then
    name=$(printf '%s' "$flat" \
      | sed -nE 's|^[[:space:]]*Skill (/[A-Za-z0-9_.:-]+)[[:space:]].{0,80}loaded.*|\1|p')
  fi
  [ -z "$name" ] && return 1
  case "$name" in
    /*) ;;
    *) name="/$name" ;;
  esac
  args=$(printf '%s' "$flat" | sed -nE 's/.*<command-args>([^<]*)<\/command-args>.*/\1/p')
  args=$(printf '%s' "$args" | sed -E 's/^ +//; s/ +$//')
  if [ -n "$args" ]; then
    printf '%s %s' "$name" "$args"
  else
    printf '%s' "$name"
  fi
  return 0
}

# 최소 환경(로케일 미설정)에서도 문자 단위 컷이 되도록 시스템에 설치된 UTF-8 로케일을 하나 찾는다.
pick_utf8_locale() {
  local avail cand
  avail=$(locale -a 2>/dev/null)
  for cand in C.UTF-8 en_US.UTF-8 en_GB.UTF-8 ko_KR.UTF-8 POSIX.UTF-8; do
    printf '%s\n' "$avail" | grep -qx "$cand" && { printf '%s' "$cand"; return 0; }
  done
  return 1
}

# UTF-8 로케일을 못 찾아 바이트 단위로 자른 경우, 끝에 남은 불완전한 멀티바이트
# 시퀀스(글자가 중간에 잘린 것)를 찾아 통째로 잘라낸다 — 깨진 바이트만은 안 남기려는 최후 방어.
trim_incomplete_utf8_tail() {
  local s="$1" len i pos b ord need_len=0 start=-1 max_back=4
  len=${#s}
  [ "$len" -lt "$max_back" ] && max_back=$len
  for (( i = 0; i < max_back; i++ )); do
    pos=$(( len - 1 - i ))
    b="${s:pos:1}"
    ord=$(printf '%d' "'$b")
    if (( (ord & 0xC0) != 0x80 )); then
      start=$pos
      if (( (ord & 0x80) == 0 )); then need_len=1
      elif (( (ord & 0xE0) == 0xC0 )); then need_len=2
      elif (( (ord & 0xF0) == 0xE0 )); then need_len=3
      elif (( (ord & 0xF8) == 0xF0 )); then need_len=4
      else need_len=1
      fi
      break
    fi
  done
  if [ "$start" -ge 0 ]; then
    local have_len=$(( len - start ))
    (( have_len < need_len )) && s="${s:0:start}"
  fi
  printf '%s' "$s"
}

hint=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  # type=user, content가 문자열, 하네스 자동 메시지(isMeta)가 아닌 것 중 마지막 하나.
  # 메시지 안의 줄바꿈은 그대로 둔다(태그 제거가 줄을 넘어 봐야 해서).
  last_msg=$(jq -n -r '
    [inputs
      | select(.type == "user" and (.isMeta // false) != true
               and (.message.content | type == "string"))
      | .message.content] as $all
    | ($all[-1] // "")
  ' "$TRANSCRIPT_PATH" 2>/dev/null || true)

  raw=""
  if [ -n "$last_msg" ]; then
    if slash=$(extract_slash_command "$last_msg"); then
      raw="$slash"
    else
      cleaned=$(strip_harness_tags "$last_msg")
      if [ -n "$cleaned" ] && [[ "$cleaned" != "<"* ]] && [[ "$cleaned" != "Background (from the session"* ]]; then
        raw="$cleaned"
      fi
    fi
  fi

  if [ -n "$raw" ]; then
    utf8_locale=$(pick_utf8_locale 2>/dev/null || true)
    if [ -n "$utf8_locale" ]; then
      hint=$(printf '%s' "$raw" | LC_ALL="$utf8_locale" cut -c1-60)
    else
      hint=$(printf '%s' "$raw" | cut -c1-60)
      hint=$(trim_incomplete_utf8_tail "$hint")
    fi
  fi
fi

# 6. add + commit — 의심 파일만 빼고 나머지는 그대로 커밋
git add -A 2>/dev/null

# 4번에서 걸린 의심 파일만 staging에서 뺀다. 파일명에 공백이 있어도 깨지지 않게
# 한 줄씩 처리한다. git restore --staged는 새로 추가된 파일이면 추적 안 함 상태로,
# 수정된 파일이면 수정 상태로 되돌린다 — 어느 쪽이든 그 파일만 커밋에서 빠지고
# 작업 내용(워킹 트리)은 그대로 남는다.
if [ -n "$suspicious" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] && git restore --staged -- "$f" 2>/dev/null
  done <<< "$suspicious"
fi

# 뺀 뒤 staging이 비었으면(의심 파일뿐이었으면) 커밋할 게 없으니 안내만 남기고 종료
if git diff --cached --quiet 2>/dev/null; then
  echo "[auto-wip] 시크릿 패턴 파일뿐이라 커밋할 변경 없음 — skip:" >&2
  printf '  %s\n' $suspicious >&2
  echo "[auto-wip] .gitignore 점검 후 수동 처리 필요" >&2
  exit 0
fi

# 변경 통계
stat_line=$(git diff --cached --shortstat 2>/dev/null | sed -E 's/^ +//; s/ +$//')

# 대표 파일 3개 (basename)
file_count=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
file_list=$(git diff --cached --name-only 2>/dev/null | head -3 | awk -F/ '{print $NF}' | paste -sd ', ' -)
extra=""
if [ "$file_count" -gt 3 ]; then
  extra=" 외 $((file_count - 3))개"
fi

# 메시지 조립
if [ -n "$hint" ]; then
  msg="wip: ${hint} — ${file_list}${extra} (${stat_line})"
else
  msg="wip: ${file_list}${extra} (${stat_line})"
fi

# 커밋 (실패해도 Claude는 막지 않음 — exit 0)
if git commit -m "$msg" >/dev/null 2>&1; then
  echo "[auto-wip] 커밋: $msg" >&2
  if [ -n "$suspicious" ]; then
    echo "[auto-wip] 시크릿 패턴 파일은 빼고 커밋함:" >&2
    printf '  %s\n' $suspicious >&2
    echo "[auto-wip] .gitignore 점검 후 수동 처리 필요" >&2
  fi
else
  echo "[auto-wip] 커밋 실패 (pre-commit hook 등) — 사용자 확인 필요" >&2
fi

exit 0
