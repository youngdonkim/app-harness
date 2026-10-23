#!/usr/bin/env bash
# with-owner.sh — 이 프로젝트 소유의 계정 장부를 불러 명령을 실행한다.
#
# 쓰는 법 (프로젝트 최상위 폴더에서):
#   .claude/scripts/with-owner.sh <명령...>     장부의 키를 환경변수로 넣고 명령을 실행(exec)
#   .claude/scripts/with-owner.sh --check       키 값 없이 소유·장부 자리·키 이름·gh 계정만 보여 줌
#   .claude/scripts/with-owner.sh --git-credential
#                                               git 자격 증명 도우미 전용 — git에게만 토큰을 건넴
#
# 소유 선언: <프로젝트>/.claude/owner 의 한 줄  owner=personal | company | org-<영문 짧은 이름>
# 장부:      ~/.config/harness/<소유>.env  (폴더 700, 파일 600, git 저장소 밖)
#            한 줄에 이름=값 하나. 쓰는 이름:
#              GH_LOGIN GH_TOKEN GIT_USER_NAME GIT_USER_EMAIL  — GitHub
#              FIREBASE_ACCOUNT  — Firebase CLI가 쓸 구글 계정 이메일(값이 아니라 이름표).
#                                  `firebase login`·`firebase login:add`로 이 컴퓨터에 등록해 두면,
#                                  실행기가 firebase·flutterfire 명령마다 --account <이메일>을 붙인다.
#              FIREBASE_SA_DIR   — 개발용 관리자 키 파일이 든 폴더 경로(보통 ~/.config/harness/keys).
#                                  그 안의 <개발용 프로젝트 ID>.json 하나만 쓴다(아래 「개발용 관리자 키」).
#                                  실서비스용 키 파일은 만들지 않는다.
#              PLAY_SERVICE_ACCOUNT_FILE      — 플레이 올리기용 서비스 계정 키 파일 경로(fastlane이 읽음)
#            키 파일(JSON)은 장부 폴더 안 keys/(파일 600)에 두고 장부에는 경로만 적는다.
#            업로드 키는 장부에 적지 않는다(아래 「업로드 키」).
# 프로젝트 전용 키: 장부를 읽은 뒤 프로젝트의 .env.cli(git 미추적)에서 장부가 다루지 않는 이름만
#            더 읽는다(프로젝트마다 다른 값).
#            장부가 다루는 이름이 .env.cli에 있으면 읽지 않고 옮기라고 알린다.
# 옛 프로젝트 호환: 소유 파일이나 장부 파일이 없고 프로젝트에 .env.cli가 있으면 그것을 통째로 읽는다.
# 한 번만 다른 소유로: HARNESS_OWNER=<소유> 를 앞에 두면 .claude/owner 대신 그 값을 쓴다
#   (소유 이전 중 새 소유 쪽 키를 확인할 때만 — transfer-ownership).
# 개발용 관리자 키: 시드·정리 스크립트(functions/scripts/)는 관리자 SDK로 돌아 자격 증명이 필요하다.
#   명령이 Node 스크립트(npm·npx·node·tsx·ts-node — fnm exec … -- 와 env 앞붙이기는 건너뛰고 본다)이고
#   대상이 개발용(--project dev·--project=dev·-P dev)일 때만, .firebaserc의 dev 프로젝트 ID로
#   $FIREBASE_SA_DIR/<그 ID>.json을 찾아 GOOGLE_APPLICATION_CREDENTIALS로 넘긴다.
#   키 파일의 project_id가 그 ID와 다르거나 파일이 없으면 실행하지 않는다(다른 자격 증명으로
#   조용히 도는 것을 막는다). 대상이 prod이거나 없거나 섞였으면 붙이지 않는다.
#   firebase·flutterfire 명령에는 붙이지 않는다 — 그쪽은 --account를 쓴다.
# 업로드 키: 플레이 업로드 키는 앱마다 따로 둔다 — 같은 소유로 앱을 여럿 만들어도 서로 덮지 않게.
#   android/app/build.gradle.kts(없으면 build.gradle)의 applicationId(접미사 없는 실서비스 패키지 이름)로
#     ~/.config/harness/keys/<패키지 이름>-upload.jks         업로드 키 파일
#     ~/.config/harness/keys/<패키지 이름>-upload.properties  비밀번호 파일(key.properties 모양)
#   을 정하고, 명령을 실행할 때 ANDROID_UPLOAD_KEY_PROPERTIES에 비밀번호 파일 경로를 넣는다(store-release가 씀).
#   장부나 .env.cli에 남은 옛 ANDROID_UPLOAD_KEY_PROPERTIES 줄은 읽지 않는다(--check가 옮기라고 알린다).
#
# 지키는 것: 어떤 경우에도 키 값을 화면(stdout·stderr)에 내지 않는다.
#            --git-credential만 값을 내보내는데, 출력이 터미널이면 거절한다(git이 받을 때만).
#            장부는 셸 코드로 실행(source)하지 않고 한 줄씩 읽어 이름=값만 받는다.
# 맥 기본 bash 3.2·리눅스·윈도우 Git Bash에서 돈다(연관 배열·mapfile 등을 쓰지 않는다).

