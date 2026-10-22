#!/bin/bash
# no-main-push.sh — PreToolUse(Bash) guard
#
# main 브랜치에 직접 push 차단. PR 워크플로 우회 방지.
#
# 차단 대상:
#   - git push to main (PR 워크플로 우회 차단)
#       - 명령어에 main이 명시된 경우 (예: git push origin main)
#       - refspec으로 main을 겨냥하는 경우 (예: git push origin HEAD:main,
#         git push origin feature:refs/heads/main, git push origin --delete main)
#       - refspec 미지정 push의 gap 봉쇄: git push / git push origin 처럼
#         refspec을 아예 안 쓴 경우(현재 브랜치가 그대로 올라감), 또는
#         refspec이 정확히 HEAD 하나뿐인 경우(현재 브랜치를 명시한 것과 동일)에
#         한해 현재 브랜치가 main이면 차단. git push origin feat/x 처럼
#         다른 브랜치를 명시한 refspec이 있으면 이 폴백은 건너뜀
#         (main을 겨냥한 refspec은 위 is_main_target이 이미 잡음)
#   - git 전역 옵션으로 검사를 우회하는 경우
#       (예: git -C . push, git -c a=b push, git --git-dir=.git push,
#       git --work-tree=. push, git --no-pager push) — push 서브커맨드를
#       찾기 전에 이런 전역 옵션(과 그 값)을 건너뛰고 판정
#       - 이때 -C / --git-dir / --work-tree 가 지목한 폴더 경로를 기억해 두고,
#         refspec 미지정 push의 폴백 검사에서 세션 cwd 대신 그 폴더의
#         현재 브랜치를 본다 (다른 폴더를 겨냥한 push로 우회하던 구멍 봉쇄)
#       - 폴백 검사의 기준 폴더는 stdin JSON의 cwd (명령이 실제로 실행될
#         세션 폴더). CLAUDE_PROJECT_DIR은 세션 시작 폴더에 고정된 값이라
#         cwd가 없을 때의 폴백으로만 쓴다
#   - force push 전면 차단 (대상 브랜치 무관)
#       -f, --force, --force-with-lease(=값 포함), --force-if-includes,
#       또는 +로 시작하는 강제 refspec (예: git push origin +feature:main)
#   - 환경변수 접두·실행기 접두로 검사를 우회하는 경우
#       (예: env GH_TOKEN=... git push origin main, env -u X git push,
#       FOO=1 git push origin main, .claude/scripts/with-owner.sh git push origin main)
#       — 명령 조각이 env·NAME=value·with-owner.sh로 시작하면 그 뒤에서
#       첫 git 토큰을 찾아 거기서부터 판정한다.
#       (값에 공백이 든 접두 "$(sed ... )"도 있어서 인자를 하나씩 건너뛰지
#       않고 첫 git 토큰을 찾는다 — 오탐은 차단 쪽이라 안전하다)
#
# 허용 예외 — 부트스트랩 첫 push:
#   main을 겨냥한 push라도 강제 push가 아니고, 그 원격에 main 브랜치가 아직
#   없으면(git ls-remote --exit-code --heads <원격> refs/heads/main 이 "없음"
#   = 종료 코드 2로 끝나면) 허용한다 — 하네스 첫 적용의 첫 push(github-connect ⑨).
#   원격에 main이 있으면(0) 「main 직접 push 금지」로 막고, 조회 자체가
#   실패하면(그 밖 — 저장소를 못 찾음·인증·네트워크) 「원격 main 조회 실패」로
#   이유를 갈라 막는다. 비공개 저장소는 키가 틀려도 「없음」이 아니라
#   「저장소를 못 찾음」으로 실패하므로, 이때 main push 금지로 알리면 엉뚱하다.
#   main push 조각이 한 명령에 둘 이상이면 예외 없이 차단한다.
#
# 정밀화: shell separator(&&, ||, ;, |, &)로 sub-command 분리 후
# 각 sub-command의 첫 토큰이 git일 때만 검사.
# → commit message 등 quote 안 텍스트의 우연한 매칭 회피.
#
# 이 저장소는 앱이라 main에 머지해도 저절로 어디에 배포되지는 않는다. 실서비스로
# 나가는 것(플레이 트랙 올리기·실서비스 Firebase 배포)은 언제나 main의 커밋에서
# store-release·backend-release 절차로 만든다. 그래서 main은 「PR로 검토를 거친
# 커밋만 있는 자리」여야 하고, main 직접 push 차단이 그 보장의 본질이다.
# 실서비스 Firebase·fastlane 명령 자체를 막는 일은 owner-runner-guard.sh가 맡는다.
#
# 자세히: docs/git-workflow.md

