# 목업 캔버스 틀

만든 화면을 모두 한 판에 펼쳐 보는 개발용 앱 **목업 캔버스**의 코드 틀입니다. 맥의 iPad 시뮬레이터(맥 안에서 도는 가상 아이패드)에 띄웁니다. 2단계 내내 사람이 「모든 화면과 상태를 한눈에 펼쳐 놓고, 고칠 곳을 짚어 AI에게 알리는」 데 씁니다.

캔버스는 실서비스 앱과 진입점(앱이 시작하는 첫 파일)이 따로입니다. 캔버스 진입점 `lib/main_canvas.dart`로 빌드할 때만 캔버스 코드가 앱에 들어가므로, 실서비스 앱에는 캔버스가 아예 없습니다.

## 목차

1. [무엇을 하나](#1-무엇을-하나)
2. [파일](#2-파일)
3. [프로젝트에 넣는 차례](#3-프로젝트에-넣는-차례)
4. [띄우기](#4-띄우기)
5. [목록 파일](#5-목록-파일)
6. [상태 흉내와 가짜 저장소](#6-상태-흉내와-가짜-저장소)
7. [캔버스 쓰는 법](#7-캔버스-쓰는-법)
8. [코멘트 핀](#8-코멘트-핀)
9. [미리보기 그림(골든 그림)](#9-미리보기-그림골든-그림)
10. [동작 메모](#10-동작-메모)
11. [지켜야 할 것](#11-지켜야-할-것)

---

## 1. 무엇을 하나

- **모든 화면이 흐름 순서로 펼쳐집니다** — 왼쪽에서 오른쪽으로 화면이 흐름 순서대로 놓입니다. 한 화면의 세로줄 안에서는 위에서 아래로 기본 모양 → 상태(빈 상태·로딩·오류·권한없음) → 비교안이 줄을 짓습니다. 한 줄에는 **보통 폰(아이폰 16 폭, 390×844dp)과 작은 폰(갤럭시 S 폭, 360×780dp)** 이 나란히 섭니다. dp는 기기 화소 밀도와 상관없이 같은 크기로 보이게 하는 Flutter의 길이 단위입니다.
- **멀리서는 미리보기 그림, 가까이서는 실제 화면입니다** — 판 전체가 보이게 줄여 놓으면 창마다 미리보기 그림(§9의 골든 그림)이 놓이고, 그림이 아직 없으면 화면 이름 카드가 놓입니다. 확대해서 배율이 0.3 이상이 되면 화면에 보이는 창부터 실제 앱 화면으로 바뀝니다(한 번에 8개까지). 실제 화면은 앱 코드 그대로라 눌러 보고 옮겨 다닐 수 있습니다.
- **창 이름으로 지금 앱과 비교안을 가릅니다** — 원래 화면 창은 이름 앞에 「지금 앱」이 붙습니다(예: 「지금 앱 · 보통 폰 · 기본」). 비교안 창은 판 이름 뒤에 처지가 붙습니다 — 고르기 전 「· 비교안」, 고른 뒤 「· 고름」·「· 고르지 않음」(예: 「대담판 (bold) · 고르지 않음 · 보통 폰 · 기본」). 판 이름표가 붙은 창을 「진짜 앱」으로 읽지 않게 하려는 것입니다(§5 `pick`).
- **크게 보기** — 창 이름 옆 「크게」를 누르거나 이름 카드를 누르면 그 화면 하나를 판 가득 띄웁니다. 보통 폰·작은 폰을 바꿔 볼 수 있습니다.
- **글자 배율** — 오른쪽 아래 「글자 1.0 / 1.3 / 2.0」으로 폰 설정의 「글자 크기」를 흉내 냅니다. 큰 글자에서 넘치는 곳을 눈으로 찾을 때 씁니다.
- **흐름 묶음 고르기** — 왼쪽 목록에서 흐름 묶음(「역할: 흐름」 꼴의 이름) 하나만 골라 보거나 전체를 봅니다.
- **코멘트 핀** — 「코멘트 달기」를 켜고 화면을 누르면 메모 칸이 뜨고, 적으면 그 자리에 핀이 꽂힙니다. 코멘트는 `mvp/canvas-comments.json`에 쌓이고, Claude Code에 「코멘트 반영해줘」라고 하면 Claude가 열린 코멘트를 읽어 고칩니다.

**왜 iPad 시뮬레이터인가** — 아이폰 시뮬레이터와 같은 iOS 엔진이라 글자 모양과 스크롤이 개발 기기에서 보는 것과 같습니다. 폰 전용 플러그인(폰 기능을 쓰는 패키지)도 그대로 돕니다. 안드로이드 쪽 모습은 USB로 연결한 폰에서 앱을 직접 실행해 봅니다.

## 2. 파일

| 틀 파일 | 프로젝트에 넣는 자리 · 하는 일 |
|---|---|
| `lib/main_canvas.dart.template` | `lib/main_canvas.dart` — 캔버스 진입점. Firebase를 켜지 않고 가짜 저장소만 씁니다 |
| `lib/core/dev_state/dev_state.dart.template` | `lib/core/dev_state/dev_state.dart` — 상태 흉내 provider와 도우미(§6). 실서비스 코드도 부르므로 `lib/dev/` 밖에 둡니다 |
| `lib/dev/canvas/canvas_app.dart.template` | `lib/dev/canvas/canvas_app.dart` — 캔버스 판(배치·확대·흐름 묶음 목록·크게 보기·코멘트 목록) |
| `lib/dev/canvas/canvas_phone.dart.template` | `lib/dev/canvas/canvas_phone.dart` — 폰 틀. 창마다 provider 묶음과 라우터를 따로 만들어 실제 화면을 띄웁니다 |
| `lib/dev/canvas/canvas_model.dart.template` | `lib/dev/canvas/canvas_model.dart` — 화면 목록·창 목록·코멘트의 모양 |
| `lib/dev/canvas/canvas_config.dart.template` | `lib/dev/canvas/canvas_config.dart` — 캔버스가 프로젝트에서 받는 것(테마·라우터·덮어쓰기·문구 파일) |
| `lib/dev/canvas/canvas_comments.dart.template` | `lib/dev/canvas/canvas_comments.dart` — 코멘트 서버에 묻기, 누른 자리의 단서 찾기 |
| `lib/dev/canvas/canvas_shots.dart.template` | `lib/dev/canvas/canvas_shots.dart` — 멀리서 보이는 모습. 미리보기 그림이 있으면 그림, 없으면 이름 카드(§9) |
| `lib/dev/canvas/screens.dart.template` | `lib/dev/canvas/screens.dart` — 목록 파일의 손 부분(§5) |
| `lib/dev/canvas/screens.generated.dart.template` | `lib/dev/canvas/screens.generated.dart` — 목록 파일의 자동 부분(§5) |
| `lib/dev/fakes/canvas_overrides.dart.template` | `lib/dev/fakes/canvas_overrides.dart` — 모든 창에 거는 가짜 저장소 덮어쓰기(§6) |
| `tool/canvas_server.dart.template` | `tool/canvas_server.dart` — 코멘트 서버. 맥에서 돌며 코멘트 파일을 읽고 쓰고, 미리보기 그림을 내보냅니다(§8·§9) |
| `tool/canvas_list.dart.template` | `tool/canvas_list.dart` — 목록 만들기 스크립트. 화면 목록 문서에서 `screens.generated.dart`를 만듭니다(§5) |
| `tool/state_fill.dart.template` | `tool/state_fill.dart` — 상태 칸 채우기 스크립트. 상태 표의 칸 끝에 `(?state=…)`를 적습니다(§5) |
| `tool/feature_list.dart.template` | `tool/feature_list.dart` — 위 두 스크립트가 함께 쓰는 표 읽기. 읽는 칸 이름이 여기 모여 있습니다 |
| `ios/Flutter/DeviceFamily.xcconfig.template` | `ios/Flutter/DeviceFamily.xcconfig` — 캔버스로 빌드할 때만 아이패드를 지원하게 하는 빌드 설정(§3의 ⑥) |
| `test/canvas/canvas_model_test.dart.template` | `test/canvas/canvas_model_test.dart` — 목록 펴기·코멘트 모양·상태 흉내 단위 테스트 |
| `test/canvas/canvas_server_test.dart.template` | `test/canvas/canvas_server_test.dart` — 코멘트 서버 테스트(임시 폴더에 실제로 읽고 씀) |
| `test/canvas/canvas_board_test.dart.template` | `test/canvas/canvas_board_test.dart` — 캔버스 위젯 테스트(창마다 상태가 갈리는지, 대화상자가 창 안에 뜨는지, 코멘트가 남는지) |
| `test/canvas/canvas_list_test.dart.template` | `test/canvas/canvas_list_test.dart` — 목록 만들기·상태 칸 채우기 단위 테스트(견본 문서를 글자로 넣어 읽음) |
| `test/goldens/canvas_golden_test.dart.template` | `test/goldens/canvas_golden_test.dart` — 미리보기 그림을 찍는 골든 테스트(§9) |
| `test/draft_checks/draft_check_test.dart.template` | `test/draft_checks/<판>_check_test.dart` — 2-3 비교안·2-4 머무는 공간 자기 점검 테스트 틀. 판마다 파일 하나로 복사해 씁니다(`stay`면 `stay_check_test.dart` — §9의 「자기 점검 그림」) |
| `dart_test.yaml.template` | `dart_test.yaml`(프로젝트 맨 위) — 테스트 태그 `golden`을 등록합니다. 이미 있으면 `tags:` 아래에 `golden:` 한 줄만 더합니다 |

새로 까는 패키지는 하나입니다 — 골든 테스트 도우미 `golden_screenshot`(개발 의존성). 테스트 안에서 앱 서체를 불러와 글자가 네모 상자로 찍히지 않게 하고, 1% 안의 작은 그림 차이를 같은 그림으로 쳐 줍니다. 스토어 스크린샷을 만드는 기능도 있어 6단계 스크린샷 초안에도 씁니다. 그 밖에 캔버스는 고정 스택의 `flutter_riverpod`(상태 관리)·`go_router`(화면 이동)만 쓰고, 스크립트와 코멘트 서버는 Dart 기본 라이브러리만 씁니다.

## 3. 프로젝트에 넣는 차례

① **파일을 복사합니다** — 위 표대로 같은 경로에 복사하면서 끝의 `.template`을 뗍니다. `test/canvas/`·`test/goldens/`의 파일에서 `package:<앱>/`을 앱 패키지 이름(`pubspec.yaml`의 `name`)으로 바꿉니다. 골든 테스트 도우미를 개발 의존성으로 깝니다 — `flutter pub add dev:golden_screenshot`(fvm을 쓰면 앞에 `fvm`). 판은 그때의 최신 stable이고, 고른 판은 `pubspec.lock`이 기록합니다.

② **라우터를 함수로 엽니다** — 캔버스는 창마다 라우터(go_router의 `GoRouter` — 경로마다 어떤 화면을 띄울지 정한 표)를 새로 만듭니다. 그래서 `lib/app/router.dart`가 아래 모양의 함수를 내놓아야 합니다.

```dart
GoRouter createAppRouter({String initialLocation = '/'}) {
  final rootKey = GlobalKey<NavigatorState>(); // 열쇠는 함수 안에서 만든다
  return GoRouter(navigatorKey: rootKey, initialLocation: initialLocation, routes: [...]);
}
```

- **개발용 경로를 받는 자리를 둡니다** — 2-3 비교안이 하단 탭 셸 안 화면이면, 비교안 경로를 셸 안에 끼워야 탭 바가 함께 보입니다. 그런데 라우터(`lib/app/`)가 `lib/dev/`를 직접 부르면 실서비스 앱에 비교안이 들어가고 디자인 규칙 검사 13번에 걸립니다. 그래서 라우터는 경로를 **인자로 받기만** 하고, 채우는 쪽은 개발용 진입점(`main_dev.dart`·`main_canvas.dart`)뿐입니다.

  ```dart
  GoRouter createAppRouter({
    String initialLocation = '/',
    List<RouteBase> devRoutes = const [], // 셸 밖에 더할 개발용 경로 (예: 디자인 시스템 페이지)
    Map<String, List<RouteBase>> devBranchRoutes = const {}, // 하단 탭 이름별로 그 가지 안에 더할 경로 (예: 'home': […])
  }) { … }
  ```

  - 라우터는 셸의 각 가지(`StatefulShellBranch`)를 만들 때 `devBranchRoutes[탭 이름]`을 그 가지의 `routes` 끝에 펼쳐 넣습니다. 인자가 비면 아무 일도 안 합니다.
  - 경로 목록(`List<RouteBase>`)은 `lib/dev/drafts/dev_routes.dart` 같은 개발용 파일에 두고, `main_canvas.dart`의 `createRouter`와 `main_dev.dart`만 `createAppRouter(devBranchRoutes: …)`로 넘깁니다. **`main_prod.dart`는 이 인자를 넘기지 않습니다.**
  - 비교안을 고르거나 지울 때는 `dev_routes.dart`와 두 진입점의 넘기는 줄도 함께 지웁니다.
  - **앱 뼈대 틀에 이 자리가 있습니다** — `.claude/templates/firebase/app/lib/app/router.dart.template`의 `createAppRouter`가 두 인자를 받고, 셸 가지를 만들 때 `routes: [..., ...?devBranchRoutes['탭 이름']]`처럼 끝에 펼쳐 넣습니다. 개발용 진입점 `main_dev.dart` 틀에는 넘기는 줄이 주석으로 있습니다. 옛 틀로 만든 프로젝트라 라우터에 이 자리가 없으면 2-3에서는 라우터를 고치지 않습니다 — 비교안은 `CanvasDraft(builder:)`로 띄웁니다(하단 탭 없이 뜹니다).
- **내비게이터 열쇠(`GlobalKey`)를 파일 맨 위 전역 값으로 두지 않습니다.** 같은 열쇠는 화면에 한 번만 있을 수 있는데, 캔버스에는 라우터가 창 수만큼 동시에 떠서 「열쇠가 겹친다」는 오류가 납니다. 셸 경로(하단 탭)의 열쇠도 같습니다.
- 라우터가 provider(앱 어디서나 꺼내 쓰는 공급자 — Riverpod의 기본 단위)를 읽어야 하면(예: 로그인 상태로 길을 돌리기), `main_canvas.dart`의 `createRouter` 한 줄에서 받은 `container`(그 창의 provider 묶음)로 읽게 바꿉니다.

③ **테마와 문구 파일을 실제 앱과 같게 넘깁니다** — `main_canvas.dart`는 `buildAppTheme(AppTokens.light)`(design-system 스킬의 3층 조립)와 `AppLocalizations`(Flutter 공식 다국어가 `.arb` 문구 파일에서 만든 클래스)를 넘깁니다. 개발용 진입점 `main_dev.dart`와 이름이 다르면 그쪽에 맞춥니다.

④ **저장·조회 코드에 상태 흉내를 잇습니다** — §6대로 저장·조회 provider가 `devStateProvider`를 읽게 하고, 흐름마다 가짜 저장소를 `lib/dev/fakes/`에 두고 `canvas_overrides.dart`에 한 줄씩 등록합니다. `canvas_overrides.dart` 틀에는 개발용·실서비스용 갈래 값(`appFlavorProvider`)을 개발용으로 넣는 줄이 이미 있습니다 — 이 provider는 진입점이 값을 넣지 않으면 읽는 순간 실패하기 때문입니다(앱 뼈대 틀 `lib/app/flavor.dart`).

⑤ **디자인 시스템 페이지를 확인합니다** — `screens.dart`는 디자인 시스템 페이지(`lib/dev/design_system/design_system_page.dart`)를 캔버스 맨 끝 창 하나로 띄웁니다. 그 페이지가 아직 없으면 그 항목을 지우고, 페이지를 만든 뒤 되살립니다.

⑥ **캔버스로 빌드할 때만 아이패드를 지원하게 합니다** — 이 앱은 폰만 지원합니다. 그런데 폰 전용 앱을 아이패드에 띄우면 아이폰 크기 창으로 작게 뜹니다. 그래서 진입점이 `main_canvas.dart`일 때만 아이패드를 지원하게 빌드 설정을 가릅니다.

1. `ios/Flutter/DeviceFamily.xcconfig`를 둡니다(①에서 복사). xcconfig는 Xcode가 읽는 빌드 설정 파일입니다.
2. `ios/Flutter/`의 빌드 설정 파일마다 `Generated.xcconfig`를 include하는 줄 바로 아래에 한 줄을 더합니다. 기본 프로젝트면 `Debug.xcconfig`·`Release.xcconfig` 둘이고, flavor(개발용·실서비스용처럼 한 코드로 여러 판을 빌드하는 갈래)를 쓰면 flavor마다 있는 설정 파일 전부입니다.

   ```
   #include "Generated.xcconfig"
   #include "DeviceFamily.xcconfig"
   ```

3. Xcode 프로젝트 파일의 「지원 기기」 값을 그 설정에 잇습니다. 프로젝트 맨 위에서:

   ```bash
   sed -i '' -E 's/TARGETED_DEVICE_FAMILY = [^;]+;/TARGETED_DEVICE_FAMILY = "$(APP_DEVICE_FAMILY)";/' ios/Runner.xcodeproj/project.pbxproj
   ```

4. 확인합니다 — 진입점을 바꿔 두 번 빌드하고, 만들어진 앱의 지원 기기 값을 읽습니다. 캔버스는 `1 2`(아이폰·아이패드), 그 밖은 `1`(아이폰)이 나와야 합니다. flavor를 쓰면 빌드 명령에 `--flavor dev`를 붙이고, 앱 경로도 flavor 이름이 붙은 폴더로 바뀝니다.

   빌드 명령 앞의 `.claude/scripts/build-lock.sh`는 빌드 잠금입니다 — 한 맥에서 여러 프로젝트가 돌 때 무거운 빌드가 한 번에 하나만 돌게 합니다. 다른 프로젝트가 빌드 중이면 「다른 프로젝트가 빌드 중이라 기다립니다」를 내고 기다립니다. fvm을 쓰면 `fvm`은 잠금 뒤, `flutter` 앞에 붙입니다.

   ```bash
   .claude/scripts/build-lock.sh flutter build ios --simulator --debug -t lib/main_canvas.dart
   /usr/libexec/PlistBuddy -c "Print :UIDeviceFamily" build/ios/iphonesimulator/Runner.app/Info.plist
   .claude/scripts/build-lock.sh flutter build ios --simulator --debug -t lib/main_dev.dart
   /usr/libexec/PlistBuddy -c "Print :UIDeviceFamily" build/ios/iphonesimulator/Runner.app/Info.plist
   ```

⑦ **골든 테스트 준비를 합니다** — 네 가지입니다.

1. `dart_test.yaml`에 `golden` 태그를 등록합니다(①에서 복사, 이미 있으면 한 줄만 더함).
2. `.gitignore`에 `test/goldens/failures/`를 더합니다. 골든 비교가 실패하면 차이 그림이 그 폴더에 생기는데, 올릴 것이 아닙니다. 같은 자리에 2-3 자기 점검 그림 폴더 `.draft-checks/`도 더합니다(주석: 2-3 자기 점검 그림 — 올리지 않는다).
3. (2-3을 할 때만) `test/draft_checks/draft_check_test.dart.template`을 판마다 `test/draft_checks/<판>_check_test.dart`로 복사합니다. 머리 주석의 규칙(자기 판 파일만 import · `pumpAndSettle` 금지)은 지시서에도 넣습니다.
4. 앱 테마가 앱에 넣은 한글 서체를 이름으로 가리키는지 봅니다(design-system 스킬의 서체 규칙). 테스트 안에는 폰의 기본 한글 서체가 없어서, 테마가 넣은 서체를 가리키지 않으면 한글이 「NOGLYPH」라고 적힌 네모 상자로 찍힙니다.

⑧ **검사를 돌립니다** — `flutter analyze`, `dart analyze`(Riverpod 린트는 이쪽에서만 돕니다), `flutter test --exclude-tags golden`, `dart run tool/canvas_list.dart`, `.claude/scripts/build-lock.sh flutter test --tags golden --update-goldens`. 그리고 §4대로 시뮬레이터에 띄워 앱이 뜨는지, 코멘트 서버 창에 `GET /comments` 줄이 찍히는지(`--log`로 켰을 때) 봅니다. 화면이 맞는지는 사람이 봅니다.

## 4. 띄우기

맥 터미널 두 개에서, 둘 다 프로젝트 맨 위 폴더에서 돌립니다. fvm(프로젝트마다 Flutter 판을 고정하는 도구)을 쓰면 `flutter`·`dart` 앞에 `fvm`을 붙입니다.

1. **코멘트 서버를 켭니다** — `dart run tool/canvas_server.dart`. 「목업 캔버스 코멘트 서버(<폴더 이름>): http://127.0.0.1:<번호>」가 뜨면 됩니다. 켜 둔 채로 둡니다.
   - 서버는 4723부터 빈 포트를 찾아 뜨고, 뜬 번호를 `.dart_tool/canvas_server.port`에 적습니다. 한 맥에서 여러 프로젝트의 서버가 함께 떠도 서로 포트를 다투지 않게 하려는 것입니다. `.dart_tool/`은 Flutter가 git에서 빼 두는 폴더입니다.
   - Ctrl+C로 끄면 그 파일을 지웁니다.
2. **캔버스를 띄웁니다** — 이 프로젝트 전용 아이패드 시뮬레이터 `<폴더 이름> 캔버스`에 띄웁니다. 그 시뮬레이터는 개발환경 준비(idea-to-mvp `2-0-dev-setup.md` §2.4)가 가장 큰 아이패드 기종으로 만들어 둡니다. 꺼져 있으면 `flutter run`이 찾지 못하니 먼저 켭니다.

   ```bash
   xcrun simctl boot "$(basename "$PWD") 캔버스" 2>/dev/null; open -a Simulator
   flutter run -t lib/main_canvas.dart -d "$(basename "$PWD") 캔버스" \
     --dart-define=CANVAS_SERVER=http://127.0.0.1:$(cat .dart_tool/canvas_server.port)
   ```

   - flavor를 쓰는 프로젝트면 `--flavor dev`를 붙입니다.
   - 코멘트 서버를 먼저 켭니다 — 포트 파일은 서버가 뜰 때 생깁니다.
   - 시뮬레이터 메뉴 Device → Rotate Left로 가로로 눕힙니다.
   - 다른 프로젝트 이름의 시뮬레이터에는 띄우지 않습니다. 기종 이름(「iPad Pro 13-inch」 같은)으로 고르면 다른 프로젝트 세션의 캔버스와 한 시뮬레이터를 나눠 쓰게 됩니다.

- **화면 코드를 고친 뒤** — `flutter run`을 띄운 터미널에서 `r`(hot reload — 앱을 끄지 않고 바뀐 코드만 바꿔 넣기)을 누르면 캔버스의 실제 화면에 바로 들어갑니다. 목록 파일·가짜 저장소처럼 앱이 시작할 때 한 번 읽는 것을 바꿨으면 `R`(hot restart — 앱을 처음부터 다시 시작)을 누릅니다.
- **코멘트 서버 없이도 캔버스는 뜹니다** — 코멘트만 못 남깁니다. 코멘트 목록 위에 「코멘트 서버에 닿지 않습니다」가 뜨면 1번을 켭니다.
- **「다른 프로젝트의 코멘트 서버입니다」가 뜨면** — 캔버스가 다른 프로젝트의 서버에 붙은 것입니다. 서버는 응답마다 자기 프로젝트 폴더 이름을 담아 보내고, 캔버스는 그 이름이 자기 프로젝트와 다르면 코멘트 읽기·쓰기를 멈춥니다. 코멘트가 엉뚱한 프로젝트의 `mvp/canvas-comments.json`에 쌓이지 않게 하려는 것입니다. 이 프로젝트 폴더에서 1번을 켠 뒤, 캔버스를 `q`로 끄고 2번 명령으로 다시 띄웁니다(포트 번호는 앱을 빌드할 때 들어가므로 `R`로는 바뀌지 않습니다).
- **포트를 정해 띄울 때** — 서버는 `--port 4730`(그 번호에만 뜨고, 차 있으면 멈춥니다), 캔버스는 위 명령 그대로입니다(포트 파일에 그 번호가 적힙니다).

## 5. 목록 파일

캔버스에 띄울 화면 목록은 두 파일로 나뉩니다. 캔버스는 둘을 합친 `screens.dart`의 `canvasScreens`를 읽습니다.

| 파일 | 누가 쓰나 | 무엇이 들어가나 |
|---|---|---|
| `screens.generated.dart` (자동 부분) | 목록 만들기 스크립트가 통째로 다시 씁니다. 손으로 고치지 않습니다 | 화면 목록에서 읽은 화면 — ID·이름·흐름 묶음·경로·상태·로그인 전 |
| `screens.dart` (손 부분) | 사람(또는 AI)이 고칩니다. 스크립트는 건드리지 않습니다 | 자동 화면 위에 덮어쓸 필드(`canvasOverrides`), 화면 목록에 없는 화면(`canvasExtraScreens`) |

**자동 부분의 모양** — 화면 하나가 `CanvasScreen` 하나입니다. `const` 목록이라 위젯을 넣을 수 없고, 글자·상태 값만 들어갑니다.

```dart
const generatedScreens = <CanvasScreen>[
  CanvasScreen(
    id: 'S-01',
    name: '모임 목록',
    group: '참가자: 모임 찾기에서 신청까지',
    path: '/meetings',
    states: [DevState.empty, DevState.loading, DevState.error],
  ),
  CanvasScreen(id: 'S-07', name: '첫 화면', group: '처음 온 사람: 둘러보기에서 가입까지', path: '/', guest: true),
];
```

**자동 부분 만들기** — 목록 만들기 스크립트가 `mvp/feature-list.md`를 읽어 `screens.generated.dart`를 통째로 다시 쓰고, `dart format`으로 줄을 맞춥니다. 프로젝트 맨 위 폴더에서 돌립니다(fvm을 쓰면 앞에 `fvm`).

```bash
dart run tool/canvas_list.dart
```

- **화면 목록이나 상태 표를 고칠 때마다 다시 돌립니다.** 그다음 캔버스를 `R`(hot restart)로 다시 시작합니다. 손 부분은 화면 ID로 붙으니 자동 부분이 바뀌어도 그대로 따라갑니다.
- 끝나면 「화면 몇 개를 적었다」와 「주소가 아직 없어 뺀 화면 ID」를 알려 줍니다. 필요한 칸이 없으면 쓰지 않고 멈춥니다.

**스크립트가 문서를 읽는 법** — 표도 칸도 번호가 아니라 **머리줄의 칸 이름**으로 찾습니다. 그래서 문서의 절 순서나 표의 칸 순서가 바뀌어도 그대로 돕니다. 대신 칸 이름을 바꾸면 스크립트가 못 찾습니다 — 이름을 바꿀 때는 `tool/feature_list.dart` 맨 위의 이름도 같이 바꿉니다. 칸 이름은 굵게 표시(`**`)를 떼고 읽습니다.

| 표 | 찾는 법 | 읽는 칸 이름 |
|---|---|---|
| 화면 목록 표 | 머리줄에 꼭 있어야 할 칸 넷이 모두 있는 첫 표 | 꼭: 「ID」·「화면 이름」·「MVP 포함」·「주소」 / 있으면: 「흐름 묶음」·「역할」 |
| 상태 표 | 머리줄에 상태 칸 이름이 둘 이상 있는 첫 표(화면 목록 표 말고) | 첫 칸(화면 ID로 시작) + 「빈 상태」·「로딩」·「오류」·「권한없음」 |

- **화면 목록 표**
  - `MVP 포함`이 `O`로 시작하고 주소가 있는 행만 올립니다. 주소가 빈 화면은 빼고 그 ID를 알려 줍니다.
  - 「ID」 칸은 `S-01` 꼴이어야 합니다. 그 꼴이 아닌 행은 건너뜁니다.
  - 경로는 주소 칸 안 `` `…` `` 속 첫 낱말입니다. 뒤에 붙은 괄호 설명은 버리고, 경로 안 질의(`?` 뒤의 값)는 그대로 둡니다.
  - 「역할」 칸이 「비로그인 방문자」로 시작하는 행은 `guest: true`를 붙입니다. 경로에 `as=guest`가 있어도 같게 읽습니다.
  - 흐름 묶음은 「흐름 묶음」 칸에서 옵니다. 칸이 없거나 비었거나 `-`·`—`이면 「<역할>: 흐름 미정」으로 묶습니다.
  - 순서는 표의 행 순서입니다. 캔버스는 같은 흐름 묶음끼리 이 순서대로 왼쪽 → 오른쪽에 놓습니다.
- **상태 표** — 첫 칸이 화면 ID로 시작하는 행에서, 칸에 적힌 `?state=` 값(`empty`·`loading`·`error`·`forbidden`)을 모아 그 화면의 `states`로 씁니다. 줄 짓는 순서는 칸 순서와 상관없이 빈 상태 → 로딩 → 오류 → 권한없음입니다.

**상태 칸 채우기** — 상태 표의 칸 끝 괄호 `(?state=…)`는 손으로 칸을 세다 한 칸 밀려 적기 쉽습니다. 그래서 스크립트가 칸 이름으로 찾아 적습니다.

```bash
dart run tool/state_fill.dart 상태값.txt   # 적기
dart run tool/state_fill.dart --check      # 적지 않고 점검만
```

- 입력 파일은 한 줄에 화면 하나 — `S-01 empty loading`처럼 화면 ID 뒤에 상태 값을 적습니다. 쉼표·공백·쌍점으로 나누고, `#`으로 시작하는 줄은 건너뜁니다.
- 그 칸이 `O`로 시작할 때만 적습니다. `해당없음`이나 `O*`(단추를 눌러야 생기는 상태)인 칸은 건드리지 않고 알려 줍니다. 한 칸에 ` · `로 이은 글이 있으면 첫 덩어리 끝에 붙이고, 이미 그 값이 있으면 건너뜁니다.
- `--check`는 「`O`인데 값이 없는 칸」과 「`O`가 아닌데 값이 있는 칸」을 찍습니다.
- 적은 뒤에는 목록 만들기를 다시 돌립니다.

**손 부분에 적는 모양** (`screens.dart`):

```dart
final canvasOverrides = <String, CanvasOverride>{
  // 비교안 — 화면 개선(2-2) 동안만. 값만 바꾼 판은 theme, 다른 화면이면 builder
  'S-02': CanvasOverride(drafts: [
    CanvasDraft(label: 'B판', theme: buildAppTheme(draftHomeB)),
    CanvasDraft(label: 'C판', builder: (_) => const HomeDraftC(), states: [DevState.empty]),
  ]),
  // 2-3 세 판 — 라벨에 영문 꼬리를 붙인다. 셸 안 화면이면 라우터의 개발용 경로 자리(§3의 ②)에 등록해 path 로 띄운다
  //   판 테마는 판 토큰 파일의 덮개 테마 함수(draft{판}Theme — 판 접두 확장까지 얹은 것)로 준다
  'S-01': CanvasOverride(drafts: [ // 소개 화면 — 대담판 대표 장면
    CanvasDraft(label: '대담판 (bold)', builder: (_) => const OnboardingBold(), theme: draftBoldTheme()),
  ]),
  'S-03': CanvasOverride(drafts: [ // 홈 — 셸 안 화면, 핵심 행동도 여기서 일어나는 예
    CanvasDraft(label: '혁신판 (innov)', path: '/dev/innov/home', theme: draftInnovTheme()),
    CanvasDraft(label: '파격판 (leap)', path: '/dev/leap/home', theme: draftLeapTheme()),
  ]),
  // 흐름 묶음을 손으로 정할 때
  'S-05': CanvasOverride(group: '처음 온 사람: 둘러보기에서 가입까지'),
  // 한 가지 폰 크기로만 볼 때
  'S-07': CanvasOverride(widths: [CanvasViewport.phone]),
  // 캔버스에서 뺄 때
  'S-09': CanvasOverride(skip: true),
};

final canvasExtraScreens = <CanvasScreen>[
  CanvasScreen(id: 'DS', name: '디자인 시스템', group: '개발: 디자인 시스템',
      builder: (_) => const DesignSystemPage(), widths: const [CanvasViewport.phone]),
];
```

| 필드 | 뜻 |
|---|---|
| `path` | go_router 경로. 창이 이 경로로 앱을 엽니다 |
| `builder` | 경로 없이 위젯을 바로 띄울 때(디자인 시스템 페이지 등). 라우터 없이 뜨므로 그 창 안에서 다른 화면으로 옮겨 가지 않습니다 |
| `states` | 기본 모양 아래에 줄을 지어 띄울 상태. 상태마다 한 줄(보통 폰·작은 폰 한 쌍)이 더 놓입니다 |
| `guest` | 「로그인 전」 모습으로 띄웁니다 |
| `widths` | 띄울 폰 크기. 안 적으면 보통 폰·작은 폰 둘 다 |
| `drafts` | 비교안. 원래 화면 아래에 판마다 줄을 짓습니다. `theme`만 주면 같은 화면을 비교안 테마로(design-system 스킬 `bootstrap-project.md` §6.3의 `drafts.dart` 값), `builder`를 주면 `lib/dev/drafts/`의 비교안 화면을, `path`를 주면 다른 경로를 띄웁니다. `states`를 안 적으면 원래 화면과 같은 상태를 띄웁니다 |
| `skip` | 캔버스에서 뺍니다 |

`CanvasDraft`에는 머무는 공간(idea-to-mvp 2-4)용 필드가 둘 더 있습니다.

| `CanvasDraft` 필드 | 뜻 |
|---|---|
| `focus` | 물건 id. 그 창에 `devFocusProvider`가 이 값으로 들어가, 공간 부품이 처음부터 그 물건으로 다가간 「가까이」 모습을 그립니다 |
| `many` | `true`면 그 창에 `devManyProvider`가 참으로 들어가, 저장·조회 코드가 예시 데이터를 늘려 「많을 때」 모습을 그립니다 |

`CanvasDraft`에는 창 이름에만 쓰는 필드 `pick`(`DraftPick`)도 있습니다. 판 이름(`label`)은 고르기 전후로 그대로 두고 이 값만 바꿉니다 — 창 열쇠·골든 그림 이름·코멘트가 판 이름에 묶여 있어서입니다.

| `pick` 값 | 창 이름 | 언제 |
|---|---|---|
| `DraftPick.open`(안 적으면 이것) | 「{판} · 비교안 · …」 | 고르기 전 |
| `DraftPick.picked` | 「{판} · 고름 · …」 | 고른 판. 본 화면 자리로 옮긴 뒤에는 `builder`·`theme`·`path`를 지우고 `states: []`로 둡니다 — 지금 앱을 띄우는 줄이 됩니다 |
| `DraftPick.notPicked` | 「{판} · 고르지 않음 · …」 | 고르지 않은 판. 비교안 코드는 그대로 둡니다 |
| `DraftPick.app` | 「지금 앱 · {판} · …」 | 비교안이 아니라 지금 앱의 다른 모습 — 2-4에서 공간을 쓰기로 정한 뒤 남기는 가까이·많을 때 줄 |

- **덮어쓰기는 적은 필드만 바꿉니다.** 안 적은 필드는 자동 값 그대로입니다. `states`를 적으면 자동 상태 목록을 통째로 바꿉니다.
- **고른 뒤** — 비교안 중 하나를 고르면 그 값이나 화면을 본 화면 자리로 옮깁니다. `drafts`의 판 줄은 지우지 않고 `pick`만 바꿉니다 — 고른 판은 `DraftPick.picked`(옮긴 뒤 `builder`·`theme`·`path`를 지워 지금 앱을 띄움), 나머지는 `DraftPick.notPicked`. 그래서 고른 뒤에도 한 세로줄에 「지금 앱 → {고른 판} · 고름 → {다른 판} · 고르지 않음」이 남아, 어느 판을 골랐고 무엇과 견줬는지 보입니다. 고르기 전 바탕 화면(개선·개성을 입히기 전 본 화면)은 캔버스에 남기지 않습니다 — 고를 때 본 화면 코드와 토큰을 제자리에서 바꾸기 때문입니다. 그 모습은 고르기 직전에 붙인 단계 이름표(idea-to-mvp SKILL.md §3.2의 `stage/2-2-drafts`·`stage/2-3-drafts`)로 돌아가 봅니다. 「· 고름」·「· 고르지 않음」 줄은 3단계 `화면 대조 끝:` 때 비교안 코드와 함께 지웁니다(`DraftPick.app` 줄은 남깁니다).
- **머무는 공간의 가까이·많을 때 창** — 2-4는 공간 화면의 `drafts`에 넷을 둡니다. 공간(`states: [DevState.empty]`), 가까이 둘(`focus:`, `states: []`), 많을 때(`many: true`, `states: []`). 라벨에는 모두 영문 꼬리 `(stay)`를 붙입니다.

  ```dart
  'S-03': CanvasOverride(drafts: [
    CanvasDraft(label: '머무는 공간 (stay)', builder: (_) => const HomeStay(), theme: draftStayTheme(), states: [DevState.empty]),
    CanvasDraft(label: '가까이 · 책장 (stay)', builder: (_) => const HomeStay(), theme: draftStayTheme(), focus: 'shelf', states: []),
    CanvasDraft(label: '가까이 · 화분 (stay)', builder: (_) => const HomeStay(), theme: draftStayTheme(), focus: 'pot', states: []),
    CanvasDraft(label: '많을 때 (stay)', builder: (_) => const HomeStay(), theme: draftStayTheme(), many: true, states: []),
  ]),
  ```

  창 열쇠는 판 부분 뒤에 `-focus-{물건 id}`·`-many`가 붙어 `S-03__draft-stay__…`·`S-03__draft-stay-focus-shelf__…`·`S-03__draft-stay-many__…`가 됩니다 — 라벨의 한글이 빠져도 그림 파일이 서로 덮이지 않습니다. 그래서 물건 id는 영문·숫자로 짓습니다. 셸 안 화면이면 `builder` 대신 개발용 경로를 `path`로 줍니다(2-3과 같음). 공간을 쓰기로 정한 뒤에는 공간 줄을 지우고, 가까이·많을 때 줄은 `builder`·`theme`을 지우고 `pick: DraftPick.app`을 붙여 본 화면을 띄우는 줄로 남깁니다.
- 캔버스는 목록을 창 목록(화면 × 폰 크기 × 상태 × 판)으로 펴서 씁니다(`canvas_model.dart`의 `buildFrames`). 창마다 열쇠가 붙습니다 — 예: `S-02__main__phone__empty`, 비교안이면 `S-02__draft-B__small__base`. 영문·숫자·`-`·`_`만 쓰므로 판 이름의 한글은 열쇠에서 빠집니다. 그래서 한글만 다른 판 이름은 열쇠가 겹칩니다. 2-3 비교안 라벨은 영문 꼬리를 붙여 `'대담판 (bold)'`·`'혁신판 (innov)'`·`'파격판 (leap)'`로 씁니다 — 열쇠는 `S-02__draft-bold__phone__base`·`…__draft-innov__…`·`…__draft-leap__…`가 되고, 이 `draft-bold` 같은 말이 창 열쇠의 판 부분입니다(골든 그림 이름·코멘트·`--name` 모두 이 열쇠).

## 6. 상태 흉내와 가짜 저장소

**상태 흉내** — 같은 화면의 빈 상태·로딩·오류·권한없음, 그리고 「로그인 전」 모습을 띄우는 장치입니다. `lib/core/dev_state/dev_state.dart`에 provider 둘이 있습니다.

| provider | 값 | 평소(실서비스 포함) |
|---|---|---|
| `devStateProvider` | `DevState.empty`·`loading`·`error`·`forbidden` | `null` |
| `devGuestProvider` | 「로그인 전」이면 `true` | `false` |
| `devFocusProvider` | 머무는 공간(2-4)에서 처음부터 가까이 다가가 그릴 물건 id | `null` |
| `devManyProvider` | 「데이터가 많을 때」 흉내면 `true` | `false` |

**화면 코드는 이 값을 읽지 않습니다.** 저장·조회 코드(각 흐름의 `data/` 폴더)가 함수 맨 앞에서 `devStateAnswer`를 불러, 값이 있으면 그 상태의 답을 바로 돌려줍니다 — 빈 상태는 빈 결과, 로딩은 끝나지 않는 응답, 오류·권한없음은 실패 값. 화면은 실제 처리 경로대로 그 답을 그리므로, 상태 화면이 실제 앱과 같은 코드로 그려집니다.

```dart
final meetingRepositoryProvider = Provider<MeetingRepository>(
  (ref) => LocalMeetingRepository(devState: ref.watch(devStateProvider)),
);

Future<Result<List<Meeting>>> listMeetings() async {
  final shortcut = await devStateAnswer<Result<List<Meeting>>>(
    _devState,
    empty: () => const Ok(<Meeting>[]),
    failure: (state) => Err(
      state == DevState.forbidden ? const PermissionDeniedError() : const NetworkError(),
    ),
  );
  if (shortcut != null) return shortcut;
  // ... 평소 처리 ...
}
```

- 지금 로그인한 사람을 읽는 코드는 `devGuestProvider`를 먼저 보고, 참이면 「로그인 전」으로 답합니다.
- `devFocusProvider`는 저장·조회 코드가 아니라 **공간 부품만** 읽습니다. `devManyProvider`는 저장·조회 코드가 `devStateAnswer` 옆에서 읽어, 참이면 예시 데이터를 여러 벌로 늘려 돌려줍니다(저장하지 않음). 개발용 앱에서는 질의 `?focus={물건 id}`·`?state=many`로 켭니다. `many`는 화면 목록 상태 표의 상태가 아니라서 `DevState`에 넣지 않았습니다.
- **값을 넣는 길은 둘입니다.** 목업 캔버스는 창마다 provider 덮어쓰기로 넣습니다(`canvas_phone.dart`). 개발용 앱(`main_dev.dart`)은 라우터가 경로 뒤 질의 `?state=empty`·`?as=guest`를 읽어 넣습니다 — 그래서 화면 목록·상태 표의 `?state=` 표기가 개발용 앱에서도 그대로 통합니다. 실서비스 진입점은 아무것도 넣지 않으므로 늘 `null`·`false`입니다.

**가짜 저장소** — 캔버스는 Firebase에 붙지 않습니다. 저장·조회 provider를 모두 견본 데이터를 돌려주는 가짜로 덮어씁니다.

- 흐름마다 `lib/dev/fakes/fake_<흐름>_repository.dart`를 두고, 진짜 저장소와 같은 인터페이스를 구현합니다. 견본 데이터는 `lib/features/<흐름>/data/`의 견본 목록에 두고, 가짜 저장소가 그것을 가져다 씁니다. 견본 목록을 `lib/dev/`에 두면 실서비스 진입점이 `lib/dev/`를 부르게 되므로 안 됩니다(디자인 규칙 검사 13번). 위젯 테스트도 같은 가짜를 씁니다.
- 가짜도 `devStateAnswer`를 거칩니다. 그래야 캔버스의 상태 창이 진짜 저장소와 같은 길로 그려집니다.
- 시간이 걸리는 흉내(진행 상황을 흘려 주는 `Stream` 등)는 `async*` 안 `Future.delayed`로 짓지 않습니다 — 화면이 닫혀도 타이머가 남아 위젯 테스트·골든이 「A Timer is still pending」으로 실패합니다. `Timer`와 `StreamController(onCancel: () => timer?.cancel())`로 짓습니다.
- `lib/dev/fakes/canvas_overrides.dart`의 `canvasFakeOverrides`에 한 줄씩 등록합니다.

  ```dart
  final canvasFakeOverrides = <Override>[
    meetingRepositoryProvider.overrideWith(
      (ref) => FakeMeetingRepository(devState: ref.watch(devStateProvider)),
    ),
  ];
  ```

- 저장·조회 provider를 새로 만들고 여기 등록하지 않으면, 캔버스의 그 화면은 진짜 저장소(2·3단계면 기기 안 저장소, 4단계부터는 Firebase)를 부릅니다. 4단계 뒤에는 Firebase가 꺼진 캔버스에서 오류가 나므로 바로 드러납니다.

## 7. 캔버스 쓰는 법

시뮬레이터에서는 맥의 마우스·트랙패드 누름이 손가락 누름으로 들어갑니다.

| 하고 싶은 것 | 하는 법 |
|---|---|
| 판 옮기기 | 빈 곳을 끌기 |
| 확대·축소 | 오른쪽 아래 −·+ 단추. 두 손가락 벌리기·모으기는 시뮬레이터에서 Option(⌥)을 누른 채 끌기 |
| 전체 다시 보기 | 오른쪽 아래 「화면에 맞추기」, 또는 왼쪽 목록에서 묶음 다시 고르기 |
| 흐름 묶음 하나만 보기 | 왼쪽 목록에서 고르기. 왼쪽 위 ☰ 단추로 목록을 접고 폅니다 |
| 화면 하나 크게 | 창 이름 옆 「크게」, 또는 이름 카드 누르기. 위쪽 단추로 보통 폰·작은 폰을 바꿉니다. 닫기는 ✕ 또는 Esc |
| 큰 글자에서 보기 | 오른쪽 아래 「글자 1.0 / 1.3 / 2.0」 |
| 코멘트 남기기 | 오른쪽 위 「코멘트 달기」를 켭니다(맥 키보드 C). 화면을 누르면 메모 칸이 뜹니다. 적고 「핀 꽂기」. 끄려면 다시 누르거나 C·Esc |
| 코멘트 보기·완료 표시 | 오른쪽 위 「코멘트 보기」(옆 숫자가 열린 코멘트 수), 또는 화면 위 핀 누르기 |

- **실제 화면 위에서 끌면 그 화면이 스크롤됩니다.** 판을 옮기려면 창 사이 빈 곳을 끕니다.
- **이름 카드는 실제 화면이 아닙니다.** 코멘트를 남기려면 확대해 실제 화면이 뜬 뒤 누르거나, 이름 카드를 눌러 크게 연 뒤 누릅니다.
- **키보드 단축키**(C·Esc)는 시뮬레이터 메뉴 I/O → Keyboard → Connect Hardware Keyboard가 켜져 있을 때 맥 키보드로 들어갑니다.

## 8. 코멘트 핀

- **남기기** — 「코멘트 달기」를 켜면 실제 화면의 원래 동작(누르면 이동 등)보다 캔버스가 먼저 누름을 받습니다. 누른 자리에 메모 칸이 뜨고, 「누른 자리」 단서가 함께 보입니다. 「핀 꽂기」를 누르면 코멘트 서버가 `mvp/canvas-comments.json`에 한 건을 더합니다.
- **누른 자리의 단서** — 코멘트 한 건에 「화면 ID·상태·폰 크기·누른 자리의 위젯 이름·그 안의 글자·코드 자리(파일:줄)」가 함께 남습니다. 코드 자리는 디버그 실행(`flutter run`의 기본 실행 방식)에서 Flutter가 위젯마다 기록해 두는 「이 위젯을 만든 코드 줄」에서 읽습니다. 프로젝트 `lib/` 안의 코드가 만든 위젯만 고르고, 캔버스 자신과 패키지 코드는 뺍니다. 그래서 대개 「고칠 줄」을 바로 가리킵니다.
- **다시 보기** — 같은 화면·같은 판·같은 폰 크기·같은 상태의 창에 핀이 다시 꽂힙니다. 핀은 남길 때의 창 안 위치에 놓이므로, 화면을 고쳐 배치가 바뀌면 핀이 조금 어긋날 수 있습니다. 끝난 코멘트(`done`)의 핀은 꽂지 않습니다.
- **목록** — 「코멘트 보기」를 누르면 오른쪽에 목록이 열립니다. 「캔버스에서 찾기」로 그 창에 가고, 「완료 표시」로 닫고, 「끝난 것도 보기」로 처리 메모를 봅니다. 열린 코멘트가 있으면 「코멘트 반영해줘」를 복사하는 단추가 뜹니다 — 시뮬레이터에서 복사한 글자는 맥 클립보드로 넘어가니 Claude Code 대화창에 붙여 넣습니다. 목록은 5초마다 서버에서 다시 읽으므로, Claude가 고치고 완료 표시를 하면 저절로 빠집니다.
- **한 건의 모양** (`canvas_model.dart`의 `CanvasComment`):

  ```json
  {
    "id": "c-mvgp9bsk-o4wa",
    "screenId": "S-01",
    "screenName": "모임 목록",
    "draft": null,
    "url": "/meetings?state=empty",
    "viewport": "phone",
    "state": "empty",
    "target": {
      "selector": "MeetingListScreen > ListView > MeetingTile > Text",
      "text": "퇴근 뒤 보드게임",
      "source": "lib/features/meetings/widgets/meeting_tile.dart:41",
      "component": "Text"
    },
    "position": { "x": 191, "y": 202, "rx": 0.5, "ry": 0.5 },
    "comment": "제목을 더 굵게 해 주세요",
    "status": "open",
    "resolution": "",
    "createdAt": "2026-01-01T00:00:00.000Z",
    "resolvedAt": null
  }
  ```

  - `url`은 개발용 앱에서 같은 모습을 여는 경로입니다(`?state=` 포함). 위젯으로 띄운 창은 `widget:<화면 ID>`입니다.
  - `viewport`는 `phone`(보통 폰)·`small`(작은 폰)입니다.
  - `target.selector`는 누른 자리까지 이어진 위젯 이름 줄(프로젝트 코드가 만든 위젯만, 바깥 → 안)입니다. `source`·`component`는 누른 자리에 가장 가까운 프로젝트 위젯의 코드 자리와 이름입니다. 코드 자리를 못 읽으면 `null`입니다.
  - `position`의 `x`·`y`는 창 왼쪽 위에서 잰 거리(dp), `rx`·`ry`는 그 위젯 상자 안의 비율(0~1)입니다.
  - `status`는 `open`·`done`입니다. 고친 쪽이 `done`으로 바꾸고 `resolution`에 무엇을 고쳤는지 적습니다.
- **코멘트 서버** — 맥에서만(127.0.0.1) 요청을 받고, 코멘트 파일 읽기·쓰기만 합니다.
  - `GET /comments`(전부), `POST /comments`(한 건 더하기 — `id`·`status`·`createdAt`은 서버가 붙임), `PATCH /comments { id, status?, resolution? }`(상태·처리 메모 고치기), `GET /health`, `GET /shots/<창 열쇠>.png`(미리보기 그림 — §9).
  - 포트는 4723부터 찾은 빈 번호이고 `.dart_tool/canvas_server.port`에 적힙니다(§4). Claude가 서버로 직접 요청할 때도 이 파일의 번호를 씁니다.
  - JSON 응답마다 프로젝트 폴더 이름(`project`)이 들어 있습니다. 캔버스는 이 이름을 자기 프로젝트 이름과 견주고, 다르면 멈춥니다(§4). 캔버스의 프로젝트 이름은 캔버스 파일이 기록된 경로에서 알아내고, `--dart-define=CANVAS_PROJECT=<이름>`으로 넘기면 그 값을 씁니다. 쓰기(POST·PATCH) 전에는 `GET /health`로 먼저 견줍니다.
  - 그림 주소는 창 열쇠 꼴(영문·숫자·`-`·`_`에 `.png`)만 받습니다. 그 밖의 이름은 그림 폴더 밖을 가리킬 수 있어 404로 돌려보냅니다.
  - Claude는 파일을 직접 고쳐도 됩니다 — 서버가 요청마다 파일을 새로 읽습니다.
  - 파일 형식이 깨져 있으면 쓰기를 거절합니다. 깨진 파일을 빈 목록으로 덮어써 코멘트를 잃지 않게 하려는 것입니다.
  - `--log`를 붙이면 받은 요청을 한 줄씩 찍습니다. 붙이지 않아도 쓰기(POST·PATCH)는 찍습니다.
- 「코멘트 반영해줘」를 들었을 때 Claude가 하는 차례는 idea-to-mvp `2-1-mockup.md`의 「코멘트 반영」 절이 정합니다.

## 9. 미리보기 그림(골든 그림)

**골든 그림**은 테스트가 화면을 그림 파일로 찍어 두는 것입니다. 캔버스의 창마다 한 장씩 찍어 `test/goldens/canvas/<창 열쇠>.png`에 둡니다. 쓰임은 셋입니다.

1. **캔버스가 멀리서 보여 주는 그림** — 판을 줄여 놓았을 때 이름 카드 대신 이 그림이 뜹니다.
2. **겉모습 비교 기준** — 다시 찍어 기준 그림과 다르면 테스트가 실패합니다. 화면이 뜻하지 않게 바뀐 곳을 찾을 때 씁니다.
3. **스토어 스크린샷 초안의 재료** — 6단계에서 씁니다.

AI가 화면이 맞는지 판정하는 수단이 아닙니다. 그림이 맞는지는 사람이 봅니다.

**찍기** — 프로젝트 맨 위 폴더에서 돌립니다(fvm을 쓰면 앞에 `fvm`).

```bash
.claude/scripts/build-lock.sh flutter test --tags golden --update-goldens test/goldens/canvas_golden_test.dart   # 새로 찍기
.claude/scripts/build-lock.sh flutter test --tags golden --update-goldens --name 'S-01__' test/goldens/canvas_golden_test.dart   # 한 화면만
.claude/scripts/build-lock.sh flutter test --tags golden                                                          # 비교만
```

- **테스트 이름이 곧 창 열쇠입니다** — 그래서 `--name`에 화면 ID를 주면 그 화면의 창만 찍습니다.
- **1% 안의 작은 차이는 같은 그림으로 칩니다** — 도우미 패키지가 그렇게 비교합니다. 그래서 `--update-goldens`도 1%를 넘게 달라진 그림만 다시 씁니다. 전부 다시 쓰려면 `--dart-define=GOLDEN_SCREENSHOT_ALWAYS_UPDATE_GOLDENS=true`를 붙입니다.
- **이 맥에서만 돌립니다** — 운영체제마다 글자를 그리는 방식이 달라, 다른 컴퓨터에서 찍으면 그림이 어긋납니다. CI는 `--exclude-tags golden`으로 이 테스트를 뺍니다. 기준 그림은 git에 올립니다.
- **화면을 바꾼 뒤에 다시 찍습니다** — 목록 만들기를 다시 돌렸을 때(창이 늘거나 줄었을 때)도 다시 찍습니다. 목록에서 빠진 창의 옛 그림은 저절로 지워지지 않으니 `test/goldens/canvas/`에서 지웁니다.

**비교안 그림을 다시 찍기** — 비교안 창의 열쇠는 `draft-bold`처럼 판 이름이 들어 있어, `--name`으로 판 하나만 찍을 수 있습니다. `pick`을 바꿔도 열쇠는 그대로입니다. 고른 판을 본 화면 자리로 옮긴 뒤에는 본 화면과 그 판 줄(이제 지금 앱을 띄움)의 그림을 다시 찍습니다 — 고른 판 줄을 `states: []`로 줄였으면 목록에서 빠진 상태 창의 옛 그림(`test/goldens/canvas/*__draft-<판>__*.png` 중 `__base` 아닌 것)은 지웁니다.

```bash
.claude/scripts/build-lock.sh flutter test --tags golden --update-goldens --name '__draft-bold__' test/goldens/canvas_golden_test.dart   # 대담판 창만
.claude/scripts/build-lock.sh flutter test --tags golden --update-goldens --name 'S-01__main__' test/goldens/canvas_golden_test.dart     # 고른 뒤 본 화면
```

**자기 점검 그림은 `test/goldens/`에 두지 않습니다** — 2-3에서 판을 만드는 에이전트와 2-4에서 머무는 공간을 만드는 에이전트가 위젯 테스트로 찍는 그림은 비교 기준이 아니라 본인이 눈으로 확인하는 기록이라서 `.draft-checks/<판>/<판>-<회차>-<묶음>.png`(프로젝트 맨 위 폴더, git에 올리지 않음)에 씁니다. 회차는 틀 맨 위 `_round` 값입니다. 틀은 `test/draft_checks/draft_check_test.dart.template`이고, 실행은 파일 하나만 지정하고 시간 상한을 겁니다.

```bash
fvm flutter test --timeout 2m test/draft_checks/bold_check_test.dart   # fvm을 안 쓰면 앞의 fvm을 뗍니다
```

틀이 하는 일: ① `RepaintBoundary.toImage`로 그림을 직접 씁니다 ② `FontLoader`로 서체를 올려 글자가 네모로 안 찍히게 합니다 — 맥의 시스템 한글 글꼴(`KR`), `pubspec.yaml`에 등록된 서체(본문 서체·대담판이 넣은 제목 서체 후보)를 그 이름 그대로, 테마가 쓰는데 파일이 아직 없는 서체 이름에는 한글 글꼴을. 앱 글자 묶음(`context.text`)은 서체 이름을 직접 가져서 대체 서체만으로는 영문·숫자가 네모로 남기 때문입니다(2026-10-22 실험). 아이콘 글꼴은 올리지 않아 아이콘은 네모로 찍힙니다 ③ 화면을 판 토큰 `Theme`으로 직접 감싸고 캔버스 틀을 거치지 않습니다(자기 판 파일만 import) ④ 다섯 묶음 — 보통 폰·작은 폰·동작 줄이기·글자 2배와 접근성 지침(`meetsGuideline`)·수단이 안 될 때 ⑤ `pumpAndSettle`을 쓰지 않고 `pump(Duration)`을 정해진 횟수만 돌립니다 — 위젯 테스트 안에서는 가짜 시계라 끝없는 움직임이 있으면 시간 초과 오류로 실패합니다 ⑥ 묶음마다 `expect` 하나 이상. 지도·카메라는 테스트에서 빈 자리로 나오고 3D 패키지는 그리기에 실패하니, 그 부분은 가짜 위젯으로 바꿔 끼운 자리로 찍힙니다. ⑤ 수단이 안 될 때 묶음은 대담판이면 지웁니다.

**캔버스와 같은 그림이 나오는 이유** — 골든 테스트는 캔버스와 같은 재료로 찍습니다.

- 창 목록은 `buildFrames(canvasScreens)`로 폅니다.
- 창마다 캔버스와 같은 폰 틀 `CanvasPhone`을 그립니다. 그래서 같은 provider 덮어쓰기(가짜 저장소·상태 흉내·로그인 전)·같은 폰 크기·같은 안전 영역이 들어갑니다.
- 설정은 `lib/main_canvas.dart`의 `canvasConfig()`를 그대로 부릅니다. 테마·라우터·문구 파일을 바꾸면 그림에도 바로 들어갑니다.
- 그림 배율은 1입니다 — 보통 폰 그림이 390×844 화소입니다. 테스트 파일 맨 위 `_pixelRatio`에서 바꿉니다.
- 화면이 데이터를 받아 그릴 시간을 조금(0.1초씩 5번) 흘린 뒤 찍습니다. 로딩 창은 끝나지 않는 응답이라 다 그려질 때까지 기다리지 않습니다.

**캔버스에 그림이 뜨는 길** — 시뮬레이터에서 도는 캔버스 앱은 맥의 그림 폴더를 직접 읽지 못합니다. 그래서 코멘트 서버가 그림을 내보냅니다.

① 골든 테스트가 `test/goldens/canvas/`에 그림을 씁니다 → ② 코멘트 서버가 `GET /shots/<창 열쇠>.png`로 그 그림을 내보냅니다 → ③ 캔버스의 `canvasShotThumbnail`(`canvas_shots.dart`, `main_canvas.dart`가 `CanvasConfig.thumbnail`에 꽂아 둠)이 그 주소에서 그림을 받아 그립니다.

- 서버가 꺼져 있거나 그 창의 그림이 아직 없으면 이름 카드가 뜹니다.
- **그림을 다시 찍은 뒤에는 캔버스를 `R`(hot restart)로 다시 시작합니다** — 한 번 받은 그림은 앱이 기억해 두기 때문입니다.

## 10. 동작 메모

- **창마다 provider 묶음이 따로입니다** — 창 하나가 `ProviderContainer`(provider 값을 들고 있는 묶음) 하나를 독립된 뿌리로 만듭니다. 그래서 덮어쓰기(가짜 저장소·상태·로그인 전)가 어느 provider에든 그대로 듣고, 한 창에서 누르고 옮겨 다녀도 다른 창은 그대로입니다. 창이 실제 화면에서 이름 카드로 돌아가면 그 묶음은 버려지고, 다시 뜰 때 처음부터 그립니다.
- **창마다 라우터가 따로입니다** — 창 안에서 링크를 누르면 그 창만 다른 화면으로 옮겨 갑니다.
- **캔버스 껍데기에는 내비게이터(화면 쌓기 관리자)가 없습니다** — 창 안 화면이 「맨 바깥 내비게이터」로 대화상자를 띄워도 캔버스 전체가 아니라 그 창의 앱 안에 뜨게 하려는 것입니다. 그래서 캔버스 자신의 메모 칸·크게 보기도 대화상자가 아니라 판 위에 겹쳐 그립니다.
- **창은 실제 폰 크기로 그리고 판 전체를 줄이고 늘립니다** — 창 안 화면은 `MediaQuery`(화면 크기·안전 영역·글자 배율을 알려 주는 값)로 폰 크기와 상태 표시줄·홈 표시줄 자리를 받습니다. 폰 크기·안전 영역은 `canvas_model.dart`의 `CanvasViewport`, 판 배치 숫자와 실제 화면으로 바뀌는 배율(0.3)·동시 상한(8)은 `canvas_app.dart` 맨 위 `_Layout`에 있습니다.
- **창 안 입력칸에 글자를 넣으면** 아이패드 화면 키보드가 판 전체 위에 뜨고, 창은 줄어들지 않습니다. 키보드가 화면을 밀어 올리는 모습은 폰에서 앱을 직접 실행해 봅니다.
- **코드 자리 읽기는 디버그 실행에서만 됩니다** — 프로젝트 폴더 위치는 캔버스 파일 자신이 기록된 경로에서 알아냅니다. 실서비스 빌드(`--release`)로 띄우면 코드 자리가 비고 위젯 이름·글자만 남습니다.
- **캔버스 껍데기는 Material 기본 테마로 그립니다** — 목록·단추·핀은 프로젝트 디자인과 상관없는 개발 도구입니다. 창 안 화면만 프로젝트 테마로 그립니다. 디자인 규칙 검사의 검사 대상(`lib/features`·`lib/shared/components`·`lib/dev/drafts`)에 `lib/dev/canvas`는 들지 않습니다.
- **아이패드 지원은 진입점 파일 이름으로 가릅니다** — flutter 명령이 빌드 직전에 `ios/Flutter/Generated.xcconfig`에 진입점 경로를 적고, `DeviceFamily.xcconfig`가 그 파일 이름이 `main_canvas`일 때만 아이패드를 켭니다. 진입점 파일 이름을 바꾸면 그 파일의 첫 줄 이름도 같이 바꿉니다.

## 11. 지켜야 할 것

- **실서비스 진입점은 캔버스를 부르지 않습니다** — `lib/main_prod.dart`와 그것이 부르는 파일이 `lib/dev/`를 import하지 않습니다(디자인 규칙 검사 13번). `lib/core/dev_state/dev_state.dart`는 실서비스 코드도 부르는 파일이라 `lib/dev/` 밖에 있고, 실서비스에서는 늘 비어 있습니다.
- **캔버스는 Firebase를 켜지 않습니다** — `main_canvas.dart`에 Firebase 시작 코드를 넣지 않고, 저장·조회는 모두 가짜 저장소로 덮어씁니다.
- **코멘트 서버를 맥 밖에 열지 않습니다** — 127.0.0.1에서만 받게 되어 있습니다. 주소를 바꾸지 않습니다.
- **골든 테스트는 이 맥에서만 돌립니다** — CI에서 돌리거나 다른 컴퓨터에서 기준 그림을 다시 찍지 않습니다(§9).
- **`screens.generated.dart`는 손으로 고치지 않습니다** — 목록 만들기가 통째로 다시 씁니다. 고칠 것은 `screens.dart`에 적습니다.
- **코멘트 파일은 git에 올립니다** — 사람이 남긴 수정 요청 기록입니다.
- **AI는 캔버스를 보고 화면을 판정하지 않습니다** — AI는 분석·테스트·빌드·실행까지 하고, 화면이 맞는지는 사람이 캔버스에서 봅니다. 사용자가 명시적으로 시킬 때만 AI가 시뮬레이터를 조작합니다.
- **캔버스 파일(`canvas_*.dart`·`canvas_server.dart`)을 고칠 일이 생기면 하네스 틀도 같이 고칩니다** — 프로젝트마다 따로 고치면 다음 프로젝트가 같은 문제를 다시 만납니다. 프로젝트마다 바뀌는 것은 `screens.dart`·`screens.generated.dart`·`canvas_overrides.dart`·`main_canvas.dart`·골든 그림뿐입니다. 스크립트(`canvas_list.dart`·`state_fill.dart`·`feature_list.dart`)도 하네스 틀과 같게 둡니다 — 칸 이름이 바뀌면 틀부터 고칩니다.
