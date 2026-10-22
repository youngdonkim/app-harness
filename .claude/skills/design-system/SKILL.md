---
name: design-system
description: Flutter(Material 3) 위의 3단 토큰 계층(foundation→semantic→component) + 조립 계층(frame·pattern) 디자인 시스템 방법론.
  화면·부품에 색/간격/글자/둥글기/그림자/움직임 값을 적용할 때, `context.colors`·`context.space` 같은 토큰 이름을 고를 때,
  `lib/core/design/`의 토큰·테마 파일을 만들거나 고칠 때, Material 감싸개 부품(`AppButton` 등)을 더하거나 고칠 때,
  새 부품·화면을 만들 때, 새 프로젝트에 토큰 시스템을 도입할 때, 새 토큰을 더할 때, 서체를 넣거나 바꿀 때,
  글자 배율(시스템 글자 크기)에서 넘치는 곳을 다룰 때, 참고 디자인(앱 캡처·사이트·색 값·프리셋)에서 색·서체를 뽑을 때 사용.
---

# 디자인 시스템 — 계층 아키텍처

모든 시각 값은 토큰을 거쳐서만 쓴다. 스택은 Flutter + Material 3 고정이고, 지원 기기는 폰뿐이다. 제품 코드(화면·부품)는 토큰을 **`BuildContext`에 붙인 짧은 이름으로 꺼낸다** (`context.colors.primary`·`context.space.s4`·`context.text.b1`). `Color(0x…)`·`Colors.*`·숫자 간격(`EdgeInsets.all(13)`)·숫자 글자 크기(`fontSize: 15`) 금지.

**토큰 계층 (Dart 파일 — 모두 `lib/core/design/` 안):**

1. **foundation** (`foundation.dart`) — 기본 값: 색 램프(`Color(0xFF…)`)·간격 단위·글자 크기 원본·둥글기 기준·그림자 원본·움직임 길이(`Duration`)·곡선(`Curve`)·서체 이름. **숫자·색 값을 쓸 수 있는 유일한 파일**이다. 교체 가능 (브랜드·디자인 시스템 변경 = 이 층 교체)
2. **semantic** (`semantic.dart`) — 의미: 1층 값을 역할 이름으로 다시 잇는다. 색 역할 이름은 Material `ColorScheme`의 이름(`primary`·`onPrimary`·`surface`·`onSurfaceVariant` …)을 따르고, Material에 없는 역할(성공·경고·희미한 글자)과 색 밖의 값(간격·영역 치수·둥글기·글자 단계·그림자·움직임)까지 전부 `ThemeExtension`(테마에 우리만의 값 묶음을 덧붙이는 Flutter 장치)으로 둔다. **화면·부품 코드가 값을 꺼내는 유일한 층**
3. **component** — 부품: `theme.dart`가 2층 값으로 `ThemeData`(Material 부품 전체의 기본 모양)를 조립한다. 부품 코드는 `lib/shared/components/ui/`(범용 — Material 감싸개, 예: `AppButton`)와 `lib/shared/components/common/`·`lib/features/<흐름>/widgets/`(전용)

**접근 확장** (`tokens.dart`) — `extension DesignTokens on BuildContext`가 `context.colors`·`context.space`·`context.layout`·`context.radius`·`context.text`·`context.shadows`·`context.motion`을 준다. 화면 코드가 2층에 닿는 길은 이것 하나다.

**조립 계층 (방법론 — 토큰 파일 없음):**

4. **frame** — 뼈대: 셸 + 영역 + 크기 예산(size budget). 셸은 `lib/app/shell.dart`. 셸 분류·파생 규칙은 [references/layout-frames.md](references/layout-frames.md)
5. **pattern** — 검증된 조합: 프레임+부품을 화면 유형별로 묶은 틀 (한 프레임 위에 패턴 여러 개 가능)

**screen (실제 화면)** = 패턴 + 콘텐츠 — 패턴의 인스턴스. 한 화면 = `lib/features/<흐름>/screens/`의 파일 하나

## 목차

