# 부품 분류·어휘 규칙

원칙: **분류(역할)는 범용 고정, 어휘(이름)는 프로젝트 사전에 위임.**
프로젝트의 부품 인벤토리(사전) 위치는 각 프로젝트 AGENTS.md에 기록돼 있다(기본 `docs/components.md`).

## 목차

1. [역할 분류 — 6가지](#1-역할-분류--6가지)
2. [어휘 두 갈래 — 범용 vs 전용](#2-어휘-두-갈래--범용-vs-전용)
3. [동의어 규칙 — 하나의 개념 = 하나의 이름](#3-동의어-규칙--하나의-개념--하나의-이름)
4. [작성 규약 (variant 열거형·토큰 계약)](#4-작성-규약-variant-열거형토큰-계약)
   - [4.1 모양이 Material 기본과 다를 때 — 고치는 차례](#41-모양이-material-기본과-다를-때--고치는-차례)
5. [결정 트리](#5-결정-트리)
6. [인벤토리(사전) 형식](#6-인벤토리사전-형식)
   - [6.1 전체 부품 색인](#61-전체-부품-색인)
7. [이식성 — 다른 프로젝트로 옮기기](#7-이식성--다른-프로젝트로-옮기기)

---

## 1. 역할 분류 — 6가지

모든 부품은 6가지 역할 중 하나다.

| 역할 | 하는 일 | 범용 예 |
|---|---|---|
| **action** | 사용자가 누르는 것 | button, FAB(떠 있는 둥근 버튼), link |
| **input** | 값을 받는 것 | text-field, select, checkbox, switch, slider |
| **container** | 내용을 담는 면 | card, bottom-sheet, dialog, section |
| **navigation** | 위치·이동을 다루는 것 | app-bar, navigation-bar(하단 탭), tab-bar, stepper |
| **feedback** | 상태를 알리는 것 | snackbar, progress, skeleton, badge |
| **display** | 정보를 보여주는 것 | list-tile, chip, avatar, thumbnail |

회사마다 부르는 이름이 달라도(toast vs snackbar) 역할은 같다 — 분류는 용어 차이에 오염되지 않는 층.

## 2. 어휘 두 갈래 — 범용 vs 전용

- **범용 부품**: 어느 제품에나 있는 개념 (button, dialog, bottom-sheet, badge, text-field, stepper…).
  **이름은 Material 부품 이름을 따르고 앞에 `App`을 붙인다** — `AppButton`·`AppTextField`·`AppDialog`·`AppBottomSheet`. Material 이름이 곧 Flutter 개발자의 표준명이라 이름만 보고 누구나(사람·AI) 뭔지 알고, `App` 접두어가 「Material 것을 바로 쓰지 말고 이 감싸개로」를 알린다. Material에 없는 범용 개념만 업계 표준 영어명으로 짓는다.
  자리는 `lib/shared/components/ui/`.
- **전용 부품**: 이 제품에만 있는 고유 개념 — 자유 명명 허용. **단, 인벤토리 등록 필수** (§6 색인 한 줄 형식으로).
  자리는 여러 흐름이 쓰면 `lib/shared/components/common/`, 한 흐름만 쓰면 `lib/features/<흐름>/widgets/`. 두 번째 흐름이 쓰기 시작하면 `common/`으로 옮긴다.

## 3. 동의어 규칙 — 하나의 개념 = 하나의 이름

인벤토리에 개념별 **정본(canonical) 이름**을 지정하고, 동의어를 함께 기록한다:

```
정본: AppDialog       ← 이렇게도 부름: modal, popup, alert, 모달, 팝업, 알림창
정본: AppBottomSheet  ← sheet, drawer, 바텀시트, 아래 판
정본: AppBadge        ← chip(정보만 보일 때), tag, pill, 칩, 태그  (눌러서 고르는 칩은 AppChip)
정본: AppTextField    ← input, field, textbox, 입력창  (여러 줄도 같은 부품 — minLines·maxLines)
정본: AppSnackbar     ← toast, 토스트, 알림 띠
```

요청에 동의어가 등장하면("팝업 띄워줘") 정본으로 번역한 뒤 인벤토리를 찾는다.

## 4. 작성 규약 (variant 열거형·토큰 계약)

- **부품은 Dart 파일 하나에 공개 위젯 하나** — 파일 이름은 정본 이름의 뱀 표기(`AppButton` → `app_button.dart`). 개념은 표준어, 쓰임새가 다른 같은 개념은 용도 접두어 허용(`ExitDialog` — 단 내부는 `AppDialog`를 쓴다)
- **변형은 열거형 인자가 고른다** — 같은 부품의 다른 모양은 `variant`·`size` 같은 열거형 인자(`enum AppButtonVariant { primary, secondary, text, danger }`)로 고른다. 새 모양이 필요하면 그 열거형에 값을 더하고 `build`의 `switch`에 갈래를 더한다. 화면이 색·모양 인자를 넘기는 길은 만들지 않는다
- **주 버튼을 고르는 인자는 기본값을 두지 않는다** — `AppButton`의 `variant`처럼 강조색 자리를 정하는 인자는 필수로 둔다. 그래야 모든 주 버튼이 `AppButtonVariant.primary` 글자로 찍혀 디자인 규칙 검사가 화면마다 셀 수 있다
- **화면은 배치만 준다** — 화면이 부품에 주는 것은 바깥 여백(`Padding`으로 감싸기)·폭(`expand`·`Expanded`)·정렬뿐이다. 색·둥글기·글자 같은 겉모양은 부품 안이 정한다
- **값은 전부 2층 이름** — `context.colors`·`context.space`·`context.radius`·`context.text`·`context.motion`. 감싸개 안에서 Material의 `style:`을 만질 때도 값은 2층 이름이다. 이 계약을 지킨 부품만 이식 가능해진다 (§7)
- **누르는 것은 48dp 이상, 높이는 최소로만** — [bootstrap-project.md](bootstrap-project.md) §1.6과 SKILL.md 「글자 배율 규칙」
- **접근 이름** — 아이콘만 있는 버튼은 `tooltip`이나 `Semantics(label:)`를 필수 인자로 받는다 ([common-patterns.md](common-patterns.md) §2)
- **머리 주석 한두 줄** — 그 부품이 무엇이고, 지킬 규칙이 있으면 무엇인지(예: 「주 버튼은 한 화면에 하나」). 자세한 설명의 정본이 여기다 (§6)

### 4.1 모양이 Material 기본과 다를 때 — 고치는 차례

1. **2층 값으로 맞춘다** — 색·둥글기·서체가 다르면 `semantic.dart`의 값과 `theme.dart`의 그 부품 테마(예: `filledButtonTheme`)를 바꾼다. 대부분 여기서 끝난다. 앱 전체의 같은 부품이 함께 바뀐다.
2. **variant를 더한다** — 같은 부품의 다른 모양이 필요하면 감싸개의 열거형에 값을 더한다.
3. **감싸개 파일을 고친다** — 1·2로 안 되면 감싸개 안에서 Material 부품의 `style:`을 2층 값으로 고친다. Material 부품을 감싸개 없이 바로 쓰던 것이면 이때 감싸개를 만들고 AGENTS.md adapter의 「감싸개 부품 목록」에 한 줄 더한다.
4. **화면에서 겉모양을 덮어쓰지 않는다** — `FilledButton(style: FilledButton.styleFrom(backgroundColor: …))`나 `Card(color: …, shape: …)`를 화면에 쓰지 않는다.

## 5. 결정 트리

SKILL.md 「새 UI 요소」 갈래를 따른다 — 여기서는 반복하지 않는다.

## 6. 인벤토리(사전) 형식

- **개념 단위로 등록** — 블록 묶음(예: `calc_*` 위젯 14개)은 1항목으로 묶는다
- **코드가 진실, 사전은 색인** — 부품 추가 절차의 마지막 단계가 "사전에 한 줄 추가"

**이 원칙을 지키는 방법 — 인벤토리든 함정 절이든, 코드나 그 파일 머리 주석을 보면 알 수 있는 값은 적지 않고 가리키기만 한다:**

- **구분은 둘** — 범용(`lib/shared/components/ui/`)과 전용(`lib/shared/components/common/`·`lib/features/*/widgets/`). 등록 단위는 부품 파일이다
- 한 줄 형식: `이름 | 범용/전용 | 한 줄 설명 | 파일 경로`
  variant 목록은 적지 않는다 — 부품 파일의 열거형이 정본이다.
  설명은 **한 문장** — 그게 무엇인지만. 왜 만들었는지·어떻게 쓰는지·어떤 값인지는 적지 않는다.
- **자세한 설명의 정본은 그 부품 파일의 머리 주석이다.** 같은 사실을 인벤토리에 다시 쓰지 않는다.
  두 군데 쓰면 반드시 어긋난다 — 실제로 존재하지 않는 인자 설명, 사용처 0인데 "쓴다"고 적힌 항목, 이미 사라진 사용처 참조가 한 프로젝트에서 동시에 나온 적 있다.
- **무엇이 어떻게 바뀌었나는 적지 않는다** — "예전엔 ~였고 지금은 ~로 바꿨다"는 git log 몫이다. (뭘 하면 터지는지의 사고 이력과는 다르다 — 그건 회귀(regression — 고친 문제가 다시 생기는 것)를 막는 근거라 함정 절에 남긴다.)
- **문서가 이기는 자리는 셋이다** — 인벤토리 항목이 아니라 프로젝트 문서의 별도 "함정" 절에 모은다: ① 여러 파일에 흩어진 걸 모은 집계(예: "`LayoutBuilder`로 폭에 따라 갈리는 부품은 다섯 곳뿐이고 여기 있다"), ② 어느 한 파일에도 안 속하는, 여러 파일에 걸친 절차, ③ 코드에 없는 규칙 — 값의 하한·상한 같은 금지, "팝업이라 부르지 마라" 같은 용어 통제, 위에서 구분한 사고 이력. 항목에 섞으면 길어지고, 길어지면 안 읽힌다.
- **지금 안 쓰는 부품**은 사연 없이 "지금 쓰는 곳 없음" 한 마디로 끝낸다.

```
좋은 예: AppDialog | 범용 | 확인·경고용 대화상자 | lib/shared/components/ui/app_dialog.dart
나쁜 예: AppDialog | 범용 | 확인·경고용 대화상자. 바깥을 누르면 닫히고 뒤로 가기로도 닫히며
         그림자는 3단, 최초 도입은 3월... (2000자 회고록)
```

### 6.1 전체 부품 색인

인벤토리 문서 **맨 끝**에 `## 전체 부품 색인` 구간을 따로 둔다. 사람이 읽는 본문(위 한 줄 형식)과 달리, 이 구간은 **기계가 대조하는 목록**이다 — 부품 파일 경로를 **한 줄에 하나씩, 꾸밈 없이** 코드 블록 안에 늘어놓는다.

왜 따로 두나 — 「새로 만든 부품이 인벤토리에 다 올라갔나」를 검사가 줄 전체 일치로 대조한다(디자인 규칙 검사 4번). 본문은 부품을 묶어 적거나 설명을 붙이니 그대로 대조하면 빠진 것과 오탐이 섞인다. 경로만 있는 목록이라야 「이 파일이 목록에 있나」가 한 줄로 갈린다.

````markdown
## 전체 부품 색인

_부품 파일을 더하거나 지울 때 이 구간을 지우고 다시 만든다. 목록은 아래 명령의 출력이다:
`find lib/shared/components lib/features -name '*.dart' -not -name '*.g.dart' | grep -E '^lib/shared/components/|/widgets/' | sort`_

```
lib/features/meetings/widgets/meeting_card.dart
lib/shared/components/common/empty_state.dart
lib/shared/components/ui/app_button.dart
lib/shared/components/ui/app_dialog.dart
```
````

- **꾸밈을 붙이지 않는다** — 줄 앞의 `- `, 뒤의 설명, 굵게 표시가 붙으면 줄 전체 일치에서 전부 「없음」으로 나온다.
- **경로는 저장소 최상위 기준**(`lib/…`)이다. 변형(열거형 값)은 파일이 아니라 적지 않는다. 코드 생성 파일(`*.g.dart` 등)은 부품이 아니라 뺀다.
- **언제 다시 만드나** — 부품 파일을 더하거나 지울 때. 손으로 고치지 않고 아래 명령으로 다시 뽑아 구간을 통째로 바꾼다.

```bash
find lib/shared/components lib/features -name '*.dart' -not -name '*.g.dart' \
  | grep -E '^lib/shared/components/|/widgets/' | sort
```

## 7. 이식성 — 다른 프로젝트로 옮기기

| 대상 | 다음 프로젝트에서 |
|---|---|
| 범용 부품(감싸개) | **파일째 복사한다** — 2층 이름 계약 덕에 복사한 그대로 새 프로젝트의 브랜드 색·모양이 적용된다. 값이 아니라 `context.*` 이름만 쓰기 때문이다 |
| 전용 부품 | **새로 조립** (제품 고유 개념이므로) — 단 재료는 감싸개 + 2층 이름 |
| 인벤토리 | **새로 작성** (복사한 감싸개 등록 + 전용 신규 등록) |