set -euo pipefail

INPUT=$(cat)

# jq가 없으면 아래 jq 줄이 set -e로 비정상 종료(127)한다. Claude Code 훅은
# 종료 코드 2만 막고 그 밖의 실패는 통과시키므로, 그대로 두면 main push를
# 못 막는다. 그래서 jq가 없을 때는 입력 원문에 git과 push가 함께 있으면
# 안전한 쪽으로 막고(exit 2), 그 밖의 명령은 통과시킨다.
if ! command -v jq >/dev/null 2>&1; then
  # 외부 명령(grep 등) 없이 bash 자체 비교로 본다 — 도구가 하나 더 빠져도 막는 쪽으로 남게.
  if [[ "$INPUT" == *git* && "$INPUT" == *push* ]]; then
    echo "jq가 없어 main push 차단 검사를 할 수 없어 막았습니다 — github-connect의 jq 단계(③)를 다시 돌리면 jq를 자동으로 깝니다." >&2
    exit 2
  fi
  exit 0
fi
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")

# Bash 명령이 실제로 실행될 폴더 = stdin의 cwd (세션이 실제로 앉은 폴더).
# CLAUDE_PROJECT_DIR은 세션 시작 폴더에 고정된 값이라 폴백으로만 쓴다 —
# 세션이 다른 폴더로 옮겨 앉은 뒤에도 CLAUDE_PROJECT_DIR을 쓰면 refspec
# 미지정 push 폴백 검사가 세션 시작 폴더만 봐서 오판할 수 있다.
BASE_DIR="${HOOK_CWD:-${CLAUDE_PROJECT_DIR:-.}}"

[ -z "$COMMAND" ] && exit 0

# 리다이렉션(2>&1, >/dev/null, 2>>로그 등)을 먼저 지운다 — 남겨 두면 `>&1`의 `&`가
# 구분자로 잘리고, `2>` 같은 조각이 원격·refspec 토큰으로 읽혀 엉뚱하게 판정한다.
# (실측 2026-10-19: `git push -q 2>&1 | tail -1`에서 `2>`를 원격으로 읽어 「원격 main 조회 실패」로 막음)
STRIPPED=$(printf '%s' "$COMMAND" | sed -E 's/[0-9]*[<>]&[0-9-]+//g; s/[0-9]*>>?[[:space:]]*[^[:space:];&|]+//g')

# shell separator로 sub-command 분리
NORMALIZED=$(printf '%s' "$STRIPPED" | sed -E 's/(&&|\|\||;|\| |&[^&])/\n/g')

# main 겨냥 여부 판정: 정확히 main / *:main / refs/heads/main / *:refs/heads/main
is_main_target() {
  case "$1" in
    main|*:main|refs/heads/main|*:refs/heads/main) return 0 ;;
    *) return 1 ;;
  esac
}

# force push 관련 토큰 여부 판정
is_force_token() {
  case "$1" in
    -f|--force|--force-if-includes|--force-with-lease|--force-with-lease=*) return 0 ;;
    +*) return 0 ;; # 강제 refspec (예: +feature:main)
    *) return 1 ;;
  esac
}

