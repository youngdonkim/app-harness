#!/usr/bin/env bash
# stage-tag.sh — idea-to-mvp 단계가 끝날 때(와 사람이 판을 고르기 직전) 지금 모습에 이름표(git 태그)를 붙여 GitHub에 올린다.
#
# 작업 중 자동 임시 저장(wip 커밋)은 이름으로 어느 단계인지 알 수 없고, main에는 한 커밋으로 묶여(squash merge)
# 들어가 그 사이 기록이 안 보인다. 태그는 squash merge 뒤에도 가리키는 커밋을 지켜 주니, 나중에
# 「고르기 전 모습으로 돌아가 보기」의 손잡이가 된다. 자리와 이름은 idea-to-mvp SKILL.md 「단계 이름표」 표가 정본이다.
#
# 쓰는 법 (프로젝트 최상위 폴더에서):
#   .claude/scripts/stage-tag.sh <이름> "<한 줄 설명>"
#   예: .claude/scripts/stage-tag.sh 2-3-drafts "2-3 세 판(대담·혁신·파격)을 고르기 직전"
#
# 하는 일:
#   ① 작업 브랜치인지 본다 — main이거나 브랜치가 없는 상태(detached)면 아무것도 하지 않고 1로 끝난다.
#   ② 바뀐 파일이 있으면 전부 커밋한다(「chore: 단계 이름표 — <이름> (<설명>)」).
#      바뀐 게 없으면 빈 커밋을 만들지 않고 지금 커밋(HEAD)에 붙인다 — 주석 태그(git tag -a)가 이름과 설명을
#      스스로 들고 있어 빈 커밋이 더해 주는 것이 없고, 자동 임시 저장 훅이 이미 커밋해 두어 바뀐 게 없는 경우가
#      흔해서 빈 커밋이 PR 기록에 쌓이기만 한다. 같은 커밋에 이름표 둘이 붙어도 괜찮다.
#   ③ 태그 이름은 stage/<이름>. 같은 이름이 로컬이나 원격에 이미 있으면 -2, -3을 붙인다(되돌아와 같은 단계를 다시 한 것).
#   ④ 태그를 붙인다(주석 태그 — 메시지는 설명, 없으면 이름).
#   ⑤ 원격 origin이 있으면 그 태그 하나만 올린다. git 자격 증명은 github-connect ⑦의 도우미가 처리하니 실행기를 붙이지 않는다.
#      - origin이 없으면(GitHub 연결 전) 로컬에만 남기고 그렇다고 알린 뒤 0으로 끝난다.
#        나중에 연결한 뒤 올리기: git push origin 'refs/tags/stage/*'
#      - 올리기에 실패하면 로컬 태그는 남기고 원인(git 출력)을 보인 뒤 1로 끝난다.
#
# 화면 그림은 여기서 찍지 않는다: 이름표 올리기를 몇 분 걸리는 빌드·골든 실패에 묶지 않으려는 것이고, 1단계·2-0 이름표에는
#   캔버스가 아직 없어 찍을 것이 없어서다. 2-로 시작하는 이름표는 끝에 stage-shots.sh 를 안내만 한다(캔버스 「단계」 보기용 그림).
#
# no-main-push 훅과의 관계: 이 스크립트를 부르는 명령은 git 명령이 아니라 훅이 보지 않고,
#   안에서 하는 push는 refs/tags/… 하나만 겨냥해 main push가 아니다.
#
# 종료 코드: 0 이름표를 붙임(올렸거나, origin이 없어 로컬에만) · 1 붙이지 못함 또는 올리기 실패 · 2 쓰는 법이 틀림
#
# 맥 기본 bash 3.2에서 돈다.

set -uo pipefail

if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
  echo "쓰는 법: .claude/scripts/stage-tag.sh <이름> \"<한 줄 설명>\"  (예: 2-1)" >&2
  exit 2
fi
name="$1"
desc="${2:-}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git 저장소 안이 아니라 이름표를 붙이지 않았습니다 — 프로젝트 최상위 폴더에서 부르세요." >&2
  exit 1
fi

branch="$(git branch --show-current 2>/dev/null)"
if [ -z "$branch" ] || [ "$branch" = "main" ]; then
  echo "이름표는 작업 브랜치에서만 붙입니다 (지금: ${branch:-브랜치 없음}). 붙이지 않았습니다." >&2
  exit 1
fi

if ! git check-ref-format "refs/tags/stage/${name}"; then
  echo "태그 이름으로 쓸 수 없는 이름입니다: ${name} (영문·숫자·-로 쓰세요. 예: 2-3-drafts)" >&2
  exit 2
fi

# ② 바뀐 것이 있으면 커밋, 없으면 지금 커밋에 붙인다
git add -A || { echo "git add 가 실패해 이름표를 붙이지 않았습니다." >&2; exit 1; }
if git diff --cached --quiet; then
  echo "바뀐 파일이 없어 지금 커밋($(git rev-parse --short HEAD))에 이름표를 붙입니다."
else
  if ! git commit -q -m "chore: 단계 이름표 — ${name}${desc:+ (${desc})}"; then
    echo "커밋이 실패해 이름표를 붙이지 않았습니다 — 위 git 출력을 보세요." >&2
    exit 1
  fi
fi

has_origin=0
git remote get-url origin >/dev/null 2>&1 && has_origin=1

remote_has_tag() {
  [ "$has_origin" = 1 ] || return 1
  GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code --tags origin "refs/tags/$1" >/dev/null 2>&1
}

# ③ 같은 이름이 있으면 -2, -3 …
tag="stage/${name}"
n=2
while git rev-parse -q --verify "refs/tags/${tag}" >/dev/null || remote_has_tag "$tag"; do
  tag="stage/${name}-${n}"
  n=$((n + 1))
done

# ④ 태그
if ! git tag -a "$tag" -m "${desc:-$name}"; then
  echo "태그 ${tag} 를 붙이지 못했습니다 — 위 git 출력을 보세요." >&2
  exit 1
fi

back="되돌아가 보기: git worktree add <폴더> ${tag}"
shots=""
case "$name" in 2-*) shots="캔버스 「단계」 보기용 그림: .claude/scripts/stage-shots.sh ${tag#stage/}" ;; esac

# ⑤ 올리기
if [ "$has_origin" = 0 ]; then
  echo "이름표 ${tag} 를 붙였습니다. GitHub 연결 전이라 로컬에만 남겼습니다 — 연결한 뒤 git push origin 'refs/tags/stage/*' 로 올립니다."
  echo "$back"
  [ -n "$shots" ] && echo "$shots"
  exit 0
fi

if ! out="$(GIT_TERMINAL_PROMPT=0 git push -q origin "refs/tags/${tag}" 2>&1)"; then
  echo "이름표 ${tag} 는 로컬에 붙였지만 GitHub에 올리지 못했습니다. 원인(git 출력):" >&2
  printf '%s\n' "$out" >&2
  echo "고친 뒤 다시 올리기: git push origin refs/tags/${tag}" >&2
  exit 1
fi

echo "이름표 ${tag} 를 붙여 GitHub에 올렸습니다."
echo "$back"
[ -n "$shots" ] && echo "$shots"
exit 0
