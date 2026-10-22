#!/bin/bash
# 앱 뼈대 틀을 프로젝트에 넣습니다 — 저장소 최상위 폴더에서 돌립니다.
#
#   bash .claude/templates/firebase/apply.sh app     '앱=<Dart 패키지 이름>' '앱 이름=<홈 화면 이름>'
#   bash .claude/templates/firebase/apply.sh backend '앱=…' '리전=…' '개발용 프로젝트 ID=…' \
#        '실서비스 프로젝트 ID=…' '저장소 이름=…' 'Node 주 판=…'
#
# - <묶음>/ 아래 파일을 같은 경로로 복사하면서 끝의 .template을 뗍니다.
# - 파일 안의 <이름> 자리를 「이름=값」으로 받은 값으로 바꿉니다.
# - 이미 있는 파일은 덮어쓰지 않고 목록으로 알린 뒤 실패로 끝납니다. 예외 하나:
#   backend 묶음의 lib/core/firebase/backend_init.dart는 app 묶음이 넣은 빈 판 그대로일 때만 바꿔 넣습니다.
# - 끝나고 바꾸지 못한 <이름> 자리가 남았으면 알립니다.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
part="${1:-}"
case "$part" in app|backend) ;; *) echo "usage: apply.sh <app|backend> '이름=값' ..." >&2; exit 2 ;; esac
shift
[ -f pubspec.yaml ] || { echo "pubspec.yaml이 없습니다 — 저장소 최상위 폴더에서 돌리세요" >&2; exit 2; }

# 이름=값 → 환경변수 PH_0, PH_1 … (perl이 읽음)
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
while IFS= read -r -d '' src; do
  rel="${src#"$HERE/$part/"}"
  dst="${rel%.template}"
  tmp="$(mktemp)"
  render "$src" > "$tmp"
  if [ -e "$dst" ]; then
    if cmp -s "$tmp" "$dst"; then rm -f "$tmp"; continue; fi
    replaceable=false
    if [ "$part" = backend ] && [ "$dst" = lib/core/firebase/backend_init.dart ]; then
      empty="$(mktemp)"; render "$HERE/app/$dst.template" > "$empty"
      cmp -s "$empty" "$dst" && replaceable=true
      rm -f "$empty"
    fi
    if [ "$replaceable" = false ]; then conflicts+=("$dst"); rm -f "$tmp"; continue; fi
  fi
  mkdir -p "$(dirname "$dst")"
  mv "$tmp" "$dst"
  copied+=("$dst")
done < <(find "$HERE/$part" -type f -name '*.template' -print0 | sort -z)

echo "넣은 파일 ${#copied[@]}개"
for f in ${copied[@]+"${copied[@]}"}; do echo "  + $f"; done

left="$(grep -rnoE '<(앱|앱 이름|리전|개발용 프로젝트 ID|실서비스 프로젝트 ID|저장소 이름|Node 주 판)>' ${copied[@]+"${copied[@]}"} 2>/dev/null || true)"
if [ -n "$left" ]; then
  echo "아직 값이 없는 자리:"; echo "$left" | sed 's/^/  /'
fi
if [ ${#conflicts[@]} -gt 0 ]; then
  echo "이미 있어 넣지 않은 파일(내용이 다름) — 두 판을 비교해 손으로 합치세요:" >&2
  for f in "${conflicts[@]}"; do echo "  ! $f" >&2; done
  exit 1
fi
[ -z "$left" ] || exit 1
