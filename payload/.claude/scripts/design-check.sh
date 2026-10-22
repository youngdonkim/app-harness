#!/usr/bin/env bash
# design-check.sh — 「디자인 규칙 검사」(Flutter/Dart 코드 기준) 18개를 한 번에 돌린다.
#
# 규칙 정본: .claude/skills/design-system/SKILL.md 「디자인 규칙 검사가 잡는 것」 표 (번호가 같다).
#   판정 기준·예외 처리는 idea-to-mvp 3단계 문서의 배포 전 검사 ①을 본다.
#   이 스크립트는 명령만 실행하고 판정은 하지 않는다. 늘 exit 0 이다.
#
# 쓰는 법 (프로젝트 최상위 폴더에서):
#   bash .claude/scripts/design-check.sh                          # 18개 전부 (11번은 --allowed 없으면 건너뜀)
#   bash .claude/scripts/design-check.sh --only 1,2,7,12          # 골라서
#   bash .claude/scripts/design-check.sh --allowed "xs sm md lg"  # 11번 「화면 규칙」 허용 space 이름
#
# 경로·이름은 기본값을 쓰고 환경변수로 덮는다 (여러 경로는 공백으로 구분):
#   PRODUCT_DIRS="lib/features lib/shared/components lib/dev/drafts lib/dev/design_system lib/app"
#       제품 코드. 감싸개 폴더 ui/ 는 1·3·6·7·9·11·12·16 에서 뺀다 (2·5·13·14·15 는 ui 도 본다).
#   TEXT_DIRS="lib/features lib/shared/components lib/app"   16번 대상 (개발용 lib/dev 는 뺀다)
#   SCREEN_DIRS="lib/features lib/dev/drafts"                 10·11번 대상 (화면 코드)
#   LIB_DIR=lib  DESIGN_DIR=lib/core/design  SHELL_FILE=lib/app/shell.dart
#   TOKENS_DART=lib/core/design/tokens.dart  MAIN_PROD=lib/main_prod.dart
#   INVENTORY=docs/components.md  FEATURE_LIST=mvp/feature-list.md
#   ALLOWED_SPACE="xs sm md"  (--allowed 와 같다)
#   BRAND_DIRS="lib/features lib/shared/components lib/app"   17번 대상 (개발용 lib/dev 는 뺀다 — 비교안과 디자인 시스템 페이지가 쓴다)
#   SEMANTIC_DART=lib/core/design/semantic.dart   (17번: AppTokens.light 의 brand: 가 AppBrand.none 인지 읽는 곳)
#   AGENTS_MD=AGENTS.md                    (17번: 연결 정보의 `BRAND_PARTS:` 줄을 읽는 곳)
#   BRAND_PARTS="lib/shared/components/common/brand_band.dart …"   (17번: 주면 AGENTS_MD 대신 이 목록을 쓴다)
#   HEAVY_PKGS="flutter_scene"             (18번: 무거운 패키지 이름. 주면 AGENTS_MD 의 `HEAVY_PKGS:` 줄 대신 쓴다. 대상은 LIB_DIR 아래에서 lib/dev 를 뺀 곳)
#   HEAVY_PARTS="lib/shared/components/map/map_view.dart …"   (18번: 그 패키지를 import 해도 되는 파일. 주면 AGENTS_MD 의 `HEAVY_PARTS:` 줄 대신 쓴다)
#
# 17·18번은 대상이 아직 없으면 「해당 없음」으로 따로 적는다 — 통과와 다르다.
# 제외: 생성 파일(*.g.dart, *.freezed.dart), 주석 줄(// 로 시작). 못 잡는 것(여러 줄에 걸친 EdgeInsets 등)은
#   SKILL.md 「grep으로 못 잡는 것」과 사람 확인 몫이다.
# bash 3.2(macOS 기본)에서 돌고, BSD grep/sed 로 돈다. 12·6-가·13·16 은 perl(macOS 기본 포함)을 쓴다.

ONLY=""
ALLOWED=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="$2"; shift 2 ;;
    --allowed) ALLOWED="$2"; shift 2 ;;
    *) echo "알 수 없는 인자: $1 (쓰는 법은 이 파일 맨 위 주석)"; exit 0 ;;
  esac