set -euo pipefail

SCRIPT_DIR=$(cd -P "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd -P "$SCRIPT_DIR/../.." && pwd)
OWNER_FILE="$PROJECT_DIR/.claude/owner"
LEDGER_DIR="$HOME/.config/harness"
OLD_FILE="$PROJECT_DIR/.env.cli"

# 장부가 다룰 수 있는 키 — 부모 셸에서 물려받은 같은 이름 값은 먼저 지운다
# (다른 소유의 토큰이 환경에 남아 있으면 그 계정으로 돌기 때문이다).
# FIREBASE_TOKEN·GOOGLE_APPLICATION_CREDENTIALS는 장부에 두지 않지만, 셸에 남아 있으면
# Firebase CLI가 --account 대신 그 자격 증명을 먼저 쓸 수 있어 함께 지운다.
CLEAR_NAMES="GH_TOKEN GITHUB_TOKEN GH_LOGIN GIT_USER_NAME GIT_USER_EMAIL FIREBASE_ACCOUNT FIREBASE_SA_DIR PLAY_SERVICE_ACCOUNT_FILE ANDROID_UPLOAD_KEY_PROPERTIES FIREBASE_TOKEN GOOGLE_APPLICATION_CREDENTIALS"
# 키 파일 경로를 담는 이름 — --check가 파일이 있는지·권한이 600인지 본다(내용은 읽지 않는다).
PATH_NAMES="FIREBASE_SA_DIR PLAY_SERVICE_ACCOUNT_FILE"
# 더 쓰지 않는 이름 — 파일에 있어도 읽지 않고, --check가 옮기고 지우라고 알린다.
# (업로드 키 자리는 실행기가 패키지 이름으로 정한다 — 머리 주석 「업로드 키」)
RETIRED_NAMES="ANDROID_UPLOAD_KEY_PROPERTIES"
FIREBASERC="$PROJECT_DIR/.firebaserc"
UPLOAD_KEY_DIR="$LEDGER_DIR/keys"

say() { printf 'with-owner: %s\n' "$*" >&2; }

usage() {
  cat >&2 <<'MSG'
쓰는 법:
  .claude/scripts/with-owner.sh <명령...>       예) .claude/scripts/with-owner.sh gh pr status
                                                예) .claude/scripts/with-owner.sh fnm exec --using=.nvmrc -- npx firebase deploy --project dev --only firestore:rules
  .claude/scripts/with-owner.sh --check
  .claude/scripts/with-owner.sh --git-credential   (git 자격 증명 도우미 전용)
MSG
}

is_windows() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- 소유 읽기 -------------------------------------------------------------
OWNER=""
OWNER_PROBLEM=""
OWNER_FROM=".claude/owner"
if [ -n "${HARNESS_OWNER:-}" ] || [ -f "$OWNER_FILE" ]; then
  if [ -n "${HARNESS_OWNER:-}" ]; then
    OWNER=$(printf '%s' "$HARNESS_OWNER" | tr -d '\r[:space:]')
    OWNER_FROM="HARNESS_OWNER — 이번 한 번만"
  else
    OWNER=$(sed -n 's/^owner=//p' "$OWNER_FILE" | head -1 | tr -d '\r[:space:]')
  fi
  case "$OWNER" in
    personal|company) ;;
    org-*)
      if ! printf '%s' "${OWNER#org-}" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
        OWNER_PROBLEM="소유 값이 형식과 다릅니다 ($OWNER_FROM: org- 뒤는 영문 소문자·숫자·하이픈)"
        OWNER=""
      fi
      ;;
    "") OWNER_PROBLEM=".claude/owner에 owner= 줄이 없습니다" ;;
    *)
      OWNER_PROBLEM="소유 값이 형식과 다릅니다 ($OWNER_FROM: personal·company·org-<이름> 중 하나)"
      OWNER=""
      ;;
  esac
