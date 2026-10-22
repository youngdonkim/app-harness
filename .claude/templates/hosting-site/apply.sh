#!/bin/bash
# 웹 페이지 틀을 프로젝트의 hosting/ 폴더에 넣습니다 — 저장소 최상위 폴더에서 돌립니다.
#
#   bash .claude/templates/hosting-site/apply.sh [--stage3] '앱 이름=예시앱' '개발자 이름=…' \
#        '문의 메일=…' '패키지 이름=app.example' '실서비스 프로젝트 ID=example-prod' '저장소 이름=example'
#
# - public/ 아래 파일을 hosting/public/에 복사하면서 <이름> 자리를 값으로 바꿉니다.
#   .well-known/assetlinks.json.template은 그대로(.template 붙은 채) 둡니다 — 앱 링크를 쓸 때 손으로 만듭니다.
# - --stage3: 3단계에서 Hosting만 먼저 올릴 때. hosting/ 안에 firebase.json·.firebaserc·package.json도 넣습니다.
#   4단계(4-0)에서 최상위로 합치는 법은 README 「4-0에서 합치기」.
# - 이미 있는 파일은 덮어쓰지 않고 알린 뒤 실패로 끝납니다.
# - 끝나고 아직 채우지 않은 <…> 자리(예: <예: …>·<처리 기간 — …>)를 파일별로 알립니다 — 그 프로젝트 내용으로 손으로 채웁니다.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
stage3=false
if [ "${1:-}" = "--stage3" ]; then stage3=true; shift; fi

i=0
for kv in "$@"; do
  case "$kv" in *=*) ;; *) echo "「이름=값」 꼴이 아닙니다: $kv" >&2; exit 2 ;; esac
  export "PH_K_$i=${kv%%=*}" "PH_V_$i=${kv#*=}"
  i=$((i + 1))
done
export PH_N=$i

render() { # $1 = 틀 파일 → 표준 출력
  perl -CSD -pe '
    BEGIN {
      for my $j (0 .. $ENV{PH_N} - 1) {
        my ($k, $v) = ($ENV{"PH_K_$j"}, $ENV{"PH_V_$j"});
        utf8::decode($k); utf8::decode($v);
        push @pairs, [$k, $v];
      }
    }
    for my $p (@pairs) { my ($k, $v) = @$p; s/<\Q$k\E>/$v/g }
  ' "$1"
}

conflicts=()
copied=()
copy_tree() { # $1 = 틀 폴더, $2 = 넣을 폴더
  local src rel dst tmp
  while IFS= read -r -d '' src; do
    rel="${src#"$1/"}"
    dst="$2/$rel"
    tmp="$(mktemp)"
    render "$src" > "$tmp"
    if [ -e "$dst" ]; then
      if ! cmp -s "$tmp" "$dst"; then conflicts+=("$dst"); fi
      rm -f "$tmp"
      continue
    fi
    mkdir -p "$(dirname "$dst")"
    mv "$tmp" "$dst"
    copied+=("$dst")
  done < <(find "$1" -type f -print0 | sort -z)
}

copy_tree "$HERE/public" "hosting/public"
$stage3 && copy_tree "$HERE/stage3" "hosting"

echo "넣은 파일 ${#copied[@]}개"
for f in ${copied[@]+"${copied[@]}"}; do echo "  + $f"; done

# 한글로 시작하는 <…> 자리 = 아직 채우지 않은 값
left="$(grep -rnoE '<[가-힣][^<>]*>' ${copied[@]+"${copied[@]}"} 2>/dev/null | grep -v '\.template:' || true)"
if [ -n "$left" ]; then
  echo "아직 채우지 않은 자리(그 프로젝트 내용으로 손으로 채웁니다):"
  echo "$left" | sed 's/^/  /'
fi
if [ ${#conflicts[@]} -gt 0 ]; then
  echo "이미 있어 넣지 않은 파일(내용이 다름) — 두 판을 비교해 손으로 합치세요:" >&2
  for f in "${conflicts[@]}"; do echo "  ! $f" >&2; done
  exit 1
fi