1. [시작하기 전에 (필수)](#시작하기-전에-필수)
2. [철칙](#철칙)
3. [강조색은 어디에 쓰나](#강조색은-어디에-쓰나)
4. [브랜드 색은 어디에 쓰나](#브랜드-색은-어디에-쓰나)
5. [결정 트리](#결정-트리)
6. [안티패턴](#안티패턴)
7. [동심원 radius 규칙](#동심원-radius-규칙)
8. [글자 배율 규칙](#글자-배율-규칙)
9. [디자인 규칙 검사가 잡는 것](#디자인-규칙-검사가-잡는-것)
10. [어느 문서를 언제 읽나](#어느-문서를-언제-읽나)

---

## 시작하기 전에 (필수)

**시작 전 브랜치 확인** — 파일을 바꾸기 전에 지금 어느 브랜치인지 먼저 본다.

```bash
git branch --show-current
```

**main이면 `/new-task`를 직접 호출해 작업 브랜치를 연 뒤 진행한다.** main에서 파일을 바꾸면 `auto-wip-commit` 훅이 안 돌아 자동 저장이 안 되고(되돌릴 지점이 안 남는다), 나중에 `no-main-push` 훅에 막혀 올리지도 못한다.

프로젝트의 AGENTS.md에서 **프로젝트 연결 정보(adapter)**를 확인한다 — 항목은 [references/bootstrap-project.md](references/bootstrap-project.md) §4가 정한다(적용 규칙 요약 포함).
없으면 [references/bootstrap-project.md](references/bootstrap-project.md)로 도입부터.

## 철칙

0. **부품-우선**: 그 일을 하는 기존 부품이 있으면 반드시 그걸 쓴다. 새로 만드는 건 최후.
1. 제품 코드(화면·부품)는 값을 **`context.*` 이름으로만** 꺼낸다 (`context.colors.onSurfaceVariant`·`context.space.s4`·`context.radius.card`·`context.text.b1`·`context.motion.base`). `Theme.of(context).colorScheme`·`Theme.of(context).textTheme`·`Theme.of(context).extension<…>()`으로 이 이름을 건너뛰지 않는다 — 그 길은 `lib/core/design/` 안에서만 쓴다.
2. 원시 값(`Color(0x…)`·`Colors.*`·간격·글자 크기·둥글기 숫자·`Duration(milliseconds: …)`·`Curves.*`)은 **`foundation.dart` 안에서만** 쓴다. 2층(`semantic.dart`)은 1층 상수만 가리킨다.
3. foundation은 **읽기 전용** — 고치는 게 아니라 통째로 교체하는 대상. 화면·부품은 `foundation.dart`를 import하지 않는다.
4. **겉모양을 고치는 차례는 2층 값 → 감싸개 부품의 variant → 감싸개 부품 파일**이다. 화면에서 `style:`·`color:`·`shape:`로 부품 겉모양을 덮어쓰지 않는다 ([references/component-taxonomy.md](references/component-taxonomy.md) §4).
5. **글자 배율에 견딘다** — 아래 「글자 배율 규칙」. 앱 전체에서 시스템 글자 크기를 막거나 낮게 묶지 않는다.
6. **화면 전체 폭(`MediaQuery.sizeOf`)은 셸만 읽는다.** 부품이 자리에 맞추는 것은 `LayoutBuilder`(부품이 받은 자리의 폭을 읽는 위젯)로 한다 ([references/layout-frames.md](references/layout-frames.md) §5).
7. **화면 글자는 문구 파일에서 꺼낸다** — 사용자에게 보이는 글자를 화면 코드에 직접 쓰지 않고 `lib/l10n/`의 `.arb` 문구 파일(다국어 문구를 언어별로 모아 두는 파일)에서 꺼낸다. 지금은 한국어만 넣지만 구조는 처음부터 다국어다. 그래서 부품은 글자 길이가 언어마다 달라도 깨지지 않게 짓는다(글자 배율 규칙과 같은 처방).

## 강조색은 어디에 쓰나

강조색(2층 `primary`, 그리고 같은 색에서 진하게·옅게 뽑은 2층 이름 `primaryContainer` 등)은 **세 자리에만** 쓴다.

1. **화면마다 그 화면의 주 행동 하나** — 강조색으로 꽉 찬 주 버튼(`AppButton(variant: AppButtonVariant.primary, …)`). 한 화면에 하나다.
2. **지금 선택된 것** — 고른 칩, 지금 탭(하단 탭의 선택 표시), 지금 고른 항목의 표시.
3. **입력 중인 자리 표시(포커스)** — 지금 글을 치고 있는 입력칸의 테두리, 외부 키보드·스위치 제어로 옮겨 간 자리의 표시.

그 밖(장식 선·제목 글자·로고·아이콘·태그·배경 무늬)에는 쓰지 않는다. 서비스를 알리는 색은 강조색이 아니라 아래 「브랜드 색은 어디에 쓰나」의 브랜드 색이 맡는다.

**왜 이렇게 좁히나** — 강조색은 사람에게 「여기를 누르세요」, 「지금 여기 있습니다」라고 알리는 신호다. 장식·제목·로고에도 같은 색이 흩어지면 신호가 여러 곳에서 동시에 켜진 셈이라, 사람은 「지금 무엇을 눌러야 하나」를 찾지 못한다. 반대로 주 행동이 있는 화면에 강조색 주 버튼이 없으면 신호가 아예 꺼져 있어, 사람이 화면을 다 읽고 나서야 할 일을 찾는다. 세 자리에만 쓰면 강조색이 보이는 곳이 곧 「누를 곳·지금 자리」라서, 처음 온 사람도 화면을 훑자마자 다음 행동을 안다.

- **주 행동은 전용 부품이 맡아도 된다** — 주 행동은 `AppButton`이 아니라 전용 부품(찍기 단추·보내기 막대 등)이 맡아도 된다 — 그때는 그 부품 하나가 강조색 자리다. 바뀐 조작의 대상(끌어 놓는 카드·명령창의 실행 줄·여럿 고르기 막대의 실행 단추 등)과 은유 안(입체 장면·게임판·지도 등)에서도 같다 — 같은 일을 하는 대체 경로 버튼은 테두리 버튼이고, 은유 안의 「지금 선택된 것·오늘」에는 강조색을 쓸 수 있으되 장식에는 쓰지 않는다. 여러 걸음으로 된 화면(가입 1→2처럼)은 걸음마다 주 버튼 하나다.
- **그 화면만의 주 행동이 없으면 상단 바의 대표 행동이 주 버튼이 된다** — 예: 목록을 훑기만 하는 화면에서는 「새로 만들기」(상단 바 행동이나 떠 있는 버튼)가 강조색 주 버튼이다. 그 화면만의 주 행동이 있는 화면에서는 상단 바의 대표 행동을 테두리·글자 버튼으로 낮춰, 한 화면에 강조색 주 버튼이 하나만 남게 한다.
- **화면마다 주 행동이 무엇인지는 프로젝트가 정한다** — idea-to-mvp 프로젝트는 `mvp/feature-list.md` 6절 화면 목록의 「주 행동」 칸이 정본이다.
- **Material의 `secondary`·`tertiary`는 두 번째 강조색이 아니다** — Material 3는 선택 표시(하단 탭 표시·고른 칩)에 `secondaryContainer`를 쓴다. 그래서 `theme.dart`가 `secondary`·`tertiary` 계열을 강조색 계열(`primary`·`primaryContainer`)로 잇는다 — 다른 색상이 몰래 두 번째 강조색이 되지 않게 한다 ([references/bootstrap-project.md](references/bootstrap-project.md) §1.3).
- **밝은 강조색을 진하게·옅게 나눠 쓸 때도 자리는 이 셋이다** — 나누는 법은 [visual-polish.md](references/visual-polish.md) D4.
- **상태 색(성공·위험)은 강조색이 아니다** — 그 뜻을 알릴 때만 쓴다 (아래 안티패턴 표).

## 브랜드 색은 어디에 쓰나

브랜드 색(2층 확장 `AppBrand`의 `context.brand.surface`와 그 짝 `context.brand.onSurface`·면 위 회색 글자 짝 `context.brand.onSurfaceMuted`)은 「이 서비스다」를 알리는 색이다. 강조색이 「여기를 누르세요」를 알리는 신호라면, 브랜드 색은 분위기다. 둘이 섞이지 않게 **모양으로 가른다** — 브랜드 색은 화면 폭을 가로지르는 넓은 면에만 쓰고, 버튼처럼 작은 덩어리에는 쓰지 않는다.

쓰는 자리는 프로젝트가 정한 목록뿐이다. 기본 목록은 다섯이다.

1. 앱을 처음 열 때 보는 소개 화면의 맨 위 띠 — 화면 폭 전체(화면 좌우 여백 `context.layout.screenX` 밖까지 — 셸이 그 자리를 준다, [layout-frames.md](references/layout-frames.md) §3.2), 높이는 화면의 3분의 1 이하
2. 빈 상태 그림의 바탕
3. 완료 화면의 위쪽 면
4. 로그인·가입 화면의 로고 뒤 작은 면
5. 로고·앱 아이콘 안의 모양

프로젝트가 자리를 더할 수 있다 — 예: 핵심 행동 화면(작업 화면)의 바탕 면(격자·보드·편집 영역의 둘레).

- **맨 위 띠는 남발하지 않는다** — 띠는 넓은 면 중에서도 눈에 가장 크게 들어와, 화면마다 되풀이하면 어디도 기억에 남지 않는다. 기본은 앱을 처음 열 때 보는 소개 화면 한 곳이고, 다른 화면에 띠를 더하는 것은 프로젝트가 이유와 함께 목록에 적을 때만이다. 2-3 개성 입히기의 판이 홈 같은 다른 화면을 대표 장면으로 바꿔도 화면 폭 전체 띠는 소개 화면에만 둔다.
- **버튼·칩·태그·아이콘·제목 글자에는 쓰지 않는다** — 작은 색 덩어리는 사람이 「누를 곳」으로 읽는다.
- **한 화면에 브랜드 색 면은 하나다** — 프로젝트가 대표 장면에 여러 겹 면을 정했으면 그 장면만 예외다.
- **면 위 주 버튼은 면과 대비 3:1 이상**(WCAG 1.4.11), 면 위 글자는 4.5:1 이상이다. 못 맞추면 버튼을 면 밖으로 내리거나 면 값을 옅게 한다. 면 위 회색 글자(`onSurfaceVariant`)가 4.5:1을 못 넘으면 2층 이름을 면 안에서 덮어쓰지 않고, 면 전용 짝 `context.brand.onSurfaceMuted`를 쓰거나 면을 옅게 한다. 진한 면이면 주 버튼은 면 밖이 기본이고, 면 위에는 테두리 버튼만 둔다. 질감·그라데이션 면은 가장 나쁜 자리로 잰다. 이 대비는 `contrastPairs`에 줄로 올려 단위 테스트가 건다 ([bootstrap-project.md](references/bootstrap-project.md) §1.5).
- **면은 바탕(`context.colors.surface`)과 대비 1.2:1 이상이다** — 이보다 낮으면 면이 바탕에 묻힌다. 바탕이 흰색이 아닌 옅은 색이면 램프의 가장 옅은 단계는 바탕과 거의 같으니 한두 단계 진한 쪽이나 아주 진한 끝에서 고른다.
- **2층에 이미 다른 이름으로 이어진 단계는 쓰지 않는다** — `primaryContainer`·`secondaryContainer`(Material 3의 선택 표시)·`surfaceContainer*`처럼 상태나 다른 면의 바탕과 같은 값이면, 브랜드 색 면이 「선택된 것」처럼 읽힌다.
- **프로젝트가 브랜드 색을 정하지 않았으면 쓰지 않는다** — 그때 `AppTokens.light`의 `brand`는 기본 묶음 `AppBrand.none`이다. 면 색은 지금 `surface`와 같고 사진 보정은 0이라, 이 이름을 불러도 화면이 달라지지 않는다. 지금처럼 강조색 세 자리 규칙만 있는 것과 같다.
- **사진 톤(`context.brand.photoTone`)은 색 면이 아니다** — 사진을 고치지 않고 밝기·채도·따뜻함만 보정하는 값 묶음이고, 씌우는 일은 공통 부품 하나가 맡는다. 위 자리 목록과 상관없다.
- 자리 목록을 더하거나 빼는 결정과 그 이유는 프로젝트가 기록한다 — idea-to-mvp 프로젝트는 `mvp/design-brief.md` 「13. 개성」이 정본이다.

**머무는 공간 안 색** — 사용자가 들어가 둘러보는 공간(idea-to-mvp 2-4)의 그림 층 안에서는 물건이 제 색을 쓴다(나무는 나무색, 화분은 초록). 브랜드 2층 이름만 쓰면 공간이 한 계열로 칙칙해지기 때문이다. 대신 둘을 지킨다. ① 물건 색은 공간 팔레트 한 곳에만 둔다 — 비교안 동안은 판 토큰 파일 `lib/core/design/drafts/stay.dart` 안 `Stay{수단}Palette`, 정한 뒤는 `lib/core/design/stay/{수단}_palette.dart`의 `{수단}Palette`(이름 붙은 `Color` 상수, 16개 안팎). 둘 다 `lib/core/design/` 안이라 검사 1번 대상 밖이다. 공간 부품(연결 정보 `STAY_PARTS:`)만 그 파일을 `import`한다 — 제 색이 공간 밖 화면으로 번지지 않게(검사 19번). ② 신호 자리(지금 고른 물건·오늘·주 행동)는 그대로 2층 이름(`context.colors.primary` 등, 수단 안이면 2층 확장 `App{수단}`)이고, 팔레트에 강조색과 헷갈리는 색을 두지 않는다. 공간 밖(그림 층 위 글 층·내용 판·버튼)은 이 문서의 규칙 그대로다. 점검 항목은 [visual-polish.md](references/visual-polish.md) J 묶음.

## 결정 트리

**새 화면이 필요하다** (frame-first — 콘텐츠부터 쓰지 말 것)
1. 셸 선택: 프레임 인벤토리 검색 → 그대로 맞으면 재사용 · 뼈대(영역 구성·예산)는 같고
   표현만 다르면 셸 부품의 `variant` · 영역 구성부터 다르면 독립 셸 신설
   → [references/layout-frames.md](references/layout-frames.md) §2.1
   ⚠️ 여럿이 공유하는 셸의 기본 규칙 직접 수정 금지 — 사용처 전부가 같이 바뀐다
2. 기존 패턴에 맞나? 맞으면 패턴 재사용, 콘텐츠만 교체
3. 그다음에야 부품·토큰 선택으로 내려간다

**새 UI 요소가 필요하다** (component-first)
1. 부품 인벤토리 검색 — 동의어로도 (예: "모달?" → `AppDialog` 항목)
2. 있다 → 재사용. 살짝 다르면 그 감싸개의 variant 열거형에 값을 더한다 (새 부품 금지). 모양이 기본과 다를 때 고치는 차례는 [references/component-taxonomy.md](references/component-taxonomy.md) §4
3. 없다 → Material 부품 목록에서 찾는다. 테마만으로 맞으면 Material 것을 바로 쓰고, variant나 누르는 크기가 걸리면 `lib/shared/components/ui/`에 감싸개를 만든다 ([references/component-taxonomy.md](references/component-taxonomy.md) §4)
4. Material에도 없다 → 역할 분류 + 범용/전용 판정 후 전용 부품 신규 생성 → [references/component-taxonomy.md](references/component-taxonomy.md)
5. 인벤토리에 등록 — 적기 전에 한 줄 색인 형식([references/component-taxonomy.md](references/component-taxonomy.md) §6)인지 확인. 값·사용법·변경 이력은 인벤토리가 아니라 부품 파일 머리 주석·git log 몫이다

**값(색·간격·모서리…)이 필요하다** (semantic-first)
1. semantic에 의미가 맞는 토큰이 있나? → [references/naming-taxonomy.md](references/naming-taxonomy.md) 유형표로 탐색
2. 있다 → 쓴다
3. 없다 → semantic에 추가 → [references/naming-taxonomy.md](references/naming-taxonomy.md) §5
4. foundation에 기본 값 자체가 없다? → 그때만 foundation 확장 검토 (드묾, 신중히)

간격·둥글기·글자처럼 2층 단계에 이미 있는 값은 그 이름(`context.space.s4`·`context.radius.card`·`context.text.b1`)을 쓴다 — 새 토큰을 만들지 않는다.

## 안티패턴

| ✗ 금지 | ✓ 대신 |
|---|---|
| 색 하드코딩 (`Color(0xFF333333)`, `Colors.white`, `Colors.blue`, `CupertinoColors.*`) | 2층 색 이름 (`context.colors.primary`·`context.colors.onPrimary`) |
| 숫자 간격 (`EdgeInsets.all(13)`, `SizedBox(height: 18)`) | 간격 단계 (`EdgeInsets.all(context.space.s3)`, `Column(spacing: context.space.s3)`) |
| 숫자 글자 크기 (`fontSize: 15`, `copyWith(fontSize: …)`) | 글자 단계(`context.text.b1`), 안 맞으면 부품 전용 글자 토큰 새로 만들기 (naming-taxonomy.md §2) |
| 숫자 둥글기 (`BorderRadius.circular(14)`) | 둥글기 이름 (`BorderRadius.circular(context.radius.card)`) |
| 화면·부품에 움직임 값 직접 쓰기 (`Duration(milliseconds: 300)`, `Curves.easeOut`) | 2층 움직임 이름 (`context.motion.base`·`context.motion.standard`). 「동작 줄이기」 설정은 `context.motion`이 한 곳에서 처리한다 — [bootstrap-project.md](references/bootstrap-project.md) §1.4 |
| `Theme.of(context).colorScheme.primary`로 2층 건너뛰기 | `context.colors.primary` — Material 이름과 우리 이름이 한 묶음에 있다 |
| 화면·부품이 `foundation.dart`를 import (`Palette.brand600`) | 2층 이름 — 1층은 2층만 읽는다 |
| 색 있는 바탕 위 글자색을 따로 고름 | `on` 짝 (`primary` 위에는 `onPrimary`) — 바탕이 바뀌면 글자도 따라가야 함 |
| 화면에서 부품 겉모양 덮어쓰기 (`FilledButton(style: FilledButton.styleFrom(backgroundColor: …))`, `AppButton`에 색 넘기기) | 2층 값 → 감싸개 variant → 감싸개 파일 차례로 ([component-taxonomy.md](references/component-taxonomy.md) §4). 화면이 부품에 주는 것은 배치(바깥 여백·폭·`Expanded`)뿐 |
| 버튼·입력칸을 Material 것으로 화면에서 바로 씀 (`ElevatedButton(…)`) | 감싸개(`AppButton`·`AppTextField`) — variant와 누르는 크기 48dp가 거기서 정해진다 |
| 개념이 같은데 새 부품 생성 (예: `AppDialog` 있는데 `PopupBox` 신설) | 인벤토리 정본 재사용 + variant |
| 목록 항목마다 카드로 감싸기 / 카드 중첩 | 밀집 데이터는 행(`ListTile` 계열)으로 |
| 상태색(위험·성공)을 장식용으로 사용 | 상태색은 의미 전달에만 |
| 강조색을 장식·제목·로고·아이콘에 칠함 | 강조색은 주 버튼 하나·선택된 것·포커스 표시에만 — 「강조색은 어디에 쓰나」 |
| 브랜드 색(`context.brand.surface`)을 버튼·칩·태그·아이콘에 칠하거나, 한 화면에 브랜드 색 면을 둘 이상 둠 | 브랜드 색은 프로젝트가 정한 넓은 면 자리에만, 화면당 하나(대표 장면만 예외) — 「브랜드 색은 어디에 쓰나」 |
| 무거운 패키지(3D·지도 등)를 정해진 부품 밖에서 부름 | 프로젝트가 정한 부품 목록 안에서만 — 디자인 규칙 검사 18번이 잡는다 ([visual-polish.md](references/visual-polish.md) I8) |
| 바뀐 조작·은유에 같은 일을 하는 평범한 길(버튼·목록)이 없음 | 같은 화면에 대체 경로를 둔다 — [visual-polish.md](references/visual-polish.md) I9 |
| 주 행동이 있는 화면에 강조색 주 버튼이 없음 (또는 둘 이상) | 그 화면의 주 행동 하나를 강조색 주 버튼으로, 나머지는 테두리·글자 버튼 — 그 화면만의 주 행동이 없으면 상단 바의 대표 행동이 주 버튼 |
| 글자 크기를 계속 줄여 위계 표현 (14 밑으로) | 굵기(`FontWeight.w500` 등) + 글자색 단계(`onSurfaceVariant`·`subtle`) 위계로 표현, 가장 옅은 단계도 대비 4.5:1 유지 ([naming-taxonomy.md](references/naming-taxonomy.md) §2) |
| 글자가 든 상자의 높이를 숫자로 고정 (`SizedBox(height: 48, child: Text(…))`) | 최소 높이만 둔다 (`ConstrainedBox(constraints: BoxConstraints(minHeight: context.layout.touchMin))`) — 「글자 배율 규칙」 1 |
| `Row` 안의 긴 `Text`를 그대로 둠 | `Expanded`·`Flexible`로 감싸거나 줄바꿈 허용 — 「글자 배율 규칙」 2 |
| 앱 전체 글자 배율을 막거나 낮게 묶음 (`TextScaler.noScaling`, 앱 바깥의 `MediaQuery.withClampedTextScaling`) | 막지 않는다. 한 부품에 상한이 꼭 필요하면 그 감싸개 안에서만, adapter 예외 줄에 이유와 함께 |
| 실행 중 인터넷으로 서체를 받음 (`google_fonts` 패키지) | 서체 파일을 앱에 넣고 `pubspec.yaml`에 등록 ([references/font-loading.md](references/font-loading.md)) |
| 하단 상시 요소(버튼 막대·입력창·탭바)를 `Stack`으로 화면에 띄우고 본문 끝을 어림 여백으로 비우기 | 셸 설계 때 하단 영역을 정하고 거기 흐름대로 — 스크롤은 본문 영역만 ([references/layout-frames.md](references/layout-frames.md) §2.2) |
| 화면이 `MediaQuery.sizeOf(context)`로 폭을 재서 갈래를 나눔 | 부품은 `LayoutBuilder`로 자기 자리를 본다. 화면 전체 폭은 셸만 ([layout-frames.md](references/layout-frames.md) §5) |
| 화면 글자를 코드에 직접 씀 (`Text('저장')`) | 문구 파일에서 꺼낸다 (`Text(context.l10n.save)` 같은 꼴 — 이름은 앱 뼈대가 정한다) |
| 안내 문구(`hintText`)를 라벨 대신 씀 | 이름(`labelText` 또는 따로 단 라벨)을 단다 — [common-patterns.md](references/common-patterns.md) §2 (WCAG 3.3.2) |
| 아이콘만 있는 버튼에 이름이 없음 | `tooltip`이나 `Semantics(label: …)` — 같은 문서 §2 (WCAG 4.1.2) |
| 엔터로 확정하는 입력란에서 한글 조합 중 제출 | 조합 중이면 무시 — 같은 문서 §3 |
| 제목 입력란에서 완료 키를 누르면 글이 그대로 올라감 | 다음 칸으로 넘긴다(`TextInputAction.next`) — 같은 문서 §3 |
| 사용자가 쓴 글을 저장 형식으로 변환하고 미리보기로 메움 | 쓴 것이 그대로 올라가게 — 같은 문서 §6 |
| 댓글·채팅 입력을 한 줄 입력으로 | 쓰는 만큼 늘어나는 글 입력란(`minLines`·`maxLines`) — 같은 문서 §5 |
| 홈 최상단을 추천 슬라이드·기획전 배너로 연다 | 검색·카테고리 같은 탐색 진입점을 먼저 — 같은 문서 §1 (관찰 37곳 중 0곳) |
| 게시판 커뮤니티 홈에 자동으로 도는 배너를 넣는다 | 커뮤니티엔 두지 않는다 — 같은 문서 §1 (관찰 18곳 중 0곳) |

## 동심원 radius 규칙

패딩 있는 상자 안의 요소 모서리는 `max(0, 바깥 radius − padding)`.
(카드 안 버튼이 어색하게 각져 보이는 문제 방지. 숫자로 따로 적어 어긋나게 하지 말 것.)
2층 `AppRadius`가 기준값 하나(`base`)에서 `control`·`card`·`sheet`를 파생하고, 안쪽 모서리는 `context.radius.inner(outer: …, padding: …)` 도우미로 계산한다 ([references/naming-taxonomy.md](references/naming-taxonomy.md) §4).

## 글자 배율 규칙

폰 설정에서 글자를 키우면 앱 글자도 커진다. 이전 앱에서 확인한 교훈: 큰 글자에서 넘치는 곳은 거의 늘 세 자리였다.

1. **높이를 숫자로 고정한 상자 안의 글자** → 높이를 고정하지 않고 최소 높이만 둔다 (`BoxConstraints(minHeight: …)`). 버튼·입력칸의 48dp도 「최소」다.
2. **`Row`(가로 줄) 안의 `Text`** → `Expanded`·`Flexible`로 감싸거나 줄바꿈을 허용한다. 줄 수를 막을 때(`maxLines`)는 `overflow: TextOverflow.ellipsis`를 같이 준다.
3. **`GridView`의 가로세로 비율 고정**(`childAspectRatio`) → 글자 배율에 따라 비율을 바꾸거나, 높이를 내용에 맞추는 배치(`Wrap`, 행마다 `IntrinsicHeight` 대신 내용 높이를 따르는 목록)로 바꾼다.

- **검사로 잡는 것** — 화면마다 글자 배율 2.0에서 그리는 위젯 테스트를 둔다. Flutter 테스트는 넘침(오버플로) 오류가 나면 실패하므로 「넘침 없음」은 화면 밖 검사로 잡힌다. 도우미 자리는 [references/bootstrap-project.md](references/bootstrap-project.md) §1.7.
- **사람이 보는 것** — 「큰 글자에서도 보기 좋은가」는 여전히 사람이 목업 캔버스·폰에서 본다.
- **언어가 늘어도 같은 처방이다** — 다른 언어의 글자가 한국어보다 길어져도 위 세 자리에서 넘친다.

## 디자인 규칙 검사가 잡는 것

`.claude/scripts/design-check.sh`가 아래 19개 규칙을 grep으로 찍는다. 스크립트는 명령만 돌리고 늘 0으로 끝나며, 걸린 줄의 판정은 메인과 사람이 한다(판정 기준·예외 처리의 정본은 idea-to-mvp 3단계 문서의 배포 전 검사 ①). 검사 대상은 `lib/features/`·`lib/shared/components/`(감싸개 폴더 `ui/`는 대부분 뺀다)·`lib/app/`(셸 포함)·`lib/dev/drafts/`·`lib/dev/design_system/`이고, `lib/core/design/`은 빠진다.

| # | 검사 | 지키는 규칙 |
|---|---|---|
| 1 | `Color(0x`·`Color.fromARGB`·`Color.fromRGBO`·`Colors.`·`CupertinoColors.` 0건, 숫자를 넣은 `EdgeInsets.*(…)`·`SizedBox(width:/height: 숫자)`·`fontSize:`·`BorderRadius.circular(숫자)`·`Radius.circular(숫자)` 0건 (`0`·`EdgeInsets.zero`는 허용) | 철칙 2 |
| 2 | 화면·부품이 `core/design/foundation.dart`를 import하는 곳 0건 | 철칙 3 |
| 3 | `MediaQuery.of(context).size`·`MediaQuery.sizeOf` 사용이 셸(`lib/app/shell.dart`) 밖에서 0건 | 철칙 6 |
| 4 | 부품 파일 목록 ↔ 부품 인벤토리 「전체 부품 색인」 대조 | [component-taxonomy.md](references/component-taxonomy.md) §6.1 |
| 5 | `onSubmitted`·`onEditingComplete`·`TextInputAction.done/send/search`를 쓰는 곳을 찍어, 한글 조합 중 제출을 막았는지 사람이 확인 | [common-patterns.md](references/common-patterns.md) §3 |
| 6 | 하단 고정 요소가 셸 밖에 `Stack`+`Positioned(bottom:)`으로 떠 있지 않은지, 셸이 `SafeArea`(또는 `MediaQuery.paddingOf`)로 안전 영역을 처리하는지 | [layout-frames.md](references/layout-frames.md) §2.2 |
| 7 | `Theme.of(context).colorScheme`·`.textTheme`·`.extension<` 직접 사용 0건 — 우리 확장 이름만 | 철칙 1 |
| 8 | `MediaQuery.disableAnimationsOf`를 읽는 전역 장치가 `lib/core/design/tokens.dart`에 한 곳 있는지 | [bootstrap-project.md](references/bootstrap-project.md) §1.4 |
| 9 | `Duration(milliseconds:`·`Duration(seconds:`·`Curves.`·`Cubic(` 사용이 `foundation.dart` 밖에서 0건 | 철칙 2 |
| 10 | 화면 파일마다 `AppButtonVariant.primary` 개수 ↔ 화면 목록 「주 행동」 칸 (`variant`는 기본값 없는 필수 인자라 모든 주 버튼이 이 글자로 찍힌다) | 「강조색은 어디에 쓰나」 |
| 11 | 화면이 부르는 `context.space.*` 이름이 프로젝트 「화면 규칙」 허용 목록 안인지 | [naming-taxonomy.md](references/naming-taxonomy.md) §2 space 행 |
| 12 | 높이를 숫자로 고정한 `SizedBox`·`Container` 안의 `Text` 찍기 | 「글자 배율 규칙」 1 |
| 13 | `lib/main_prod.dart`와 그것이 부르는 파일이 `lib/dev/`를 import하는 곳 0건 | [bootstrap-project.md](references/bootstrap-project.md) §6 |
| 14 | `lib/features`·`lib/shared`에서 Firebase `.instance` 직접 호출 0건 | 앱 코드 규칙(디자인 밖 — 같은 스크립트가 함께 돈다) |
| 15 | 앱 글자 배율을 막는 코드(`TextScaler.noScaling`·`textScaleFactor`·`MediaQuery.withNoTextScaling`·`TextScaler.linear(1)`) 0건 (`ui/`·`lib/app/` 포함) | 「글자 배율 규칙」 |
| 16 | 화면·부품에 글자를 직접 쓴 `Text('…')`·`Text("…")` 0건 (`lib/features`·`lib/shared/components`·`lib/app`, `ui/`·`lib/dev` 제외) — 문구는 `.arb`에서 꺼낸다 | 철칙 7 |
| 17 | 브랜드 색 면(`context.brand.surface`·`context.brand.onSurface`)을 쓴 파일이 AGENTS.md 연결 정보의 `BRAND_PARTS:` 목록 밖에 0건 (`lib/features`·`lib/shared/components`·`lib/app`, `lib/dev` 제외). 브랜드 색을 아직 안 들였으면(`AppTokens.light`의 `brand`가 `AppBrand.none`) 「해당 없음」으로 따로 적는다 — 통과와 다르다. 들였는데 목록 줄이 없으면 걸린 줄로 센다 | 「브랜드 색은 어디에 쓰나」 |
| 18 | AGENTS.md 연결 정보의 `HEAVY_PKGS:` 패키지(3D·지도 등 무거운 것)를 `import 'package:…/…'`로 부르는 파일이 `HEAVY_PARTS:` 목록 밖에 0건 (`lib/`에서 `lib/dev/` 제외). `HEAVY_PKGS:` 줄이 없으면 「해당 없음」으로 따로 적는다 — 통과와 다르다. `HEAVY_PKGS:`는 있는데 `HEAVY_PARTS:`가 없으면 「목록 줄 없음」으로 걸린 줄로 센다. 목록에 있는데 파일이 없으면 참고로 적는다 | 안티패턴 표, [visual-polish.md](references/visual-polish.md) I8 |
| 19 | AGENTS.md 연결 정보의 `STAY_PALETTE:` 공간 팔레트 파일(머무는 공간의 물건 제 색)을 `import`하는 파일이 `STAY_PARTS:` 목록 밖에 0건 (`lib/`에서 `lib/dev/`와 `lib/core/design/` 제외). `STAY_PALETTE:` 줄이 없고 `lib/core/design/stay/*_palette.dart`도 없으면 「해당 없음」으로 따로 적는다 — 통과와 다르다 | 위 「머무는 공간 안 색」 |

grep으로 못 잡는 것 — 토큰을 맞는 자리에 썼는가(본문에 캡션 전용 글자 토큰을 씀 같은 것), 강조색을 장식에 썼는가(`context.colors.primary`를 아이콘에 칠함), 큰 글자에서 보기 좋은가 — 는 adapter의 적용 규칙 요약을 아는 쓰는 쪽과 사람의 눈이 맡는다. 오탐·누락이 두 번 이상 문제가 되면 Dart 분석기 플러그인(우리 규칙을 `flutter analyze` 안에 넣는 장치)으로 옮긴다.

화면 밖에서 숫자로 거르는 디자인 검사가 둘 더 있다 — 둘 다 단위 테스트다: ① 2층 글자색·바탕색 짝의 대비가 기준 이상인지 ([bootstrap-project.md](references/bootstrap-project.md) §1.5) ② 화면마다 글자 배율 2.0에서 넘침이 없는지 (§1.7).

## 어느 문서를 언제 읽나

- **값(색·간격·모서리…) 이름을 정하거나 새 토큰을 추가할 때** — [naming-taxonomy.md](references/naming-taxonomy.md) (이름 문법·유형표 + 새 토큰을 1층 → 2층 확장 → 접근 확장에 잇는 절차)
- **새 부품을 만들거나 감싸개를 고치거나 인벤토리에 등록할 때** — [component-taxonomy.md](references/component-taxonomy.md) (역할 분류·범용/전용·이름 규칙·variant 열거형 작성·고치는 차례·인벤토리 색인)
- **홈 첫 화면에 무엇을 먼저 둘지 정할 때** — [common-patterns.md](references/common-patterns.md) §1 (SaaS / 커머스 / 마켓플레이스 / O2O / 커뮤니티 / SNS / 사람 매칭 / 혼자 쓰는 기록·도구형 여덟 유형의 최상단 차례와 로그인 전후 갈래 · 관례는 기본값이고 사용자 결정이 우선, 다르게 정하면 이유와 함께 기록)
- **댓글창·게시글 에디터처럼 글을 써서 올리는 입력란을 만들 때, 접근성을 훑을 때** — [common-patterns.md](references/common-patterns.md) §2~§7 (접근성 점검 목록 · 한글 조합 · 컴포저 · 에디터)
- **새 화면·레이아웃을 설계할 때** — [layout-frames.md](references/layout-frames.md) (frame-first 절차, 셸 분류, 하단 고정 요소, 컨테이너 정책, 안전 영역, 작은 폰·큰 폰)
- **참고 앱·사이트·스크린샷에서 스타일 값을 뽑을 때, 또는 그렇게 뽑아 브리프에 적어 둔 값을 토큰으로 옮길 때** — [reference-analysis.md](references/reference-analysis.md) (고르는 법·갤러리 · 입력 다섯 종류와 값 뽑는 법 · 분석 항목표 · 분석값 → 1층 상수·2층 역할 이름 · 금지)
- **화면 생김새를 개선할 때** — [visual-polish.md](references/visual-polish.md) (위계·글자·간격·색·부품·작은 폰으로 옮기기 점검 항목과 지시 문장 예 · 규칙을 디자인 시스템 페이지에 먼저 올리고 비교안을 만들게 한다)
- **「[서비스 이름] 디자인 시스템」 페이지를 만들거나 고칠 때, 비교안 값을 지금 값과 나란히 보일 때** — [bootstrap-project.md](references/bootstrap-project.md) §6 (보여 주는 것 · 값은 실제 테마에서 읽어서 · 정본이 아니라 거울 · 비교안만 감싸는 `Theme` 덮개)
- **개성(그림 소재·브랜드 색 면·제목 서체·로고·사진 톤·대표 장면)을 입힐 때** — [visual-polish.md](references/visual-polish.md) I 개성 묶음과 위 「브랜드 색은 어디에 쓰나」
- **사용자가 들어가 둘러보는 공간(머무는 공간)을 만들 때** — [visual-polish.md](references/visual-polish.md) J 머무는 공간 묶음과 위 「머무는 공간 안 색」
- **서체를 새로 넣거나 바꿀 때** — [font-loading.md](references/font-loading.md) (앱에 서체 파일 넣기·`pubspec.yaml` 등록·가변 서체·한글 서체 용량·`google_fonts`를 쓰지 않는 이유·확인 관문)
- **새 프로젝트에 도입할 때** — [bootstrap-project.md](references/bootstrap-project.md)를 순서대로 따른다. 이 절차는 도중에 세 문서를 함께 읽는다: 토큰 3층 단계에서 font-loading.md(서체 선정·넣는 방식을 같이 정한다 — 미루면 foundation을 다시 갈아엎는다), 인벤토리 생성에서 component-taxonomy.md §6(인벤토리 한 줄 형식), 프레임 정의에서 layout-frames.md §2·§4(하단 고정 요소·작은 폰 예산)