else
  OWNER_PROBLEM=".claude/owner 파일이 없습니다"
fi

LEDGER_FILE=""
[ -n "$OWNER" ] && LEDGER_FILE="$LEDGER_DIR/$OWNER.env"

# --- 어느 파일을 읽을지 -----------------------------------------------------
SOURCE_FILE=""
SOURCE_KIND=""   # ledger | old
if [ -n "$LEDGER_FILE" ] && [ -f "$LEDGER_FILE" ]; then
  SOURCE_FILE="$LEDGER_FILE"
  SOURCE_KIND="ledger"
elif [ -z "${HARNESS_OWNER:-}" ] && [ -f "$OLD_FILE" ]; then
  SOURCE_FILE="$OLD_FILE"
  SOURCE_KIND="old"
fi

# --- 파일을 한 줄씩 읽어 이름=값을 환경변수로 넣는다 ---------------------------
LOADED_NAMES=""
STALE_NAMES=""
RETIRED_FROM=""   # 옛 줄이 남은 파일(화면용, · 로 이음)
RETIRED_PATH=""   # 옛 줄이 가리키던 경로(경로일 뿐 키 값이 아니다)
load_file() {
  local f="$1" mode="${2:-all}" line name value
  [ "$mode" = "all" ] && for name in $CLEAR_NAMES; do unset "$name"; done
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in *=*) ;; *) continue ;; esac
    name=${line%%=*}
    value=${line#*=}
    name=$(printf '%s' "$name" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?//; s/[[:space:]]+$//')
    printf '%s' "$name" | grep -Eq '^[A-Z_][A-Z0-9_]*$' || continue
    case " $RETIRED_NAMES " in *" $name "*)
      case " · $RETIRED_FROM · " in *" · $f · "*) ;; *) RETIRED_FROM="${RETIRED_FROM:+$RETIRED_FROM · }$f" ;; esac
      RETIRED_PATH=$(printf '%s' "$value" | sed -E "s/^[\"']//; s/[\"']\$//")
      case "$RETIRED_PATH" in "~/"*) RETIRED_PATH="$HOME/${RETIRED_PATH#\~/}" ;; esac
      continue ;;
    esac
    if [ "$mode" = "project" ]; then
      case " $CLEAR_NAMES " in *" $name "*)
        case " $STALE_NAMES " in *" $name "*) ;; *) STALE_NAMES="${STALE_NAMES:+$STALE_NAMES }$name" ;; esac
        continue ;;
      esac
    fi
    # 앞뒤를 감싼 따옴표 한 쌍은 벗긴다
    case "$value" in
      \"*\") value=${value#\"}; value=${value%\"} ;;
      \'*\') value=${value#\'}; value=${value%\'} ;;
    esac
    [ -z "$value" ] && continue
    # 키 파일 경로를 ~/…로 적었으면 집 폴더로 풀어 넣는다(명령은 ~를 스스로 풀지 않는다)
    case "$value" in "~/"*) value="$HOME/${value#\~/}" ;; esac
    export "$name=$value"
    case " $LOADED_NAMES " in *" $name "*) ;; *) LOADED_NAMES="${LOADED_NAMES:+$LOADED_NAMES }$name" ;; esac
  done < "$f"
}

load_all() {
  load_file "$SOURCE_FILE"
  if [ "$SOURCE_KIND" = "ledger" ] && [ -f "$OLD_FILE" ]; then
    load_file "$OLD_FILE" project
  fi
}

