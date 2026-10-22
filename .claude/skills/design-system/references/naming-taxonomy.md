# 토큰 명명 문법과 유형표

semantic 층(`lib/core/design/semantic.dart`)에 토큰을 추가할 때 따르는 규범. **기존 토큰의 이름·값은 바꾸지 않는다**(이미 쓰는 이름 허용) — 이 문법은 **새로 더하는 것**에만 적용한다.

**이 문서의 용어** (토큰 계층):

| 용어 | 뜻 |
|---|---|
| foundation(1층) | 원시 재료 — 색 램프·간격 단위·글자 크기·둥글기·움직임 원본. `foundation.dart`. 브랜드·디자인 시스템 교체 때 통째로 갈아끼우는 층 |
| semantic(2층) | 의도로 명명한 별칭(`primary`·`error`·`card`…). `semantic.dart`의 `ThemeExtension`들. **화면·부품이 값을 꺼내는 유일한 층** |
| component(3층) | 실제 부품 — `theme.dart`가 조립한 Material 부품 테마와 `lib/shared/components/ui/`의 감싸개, 전용 부품 |
| ramp(램프) | 한 색의 밝기 단계 세트 (예: `Palette.gray50`~`Palette.gray900`) — foundation의 원시 재료 |
| alias(별칭) | 원시 값을 의도 이름으로 다시 가리키는 것 — semantic 층이 하는 일 |
| `on` 짝 | 색 바탕 위에 올라가는 글자·아이콘 색. 바탕 이름 앞에 `on`을 붙인 짝 (`primary` ↔ `onPrimary`). 바탕이 바뀌면 따라감 (§1) |
| 확장 묶음 | `context.colors`처럼 한 유형의 2층 이름을 모은 `ThemeExtension` 하나 — `AppColors`·`AppSpace`·`AppLayout`·`AppRadius`·`AppTextStyles`·`AppShadows`·`AppMotion`·`AppBrand` |
| 유형·역할·변형·상태 | 토큰 이름의 문법 조각 — §1에서 정의 |

## 목차

