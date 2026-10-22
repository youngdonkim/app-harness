#!/bin/bash
# owner-runner-guard.sh — PreToolUse(Bash) guard
#
# 키·계정이 필요한 CLI를 실행기 없이 부르거나, 실서비스를 잘못 건드릴 수 있는 명령을 막는다.
# 그리고 평문 비밀번호·개인 키가 든 변경을 커밋하려 하면 막는다.
#
# 왜 실행기인가: gh·Firebase CLI·fastlane의 로그인은 컴퓨터 전체에 남는다. 실행기
#   (.claude/scripts/with-owner.sh)를 빼고 부르면 이 프로젝트 소유의 계정 장부가 아니라
#   컴퓨터에 남은 기본 로그인으로 돌아, 소유가 다른 프로젝트(개인·회사)가 한 컴퓨터에 있을 때
#   PR·배포·앱 올리기가 조용히 다른 계정으로 일어난다. 실행기는 gh에는 장부의 토큰을,
#   firebase·flutterfire에는 장부의 계정 이메일(--account)을 붙여 준다.
#   (실측 2026-10-19: PR을 실행기 없이 기본 gh 로그인으로 만듦 — 계정이 같아 사고는
#   아니었지만 규칙 문장만으로는 안 막혔다)
#
# 막는 것 — 명령 조각의 첫 실행 낱말 기준:
#   gh <무엇이든>
#     실행기 없이 부를 때. 예외: gh auth …(github-connect가 전역 로그인을 다룸)·
#     gh --version·gh version·gh help·인자 없는 gh, 조각 앞에 GH_TOKEN=를 직접 준 경우.
#   firebase …(npx firebase·firebase-tools 포함)
#     ① 실행기 없이 부를 때.
#     ② --project dev·--project prod(-P·--project= 꼴 포함)가 없거나 값이 별칭 dev·prod가
#        아닐 때. 기본 프로젝트에 기대거나 프로젝트 ID를 직접 쓰면 엉뚱한 쪽에 붙기 쉽다.
#     ③ firebase use — 기본 프로젝트를 바꾸는 명령이라 언제나 막는다(.firebaserc의 별칭을 쓴다).
#     ④ --project prod인데 바꾸는 명령(deploy·functions:secrets:set 등)이고 현재 브랜치가
#        main이 아닐 때. 읽기만 하는 명령(아래 PROD_READONLY)은 브랜치와 무관하게 통과.
#     ⑤ --project prod로 데이터를 지우는 명령(firestore:delete 등) — 언제나.
#     ⑥ functions:secrets:access — 비밀값을 화면에 내므로 언제나.
#     예외(실행기·프로젝트 없이 통과): 조각 어디든 --version·-V·--help·-h가 있는 도움말·판 확인, help·login·login:*·logout.
#     예외(프로젝트 없이 통과, 실행기는 필요): projects:list·projects:create.
#     에뮬레이터는 보안 규칙 테스트용으로 CI에서만 쓴다 — 이 컴퓨터에서는 ②에 걸린다.
#   flutterfire …(fvm dart pub global run flutterfire_cli:flutterfire 포함)
#     실행기 없이 부를 때, configure에 --project(-p)가 없을 때. 예외: --version·--help·-h·help(--help·-h는 어느 자리든).
#   fastlane …(bundle exec fastlane 포함)
#     실행기 없이 부를 때, 현재 브랜치가 main이 아닐 때.
#     예외: --version·-v·help·lanes·list, --help·-h(어느 자리든).
#   데이터 지우기 스크립트
#     조각 안에 delete·cleanup·wipe·purge·reset·truncate·drop이 든 낱말과 실서비스 표시
#     (prod 낱말, =prod, .firebaserc의 prod 프로젝트 ID)가 함께 있으면 — 언제나.
#   git commit
#     올리려는 변경의 더한 줄에 업로드 키 비밀번호가 값과 함께 적혀 있거나(키 이름 바로 뒤에
#     = 와 값), PEM 개인 키 머리줄이 한 줄을 통째로 차지하거나, 서비스 계정 키 JSON의
#     private_key 값이 들어 있을 때. 같은 명령에 git add가 있거나 commit -a·--all이면 아직
#     스테이징 안 된 변경과 새 파일(무시 목록 제외)까지 본다. 화면에는 파일 이름만 내고
#     값은 내지 않는다. 예시 파일은 값 자리를 <…>·${…}로 비워 두면 걸리지 않는다.
#
# 앞붙이기 건너뛰기: npx·npm exec·fnm exec … --·bundle exec·fvm·env·command·exec·time·
#   NAME=값, 빌드 잠금(…/build-lock.sh), 그리고 실행기(…/with-owner.sh). 실행기를 건너뛴 뒤에도 위 ②~⑥과 커밋 검사는 한다.
#
# 통과시키는 것:
#   - 명령이 실행될 폴더와 그 위 폴더 어디에도 .claude/scripts/with-owner.sh가 없는 경우
#     (하네스 밖 폴더). functions/·fastlane/ 같은 하위 폴더에서 불러도 위로 올라가 찾는다.
#   - jq가 없을 때(검사를 못 하니 통과 — main push는 no-main-push가 따로 막는다)
#
# 정밀화: 따옴표 안 글(커밋 메시지 등)과 리다이렉션을 먼저 지우고, shell separator
#   (&&, ||, ;, |, &, $( , ( , ), 백틱)로 조각을 나눠 조각마다 첫 실행 낱말만 본다.
#   `cd <폴더>` 조각은 뒤 조각의 「명령이 실행될 폴더」를 바꾼다.
#   따옴표로 감싼 --project 값은 빈 값으로 보여 ②에 걸린다(막는 쪽).
#   bash -c "…" 처럼 따옴표 안에 숨긴 명령은 못 본다(놓치는 쪽 — 규칙 문장이 같이 막는다).