# .firebaserc에서 별칭의 프로젝트 ID를 읽는다(jq가 있으면 jq, 없으면 sed).
alias_id() {
  local a="$1"
  [ -f "$FIREBASERC" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg a "$a" '.projects[$a] // empty' "$FIREBASERC" 2>/dev/null || true
  else
    sed -n "s/.*\"$a\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$FIREBASERC" | head -1
  fi
}

# 키 파일에서 project_id 값만 읽는다. 다른 줄(개인 키 등)은 내지 않는다.
key_project_id() {
  sed -n 's/.*"project_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -1
}

# 개발용 관리자 키 파일 자리와 상태를 정한다 — DEV_KEY_FILE·DEV_KEY_PROBLEM
dev_key_lookup() {
  DEV_KEY_FILE=""
  DEV_KEY_PROBLEM=""
  local dev_id prod_id kid
  dev_id=$(alias_id dev)
  prod_id=$(alias_id prod)
  if [ -z "$dev_id" ]; then
    DEV_KEY_PROBLEM=".firebaserc에 dev 별칭이 없습니다"; return 0
  fi
  if [ -n "$prod_id" ] && [ "$dev_id" = "$prod_id" ]; then
    DEV_KEY_PROBLEM=".firebaserc의 dev와 prod가 같은 프로젝트입니다"; return 0
  fi
  if [ -z "${FIREBASE_SA_DIR:-}" ]; then
    DEV_KEY_PROBLEM="장부에 FIREBASE_SA_DIR가 없습니다"; return 0
  fi
  DEV_KEY_FILE="$FIREBASE_SA_DIR/$dev_id.json"
  if [ ! -f "$DEV_KEY_FILE" ]; then
    DEV_KEY_PROBLEM="키 파일이 없습니다 ($DEV_KEY_FILE)"; return 0
  fi
  kid=$(key_project_id "$DEV_KEY_FILE")
  if [ "$kid" != "$dev_id" ]; then
    DEV_KEY_PROBLEM="키 파일의 프로젝트가 개발용($dev_id)이 아닙니다 (${kid:-읽지 못함})"; return 0
  fi
}

# 업로드 키 자리를 정한다 — UPLOAD_PKG·UPLOAD_PROPS·UPLOAD_JKS·UPLOAD_PROBLEM
# applicationId 읽는 식은 templates/firebase의 check_firebase_config.dart와 같다:
#   applicationId\s*=?\s*["']([^"']+)["'] 의 첫 일치(applicationIdSuffix는 걸리지 않는다).
#   build.gradle.kts에 없으면 build.gradle을 본다.
upload_key_lookup() {
  UPLOAD_PKG=""
  UPLOAD_PROPS=""
  UPLOAD_JKS=""
  UPLOAD_PROBLEM=""
  local gname gfile found=0 pkg
  for gname in build.gradle.kts build.gradle; do
    gfile="$PROJECT_DIR/android/app/$gname"
    [ -f "$gfile" ] || continue
    found=1
    # 못 찾으면 grep이 1로 끝난다 — pipefail에 걸려 실행기 전체가 멈추지 않게 || true로 받는다
    pkg=$( { grep -oE "applicationId[[:space:]]*=?[[:space:]]*[\"'][^\"']+[\"']" "$gfile" 2>/dev/null || true; } | head -1 \
      | sed -E "s/^applicationId[[:space:]]*=?[[:space:]]*[\"']([^\"']+)[\"']\$/\1/")
    if [ -n "$pkg" ]; then UPLOAD_PKG="$pkg"; break; fi
  done
  if [ -z "$UPLOAD_PKG" ]; then
    if [ "$found" -eq 0 ]; then
      UPLOAD_PROBLEM="android 폴더가 아직 없음"
    else
      UPLOAD_PROBLEM="android/app/build.gradle(.kts)에서 applicationId를 찾지 못함"
    fi
    return 0
  fi
  # 패키지 이름 꼴(영문·숫자·_ 마디를 .로 이은 것)이 아니면 경로로 쓰지 않는다
  if ! printf '%s' "$UPLOAD_PKG" | grep -Eq '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$'; then
    UPLOAD_PROBLEM="applicationId가 패키지 이름 꼴이 아님 ($UPLOAD_PKG)"
    UPLOAD_PKG=""
    return 0
  fi
  UPLOAD_PROPS="$UPLOAD_KEY_DIR/$UPLOAD_PKG-upload.properties"
  UPLOAD_JKS="$UPLOAD_KEY_DIR/$UPLOAD_PKG-upload.jks"
}

# 옛 업로드 키 줄을 옮기라는 안내 한 줄(upload_key_lookup 뒤에 부른다)
retired_upload_message() {
  local dest="${UPLOAD_PROPS:-$UPLOAD_KEY_DIR/<패키지 이름>-upload.properties}"
  local jks="${UPLOAD_JKS:-$UPLOAD_KEY_DIR/<패키지 이름>-upload.jks}"
  printf '%s' "$RETIRED_FROM 의 ANDROID_UPLOAD_KEY_PROPERTIES 줄은 더 쓰지 않습니다(업로드 키는 앱마다 따로 둡니다) — 그 줄이 가리키는 파일${RETIRED_PATH:+($RETIRED_PATH)}을 $dest 로, 업로드 키 파일(.jks)을 $jks 로 옮기고 storeFile을 새 .jks 경로로 고친 뒤 그 줄을 지우세요"
}

perm_warning() {
  local f="$1"
  is_windows && return 0
  if [ -n "$(find "$f" \( -perm -040 -o -perm -004 \) -print 2>/dev/null)" ]; then
    say "이 파일을 다른 사용자도 읽을 수 있습니다 — chmod 600 \"$f\" 로 막으세요"
  fi
}

# --- --git-credential ------------------------------------------------------
if [ "${1:-}" = "--git-credential" ]; then
  # git이 보내는 질문(host=… 등)을 끝까지 받아 둔다. 터미널에서 직접 부르면 값을 내지 않는다.
  if [ -t 0 ] || [ -t 1 ]; then
    say "--git-credential은 git 자격 증명 도우미 전용입니다 — 화면에는 값을 내지 않습니다"
    exit 64
  fi
  host=""
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    [ -z "$line" ] && break
    case "$line" in host=*) host=${line#host=} ;; esac
  done
  case "$host" in ""|github.com) ;; *) exit 0 ;; esac
  [ -n "$SOURCE_FILE" ] || exit 0
  load_file "$SOURCE_FILE"
  [ -n "${GH_TOKEN:-}" ] || exit 0
  printf 'username=x-access-token\npassword=%s\n' "$GH_TOKEN"
  exit 0
