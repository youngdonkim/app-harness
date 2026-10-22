# 앱 뼈대 틀 (Flutter + Firebase)

새 앱의 뼈대를 만드는 틀입니다. 두 번에 나눠 넣습니다.

- **`app/` 묶음 — 2-0 개발환경 준비에서.** 개발용·실서비스용 두 벌 빌드(flavor), 진입점 둘, 오류 모양(`Result`·`AppError`), 화면 이동 표, 「개발」 띠, 검사 스크립트. 아직 Firebase는 붙지 않습니다.
- **`backend/` 묶음 — 4단계 준비(4-0)에서.** Firebase 연결, Firebase 객체 공급자, 계측 이벤트 파일, 보안 규칙, 서버 함수, 보안 규칙 테스트, Remote Config 틀, Hosting 설정.

안드로이드 서명은 옆 폴더 `../android-signing/`에 따로 있습니다. 2-0에서 함께 넣습니다.

아래 예시 값은 가상의 앱 「예시앱」의 것입니다 — 패키지 이름 `app.example`(개발용 `app.example.dev`), Firebase 프로젝트 `example-dev`·`example-prod`, 리전 `asia-northeast3`(서울).

## 목차

1. [무엇을 하나](#1-무엇을-하나)
2. [파일](#2-파일)
   - [2.1 app 묶음](#21-app-묶음)
   - [2.2 backend 묶음](#22-backend-묶음)
   - [2.3 손으로 넣는 조각과 복사 스크립트](#23-손으로-넣는-조각과-복사-스크립트)
3. [2-0에서 넣는 순서](#3-2-0에서-넣는-순서)
4. [4-0에서 넣는 순서](#4-4-0에서-넣는-순서)
5. [검사](#5-검사)
6. [실측 메모](#6-실측-메모)
7. [지켜야 할 것](#7-지켜야-할-것)

---

## 1. 무엇을 하나

**flavor 두 벌** — flavor는 「같은 코드로 설정만 다른 앱 두 벌을 빌드하는 장치」입니다.

| 자리 | 개발용(`dev`) | 실서비스용(`prod`) |
|---|---|---|
| 진입점(앱이 시작하는 첫 파일) | `lib/main_dev.dart` | `lib/main_prod.dart` |
| 실행·빌드 명령 | `fvm flutter run --flavor dev -t lib/main_dev.dart` | `fvm flutter build appbundle --release --flavor prod -t lib/main_prod.dart` |
| 패키지 이름·번들 ID | `<패키지 이름>.dev` | `<패키지 이름>` |
| 홈 화면 이름 | 「<앱 이름> 개발」 | 「<앱 이름>」 |
| Firebase 프로젝트 | 개발용 | 실서비스용 |
| 화면 구석 「개발」 띠 | 있음 | 없음 |
| 주소의 `?state=`·`?as=`로 상태 흉내 | 켜짐 | 꺼짐 |

패키지 이름이 달라서 한 폰에 두 앱을 함께 깔 수 있습니다.

**코드 규칙 둘을 틀이 먼저 깔아 둡니다.**

1. **오류는 `Result<T>`로 돌려줍니다.** 저장·조회 함수는 예외를 화면까지 던지지 않고 「성공(`Ok`) 또는 실패(`Err`)」를 돌려줍니다. 실패는 `AppError`의 네 갈래(네트워크·권한 없음·찾을 수 없음·알 수 없음) 중 하나라, 화면이 갈래마다 오류 상태를 고릅니다. `Result.guard`가 예외를 이 모양으로 감싸 줍니다.
2. **Firebase 객체는 생성자로 받습니다.** 저장·조회 코드(repository)는 `FirebaseFirestore.instance`를 직접 부르지 않습니다. `lib/core/firebase/firebase_providers.dart`의 provider(앱 어디서나 꺼내 쓰는 공급자 — Riverpod의 기본 단위)가 만든 객체를 생성자로 받습니다. 그래야 테스트에서 가짜를 넣을 수 있습니다.

```dart
class MeetingRepository {
  MeetingRepository(this._db);
  final FirebaseFirestore _db;

  Future<Result<Meeting>> load(String id) => Result.guard(
    () async => Meeting.fromDoc(await _db.doc('meetings/$id').get()),
    mapError: firestoreError, // permission-denied → PermissionDeniedError 등
  );
}

@riverpod
MeetingRepository meetingRepository(Ref ref) =>
    MeetingRepository(ref.watch(firestoreProvider));
```

**잘못 붙는 사고를 막는 장치 셋**

1. `firebase` 명령은 언제나 `--project dev` 또는 `--project prod`를 적습니다(`.firebaserc`의 별칭). 감시 훅이 막아 줍니다.
2. 설정 파일 대조 스크립트(`tool/check_firebase_config.dart`)가 flavor마다 설정 파일 세 개의 프로젝트 ID와 패키지 이름을 `.firebaserc`와 대조합니다. CI에서 돕니다.
3. 개발용 앱은 화면 왼쪽 아래에 「개발」 띠를 그립니다.

## 2. 파일

틀 파일은 끝에 `.template`이 붙어 있습니다. 하네스 저장소 안에서 Dart 분석기가 틀을 진짜 코드로 읽지 않게 하려는 것입니다. 복사할 때 뗍니다. 파일 안의 `<앱>` 같은 자리는 복사 스크립트가 값으로 바꿉니다(§2.3).

### 2.1 app 묶음

| 넣는 자리 | 하는 일 |
|---|---|
| `lib/main_dev.dart` | 개발용 진입점 — 「개발」 띠와 상태 흉내를 켭니다 |
| `lib/main_prod.dart` | 실서비스 진입점 — `lib/dev/`를 불러오면 검사가 실패합니다 |
| `lib/app/bootstrap.dart` | 진입점 공통 시작 순서 — 바탕 준비 → 백엔드 준비 → 앱 그리기 |
| `lib/app/flavor.dart` | `AppFlavor`(dev·prod)와 그 값을 읽는 `appFlavorProvider` |
| `lib/app/app.dart` | 앱 바깥 틀 — 라우터·문구 파일을 잇고, 화면을 옮길 때마다 지금 주소를 기록 |
| `lib/app/router.dart` | `createAppRouter({initialLocation, devRoutes, devBranchRoutes})` — 화면 이동 표(go_router). 목업 캔버스도 이 함수를 부릅니다. `devRoutes`·`devBranchRoutes`는 개발용 경로 주입 자리 — 셸 밖에 더할 경로와 하단 탭 이름별로 그 탭 가지 안에 끼울 경로(2-3 비교안이 하단 탭과 함께 뜨게)입니다. 개발용 진입점(`main_dev.dart`·`main_canvas.dart`)만 넘기고 `main_prod.dart`는 넘기지 않습니다. 셸을 만들 때 가지마다 `branchRoutes`로 감쌉니다 |
| `lib/app/current_location.dart` | 지금 열린 화면의 주소(경로 + `?질의`) |
| `lib/core/result/result.dart`·`app_error.dart` | `Result<T>`·`AppError` |
| `lib/core/firebase/backend_init.dart` | 백엔드 준비 자리 — 이 묶음에서는 아무것도 하지 않습니다. 4-0에서 Firebase 판으로 바뀝니다 |
| `lib/dev/dev_flavor_banner.dart` | 「개발」 띠 |
| `lib/dev/dev_route_state.dart` | 주소의 `?state=`·`?as=guest`를 상태 흉내(`devStateProvider`·`devGuestProvider`)에, 머무는 공간(2-4)의 `?focus=`·`?state=many`를 `devFocusProvider`·`devManyProvider`에 넣는 덮어쓰기 |
| `lib/l10n/app_ko.arb`, `l10n.yaml` | Flutter 공식 다국어 설정과 한국어 문구 파일. `lib/l10n/app_localizations.dart`의 `AppLocalizations`가 만들어집니다 |
| `test/…` | `Result`·「개발」 띠·라우터(화면 목록의 경로마다 맞는 길이 있는지 — 3단계에서 `screenPaths`에 경로를 채웁니다, 동시에 둘 만들기, `?state=` 읽기, 실서비스는 꺼짐) 테스트 |
| `tool/check_firebase_config.dart` | 설정 파일 대조와 flavor 경계 검사(§5) |
| `tool/check_analytics_events.dart` | 계측 이벤트 「정의 + 호출」 검사(§5) |
| `tool/ios_flavors.rb` | iOS 쪽 flavor 설정을 만드는 스크립트(§3 ⑨) |

`lib/dev/dev_route_state.dart`는 목업 캔버스 틀의 `lib/core/dev_state/dev_state.dart`를 씁니다. 그래서 2-0에서 그 파일 하나를 먼저 함께 넣습니다(§3 ⑤).

### 2.2 backend 묶음

| 넣는 자리 | 하는 일 |
|---|---|
| `lib/core/firebase/backend_init.dart` | 빈 판을 바꿔 넣습니다 — flavor에 맞는 설정 파일로 Firebase에 붙습니다 |
| `lib/core/firebase/firebase_providers.dart` | Firebase 객체를 공급하는 유일한 자리. 서버 함수는 리전을 맞춰 부릅니다(`functionsRegion`) |
| `lib/core/analytics/events.dart` | 계측 이벤트를 모아 두는 유일한 파일. 이벤트 하나 = 공개 함수 하나 |
| `.firebaserc` | 별칭 `dev`·`prod`와 두 프로젝트 ID |
| `firebase.json` | 보안 규칙·색인·서버 함수·Hosting·Remote Config 자리와 에뮬레이터 포트. `hosting`은 웹 페이지 틀(`../hosting-site/`)의 `hosting/public`을 가리키고, `/api/deletion-request`를 서버 함수 `deletionRequest`로 넘기는 재작성 규칙(rewrite — 들어온 주소를 다른 대상으로 넘기는 규칙)을 담습니다 |
| `remoteconfig.template.json` | Remote Config 값의 정본 — 강제 업데이트용 `min_version`·`latest_version`(`4-3-backend-deploy.md`) |
| `firestore.rules`·`storage.rules` | 보안 규칙 뼈대 — 기본은 전부 거부, 보호 필드 예, 웹 폼 컬렉션(`deletionRequests` — 클라이언트 읽기·쓰기 전부 막음, 서버 함수만 씀) 예 |
| `firestore.indexes.json` | 색인 — 비어 있음 |
| `package.json`(최상위) | Firebase CLI 판 고정 자리 |
| `functions/` | 서버 함수(TypeScript) — `src/config/region.ts` 리전 상수, `src/index.ts`에서 모든 함수에 리전 적용, 기능 폴더 예 `src/example/`(순수 함수 + 단위 테스트), 계정 삭제 요청 받기 `src/deletion/`(아래) |
| `rules-test/` | 보안 규칙 테스트 — 공식 도구 `@firebase/rules-unit-testing`, Node 기본 테스트 실행기 |

**계정 삭제 요청 받기(`functions/src/deletion/`)** — 웹 페이지의 계정 삭제 요청 폼은 Firestore에 바로 쓰지 않고 HTTP 서버 함수 `deletionRequest` 하나로 보냅니다. 웹 페이지에는 App Check(우리 앱에서 온 요청인지 확인하는 장치) 토큰이 없어서, 폼이 Firestore에 바로 쓰면 Firestore의 App Check 강제를 켜는 순간 막히기 때문입니다.

1. 폼이 같은 사이트의 `/api/deletion-request`로 보냅니다.
2. Hosting이 `firebase.json`의 재작성 규칙대로 그 요청을 함수에 넘깁니다. 같은 사이트 주소라 폼에 프로젝트 값이 없고, CORS(다른 사이트에서 부르기 허락)를 열지 않습니다.
3. 함수가 검사합니다 — POST만, 이메일 형식·길이(320자), 이유 길이(500자), 봇이 채우는 빈칸.
4. 같은 이메일의 요청이 24시간 안에 이미 있으면 새로 쓰지 않습니다. 새로 썼든 건너뛰었든 답은 같습니다 — 어떤 이메일이 요청했는지 바깥에서 알아낼 수 없게 하려는 것입니다.
5. 함수가 관리자 권한으로 `deletionRequests`에 `email`·`reason`·`createdAt`(서버 시간)을 씁니다. 보안 규칙은 이 컬렉션의 클라이언트 쓰기를 전부 막습니다.

이 함수는 「`onRequest`는 웹훅에만」 규칙(`4-1-backend-db.md`)의 정해진 예외입니다. 판단 로직은 Firebase 없이 도는 함수로 떼어 단위 테스트합니다(가짜 저장소). 함수 인스턴스는 2개로 묶어 마구 불려도 비용이 크게 늘지 않게 합니다.

### 2.3 손으로 넣는 조각과 복사 스크립트

| 파일 | 하는 일 |
|---|---|
| `apply.sh` | 묶음 하나를 프로젝트에 복사하면서 `.template`을 떼고 `<이름>` 자리를 값으로 바꿉니다. 이미 있는 파일은 덮어쓰지 않고 알린 뒤 실패로 끝납니다. 예외는 `backend_init.dart` 하나 — app 묶음의 빈 판 그대로일 때만 바꿔 넣습니다 |
| `snippets/android-flavors.gradle.kts` | `android/app/build.gradle.kts`에 넣는 flavor 조각 |
| `snippets/analysis_options-exclude.yaml` | `analysis_options.yaml`의 분석 제외 목록에 더할 줄 |

`apply.sh`가 받는 값

| 이름 | 뜻 | 예 |
|---|---|---|
| `앱` | Dart 패키지 이름(`pubspec.yaml`의 `name`) | `example` |
| `앱 이름` | 홈 화면 이름 | `예시앱` |
| `리전` | Firestore·서버 함수 리전 | `asia-northeast3` |
| `개발용 프로젝트 ID`·`실서비스 프로젝트 ID` | Firebase 프로젝트 ID | `example-dev`·`example-prod` |
| `저장소 이름` | 최상위 `package.json` 이름 앞부분 | `example` |
| `Node 주 판` | 서버 함수 실행 판 — `.nvmrc`와 같은 주 판. Cloud Functions가 지원하는 판인지 공식 문서로 확인 | `.nvmrc` 값 |

## 3. 2-0에서 넣는 순서

명령은 모두 저장소 최상위 폴더에서 부릅니다. `flutter`·`dart` 앞에는 `fvm`을 붙입니다.

① **앱을 만듭니다** — `fvm flutter create --org <패키지 앞부분> --project-name <앱> --platforms android,ios .` 예를 들어 `--org app --project-name example`이면 패키지 이름이 `app.example`이 됩니다.

② **만들어진 견본 두 개를 지웁니다** — `lib/main.dart`, `test/widget_test.dart`. 진입점이 `main_dev`·`main_prod`로 바뀌기 때문입니다.

③ **app 묶음을 넣습니다**

```bash
bash .claude/templates/firebase/apply.sh app '앱=example' '앱 이름=예시앱'
```

④ **패키지를 들입니다** — 판 숫자는 적지 않고 `pub add`가 고르게 둡니다.

```bash
fvm flutter pub add flutter_riverpod riverpod_annotation go_router intl dev:riverpod_generator dev:build_runner
fvm flutter pub add 'flutter_localizations:{"sdk":"flutter"}'
```

⑤ **상태 흉내 파일을 넣습니다** — 목업 캔버스 틀의 `lib/core/dev_state/dev_state.dart.template`을 `lib/core/dev_state/dev_state.dart`로 복사합니다. 캔버스 나머지는 2-1에서 넣어도 됩니다.

⑥ **`pubspec.yaml`과 `analysis_options.yaml`을 고칩니다**

- `pubspec.yaml`의 `flutter:` 아래에 `generate: true`를 넣습니다. 다국어 문구 클래스(`AppLocalizations`)를 빌드 때 만들게 하는 줄입니다.
- `analysis_options.yaml`의 `analyzer: exclude:`에 `snippets/analysis_options-exclude.yaml`의 네 줄을 더합니다(`hosting/**`는 3단계 웹 페이지 폴더 — 아직 없어도 미리 넣어 둡니다).

⑦ **안드로이드 flavor를 넣습니다**

- `snippets/android-flavors.gradle.kts`를 `android/app/build.gradle.kts`의 `android { … }` 안 `defaultConfig { … }` 바로 아래에 넣고, `<앱 이름>`을 바꿉니다.
- `android/app/src/main/AndroidManifest.xml`의 `android:label` 값을 `@string/app_name`으로 바꿉니다. flavor마다 다른 홈 화면 이름이 여기로 들어옵니다.

⑧ **안드로이드 서명을 넣습니다** — `../android-signing/README.md`의 「넣는 순서」.

⑨ **iOS flavor를 만듭니다**

```bash
ruby tool/ios_flavors.rb app.example 예시앱
```

빌드 설정 여섯 개(`Debug-dev`·`Profile-dev`·`Release-dev`와 `-prod` 셋), scheme `dev`·`prod`, 번들 ID·홈 화면 이름, 「Firebase 설정 파일 복사」 빌드 단계를 만듭니다. 여러 번 돌려도 결과가 같습니다. `xcodeproj`(Xcode 프로젝트 파일을 고치는 Ruby 도구 — FlutterFire CLI도 씁니다)가 필요합니다. 없으면 `gem install xcodeproj`.

flavor마다 만드는 빌드 설정 파일(`ios/Flutter/Debug-dev.xcconfig` 등)은 목업 캔버스의 `DeviceFamily.xcconfig`를 이미 include합니다. 그래서 캔버스를 넣을 때(캔버스 README 「프로젝트에 넣는 차례」 ⑥)는 기본 `Debug.xcconfig`·`Release.xcconfig` 두 파일에만 줄을 더하면 됩니다. 캔버스 파일이 아직 없어도 빌드는 됩니다(없으면 건너뛰는 include).

⑩ **만들고 검사합니다**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --output=none --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
fvm dart run tool/check_firebase_config.dart
fvm dart run tool/check_analytics_events.dart
.claude/scripts/build-lock.sh fvm flutter build apk --debug --flavor dev -t lib/main_dev.dart
.claude/scripts/build-lock.sh fvm flutter build apk --debug --flavor prod -t lib/main_prod.dart
.claude/scripts/build-lock.sh fvm flutter build ios --simulator --debug --flavor dev -t lib/main_dev.dart
.claude/scripts/build-lock.sh fvm flutter build ios --simulator --debug --flavor prod -t lib/main_prod.dart
```

⑪ **화면 이동·테마를 채웁니다** — `lib/app/router.dart`의 첫 화면 자리를 실제 화면으로, `lib/app/app.dart`에 `theme: buildAppTheme(AppTokens.light)`를 디자인 시스템을 들인 뒤 잇습니다. 라우터의 내비게이터 열쇠는 함수 안에서 만듭니다(파일 맨 위 전역 값 금지 — 캔버스가 라우터를 여러 개 동시에 만듭니다).

## 4. 4-0에서 넣는 순서

① **backend 묶음을 넣습니다**

```bash
bash .claude/templates/firebase/apply.sh backend '앱=example' '리전=asia-northeast3' \
  '개발용 프로젝트 ID=example-dev' '실서비스 프로젝트 ID=example-prod' \
  '저장소 이름=example' 'Node 주 판=<.nvmrc의 주 판>'
```

② **Firebase 패키지를 들입니다**

```bash
fvm flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage cloud_functions firebase_analytics
```

Crashlytics·Remote Config·App Check·메시지는 쓰기 시작하는 단계에서 들입니다.

③ **Node 쪽 도구를 깝니다** — 판 숫자는 `npm`이 고르고 잠금 파일(`package-lock.json`)에 남습니다. 잠금 파일 셋(최상위·`functions/`·`rules-test/`)을 모두 git에 올립니다. CI가 이 파일들로 같은 판을 깝니다.

```bash
fnm exec --using=.nvmrc -- npm install --save-dev --save-exact firebase-tools
cd functions && fnm exec --using=../.nvmrc -- npm install firebase-functions firebase-admin
fnm exec --using=../.nvmrc -- npm install -D typescript eslint typescript-eslint && cd ..
cd rules-test && fnm exec --using=../.nvmrc -- npm install -D @firebase/rules-unit-testing firebase && cd ..
```

④ **설정 파일을 만듭니다** — flavor마다 한 번씩, 실행기를 앞에 붙여 부릅니다. 옵션 이름은 그때 FlutterFire 공식 문서로 다시 확인합니다.

```bash
.claude/scripts/with-owner.sh flutterfire configure --project=example-dev --platforms=android,ios --yes \
  --out=lib/core/firebase/firebase_options_dev.dart \
  --android-package-name=app.example.dev --android-out=android/app/src/dev/google-services.json \
  --ios-bundle-id=app.example.dev --ios-out=ios/config/dev/GoogleService-Info.plist --ios-build-config=Debug-dev
```

실서비스용은 `dev`를 `prod`로, 패키지 이름·번들 ID의 `.dev`를 떼고 한 번 더 부릅니다.

⑤ **iOS flavor 스크립트를 다시 돌립니다** — `ruby tool/ios_flavors.rb app.example 예시앱`. FlutterFire CLI는 `--ios-build-config`를 받으면 설정 파일을 앱에 넣는 자기 빌드 단계를 더합니다. 그 단계는 빌드할 때마다 FlutterFire CLI가 깔려 있어야 하고, 우리 「Firebase 설정 파일 복사」 단계와 일이 겹칩니다. 스크립트가 FlutterFire 단계를 지우고 우리 단계 하나만 남깁니다.

⑥ **안드로이드 빌드 설정을 확인합니다** — FlutterFire CLI가 Google 서비스 Gradle 플러그인 두 줄(`android/settings.gradle.kts`의 `plugins { … }`에 판과 함께 한 줄, `android/app/build.gradle.kts`의 `plugins { … }`에 한 줄)을 넣었는지 봅니다. 없으면 Firebase 안드로이드 설정 공식 문서의 줄을 그대로 넣습니다.

⑦ **만들고 검사합니다** — §3 ⑩의 명령에 더해, `functions/`에서 `npm run lint`·`npm run build`·`npm test`. 보안 규칙 테스트는 CI에서만 돕니다(§5).

⑧ **리전 세 곳이 같은지 봅니다** — `functions/src/config/region.ts`의 `REGION`, `lib/core/firebase/firebase_providers.dart`의 `functionsRegion`, `firebase.json`의 `hosting.rewrites`의 `region`. 앞의 둘이 다르면 앱이 서버 함수를 찾지 못하고, 셋째가 다르면 웹 폼이 함수를 찾지 못합니다. `apply.sh`가 세 곳에 같은 `리전` 값을 넣습니다.

⑨ **웹 페이지 틀을 넣습니다** — `firebase.json`의 `hosting`이 `hosting/public`을 가리키므로, `../hosting-site/README.md` 「4-0에서 합치기」대로 합니다. 3단계에서 이미 넣었으면 `hosting/` 안의 3단계 설정만 지웁니다.

## 5. 검사

| 검사 | 무엇을 보나 | 언제 없으면 건너뛰나 |
|---|---|---|
| `tool/check_firebase_config.dart` | ① `lib/main_prod.dart`가 import를 따라가도 `lib/dev/`에 닿지 않는가 ② `lib/features`·`lib/shared`에서 `Firebase….instance`를 직접 부르지 않는가 ③ flavor마다 설정 파일 세 개(`firebase_options_<flavor>.dart`·`google-services.json`·`GoogleService-Info.plist`)의 프로젝트 ID = `.firebaserc`의 같은 별칭, 패키지 이름·번들 ID = 그 flavor의 것 | ③은 `.firebaserc`가 없으면 건너뜁니다. 한 flavor의 세 파일이 모두 없으면 그 flavor만 건너뛰고, 하나라도 있으면 셋 다 있어야 합니다. 실서비스 프로젝트를 Hosting용으로 먼저 만든 3단계에도 통과합니다 |
| `tool/check_analytics_events.dart` | ① `events.dart`의 공개 이벤트 함수마다 그 파일 밖(`lib/`, 생성 파일 제외)에서 부르는 곳이 있는가 ② `events.dart` 밖에서 `logEvent`를 직접 부르지 않는가 | `lib/core/analytics/events.dart`가 없으면 건너뜁니다. 테스트에서 부른 것은 세지 않습니다 |
| 보안 규칙 테스트 | 남의 것 읽기·쓰기 거부, 보호 필드 쓰기 거부, 웹 폼 컬렉션은 클라이언트가 읽기·쓰기 모두 못 함, 규칙 없는 경로 거부, Storage 본인 폴더·이미지만 | CI에서만 에뮬레이터를 띄워 돕니다(`--project demo-rules-test` — `demo-`로 시작하는 가짜 프로젝트라 실제 Firebase에 닿지 않습니다). 이 맥에서는 감시 훅이 에뮬레이터 명령을 막습니다 |

두 Dart 검사는 바깥 패키지 없이 Dart 기본 라이브러리만 씁니다. 퍼널 단계표(`launch-plan.md`)와 이벤트 함수를 대조하는 일은 이 스크립트에 없습니다 — 계측 단계 문서가 정합니다.

## 6. 실측 메모

빈 Flutter 앱에 이 틀을 넣어 실제로 빌드하며 확인한 것입니다.

- **안드로이드 빌드 도구 최근 판은 `resValue`가 기본으로 꺼져 있습니다.** flavor 조각의 `buildFeatures { resValues = true }`가 없으면 「Product Flavor dev contains custom resource values, but the feature is disabled」로 빌드가 멈춥니다.
- **Firebase CLI를 최상위 `node_modules`에 깔면 `flutter analyze`가 오류를 냅니다.** 그 안에 Dart 견본 파일이 들어 있어서입니다. 분석 제외 줄(§3 ⑥)이 막습니다. CI의 Flutter 검사는 `node_modules`를 깔지 않아 원래 안 걸립니다.
- **iOS는 Swift Package Manager(Xcode의 패키지 관리 도구)로 플러그인을 받는 것이 Flutter 기본입니다.** 그래서 `ios/Podfile`이 없을 수 있습니다. `ios_flavors.rb`는 Podfile이 있을 때만 새 빌드 설정을 적어 넣고, 빌드 설정 파일의 CocoaPods 줄은 없으면 건너뛰는 include로 둡니다.
- **Firebase iOS SDK 최신 판은 최신 Xcode가 필요합니다.** Xcode가 오래되면 iOS 빌드가 「firebase-ios-sdk … contains incompatible tools version」으로 멈춥니다. 4-0 전에 Xcode 판을 Firebase iOS SDK 요구 판과 맞춥니다.
- **iOS 홈 화면 이름은 빌드 설정 값 `APP_DISPLAY_NAME`으로 갈립니다.** 스크립트가 `Info.plist`의 표시 이름을 그 값으로 바꿔 둡니다.
- **「개발」 띠는 앱 바깥에 씌웁니다.** 실서비스 진입점이 `lib/dev/`를 부르지 않게 하려는 것이라, 글 방향을 띠에 직접 줍니다.
- **지금 주소 기록은 첫 화면을 그리는 도중에는 할 수 없습니다.** provider는 화면을 그리는 도중에 바꿀 수 없어서, 앱이 처음 뜰 때만 그 프레임이 끝난 뒤에 넣습니다. 버튼으로 화면을 옮길 때는 새 화면을 그리기 전에 들어갑니다(테스트로 확인).
- **서명은 `key.properties`를 심볼릭 링크로 걸어도 업로드 키로 서명됩니다.**
- **Hosting 재작성 규칙은 서울 리전 함수에도 닿습니다.** `demo-` 가짜 프로젝트로 Hosting·서버 함수·Firestore 에뮬레이터를 함께 띄워, `/api/deletion-request`로 보낸 요청이 `asia-northeast3`의 `deletionRequest`로 넘어가 문서 하나가 서버 시간과 함께 쓰이는 것을 확인했습니다(같은 이메일 두 번째 요청·봇 빈칸은 쓰이지 않음, 잘못된 이메일 400, GET 405). 실제 Firebase의 동작은 처음 올릴 때 개발용 프로젝트에서 다시 봅니다.

## 7. 지켜야 할 것

- **FlutterFire 설정 파일(`firebase_options_*.dart`·`google-services.json`·`GoogleService-Info.plist`)은 git에 올립니다.** 안의 값은 「이 앱이 어느 프로젝트에 붙나」를 가리키는 공개 식별값입니다. 막는 일은 보안 규칙과 App Check가 합니다. CI 빌드에도 필요합니다.
- **비밀값(AI 제공사 키·결제 비밀값)은 앱에 넣지 않습니다.** 서버 함수 비밀값(Secret Manager)에 프로젝트마다 넣습니다.
- **보호 필드를 바꿀 때는 보안 규칙·보호 필드 표·규칙 테스트를 한 커밋에서 함께 고칩니다.**
- **계측 이벤트는 `events.dart`에만 정의하고, 만든 작업에서 부르는 곳도 함께 만듭니다.**
- **`lib/dev/`는 개발용 진입점과 캔버스 진입점에서만 부릅니다.**
- **`appFlavorProvider`는 진입점이 덮어써야 값이 생깁니다.** 덮어쓰지 않은 채 읽으면 실패합니다 — flavor를 모르는 채로 도는 일을 막으려는 것입니다.