done

PRODUCT_DIRS="${PRODUCT_DIRS:-lib/features lib/shared/components lib/dev/drafts lib/dev/design_system lib/app}"
TEXT_DIRS="${TEXT_DIRS:-lib/features lib/shared/components lib/app}"
SCREEN_DIRS="${SCREEN_DIRS:-lib/features lib/dev/drafts}"
LIB_DIR="${LIB_DIR:-lib}"
DESIGN_DIR="${DESIGN_DIR:-lib/core/design}"
SHELL_FILE="${SHELL_FILE:-lib/app/shell.dart}"
TOKENS_DART="${TOKENS_DART:-lib/core/design/tokens.dart}"
MAIN_PROD="${MAIN_PROD:-lib/main_prod.dart}"
INVENTORY="${INVENTORY:-docs/components.md}"
FEATURE_LIST="${FEATURE_LIST:-mvp/feature-list.md}"
ALLOWED="${ALLOWED:-${ALLOWED_SPACE:-}}"
BRAND_DIRS="${BRAND_DIRS:-lib/features lib/shared/components lib/app}"
SEMANTIC_DART="${SEMANTIC_DART:-lib/core/design/semantic.dart}"
AGENTS_MD="${AGENTS_MD:-AGENTS.md}"

g() { command grep "$@"; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

read -r -a PRODUCT <<< "$PRODUCT_DIRS"
read -r -a TEXTD <<< "$TEXT_DIRS"
read -r -a SCREEND <<< "$SCREEN_DIRS"
read -r -a BRANDD <<< "$BRAND_DIRS"

# 숫자 글자(0 은 빼고 0.0 도 뺀다)
NUM='([1-9][0-9]*(\.[0-9]+)?|[0-9]*\.[0-9]*[1-9])'
# 식별자 글자가 앞에 붙지 않은 시작
NI='(^|[^A-Za-z0-9_])'

EX=()
ex() {
  EX=()
  local p
  for p in "$@"; do
    if [ -e "$p" ]; then EX+=("$p"); else echo "경로 없음: $p"; fi
  done
}

want() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

# 주석 줄(// 로 시작) 거르기, 그리고 줄 끝 주석(공백 뒤 // …)은 그 앞까지만 남겨 본다
#   (문자열 속 `https://` 처럼 공백 없이 붙은 // 는 남는다)
nc() { g -vE '^[^:]+:[0-9]+:[[:space:]]*//' | sed -E 's# //.*$##'; }
# ui/ 뺀 grep / ui/ 포함 grep (생성 파일은 둘 다 뺀다)
gx() { g -rnHE --include='*.dart' --exclude='*.g.dart' --exclude='*.freezed.dart' --exclude-dir=ui "$@" | nc; }
ga() { g -rnHE --include='*.dart' --exclude='*.g.dart' --exclude='*.freezed.dart' "$@" | nc; }

# 여러 줄에 걸친 모양을 보는 perl (dart 파일 목록을 인자로)
cat > "$T/scan.pl" <<'PERL'
use strict; use warnings;
my $mode = shift @ARGV;
my $num = qr/(?<![\w.])(?:[1-9]\d*(?:\.\d+)?|0?\.\d*[1-9])(?![\w])/;
for my $f (@ARGV) {
  open(my $fh, '<', $f) or next; local $/; my $s = <$fh>; close $fh;
  my $line = sub { my $n = () = substr($s, 0, $_[0]) =~ /\n/g; return $n + 1 };
  if ($mode eq 'fixedtext') {
    while ($s =~ /(?<![\w.])(SizedBox|Container)\s*(?<p>\((?:[^()]++|(?&p))*\))/g) {
      my $name = $1; my $pos = $-[0]; my $body = $+{p};
      my $in = substr($body, 1, -1); my $top = $in;
      1 while $top =~ s/\([^()]*\)/_/g;
      next unless $top =~ /\bheight\s*:\s*$num/;
      next unless $in =~ /(?<![\w.])Text(?:\.rich)?\s*\(/;
      printf "%s:%d: 높이를 숫자로 고정한 %s 안에 Text\n", $f, $line->($pos), $name;
    }
  } elsif ($mode eq 'bottompos') {
    while ($s =~ /(?<![\w.])Positioned\s*(?<p>\((?:[^()]++|(?&p))*\))/g) {
      my $pos = $-[0]; my $in = substr($+{p}, 1, -1); my $top = $in;
      1 while $top =~ s/\([^()]*\)/_/g;
      next unless $top =~ /\bbottom\s*:/;
      printf "%s:%d: Positioned(bottom:) 가 셸 밖에 있음\n", $f, $line->($pos);
    }
  } elsif ($mode eq 'textliteral') {
    while ($s =~ /(?<![\w.])Text\s*\(\s*r?(['"])/g) {
      my $pos = $-[0];
      my $l = $line->($pos);
      my @ls = split /\n/, $s, -1;
      my $txt = $ls[$l-1] // ''; $txt =~ s/^\s+//;
      next if $txt =~ m{^//};
      printf "%s:%d: %s\n", $f, $l, $txt;
    }
  }
}
PERL

# 대상 폴더들의 dart 파일 목록 (ui/ 뺀 것: files_x, 포함: files_a)
files_x() { find "$@" -name '*.dart' -not -name '*.g.dart' -not -name '*.freezed.dart' -not -path '*/ui/*' 2>/dev/null | sort; }
files_a() { find "$@" -name '*.dart' -not -name '*.g.dart' -not -name '*.freezed.dart' 2>/dev/null | sort; }

# ---------- 검사 함수 ----------
c1() { # 색·숫자 하드코딩 (ui/ 뺀다)
  ex "${PRODUCT[@]}"; [ ${#EX[@]} -eq 0 ] && return
  gx "Color\(0x|Color\.from(ARGB|RGBO)\(|${NI}(Cupertino)?Colors\." "${EX[@]}"
  gx "EdgeInsets(Directional)?\.[A-Za-z]+\(([^)]*[^A-Za-z0-9_.])?${NUM}" "${EX[@]}"
  gx "SizedBox(\.[A-Za-z]+)?\(([^)]*[^A-Za-z0-9_.])?(width|height|dimension):[[:space:]]*${NUM}" "${EX[@]}"
  gx "fontSize:" "${EX[@]}"
  gx "Radius\.circular\([[:space:]]*${NUM}" "${EX[@]}"
}

c2() { # foundation.dart import (core/design 밖 전부, ui 포함)
  ex "$LIB_DIR"; [ ${#EX[@]} -eq 0 ] && return
  ga "^[[:space:]]*(import|export)[[:space:]].*foundation\.dart" "$LIB_DIR" | g -v "^${DESIGN_DIR}/"
}

c3() { # 화면 폭을 셸 밖에서 읽음 (ui 뺀다)
  ex "${PRODUCT[@]}"; [ ${#EX[@]} -eq 0 ] && return
  gx "MediaQuery\.(maybeS|s)izeOf|MediaQuery\.(maybeOf|of)\([^)]*\)[?!]?\.size" "${EX[@]}" | g -v "^${SHELL_FILE}:"
}

c4() { # 부품 파일 ↔ 인벤토리 색인
  ex "$INVENTORY" lib/shared/components lib/features
  [ -e "$INVENTORY" ] || return
  sed -n '/^## 전체 부품 색인/,$p' "$INVENTORY" > "$T/inventory-index.txt"
  [ -s "$T/inventory-index.txt" ] || { echo "미등록 확인 불가: $INVENTORY 에 「## 전체 부품 색인」 구간이 없음"; return; }
  find lib/shared/components lib/features -name '*.dart' -not -name '*.g.dart' 2>/dev/null \
    | g -E '^lib/shared/components/|/widgets/' | sort > "$T/parts.txt"
  local f
  while read -r f; do [ -n "$f" ] && { g -qxF -- "$f" "$T/inventory-index.txt" || echo "미등록 부품: $f"; }; done < "$T/parts.txt"
  g -E '^lib/.*\.dart$' "$T/inventory-index.txt" | while read -r f; do
    [ -e "$f" ] || echo "색인에만 있고 파일이 없음: $f"
  done
}

c5() { # 제출 동작 — 한글 조합 가드는 사람이 확인 (ui 포함: 감싸개에 가드가 있을 수 있다)
  ex "${PRODUCT[@]}"; [ ${#EX[@]} -eq 0 ] && return
  ga "onSubmitted|onEditingComplete|TextInputAction\.(done|send|search)" "${EX[@]}"
}

c6() { # 하단 고정 요소 + 셸 안전 영역
  ex "${PRODUCT[@]}" "$SHELL_FILE"
  local fl; fl=$(files_x "${PRODUCT[@]}" | g -vxF "$SHELL_FILE")
  [ -n "$fl" ] && echo "$fl" | xargs perl "$T/scan.pl" bottompos
  if [ -e "$SHELL_FILE" ]; then
    if g -qE 'SafeArea|MediaQuery\.(paddingOf|viewPaddingOf|maybePaddingOf)|MediaQuery\.(of|maybeOf)\([^)]*\)\.(view)?[pP]adding' "$SHELL_FILE"; then
      echo "  (참고) 셸이 안전 영역을 처리함: $SHELL_FILE"
    else
      echo "셸에 안전 영역 처리가 없음: $SHELL_FILE 에 SafeArea 도 MediaQuery.paddingOf 도 없음"
    fi
  fi
}

c7() { # Theme.of 직접 사용 (ui 뺀다)
  ex "${PRODUCT[@]}"; [ ${#EX[@]} -eq 0 ] && return
  gx "Theme\.of\([^)]*\)\.(colorScheme|textTheme)|\.extension<" "${EX[@]}"
}

c8() { # 동작 줄이기 전역 장치
  ex "$TOKENS_DART"
  [ -e "$TOKENS_DART" ] || return
  echo "결과: $(g -c 'disableAnimationsOf' "$TOKENS_DART")"
}

c9() { # 모션 값 하드코딩 (ui 뺀다)
  ex "${PRODUCT[@]}"; [ ${#EX[@]} -eq 0 ] && return
  gx "Duration\([^)]*(milliseconds|seconds|microseconds):|${NI}Curves\.|${NI}Cubic\(" "${EX[@]}"
}

c10() { # 화면 파일마다 주 버튼 수
  ex "$FEATURE_LIST" "${SCREEND[@]}"
  echo "  (참고) 10-가. 화면 목록의 주 행동 칸 (MVP 포함 = O)"
  if [ -e "$FEATURE_LIST" ]; then
    # 표는 절 번호·칸 순서가 아니라 머리줄의 칸 이름으로 찾는다 (ID·화면 이름·MVP 포함·주소가 모두 있는 첫 표, 「주 행동」 칸도 이름으로)
    awk '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function split_cells(line, arr,   n, i) {
  line = trim(line)
  gsub(/\\\|/, "\001", line)
  sub(/^\|/, "", line); sub(/\|$/, "", line)
  n = split(line, arr, "|")
  for (i = 1; i <= n; i++) { gsub(/\001/, "|", arr[i]); arr[i] = trim(arr[i]) }
  return n
}
function head_name(s) { gsub(/\*\*/, "", s); gsub(/`/, "", s); return trim(s) }
function is_divider(s) { return (s ~ /^[ \t]*\|?[ \t:|-]+\|?[ \t]*$/ && s ~ /-/) }
BEGIN { st = 0; done = 0 }
{
  if (done) next
  if (st == 2) {
    if ($0 ~ /^[ \t]*\|/) {
      n = split_cells($0, c)
      id = c[ci]; gsub(/ /, "", id)
      if (id ~ /S-[0-9]/ && c[cm] == "O") print "  (참고) " id " · 주 행동: " c[ca] " · 주소: " c[cu]
      next
    }
    done = 1; next
  }
  if (st == 1) {
    st = 0
    if (is_divider($0)) {
      n = split_cells(hdr, h); ci = cm = cu = ca = 0; nm = 0
      for (i = 1; i <= n; i++) {
        x = head_name(h[i])
        if (x == "ID") ci = i; else if (x == "화면 이름") nm = i
        else if (x == "MVP 포함") cm = i; else if (x == "주소") cu = i
        else if (x == "주 행동") ca = i
      }
      if (ci && nm && cm && cu) { if (!ca) { print "  (참고) 화면 목록 표에 「주 행동」 칸이 없음"; done = 1; next } st = 2; next }
    }
  }
  if ($0 ~ /^[ \t]*\|/) { hdr = $0; st = 1 }
}
' "$FEATURE_LIST"
  fi
  echo "  (참고) 10-나. 화면 파일마다 AppButtonVariant.primary 수 — 1개가 아닌 파일만 나온다 (화면 파일 밖 위젯 파일의 버튼은 안 센다)"
  find "${SCREEND[@]}" \( -name '*_screen.dart' -o -name '*_page.dart' \) -not -name '*.g.dart' 2>/dev/null | sort > "$T/screens.txt"
  local f n
  while read -r f; do
    [ -n "$f" ] || continue
    n=$(g -v '^[[:space:]]*//' "$f" | g -o 'AppButtonVariant\.primary' | wc -l | tr -d ' ')
    [ "$n" = 1 ] || echo "주 버튼 ${n}개: $f"
  done < "$T/screens.txt"
}

c11() { # 화면이 부르는 context.space.* 이름이 허용 목록 안인지 (ui 뺀다)
  if [ -z "$ALLOWED" ]; then echo "  (참고) 허용 space 이름을 모름 — --allowed \"xs sm md\" 를 주세요"; return; fi
  ex "${SCREEND[@]}"; [ ${#EX[@]} -eq 0 ] && return
  gx "context\.space\.[A-Za-z0-9_]+" "${EX[@]}" \
    | awk -v ok="$ALLOWED" 'BEGIN{n=split(ok,a," "); for(i=1;i<=n;i++) s[a[i]]=1}
        { m=$0; while (match(m,/context\.space\.[A-Za-z0-9_]+/)) { v=substr(m,RSTART+14,RLENGTH-14); if(!(v in s)) { print $0 "   ← " v; break } m=substr(m,RSTART+RLENGTH) } }'
}

c12() { # 높이를 숫자로 고정한 SizedBox·Container 안의 Text (ui 뺀다)
  ex "${PRODUCT[@]}"; [ ${#EX[@]} -eq 0 ] && return
  local fl; fl=$(files_x "${EX[@]}")
  [ -n "$fl" ] && echo "$fl" | xargs perl "$T/scan.pl" fixedtext
}

c13() { # main_prod 가 (건너서라도) lib/dev 를 부르는지 — import·export 를 따라가며 센다
  ex "$MAIN_PROD"; [ -e "$MAIN_PROD" ] || return
  local pkg; pkg=$(sed -n 's/^name:[[:space:]]*//p' pubspec.yaml 2>/dev/null | head -1 | tr -d '\r "')
  if [ -z "$pkg" ]; then echo "  (참고) pubspec.yaml 에서 패키지 이름을 못 읽음 — package: import 를 못 따라갈 수 있음"; fi
  PKG="$pkg" perl -e '
    use strict; use warnings; use File::Basename;
    my $pkg = $ENV{PKG} // "";
    my @q = ($ARGV[0]); my %seen = ($ARGV[0] => 1); my %from;
    while (my $f = shift @q) {
      open(my $fh, "<", $f) or next; my $n = 0;
      while (my $l = <$fh>) { $n++;
        next unless $l =~ /^\s*(?:import|export)\s+[\x27"]([^\x27"]+)[\x27"]/;
        my $u = $1; my $t;
        if ($u =~ m{^package:([^/]+)/(.*)$}) { next unless $1 eq $pkg; $t = "lib/$2"; }
        elsif ($u =~ m{^(dart|package):}) { next }
        else { $t = dirname($f) . "/" . $u; 1 while $t =~ s{[^/]+/\.\./}{}; $t =~ s{/\./}{/}g; }
        next unless -e $t;
        if ($t =~ m{^lib/dev/}) { print "$f:$n: lib/dev 를 부름 → $t\n"; }
        next if $seen{$t}++; push @q, $t;
      }
      close $fh;
    }' "$MAIN_PROD"
}

c14() { # Firebase .instance 직접 호출 (ui 포함)
  ex lib/features lib/shared; [ ${#EX[@]} -eq 0 ] && return
  ga "Firebase[A-Za-z]*\.instance" "${EX[@]}"
}

c15() { # 앱 글자 배율을 막는 코드 (ui 포함, lib/app 포함)
  ex "${PRODUCT[@]}"; [ ${#EX[@]} -eq 0 ] && return
  ga "TextScaler\.noScaling|textScaleFactor|withNoTextScaling|TextScaler\.linear\([[:space:]]*1(\.0*)?[[:space:]]*\)" "${EX[@]}"
}

c16() { # 화면에 글자를 직접 쓴 Text('…') — 문구는 .arb 에서 꺼내야 함
  ex "${TEXTD[@]}"; [ ${#EX[@]} -eq 0 ] && return
  local fl; fl=$(files_x "${EX[@]}")
  [ -n "$fl" ] && echo "$fl" | xargs perl "$T/scan.pl" textliteral
}

# 17번: context.brand.surface·onSurface(브랜드 색 면)를 쓴 파일이 연결 정보의 자리 부품 목록(BRAND_PARTS) 밖에 있으면 찍는다.
# lib/dev 는 뺀다 — 디자인 시스템 페이지 견본과 2-3 비교안이 쓴다.
# 세 갈래를 가른다:
#   ① 브랜드 색을 아직 안 들임(AppTokens.light 의 brand: 가 AppBrand.none · 제품 코드에 쓴 곳 없음 · 목록 줄 없음) → 「해당 없음」 (걸린 줄로 세지 않는다)
#   ② 들였는데 목록 줄이 없음(brand: 가 진짜 값이거나 쓴 파일이 있는데 BRAND_PARTS 줄 없음) → 「목록 줄 없음」 (걸린 줄)
#   ③ 목록이 있음 → 목록 밖 파일만 찍는다. 목록에 있는데 파일이 없으면 (참고)로 알린다
NA_LIST=""
c17() {
  local list="${BRAND_PARTS:-}"
  if [ -z "$list" ] && [ -e "$AGENTS_MD" ]; then
    list=$(g -m1 -E '^[[:space:]]*(-[[:space:]]+)?`?BRAND_PARTS:' "$AGENTS_MD" | sed -E 's/.*BRAND_PARTS:[[:space:]]*//' | tr -d '`')
  fi
  : > "$T/brand-files.txt"
  ex "${BRANDD[@]}"
  [ ${#EX[@]} -gt 0 ] && ga 'context\.brand\.(surface|onSurface)\b' "${EX[@]}" | cut -d: -f1 | sort -u > "$T/brand-files.txt"
  local entered=0
  if [ -e "$SEMANTIC_DART" ]; then
    # AppTokens.light 를 만드는 식 안의 brand: 값이 AppBrand.none 이 아니면 들인 것
    entered=$(perl -e '
      use strict; use warnings;
      local $/; open(my $fh, "<", $ARGV[0]) or do { print 0; exit };
      my $s = <$fh>; close $fh;
      $s =~ s{//[^\n]*}{}g;
      if ($s =~ /\blight\s*=\s*AppTokens\s*(?<p>\((?:[^()]++|(?&p))*\))/) {
        my $in = substr($+{p}, 1, -1);
        if ($in =~ /\bbrand\s*:\s*(.*)/s) { print(($1 =~ /^AppBrand\.none\b/) ? 0 : 1); exit }
      }
      print 0' "$SEMANTIC_DART")
  fi
  if [ -z "$list" ]; then
    if [ ! -s "$T/brand-files.txt" ] && [ "$entered" = 0 ]; then
      echo "  (참고) 해당 없음 — 브랜드 색 면을 아직 들이지 않았다(AppTokens.light 의 brand: 가 AppBrand.none, 제품 코드에 쓴 곳 없음, 연결 정보에 BRAND_PARTS 줄 없음)"
      NA_LIST="$NA_LIST 17"
      return
    fi
    echo "목록 줄 없음: 브랜드 색 면을 들였는데($([ "$entered" != 0 ] && echo 'AppTokens.light 에 brand: 값 있음')$([ -s "$T/brand-files.txt" ] && echo ' 제품 코드에 쓴 파일 있음')) $AGENTS_MD 연결 정보에 BRAND_PARTS: 줄이 없다 — 줄을 빠뜨린 것"
  fi
  local parts=() p f ok
  [ -n "$list" ] && read -r -a parts <<< "$list"
  if [ ${#parts[@]} -gt 0 ]; then
    for p in "${parts[@]}"; do [ -e "$p" ] || echo "  (참고) 목록에 있는데 파일이 없음: $p"; done
  fi
  [ -s "$T/brand-files.txt" ] || return
  while read -r f; do
    ok=0
    if [ ${#parts[@]} -gt 0 ]; then
      for p in "${parts[@]}"; do [ "$f" = "$p" ] && ok=1; done
    fi
    [ "$ok" = 1 ] || echo "자리 부품 목록 밖: $f"
  done < "$T/brand-files.txt"
}

# 18번: 무거운 패키지(3D 등)를 연결 정보의 부품 목록(HEAVY_PARTS) 밖 파일에서 import 하면 찍는다.
# 패키지 이름은 스크립트에 없다 — 연결 정보의 `HEAVY_PKGS:`(이름 목록)와 `HEAVY_PARTS:`(불러도 되는 파일 목록) 두 줄을 읽는다.
# 대상은 lib/ 아래에서 lib/dev 를 뺀 곳 — 비교안 폴더는 무거운 패키지를 부르는 자리다. 찾는 꼴: import 'package:이름/ (큰따옴표도)
# 세 갈래를 가른다:
#   ① HEAVY_PKGS 줄 없음(또는 값이 비어 있음 — 비교안 단계) → 「해당 없음」 (걸린 줄로 세지 않는다)
#   ② HEAVY_PKGS 는 있는데 HEAVY_PARTS 줄 없음 → 「목록 줄 없음」 (걸린 줄)
#   ③ 두 줄이 다 있음 → 목록 밖 파일만 찍는다. 목록에 있는데 파일이 없으면 (참고)로 알린다
c18() {
  local pkgs="${HEAVY_PKGS:-}" list="${HEAVY_PARTS:-}" haveparts=0
  if [ -e "$AGENTS_MD" ]; then
    [ -z "$pkgs" ] && pkgs=$(g -m1 -E '^[[:space:]]*(-[[:space:]]+)?`?HEAVY_PKGS:' "$AGENTS_MD" | sed -E 's/.*HEAVY_PKGS:[[:space:]]*//' | tr -d '`')
    [ -z "$list" ] && list=$(g -m1 -E '^[[:space:]]*(-[[:space:]]+)?`?HEAVY_PARTS:' "$AGENTS_MD" | sed -E 's/.*HEAVY_PARTS:[[:space:]]*//' | tr -d '`')
    g -qE '^[[:space:]]*(-[[:space:]]+)?`?HEAVY_PARTS:' "$AGENTS_MD" && haveparts=1
  fi
  [ -n "$list" ] && haveparts=1
  # 공백으로 나눈 단어 중 패키지 이름 모양(소문자·숫자·_)만 앞에서부터 읽고, 다른 모양(괄호·설명)이 나오면 거기서 멈춘다
  local names=() n
  for n in $pkgs; do
    case "$n" in
      [a-z]*) case "$n" in *[!a-z0-9_]*) break ;; esac; names+=("$n") ;;
      *) break ;;
    esac
  done
  if [ ${#names[@]} -eq 0 ]; then
    echo "  (참고) 해당 없음 — 무거운 패키지를 아직 들이지 않았다(연결 정보에 HEAVY_PKGS 줄이 없거나 비어 있음)"
    NA_LIST="$NA_LIST 18"
    return
  fi
  if [ "$haveparts" = 0 ]; then
    echo "목록 줄 없음: HEAVY_PKGS 는 있는데 $AGENTS_MD 연결 정보에 HEAVY_PARTS: 줄이 없다 — 줄을 빠뜨린 것"
  fi
  local alt="" parts=() p f ok
  for n in "${names[@]}"; do alt="${alt:+$alt|}$n"; done
  [ -n "$list" ] && read -r -a parts <<< "$list"
  if [ ${#parts[@]} -gt 0 ]; then
    for p in "${parts[@]}"; do [ -e "$p" ] || echo "  (참고) 목록에 있는데 파일이 없음: $p"; done
  fi
  [ -e "$LIB_DIR" ] || { echo "경로 없음: $LIB_DIR"; return; }
  ga "import[[:space:]]+['\"]package:($alt)/" "$LIB_DIR" | cut -d: -f1 | sort -u | g -v "^${LIB_DIR%/}/dev/" > "$T/heavy-files.txt"
  [ -s "$T/heavy-files.txt" ] || return
  while read -r f; do
    ok=0
    if [ ${#parts[@]} -gt 0 ]; then
      for p in "${parts[@]}"; do [ "$f" = "$p" ] && ok=1; done
    fi
    [ "$ok" = 1 ] || echo "자리 부품 목록 밖: $f"
  done < "$T/heavy-files.txt"
}

# ---------- 실행 ----------
HIT_LIST=""
VAL_LIST=""

run() { # 번호 이름 함수 종류(h=걸린 줄 수, v=값, s=화면 파일 수)
  want "$1" || return
  echo "== $1 $2"
  "$3" > "$T/out" 2>&1
  cat "$T/out"
  local n
  if [ "$4" = v ]; then
    n=$(sed -n 's/^결과: //p' "$T/out" | head -1)
    [ -z "$n" ] && n="확인불가"
    VAL_LIST="$VAL_LIST $1=$n"
  elif [ "$4" = s ]; then
    n=$(g -c '^주 버튼 ' "$T/out")
    VAL_LIST="$VAL_LIST $1=${n}개화면"
  else
    n=$(g -cvE '^(경로 없음|  \(참고\))' "$T/out")
    if [ "$n" -gt 0 ]; then HIT_LIST="$HIT_LIST $1(${n}줄)"; fi
  fi
}

run 1  "색·숫자 하드코딩 (Color·Colors·EdgeInsets·SizedBox·fontSize·Radius)" c1 h
run 2  "foundation.dart import" c2 h
run 3  "화면 폭 읽기(MediaQuery size)가 셸 밖" c3 h
run 4  "부품 파일 ↔ 인벤토리 색인" c4 h
run 5  "제출 동작 — 한글 조합 가드 사람 확인" c5 h
run 6  "하단 고정 요소·셸 안전 영역" c6 h
run 7  "Theme.of 직접 사용" c7 h
run 8  "동작 줄이기 전역 장치(disableAnimationsOf)" c8 v
run 9  "모션 값(Duration·Curves·Cubic) 하드코딩" c9 h
run 10 "화면마다 주 버튼 수" c10 s
run 11 "허용 목록 밖 context.space 이름" c11 h
run 12 "높이를 숫자로 고정한 상자 안의 Text" c12 h
run 13 "main_prod 가 lib/dev 를 부름" c13 h
run 14 "Firebase .instance 직접 호출" c14 h
run 15 "앱 글자 배율을 막는 코드" c15 h
run 16 "화면에 직접 쓴 Text('…') 문구" c16 h
run 17 "브랜드 색 면 자리 부품 밖 사용" c17 h
run 18 "무거운 패키지 자리 부품 밖 import" c18 h

echo
echo "걸린 검사:${HIT_LIST:- 없음} / 기준 확인이 필요한 검사: 5(걸린 곳마다 한글 조합 가드 사람 확인), 8(1 이상이어야 통과), 10(1개가 아닌 화면은 주 행동 칸과 맞대 판정) —${VAL_LIST:- 해당 없음}"
[ -n "$NA_LIST" ] && echo "해당 없음(검사할 대상이 아직 없음 — 통과와 다르다):$NA_LIST"
exit 0