fi

# --- --check ---------------------------------------------------------------
if [ "${1:-}" = "--check" ]; then
  problems=0
  echo "프로젝트: $PROJECT_DIR"
  if [ -n "$OWNER" ]; then
    echo "소유: $OWNER ($OWNER_FROM)"
  else
    echo "소유: 없음 — $OWNER_PROBLEM"
    problems=1
  fi
  if [ -n "$LEDGER_FILE" ]; then
    if [ -f "$LEDGER_FILE" ]; then
      echo "장부 파일: $LEDGER_FILE (있음)"
    else
      echo "장부 파일: $LEDGER_FILE (없음)"
      problems=1
    fi
  fi
  case "$SOURCE_KIND" in
    ledger)
      perm_warning "$SOURCE_FILE"
      ;;
    old)
      echo "읽은 파일: $OLD_FILE (옛 방식) — 장부로 옮기세요(project-init 동기화)"
      problems=1
      ;;
    *)
      echo "읽은 파일: 없음 — 장부 파일도 옛 .env.cli도 없습니다"
      exit 1
      ;;
  esac
  load_all
  [ "$SOURCE_KIND" = "ledger" ] && [ -f "$OLD_FILE" ] && echo "프로젝트 전용 키 파일: $OLD_FILE (있음)"
  if [ -n "$STALE_NAMES" ]; then
    echo "주의: .env.cli에 장부가 다루는 키가 남아 있어 읽지 않았습니다($STALE_NAMES) — project-init 동기화로 장부로 옮기세요"
    problems=1
  fi
  echo "있는 키: ${LOADED_NAMES:-(없음)}"
  upload_key_lookup
  if [ -n "$RETIRED_FROM" ]; then
    echo "주의: $(retired_upload_message)"
    problems=1
  fi
  # Firebase 계정 이메일은 비밀값이 아니라 이름표라 그대로 보여 준다.
  if [ -n "${FIREBASE_ACCOUNT:-}" ]; then
    echo "Firebase 계정: $FIREBASE_ACCOUNT (firebase·flutterfire 명령에 --account로 붙음)"
  else
    echo "Firebase 계정: FIREBASE_ACCOUNT가 없습니다 — firebase·flutterfire 명령은 실행기가 거절합니다(4단계 준비가 채웁니다)"
  fi
  # 키 파일 경로는 파일이 있는지·남이 읽을 수 있는지만 본다. 내용은 열지 않는다.
  for name in $PATH_NAMES; do
    eval "path=\${$name:-}"
    [ -z "$path" ] && continue
    if [ ! -e "$path" ]; then
      echo "$name: 가리키는 자리에 파일이 없습니다 ($path)"
      problems=1
    else
      echo "$name: 있음 ($path)"
      perm_warning "$path"
    fi
  done
  # 개발용 관리자 키 — 파일이 있는지, 개발용 프로젝트의 것인지만 본다.
  if [ -n "${FIREBASE_SA_DIR:-}" ] || [ -f "$FIREBASERC" ]; then
    if [ ! -f "$FIREBASERC" ]; then
      echo "개발용 관리자 키: .firebaserc가 아직 없어 확인하지 않았습니다(4단계 준비가 만듭니다)"
    else
      dev_key_lookup
      if [ -n "$DEV_KEY_PROBLEM" ]; then
        echo "개발용 관리자 키: 쓸 수 없음 — $DEV_KEY_PROBLEM"
        [ -n "${FIREBASE_SA_DIR:-}" ] && problems=1
      else
        echo "개발용 관리자 키: 있음 ($DEV_KEY_FILE — 개발용 대상 Node 스크립트에만 붙음)"
        perm_warning "$DEV_KEY_FILE"
      fi
    fi
  fi
  # 업로드 키 — 앱마다 따로. 아직 없거나 패키지 이름을 못 읽는 것은 정상 단계라 실패로 치지 않는다.
  if [ -n "$UPLOAD_PROBLEM" ]; then
    echo "업로드 키: 패키지 이름을 못 읽음($UPLOAD_PROBLEM)"
  elif [ -f "$UPLOAD_PROPS" ]; then
    echo "업로드 키: 있음($UPLOAD_PROPS)"
    perm_warning "$UPLOAD_PROPS"
    if [ -f "$UPLOAD_JKS" ]; then
      perm_warning "$UPLOAD_JKS"
    else
      echo "업로드 키: 비밀번호 파일은 있는데 업로드 키 파일이 없습니다 ($UPLOAD_JKS)"
      problems=1
    fi
  else
    echo "업로드 키: 아직 없음($UPLOAD_PROPS — 3단계 배포 전에 만듭니다)"
  fi
  if [ -n "${GH_TOKEN:-}" ]; then
    if ! command -v gh >/dev/null 2>&1; then
      echo "gh 계정: 확인 못 함 — gh가 설치돼 있지 않습니다"
      problems=1
    elif login=$(gh api user --jq .login 2>/dev/null); then
      if [ -n "${GH_LOGIN:-}" ] && [ "$login" != "$GH_LOGIN" ]; then
        echo "gh 계정: $login — 장부의 GH_LOGIN($GH_LOGIN)과 다릅니다"
        problems=1
      else
        echo "gh 계정: $login"
      fi
    else
      echo "gh 계정: 확인 실패 — 토큰이 만료·폐기됐거나 네트워크 문제입니다"
      problems=1
    fi
  else
    echo "gh 계정: GH_TOKEN이 없어 확인하지 않았습니다"
  fi
  exit "$problems"