set -euo pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
BASE_DIR="${HOOK_CWD:-${CLAUDE_PROJECT_DIR:-.}}"

[ -z "$COMMAND" ] && exit 0

# 실서비스 프로젝트에 대고 써도 아무것도 바꾸지 않는 firebase 하위 명령
PROD_READONLY=" projects:list apps:list apps:sdkconfig functions:list functions:log functions:secrets:get firestore:indexes firestore:databases:list firestore:databases:get firestore:locations hosting:sites:list hosting:sites:get hosting:channel:list remoteconfig:get remoteconfig:versions:list open target "
# 실서비스 데이터를 지우는 firebase 하위 명령
PROD_DELETE=" firestore:delete firestore:databases:delete database:remove database:set database:push database:update auth:import "

# 하네스 뿌리 찾기 — 폴더에서 위로 올라가며 실행기가 있는 곳
find_root() {
  local d
  d=$(cd "$1" 2>/dev/null && pwd -P) || return 1
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    [ -f "$d/.claude/scripts/with-owner.sh" ] && { printf '%s' "$d"; return 0; }
    d=$(dirname "$d")
  done
  return 1
}

current_branch() { git -C "$1" branch --show-current 2>/dev/null || true; }

prod_id() {
  [ -f "$1/.firebaserc" ] || return 0
  jq -r '.projects.prod // empty' "$1/.firebaserc" 2>/dev/null || true
}

# 따옴표 안 글 → 빈 따옴표, 리다이렉션 지우기, 조각 나누기
STRIPPED=$(printf '%s' "$COMMAND" \
  | sed -E "s/'[^']*'/''/g" \
  | sed -E 's/"([^"\\]|\\.)*"/""/g' \
  | sed -E 's/[0-9]*[<>]&[0-9-]+//g; s/[0-9]*>>?[[:space:]]*[^[:space:];&|]+//g')
NORMALIZED=$(printf '%s' "$STRIPPED" | sed -E 's/(&&|\|\||;|\||&|\$\(|\(|\)|`)/\n/g')

# --- 커밋 검사 -----------------------------------------------------------------
# 비밀값 무늬 — 이 파일 자체가 걸리지 않게, 무늬 글자가 자기 자신과 맞지 않도록 짰다.
#   ① 업로드 키 비밀번호: 키 이름 바로 뒤 = 와 값(값 첫 글자가 공백·따옴표·<·$·{·*·`·, 이면 자리표시로 봄)
#   ② PEM 개인 키 머리줄이 한 줄 전체
#   ③ 서비스 계정 키 JSON의 private_key 값
SECRET_RE='(^|[^A-Za-z0-9_])(store|key)Password=[^[:space:]"'"'"'<$\{*`,;|)]|^[[:space:]]*-----BEGIN [A-Z ]*PRIVATE KEY-----[[:space:]]*$|"private_key"[[:space:]]*:[[:space:]]*"-----BEGIN'