block_reason=""
main_push_count=0
main_push_dir=""
main_push_remote=""
while IFS= read -r sub; do
  # leading/trailing 공백 제거
  sub_trimmed=$(printf '%s' "$sub" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  [ -z "$sub_trimmed" ] && continue

  # 공백 기준 토큰화 (glob 확장 방지 위해 read -a 사용)
  tokens=()
  IFS=$' \t' read -r -a tokens <<< "$sub_trimmed"
  n=${#tokens[@]}

  # `cd <폴더>` 조각은 뒤 조각이 실행될 폴더를 바꾼다 — refspec 미지정 push의
  # 폴백 검사가 세션 폴더가 아니라 cd한 폴더의 브랜치를 보게 기억해 둔다.
  # (실측 2026-10-19: `cd 다른저장소 && git push`를 세션 폴더(main)의 push로 오판)
  if [ "${tokens[0]:-}" = "cd" ]; then
    cd_to="${tokens[1]:-$HOME}"
    cd_to="${cd_to/#\~/$HOME}"
    case "$cd_to" in
      /*) BASE_DIR="$cd_to" ;;
      *)  BASE_DIR="$BASE_DIR/$cd_to" ;;
    esac
    continue
  fi

  # git 토큰 위치 찾기. 첫 토큰이 git이면 0.
  # env·NAME=value·with-owner.sh 접두로 시작하면 그 뒤의 첫 git 토큰 (우회 봉쇄).
  first="${tokens[0]:-}"
  git_idx=-1
  if [ "$first" = "git" ]; then
    git_idx=0
  elif [ "$first" = "env" ] || [[ "$first" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] \
       || [[ "$first" == *with-owner.sh* ]]; then
    k=1
    while [ "$k" -lt "$n" ]; do
      if [ "${tokens[$k]}" = "git" ]; then
        git_idx=$k
        break
      fi
      k=$((k + 1))
    done
  fi
  [ "$git_idx" -lt 0 ] && continue

  # git 전역 옵션(과 그 값)을 건너뛰고 서브커맨드 탐색
  # -C / --git-dir / --work-tree 의 값은 버리지 않고 target_dir에 기억해 둔다.
  # (뒤의 refspec 미지정 폴백에서 이 폴더의 브랜치를 봐야 하므로)
  i=$((git_idx + 1))
  subcmd=""
  target_dir=""
  while [ "$i" -lt "$n" ]; do
    t="${tokens[$i]}"
    case "$t" in
      -C)
        target_dir="${tokens[$((i + 1))]:-}"
        i=$((i + 2))
        ;;
      -c)
        i=$((i + 2))
        ;;
      --git-dir|--work-tree)
        target_dir="${tokens[$((i + 1))]:-}"
        i=$((i + 2))
        ;;
      --namespace|--exec-path)
        i=$((i + 2))
        ;;
      --git-dir=*|--work-tree=*)
        target_dir="${t#*=}"
        i=$((i + 1))
        ;;
      --namespace=*|--exec-path=*|-c*)
        i=$((i + 1))
        ;;
      -*)
        # 값 없는 전역 옵션 (--no-pager, --paginate, -p, --bare 등)
        i=$((i + 1))
        ;;
      *)
        subcmd="$t"
        break
        ;;
    esac
  done

  [ "$subcmd" != "push" ] && continue

  # push 이후의 인자들 검사
  # non-dash 토큰 중 첫 번째는 remote, 두 번째부터는 refspec으로 센다.
  j=$((i + 1))
  non_dash_count=0
  refspec_count=0
  last_refspec=""
  push_remote=""
  main_hit=0
  while [ "$j" -lt "$n" ]; do
    arg="${tokens[$j]}"
    if is_force_token "$arg"; then
      block_reason="force-push"
      break 2
    fi
    # main 겨냥은 기록만 하고 끝까지 훑는다 — 뒤에 붙은 force 토큰도 잡기 위해
    if is_main_target "$arg"; then
      main_hit=1
    fi
    case "$arg" in
      -*) : ;; # 옵션 토큰은 remote/refspec 계산에서 제외
      *)
        non_dash_count=$((non_dash_count + 1))
        if [ "$non_dash_count" -eq 1 ]; then
          push_remote="$arg"
        else
          refspec_count=$((refspec_count + 1))
          last_refspec="$arg"
        fi
        ;;
    esac
    j=$((j + 1))
  done

  # 검사 대상 폴더: -C / --git-dir / --work-tree 로 지목한 폴더가 있으면 그쪽,
  # 없으면 명령이 실행될 폴더(BASE_DIR = stdin cwd). 상대 경로도 BASE_DIR 기준으로
  # 푼다 — Bash 도구가 세션 cwd에서 명령을 돌리므로 상대 -C 경로는 거기서 풀린다.
  check_dir="$BASE_DIR"
  if [ -n "$target_dir" ]; then
    case "$target_dir" in
      /*) check_dir="$target_dir" ;;
      *)  check_dir="$BASE_DIR/$target_dir" ;;
    esac
  fi

  if [ "$main_hit" -eq 1 ]; then
    main_push_count=$((main_push_count + 1))
    main_push_dir="$check_dir"
    main_push_remote="${push_remote:-origin}"
    continue
  fi

  # refspec 미지정(0개) 또는 refspec이 정확히 HEAD 하나뿐인 경우에만
  # 현재 브랜치가 main인지 확인해서 차단 (gap 봉쇄). 다른 브랜치를
  # 명시한 refspec이 있으면 이 폴백은 건너뜀.
  if [ "$refspec_count" -eq 0 ] || { [ "$refspec_count" -eq 1 ] && [ "$last_refspec" = "HEAD" ]; }; then
    current_branch=$(git -C "$check_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ "$current_branch" = "main" ]; then
      main_push_count=$((main_push_count + 1))
      main_push_dir="$check_dir"
      main_push_remote="${push_remote:-origin}"
    fi
  fi
done <<EOF
$NORMALIZED
EOF

# main push 판정 — force가 아니고 조각이 하나뿐이면 부트스트랩 예외를 본다.
# 원격에 main이 없을 때(ls-remote --exit-code가 2)만 허용. 있으면(0)은 main push 금지,
# 조회 실패(그 밖)는 이유를 갈라 막는다.
if [ -z "$block_reason" ] && [ "$main_push_count" -gt 0 ]; then
  block_reason="main-push"
  if [ "$main_push_count" -eq 1 ]; then
    rc=0
    GIT_TERMINAL_PROMPT=0 git -C "$main_push_dir" ls-remote --exit-code --heads "$main_push_remote" refs/heads/main >/dev/null 2>&1 || rc=$?
    if [ "$rc" -eq 2 ]; then
      echo "no-main-push: 원격 main이 없어 첫 push를 허용 (부트스트랩 — 원격 ${main_push_remote})" >&2
      exit 0
    elif [ "$rc" -ne 0 ]; then
      block_reason="lookup-failed"
    fi
  fi
fi

if [ "$block_reason" = "force-push" ]; then
  cat >&2 <<'MSG'
BLOCKED: force push 금지 (대상 브랜치 무관).

이유: force push는 원격 기록을 덮어써서 다른 사람의 커밋이 흔적도 없이
사라질 수 있음. 이 저장소에서 실제로 그런 사고가 있었음.
필요하면 새 커밋을 쌓거나, 정말 필요한 경우 사람이 직접 판단해서 처리할 것.

자세히: docs/git-workflow.md
MSG
  exit 2
fi

if [ "$block_reason" = "lookup-failed" ]; then
  cat >&2 <<MSG
BLOCKED: 원격 main 조회 실패 — 원격(${main_push_remote})의 저장소를 찾지 못했습니다.

main 직접 push라서 막은 것이 아닙니다. 첫 push(부트스트랩)인지 확인하려고
원격 main을 조회했는데 조회 자체가 실패했습니다. 비공개 저장소는 키가
틀리거나 없을 때 「저장소 없음」으로 보입니다 — 키 문제일 수 있습니다.

확인할 것:
  1) .claude/scripts/with-owner.sh --check  — 소유·장부·gh 계정이 맞는지
  2) github-connect ⑦ — 이 저장소의 git 자격 증명 도우미가 걸렸는지
     (git credential fill 에 username=x-access-token 이 나와야 합니다)
  3) 원격 주소(git remote get-url ${main_push_remote})와 네트워크

자세히: docs/git-workflow.md
MSG
  exit 2
fi

if [ "$block_reason" = "main-push" ]; then
  cat >&2 <<'MSG'
BLOCKED: main branch 직접 push 금지.

이유: 모든 변경은 PR 워크플로를 거쳐야 함 (CI 통과 관문).
feature branch → push -u → PR → CI → merge 흐름 사용.

자세히: docs/git-workflow.md
MSG
  exit 2
fi

exit 0