fi

# --- 명령 실행 --------------------------------------------------------------
if [ "$#" -eq 0 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 64
fi

case "$SOURCE_KIND" in
  ledger)
    perm_warning "$SOURCE_FILE"
    ;;
  old)
    say "옛 .env.cli를 읽었습니다 — 장부로 옮기세요(project-init 동기화)"
    ;;
  *)
    if [ -n "$LEDGER_FILE" ]; then
      say "장부 파일이 없습니다: $LEDGER_FILE — github-connect(GitHub)나 4단계 준비가 키를 채웁니다"
    else
      say "$OWNER_PROBLEM — project-init이 소유를 정해 이 파일을 씁니다"
    fi
    exit 66
    ;;
esac

load_all
[ -n "$STALE_NAMES" ] && say ".env.cli의 $STALE_NAMES 는 장부가 다루는 키라 읽지 않았습니다 — project-init 동기화로 옮기세요"

# --- 업로드 키 자리 넣기 -------------------------------------------------------
# 패키지 이름으로 정한 비밀번호 파일 경로를 넣는다(파일이 있는지는 store-release의 test -f가 본다).
upload_key_lookup
if [ -n "$UPLOAD_PROPS" ]; then
  export ANDROID_UPLOAD_KEY_PROPERTIES="$UPLOAD_PROPS"
fi
[ -n "$RETIRED_FROM" ] && say "$(retired_upload_message)"