secret_files_in_diff() {
  # 더한 줄만 보고, 걸린 파일 이름만 낸다
  awk -v re="$SECRET_RE" '
    /^\+\+\+ / { f=$2; sub(/^b\//, "", f); next }
    /^\+/ { line=substr($0, 2); if (line ~ re) hit[f]=1 }
    END { for (k in hit) print k }'
}

check_commit() {
  local dir="$1" wide="$2" hits=""
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  hits=$(git -C "$dir" diff --cached -U0 --no-color --no-ext-diff 2>/dev/null | secret_files_in_diff || true)
  if [ "$wide" -eq 1 ]; then
    hits="$hits
$(git -C "$dir" diff -U0 --no-color --no-ext-diff 2>/dev/null | secret_files_in_diff || true)"
    local top
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")
    hits="$hits
$( (cd "$top" && git ls-files --others --exclude-standard -z 2>/dev/null \
      | xargs -0 grep -I -l -E -e "$SECRET_RE" -- 2>/dev/null) || true)"
  fi
  printf '%s\n' "$hits" | sed '/^$/d' | sort -u
}

block_msg=""
block_kind=""   # runner | rule | secret
block_cmd=""
add_seen=0

block() { block_kind="$1"; block_cmd="$2"; block_msg="$3"; }

while IFS= read -r sub; do
  tokens=()
  IFS=$' \t' read -r -a tokens <<< "$sub" || true
  n=${#tokens[@]}
  [ "$n" -eq 0 ] && continue

  if [ "${tokens[0]}" = "cd" ]; then
    cd_to="${tokens[1]:-$HOME}"
    cd_to="${cd_to/#\~/$HOME}"
    case "$cd_to" in
      /*) BASE_DIR="$cd_to" ;;
      *)  BASE_DIR="$BASE_DIR/$cd_to" ;;
    esac
    continue
  fi

  ROOT=$(find_root "$BASE_DIR") || continue

  # 접두 건너뛰기
  i=0
  explicit_token=0
  runner=0
  while [ "$i" -lt "$n" ]; do
    t="${tokens[$i]}"
    case "$t" in
      */with-owner.sh|with-owner.sh)
        runner=1; i=$((i + 1)) ;;
      */build-lock.sh|build-lock.sh)
        i=$((i + 1)) ;;
      GH_TOKEN=*)
        explicit_token=1; i=$((i + 1)) ;;
      env|command|exec|time|npx|fvm)
        i=$((i + 1)) ;;
      -u|--unset)
        i=$((i + 2)) ;;
      -*)
        # env -i, npx -y/--yes, 실행기 --check 같은 접두 옵션
        i=$((i + 1)) ;;
      npm|bundle)
        [ "${tokens[$((i + 1))]:-}" = "exec" ] && i=$((i + 2)) || break ;;
      fnm)
        # fnm exec … -- 명령
        k=$((i + 1))
        while [ "$k" -lt "$n" ] && [ "${tokens[$k]}" != "--" ]; do k=$((k + 1)); done
        [ "$k" -lt "$n" ] && i=$((k + 1)) || break ;;
      *)
        if [[ "$t" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then i=$((i + 1)); else break; fi ;;
    esac
  done
  [ "$i" -ge "$n" ] && continue

  cmd="${tokens[$i]##*/}"

  # fvm dart pub global run flutterfire_cli:flutterfire … → flutterfire로 본다
  if [ "$cmd" = "dart" ] || [ "$cmd" = "flutter" ]; then
    for ((k = i + 1; k < n; k++)); do
      if [ "${tokens[$k]}" = "flutterfire_cli:flutterfire" ]; then i=$k; cmd=flutterfire; break; fi
    done
  fi
  case "$cmd" in firebase-tools|firebase-tools@*) cmd=firebase ;; esac

  rest=()
  [ $((i + 1)) -lt "$n" ] && rest=("${tokens[@]:$((i + 1))}")
  a1="${rest[0]:-}"

  # --- 데이터 지우기 스크립트 + 실서비스 (git·firebase는 아래에서 따로 본다) ---
  if [ "$cmd" != "git" ] && [ "$cmd" != "firebase" ]; then
    pid=$(prod_id "$ROOT")
    destructive=0; prodmark=0
    for t in "${tokens[@]}"; do
      lt=$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]')
      case "$lt" in *delete*|*cleanup*|*clean-up*|*clean_up*|*wipe*|*purge*|*reset*|*truncate*|*drop*) destructive=1 ;; esac
      case "$lt" in prod|*=prod) prodmark=1 ;; esac
      if [ -n "$pid" ]; then
        case "$t" in "$pid"|*="$pid") prodmark=1 ;; esac
      fi
    done
    if [ "$destructive" -eq 1 ] && [ "$prodmark" -eq 1 ]; then
      block rule "${tokens[*]:$i}" "실서비스 데이터를 지우는 명령은 AI가 실행하지 않습니다. 정말 지워야 하면 사람이 직접, 무엇이 지워지는지 확인한 뒤 실행합니다."
      break
    fi
  fi

  case "$cmd" in
    gh)
      [ "$runner" -eq 1 ] && continue
      [ "$explicit_token" -eq 1 ] && continue
      case "$a1" in
        ""|auth|--version|version|help|--help) : ;;
        *) block runner "gh $a1" ""; break ;;
      esac ;;

    firebase)
      # 하위 명령과 프로젝트 값 찾기
      fsub=""; proj=""; has_proj=0; help=0
      k=0
      while [ "$k" -lt "${#rest[@]}" ]; do
        t="${rest[$k]}"
        case "$t" in
          --project|-P) has_proj=1; proj="${rest[$((k + 1))]:-}"; k=$((k + 2)); continue ;;
          --project=*|-P=*) has_proj=1; proj="${t#*=}" ;;
          --account|--token|-c|--config) k=$((k + 2)); continue ;;
          --version|-V|--help|-h) help=1 ;;
          -*) : ;;
          *) [ -z "$fsub" ] && fsub="$t" ;;
        esac
        k=$((k + 1))
      done
      [ "$help" -eq 1 ] && continue   # --help·--version이 든 조각은 도움말·판 확인뿐이다
      case "$fsub" in
        help|login|login:*|logout) continue ;;
        "") [ "$help" -eq 1 ] && continue ;;
      esac
      if [ "$fsub" = "use" ]; then
        block rule "firebase use" "기본 프로젝트를 정하거나 바꾸는 명령은 쓰지 않습니다. 별칭은 .firebaserc에 dev·prod로 적어 두고, 명령마다 --project dev 또는 --project prod를 붙입니다."
        break
      fi
      if [ "$fsub" = "functions:secrets:access" ]; then
        block rule "firebase functions:secrets:access" "비밀값을 화면에 내는 명령이라 막았습니다. 값이 맞는지는 콘솔이나 비밀값 장부(mvp/backend-build.md)로 확인합니다."
        break
      fi
      if [ "$runner" -eq 0 ]; then
        block runner "firebase ${fsub}" ""; break
      fi
      case "$fsub" in projects:list|projects:create) continue ;; esac
      if [ "$has_proj" -eq 0 ] || { [ "$proj" != "dev" ] && [ "$proj" != "prod" ]; }; then
        hint=""
        case "$fsub" in emulators:*) hint=" 에뮬레이터는 보안 규칙 테스트용으로 CI에서만 띄웁니다 — 이 컴퓨터에서는 쓰지 않습니다." ;; esac
        block rule "firebase ${fsub}" "firebase 명령에는 --project dev 또는 --project prod를 반드시 적습니다(.firebaserc의 별칭). 별칭 없는 명령·기본 프로젝트·프로젝트 ID 직접 쓰기는 엉뚱한 쪽에 붙기 쉬워 막습니다.${hint}"
        break
      fi
      if [ "$proj" = "prod" ]; then
        case "$PROD_DELETE" in *" $fsub "*)
          block rule "firebase ${fsub} --project prod" "실서비스 데이터를 지우거나 덮어쓰는 명령은 AI가 실행하지 않습니다. 정말 필요하면 사람이 직접 실행합니다."
          break ;;
        esac
        case "$PROD_READONLY" in *" $fsub "*) continue ;; esac
        br=$(current_branch "$ROOT")
        if [ "$br" != "main" ]; then
          block rule "firebase ${fsub} --project prod" "실서비스 Firebase를 바꾸는 명령은 main에서만, backend-release 절차(실서비스 배포 전 확인)를 거쳐 실행합니다. 지금 브랜치: ${br:-알 수 없음}. 작업 브랜치에서는 --project dev로 배포해 확인합니다."
          break
        fi
      fi ;;

    flutterfire)
      case "$a1" in ""|--version|-v|--help|-h|help) continue ;; esac
      for t in ${rest[@]+"${rest[@]}"}; do
        case "$t" in --help|-h) continue 2 ;; esac
      done
      if [ "$runner" -eq 0 ]; then
        block runner "flutterfire $a1" ""; break
      fi
      if [ "$a1" = "configure" ] || [ "$a1" = "reconfigure" ]; then
        has_proj=0
        for t in ${rest[@]+"${rest[@]}"}; do
          case "$t" in --project|-p|--project=*|-p=*) has_proj=1 ;; esac
        done
        if [ "$has_proj" -eq 0 ]; then
          block rule "flutterfire $a1" "flutterfire $a1에는 --project=<개발용 또는 실서비스 프로젝트 ID>를 반드시 적습니다. 빼면 기본 프로젝트나 고르는 화면에 기대게 되어 엉뚱한 쪽 설정 파일이 만들어질 수 있습니다."
          break
        fi
      fi ;;

    fastlane)
      case "$a1" in ""|--version|-v|--help|-h|help|lanes|list) continue ;; esac
      for t in ${rest[@]+"${rest[@]}"}; do
        case "$t" in --help|-h) continue 2 ;; esac
      done
      if [ "$runner" -eq 0 ]; then
        block runner "fastlane $a1" ""; break
      fi
      br=$(current_branch "$ROOT")
      if [ "$br" != "main" ]; then
        block rule "fastlane $a1" "플레이에 올리는 일은 main의 커밋에서, store-release 절차로만 합니다. 지금 브랜치: ${br:-알 수 없음}."
        break
      fi ;;

    git)
      # git 전역 옵션(-C 폴더, -c 값 등)을 건너뛰고 하위 명령을 찾는다
      gdir="$BASE_DIR"
      k=0; gsub=""
      while [ "$k" -lt "${#rest[@]}" ]; do
        t="${rest[$k]}"
        case "$t" in
          -C) gdir="${rest[$((k + 1))]:-$gdir}"; case "$gdir" in /*) ;; *) gdir="$BASE_DIR/$gdir" ;; esac; k=$((k + 2)); continue ;;
          -c|--git-dir|--work-tree|--namespace) k=$((k + 2)); continue ;;
          -*) k=$((k + 1)); continue ;;
          *) gsub="$t"; break ;;
        esac
      done
      case "$gsub" in
        add) add_seen=1 ;;
        commit)
          wide=$add_seen
          for t in ${rest[@]+"${rest[@]:$((k + 1))}"}; do
            case "$t" in
              --all) wide=1 ;;
              --*) : ;;
              -*a*) wide=1 ;;
            esac
          done
          files=$(check_commit "$gdir" "$wide")
          if [ -n "$files" ]; then
            block secret "git commit" "$files"
            break
          fi ;;
      esac ;;
  esac
done <<EOF
$NORMALIZED
EOF

[ -z "$block_kind" ] && exit 0

case "$block_kind" in
  runner)
    cat >&2 <<MSG
BLOCKED: 「${block_cmd}」는 실행기를 앞에 붙여 부르세요 — .claude/scripts/with-owner.sh ${block_cmd} …

이유: gh·Firebase CLI·fastlane의 로그인은 컴퓨터 전체에 남아, 실행기 없이 부르면 이
프로젝트 소유의 계정 장부(~/.config/harness/<소유>.env)가 아니라 컴퓨터에 남은 기본
로그인으로 돕니다. 소유가 다른 프로젝트가 한 컴퓨터에 있으면 PR·배포·앱 올리기가 다른
계정으로 일어납니다. 실행기는 firebase·flutterfire 명령에 장부의 계정(--account)을 붙여 줍니다.

npx·fnm·bundle을 쓰는 명령은 실행기가 맨 앞입니다:
  .claude/scripts/with-owner.sh fnm exec --using=.nvmrc -- npx firebase deploy --project dev --only firestore:rules
지금 어느 소유·계정으로 도는지는 .claude/scripts/with-owner.sh --check 로 봅니다.
MSG
    ;;
  rule)
    cat >&2 <<MSG
BLOCKED: 「${block_cmd}」
${block_msg}
MSG
    ;;
  secret)
    cat >&2 <<MSG
BLOCKED: 커밋하려는 변경에 평문 비밀값으로 보이는 줄이 있습니다(값은 표시하지 않습니다).
걸린 파일:
$(printf '%s\n' "$block_msg" | sed 's/^/  - /')

업로드 키 비밀번호(키 이름 바로 뒤 = 와 값), PEM 개인 키, 서비스 계정 키 JSON은 git에
올리지 않습니다. 진짜 값은 장부 폴더(~/.config/harness/keys/)에 두고 경로만 적습니다.
예시 파일이라면 값 자리를 <업로드 키 비밀번호>·\${STORE_PASSWORD}처럼 비워 둡니다.
이미 스테이징했다면 git restore --staged <파일> 로 빼고, 값을 지운 뒤 다시 커밋합니다.
MSG
    ;;
esac
exit 2