1. [명명 문법 (grammar)](#1-명명-문법-grammar)
2. [유형표 — 새 토큰의 자리 찾기](#2-유형표--새-토큰의-자리-찾기)
3. [표면 위계 규범 (surface hierarchy)](#3-표면-위계-규범-surface-hierarchy)
4. [radius 위계 참고](#4-radius-위계-참고)
5. [새 토큰 추가 절차](#5-새-토큰-추가-절차)
   - [5.1 자리 찾기](#51-자리-찾기)
   - [5.2 이름 짓기](#52-이름-짓기)
   - [5.3 값 연결](#53-값-연결)
   - [5.4 주석](#54-주석)
   - [5.5 검증](#55-검증)

---

## 1. 명명 문법 (grammar)

**색 — Material `ColorScheme` 문법을 따른다.** 2층 색 이름은 Material이 정한 역할 이름(`primary`·`surface`·`outline`·`error` …)을 쓰고, 프로젝트가 더하는 색도 같은 문법으로 짓는다. 이름을 Material에 맞춰야 `theme.dart`가 `ColorScheme`으로 그대로 옮겨, Material 부품이 같은 색으로 돈다.

```
{역할}        바탕·면·선으로 쓰는 색      예: primary · success · surfaceContainer
on{역할}      그 위에 올라가는 글자·아이콘  예: onPrimary · onSuccess · onSurface
```

- **색 바탕 위 글자는 반드시 `on` 짝으로 분리한다.** 바탕이 바뀌면(테마 교체·다크 모드) 글자색이 자동으로 따라가야 하기 때문이다. 바탕 색을 새로 더하면 짝도 같이 더한다.

  ```dart
  ✗ Container(color: context.colors.primary, child: Text('…', style: TextStyle(color: Colors.white)))
  ✓ Container(color: context.colors.primary,
        child: Text('…', style: context.text.b1.copyWith(color: context.colors.onPrimary)))
  ```

- **Material 이름 중 쓰지 않는 것** — 판에 따라 사라진 이름(`background`·`onBackground`·`surfaceVariant` 등)은 쓰지 않는다. 지금 쓰는 이름은 그 판의 `ColorScheme` API 문서가 정본이다. `secondary`·`tertiary`는 강조색 계열로 이어 두니 화면에서 따로 쓰지 않는다(SKILL.md 「강조색은 어디에 쓰나」).

**색 밖의 값 — 확장 묶음 + 역할·변형·상태 문법.**

```
context.{유형}.{역할}[{변형}][{상태}]      (Dart 이름이라 낮은 낙타 표기로 붙인다)

유형(category) = 확장 묶음: space · layout · radius · text · shadows · motion
역할(role)     = 어떤 의도인가: card · control · sheet · screenX · touchMin …
변형(variant)  = 강도/파생:    Strong · Weak · Light · Deep
상태(state)    = 상호작용:     Pressed · Disabled · Selected
```

예: `context.radius.card` · `context.layout.screenX` · `context.shadows.card` · `context.colors.primaryPressed`.

**대원칙 두 가지:**
- 이름은 *색이 아니라 의도*: `onInfo` ✓ / `blueText` ✗
- 크기는 *숫자보다 용도*: 둥글기·그림자·글자는 용도 이름(`radius.card`·`text.b1`)이다. **간격만 예외로 숫자 단계 이름**(`space.s4` = 4의 4배 = 16)을 쓴다 — 간격은 용도가 너무 많아 이름을 붙이면 금방 수십 개가 되고, 4 단위 격자를 지키는 것이 더 중요하기 때문이다.

## 2. 유형표 — 새 토큰의 자리 찾기

새 토큰 하나는 세 곳에 걸친다 — 값은 `foundation.dart`, 이름은 `semantic.dart`의 확장 묶음 필드, 쓰는 길은 `context.{유형}.{이름}`. Material 부품이 읽어야 하는 색이면 `theme.dart`의 `ColorScheme`에도 잇는다. 「둘 자리」 열이 그 배치다.

| 유형 | 하위 유형 | 예시 | 둘 자리 → 쓰는 이름 | 새로 더할 때 문법 |
|---|---|---|---|---|
| color/brand | 강조 | `primary` · `primaryContainer` | `AppColors` 필드 + `ColorScheme` → `context.colors.primary` | Material 세트에 있으면 그 이름, 없으면 `{역할}` + `on{역할}` 짝 |
| color/brand | 브랜드 색 면 | `AppBrand`의 `surface` · `onSurface` · `onSurfaceMuted`(면 위 회색 글자 짝 — 본 값은 지금 회색 글자 `onSurfaceVariant`와 같게 먼저 두고, 개성을 입힐 때 면 위에서 4.5:1을 넘는 값으로 채운다) — 값은 1층 램프 단계(강조색과 같은 램프의 옅은 쪽·아주 진한 단계, 또는 두 번째 색 램프 — 바탕 `context.colors.surface`와 1.2:1 이상, 2층에 이미 이어진 `primaryContainer`·`secondaryContainer`·`surfaceContainer*` 단계는 피한다) | `AppBrand` 필드(색 이름이 아니라 별도 확장) → `context.brand.surface`·`context.brand.onSurface`·`context.brand.onSurfaceMuted` | 쓰는 자리는 넓은 면뿐, 정해진 전용 부품 안에서만 — design-system `SKILL.md` 「브랜드 색은 어디에 쓰나」. 프로젝트가 브랜드 색을 정하지 않았으면 기본 묶음 `AppBrand.none`(면 색은 `surface`와 같음)이다. 사진 보정 값 `photoTone`(밝기·채도·따뜻함)도 같은 `AppBrand`에 둔다 |
| color/text | 위계 | `onSurface` · `onSurfaceVariant` · `subtle` | `AppColors` 필드 → `context.colors.onSurfaceVariant` | Material 2단(`onSurface`·`onSurfaceVariant`)에 희미 1단(`subtle`)을 더해 셋. 그 이상 늘리지 않는다 |
| color/semantic | 상태 의미 | `error` · `success` · `onSuccess` · `warning` | `AppColors` 필드(`error`는 `ColorScheme`에도) → `context.colors.success` | `{의미}` + `on{의미}` |
| color/surface·line | 면과 선 | `surface` · `surfaceContainerLow` · `surfaceContainer` · `surfaceContainerHigh` · `outline` · `outlineVariant` · `scrim` | `AppColors` 필드 + `ColorScheme` → `context.colors.surfaceContainer` | 표면 위계 규범(§3) 준수 |
| color/control | 부품 전용 | `primaryPressed` | `AppColors` 필드 | `{역할}{부위}[{상태}]` |
| color/domain | 기능 전용 팔레트 | `chart1`~`chart5` · 입체 장면·게임판·지도 같은 은유 수단 안의 색(idea-to-mvp 2-3 파격판이 고른 것 — 장면 재질·판 칸·지도 표시) | `AppColors` 필드. 수단 안의 색은 고른 뒤 새 확장 `App{수단}`(예: `AppBoard`의 `cell`·`cellActive`)으로 두고 `tokens.dart`에 접근 이름을 더한다 → `context.board.cell` | `{도메인}{역할}`·`{수단}{역할}` — 2개 이상 화면에서 쓸 때만. 수단의 색은 2층 이름만 거치고 1층 램프(`Palette.*`)를 바로 읽지 않는다 |
| radius | 용도별 | `base`(기준) · `control` · `card` · `sheet` · `pill` | `AppRadius` 필드 — 대개 `base`에서 ±로 파생 → `context.radius.card` | `{용도}` |
| space | 콘텐츠 간격·여백 | `s1`·`s2`·`s3`·`s4`·`s5`·`s6`·`s8`·`s10`·`s12`·`s16` (4 단위 격자) | `AppSpace` 필드 → `context.space.s4` | 단계 이름은 고정. 화면이 쓸 단계는 프로젝트 「화면 규칙」 허용 목록이 고른다(디자인 규칙 검사 11번). 단계 밖 간격이 정말 필요하면 용도 이름으로 `layout`에 |
| layout/frame-budget | 프레임 계약 값 | `screenX`(화면 좌우 여백) · `touchMin`(누르는 영역 바닥선) · `listRowMin`(목록 한 줄 최소 높이) · `bottomBarGap` | `AppLayout` 필드 → `context.layout.screenX` | `{영역}{치수}` |
| shadow | 용도별 | `card` · `sheet` · `fab` | `AppShadows` 필드(`List<BoxShadow>`) → `context.shadows.card` | `{용도}` |
| motion | 길이·가속 곡선 | `fast`·`base`·`slow` · `standard`·`emphasis` | `AppMotion` 필드 → `context.motion.base` ([bootstrap-project.md](bootstrap-project.md) §1.4) | 길이는 `{속도}`, 곡선은 `{느낌}` |
| typography/family | 글꼴 자체 | 본문 기본 서체, 필요시 제목 서체 | `foundation.dart`의 서체 이름 → `AppTextStyles`의 각 스타일 `fontFamily`·`ThemeData.fontFamily` | `FoundationType.{역할}Family` ([font-loading.md](font-loading.md) §3) |
| typography/weight | 글자 굵기 | 400 · 500 · 700 | `FontWeight.w400`·`w500`·`w700` — 앱에 넣은 굵기만 | 역할 이름이 필요하면 `AppTextStyles`에 굵기를 바꾼 스타일을 따로 |
| typography/scale | 글(prose) 전용 — 제목·본문 | `t1`·`t2`·`h1`·`h2`·`h3`·`b1`·`b2`·`label`·`caption` | `AppTextStyles` 필드(`TextStyle`) → `context.text.b1` | 이름은 시스템 규약으로 고정, 크기 값만 프로젝트별 교체. 안 맞는 크기는 typography/component로. 예외 — 전시용 제목 `display` 한 단계는 대표 장면 한 곳에서만 쓴다(idea-to-mvp 2-3). 본 값은 `t1`과 같게 먼저 두고, 그 한 곳 밖에서 쓰면 안 된다 |
| typography/component | 부품 전용 — 칩·배지·입력칸 라벨·도움말 등 | `chip` · `fieldLabel` | `AppTextStyles` 필드 → `context.text.chip` | `{부품/역할}` — §5 절차로 신규 추가 |

**typography가 두 갈래인 이유:** `t1`~`label` 단계는 **글(prose) 역할** 전용이다 — 제목·본문처럼 화면 구조를 나타내는 글자에만 쓴다. 칩·배지·입력칸 라벨·도움말 같은 **부품 글자**는 이 단계에 억지로 맞추지 않는다 — 실무에서 제일 흔한 이탈 지점이 바로 여기서, 안 맞는 크기를 욱여넣거나 그냥 `fontSize: 13`으로 새 버린다. 부품 글자는 `typography/component` 유형으로 따로 토큰을 만든다(철칙 2는 그대로 지키되, 이름만 부품 전용으로 나누는 것). Material의 `TextTheme` 이름(`bodySmall`·`labelSmall` 등)은 Material 부품이 읽는 이름이라 막지 않고 `theme.dart`가 우리 단계로 다시 이어 둔다 — 화면 코드는 우리 이름을 쓴다.

**글자 크기로 위계를 만들려고 계속 줄이지 않는다.** 그림 위 글자(`caption`)를 뺀 모든 글자는 14 아래로 내려가지 않는다(가독성 바닥). 크기 단계가 좁아져 위계가 안 설 때는 크기를 더 쪼개는 대신 `typography/weight`(400/500/700)와 `color/text` 위계(`onSurface`·`onSurfaceVariant`·`subtle` 세 단)를 함께 써서 위계를 표현한다. 단 가장 옅은 단계도 바탕과의 대비는 4.5:1 이상을 지킨다 — 대비 테스트([bootstrap-project.md](bootstrap-project.md) §1.5)가 숫자로 확인한다. 위계를 만들려다 안 보이는 글자를 만들면 본말전도다.

**기존 코드의 숫자 값 이관은 점진적으로.** 이미 숫자 값이 많은 코드를 한 번에 토큰화하려 들지 말 것 — 과설계 위험이 크고, 각 부품이 어느 역할 토큰에 맞는지 판정하는 데만도 큰 작업이 된다. 대신 그 부품을 **다른 이유로 손댈 때마다** 그 김에 토큰으로 옮긴다. 새로 만드는 부품만 처음부터 토큰으로 — 그러면 시간이 지나며 자연스럽게 정리된다.

**화면·묶음 단위로 토큰을 비례 조정할 때:** 2층 기본 묶음을 덮어쓰지 말고, 바꾼 토큰 한 벌을 만들어 그 범위를 `Theme`으로 감싼다. 값은 **1층 원본 기준**으로 증감폭만 적는다(`FoundationType.b1 - 1`). 목표값을 숫자로 적는 대신 증감폭만 적으면, 원본 값이 나중에 바뀌어도 자동으로 따라가 사람이 다시 계산할 필요가 없다. 숫자를 쓰는 자리라 그 토큰 한 벌은 `lib/core/design/` 안(`semantic.dart`의 이름 붙인 묶음, 예: `AppTextStyles.dense`)에 둔다 — 화면 폴더에 두면 디자인 규칙 검사의 숫자 검사에 걸린다. 비교안을 잠시 두는 자리는 따로 있다(`drafts.dart` — [bootstrap-project.md](bootstrap-project.md) §6.3).

```dart
// semantic.dart — 촘촘한 화면용 글자 묶음. 1층 원본 기준으로 증감만 적는다.
static final dense = regular.copyWith(
  b1: regular.b1.copyWith(fontSize: FoundationType.b1 - 1),
);
// 셸의 변형이나 그 화면 묶음 맨 바깥에서:
// Theme(data: Theme.of(context).copyWith(extensions: [..., AppTextStyles.dense]), child: …)
```

판정 기준 — space vs layout: **프레임 계약에 속하는 값이면 layout, 콘텐츠 사이 간격이면 space.**

## 3. 표면 위계 규범 (surface hierarchy)

바탕·표면 토큰은 **시각 깊이의 위계**로 명명한다. 이름은 Material 3의 표면 계단을 그대로 쓴다:

```
surface                  (화면 바탕 — 셸의 Scaffold 배경)
  → surfaceContainerLow  (카드·목록 묶음 바탕)
  → surfaceContainer     (눌러 볼 수 있는 면·입력칸 바탕)
  → surfaceContainerHigh (떠 있는 면 — 시트·메뉴·대화상자)
```

- 계단을 다 쓸 필요는 없다. 프로젝트가 쓰는 단만 `AppColors`에 두고, 나머지는 `theme.dart`에서 가까운 단으로 잇는다(Material 부품이 읽으니 비워 두지 않는다).
- 새 표면 토큰이 필요하면 이 위계에서 자리를 정한 뒤 이름 붙인다 (예: 대화상자 위에 다시 뜨는 면이 생기면 `surfaceContainerHighest` 같은 상위 깊이로, 그 위 글자는 `onSurface` 계열로 대비를 확인한다).
- **폰 전용이라 「화면 밖 바탕(canvas)」 토큰은 두지 않는다** — 화면이 늘 기기 전체를 덮어 화면 밖이 보이지 않는다.

## 4. radius 위계 참고

값은 기준 하나(`AppRadius.base` ← `FoundationRadius.base`)에서 파생한다(§2 유형표). 용도 이름은 자유지만, 개념적으로는 안쪽→바깥쪽 위계를 따른다:

```
tight(장식) < badge(작은 태그) < control(버튼·입력칸) < card(묶음) < sheet(아래서 올라오는 판) < pill(완전 원형)
```

**동심원 도우미** — 패딩 있는 상자 안 요소의 모서리는 `max(0, 바깥 radius − padding)`이다(SKILL.md 「동심원 radius 규칙」). `AppRadius`에 도우미를 둔다:

```dart
double inner({required double outer, required double padding}) => math.max(0, outer - padding);
// 쓰기: BorderRadius.circular(context.radius.inner(outer: context.radius.card, padding: context.space.s3))
```

## 5. 새 토큰 추가 절차

semantic 층에 토큰을 추가할 때. (foundation 확장은 기본 값 자체가 없을 때만 — 드묾, 신중히.)

### 5.1 자리 찾기

§2 유형표에서 어느 유형·하위 유형(= 어느 확장 묶음)인지 정한다. 기존 토큰으로 되면 추가하지 않는다 (중복 별칭 금지).

### 5.2 이름 짓기

색은 `{역할}` + `on{역할}`, 그 밖은 확장 묶음 안의 `{역할}[{변형}][{상태}]` (§1). 의도로 명명: `onInfo` ✓ / `blueText` ✗.
역할이 한정된 토큰(특정 자리 전용)은 이름에 그 자리를 넣는다 — 예: 그림 위 글자 전용 크기면 이름이 `caption`이 아니라 더 좁게 `imageCaption`이어도 좋다. 이름이 역할을 말해야, 고치는 파일만 읽는 에이전트가 토큰 선택만으로 규칙을 지킨다.

**판 접두 규칙** — idea-to-mvp 2-3처럼 판(`bold`·`innov`·`leap`)마다 비교안을 따로 쓸 때, 그 판의 토큰 파일(`lib/core/design/drafts/{판}.dart`) 안에서 새로 만드는 상수·확장 이름은 판 이름으로 시작한다. 판끼리 이름이 겹쳐 서로 덮어쓰는 일을 막으려는 것이다. 예: 상수 클래스 `BoldPalette.cover900`, 판만의 확장 `BoldBrandExtra`와 그 접근 이름 `context.boldExtra`(접근 이름도 그 파일 안에 둔다 — 검사 7번은 `lib/core/design/` 밖만 본다). 모든 판이 쓰는 이름(`AppBrand.onSurfaceMuted`·`AppTextStyles.display`)은 접두 없이 본 파일에 먼저 올려 둔다. 고른 뒤 전체 적용에서 접두를 떼고 위 유형표 자리로 옮긴다 — `BoldPalette.cover900` → `Palette.cover900`처럼.

### 5.3 값 연결

세 곳(색이면 네 곳)에 한 줄씩 넣는다 — **2층 값은 반드시 1층 상수 참조**:

```dart
// foundation.dart — 원시 값이 없을 때만
static const green600 = Color(0xFF15803D);

// semantic.dart — AppColors: 필드 · 생성자 · light(·dark) · copyWith · lerp에 한 줄씩
final Color success, onSuccess;
success: Palette.green600, onSuccess: Palette.gray0,
success: Color.lerp(success, other.success, t)!,

// semantic.dart — 글자·바탕 짝이면 contrastPairs에도
('onSuccess / success', onSuccess, success, 4.5),

// theme.dart — Material 부품이 읽어야 하는 색일 때만 ColorScheme에
```

`Palette.green600` ✓ / `Color(0xFF15803D)`를 `semantic.dart`에 직접 ✗ — 원시 값을 직접 쓰면 foundation 교체 때 안 따라간다. `copyWith`·`lerp`에 빠뜨리면 비교안 덮개와 테마 전환에서 그 값만 안 바뀐다 — 필드를 더하면 다섯 자리를 모두 채운다.

### 5.4 주석

용처 한 줄 기록 (기존 파일의 주석 스타일 유지).
역할 한정 토큰은 **어디 전용인지, 다른 자리에 쓰면 왜 안 되는지**까지 적는다 — 예: `// 그림 위 글자 전용 — 본문 바닥선(14) 아래 값`.
토큰을 썼다는 이유만으로 규칙을 지킨 것처럼 보이는 걸 막는 장치다 — 에이전트가 반드시 읽는 파일은 고치는 파일뿐이라, 토큰 자신이 역할을 말해야 한다.

### 5.5 검증

`flutter analyze`와 `flutter test`가 둘 다 통과하는지 확인한다 — 대비 테스트(색을 더했을 때)와 글자 배율 테스트가 여기서 돈다. 둘 중 하나만 통과한 것을 「통과」로 보고하지 않는다(`flutter test`는 테스트가 불러오지 않은 파일의 오류를 못 잡는다). 실제 명령 모양(판 고정 도구를 앞에 붙이는지 등)은 프로젝트 AGENTS.md를 따른다.