# --- firebase·flutterfire 명령에 --account 붙이기 -----------------------------
# Firebase CLI 로그인은 컴퓨터 전체에 여러 계정을 등록해 두고 명령마다 고르는 방식이다
# (공식 README: login:add로 계정을 더하고, 아무 명령에나 --account를 붙여 고른다).
# 기본 계정(login:use)에 기대면 소유가 다른 프로젝트가 한 컴퓨터에 있을 때 다른 계정으로
# 배포되므로, 실행기가 장부의 FIREBASE_ACCOUNT를 명령마다 붙인다.
# 명령이 fnm exec … -- npx firebase …처럼 감싸져 있어도 firebase 낱말 바로 뒤에 끼운다.
# flutterfire는 옵션이 하위 명령(configure 등) 뒤에 와야 해서 하위 명령 바로 뒤에 끼운다.
fb_at=-1
fb_kind=""
args=("$@")
j=0
while [ "$j" -lt "${#args[@]}" ]; do
  base="${args[$j]##*/}"
  case "$base" in
    firebase|firebase-tools|firebase-tools@*) fb_at=$j; fb_kind=firebase; break ;;
    flutterfire|flutterfire_cli:flutterfire) fb_at=$j; fb_kind=flutterfire; break ;;
  esac
  j=$((j + 1))
done

if [ "$fb_at" -ge 0 ]; then
  sub="${args[$((fb_at + 1))]:-}"
  need=1
  case "$sub" in
    ""|-V|--version|-v|-h|--help|help|login|login:*|logout) need=0 ;;
  esac
  [ "$fb_kind" = "flutterfire" ] && case "$sub" in -*) need=0 ;; esac
  for a in "${args[@]}"; do
    case "$a" in --account|--account=*|-e) need=0 ;; esac
  done
  if [ "$need" -eq 1 ]; then
    if [ -z "${FIREBASE_ACCOUNT:-}" ]; then
      say "장부에 FIREBASE_ACCOUNT(Firebase CLI가 쓸 구글 계정 이메일)가 없어 실행하지 않았습니다 — 4단계 준비가 이 값을 채웁니다"
      exit 66
    fi
    # firebase는 firebase 낱말 바로 뒤, flutterfire는 하위 명령 바로 뒤
    cut=$((fb_at + 1))
    [ "$fb_kind" = "flutterfire" ] && cut=$((fb_at + 2))
    set -- "${args[@]:0:$cut}" --account "$FIREBASE_ACCOUNT" "${args[@]:$cut}"
  fi
fi

# --- 개발용 대상 Node 스크립트에 관리자 키 붙이기 ---------------------------------
# firebase·flutterfire 명령이 아니고, 감싼 명령을 벗긴 실제 프로그램이 Node 스크립트일 때만 본다.
if [ "$fb_at" -lt 0 ]; then
  args=("$@")
  p=0
  n=${#args[@]}
  # fnm exec … -- 와 env·NAME=값 앞붙이기를 건너뛴다
  while [ "$p" -lt "$n" ]; do
    base="${args[$p]##*/}"
    case "$base" in
      fnm)
        q=$((p + 1))
        while [ "$q" -lt "$n" ] && [ "${args[$q]}" != "--" ]; do q=$((q + 1)); done
        p=$((q + 1)) ;;
      env) p=$((p + 1)) ;;
      *=*) case "$base" in -*) break ;; esac; p=$((p + 1)) ;;
      *) break ;;
    esac
  done
  prog="${args[$p]:-}"
  prog="${prog##*/}"
  case "$prog" in
    npm|npx|node|tsx|ts-node)
      targets=""
      k=0
      while [ "$k" -lt "$n" ]; do
        a="${args[$k]}"
        case "$a" in
          --project|-P) targets="$targets ${args[$((k + 1))]:-_none_}"; k=$((k + 1)) ;;
          --project=*) targets="$targets ${a#--project=}" ;;
        esac
        k=$((k + 1))
      done
      only_dev=0
      if [ -n "$targets" ]; then
        only_dev=1
        for t in $targets; do [ "$t" = "dev" ] || only_dev=0; done
      fi
      if [ "$only_dev" -eq 1 ]; then
        dev_key_lookup
        if [ -n "$DEV_KEY_PROBLEM" ]; then
          say "개발용 대상(--project dev) 스크립트인데 개발용 관리자 키를 쓸 수 없어 실행하지 않았습니다 — $DEV_KEY_PROBLEM (4단계 준비의 「개발용 관리자 키」 절)"
          exit 66
        fi
        export GOOGLE_APPLICATION_CREDENTIALS="$DEV_KEY_FILE"
      fi
      ;;
  esac
fi

exec "$@"
