# 안드로이드 서명 틀

플레이 스토어에 올리는 앱은 **업로드 키**(우리가 만들어 갖고 있는 서명 열쇠 파일)로 서명해야 합니다. 서명(signing)은 「이 앱 파일은 이 열쇠를 가진 사람이 만들었다」를 증명하는 도장입니다. 플레이 앱 서명을 켜 두면 진짜 배포용 서명 키는 구글이 보관하고, 우리는 업로드 키만 갖습니다.

이 폴더는 그 서명을 빌드 설정(Gradle — 안드로이드 빌드 도구)에 잇는 틀입니다.

## 무엇을 하나

- `android/key.properties`가 **있으면 release 서명**(업로드 키), **없으면 debug 서명**(이 맥의 개발용 열쇠)으로 빌드합니다.
- 그래서 키가 없는 컴퓨터와 CI(GitHub에서 자동으로 도는 검사)에서도 빌드 확인은 됩니다.
- 대신 debug 서명으로 만든 번들을 실수로 올릴 수 있으니, 앱 출시 절차(`store-release`)가 올리기 전에 번들의 서명이 업로드 키인지 확인합니다.

## 파일

| 틀 파일 | 쓰는 법 |
|---|---|
| `signing.gradle.kts.snippet` | `android/app/build.gradle.kts`에 손으로 넣는 조각 둘. 조각 ①은 파일 맨 위, 조각 ②는 기존 `buildTypes { … }` 자리 |
| `key.properties.example` | `key.properties`의 모양. 값 자리는 `<…>`로 비워 두었습니다 |

## 넣는 순서 (2-0 개발환경 준비)

① `signing.gradle.kts.snippet`의 조각 ①을 `android/app/build.gradle.kts`의 `plugins { … }` 위에 넣습니다.

② 같은 파일 `android { … }` 안의 기존 `buildTypes { … }`(Flutter가 만든 「debug 키로 서명」 블록)를 조각 ②로 바꿉니다.

③ 확인합니다 — 키가 없는 상태에서 실서비스용 출시 빌드가 debug 서명으로 만들어지는지 봅니다.

```bash
.claude/scripts/build-lock.sh fvm flutter build apk --release --flavor prod -t lib/main_prod.dart
"$ANDROID_HOME/build-tools/<판>/apksigner" verify --print-certs build/app/outputs/flutter-apk/app-prod-release.apk
```

서명자 줄에 `CN=Android Debug`가 나오면 됩니다.

## 업로드 키를 만들 때 (3단계 배포 전)

① AI가 `keytool`(자바에 든 열쇠 만들기 도구)로 업로드 키를 만듭니다. 파일은 **프로젝트 폴더 밖** `~/.config/harness/keys/<패키지 이름>-upload.jks`에 두고 권한을 600(나만 읽고 쓰기)으로 바꿉니다.

② 비밀번호는 AI가 만들어 같은 폴더의 `key.properties`에 적습니다. 모양은 `key.properties.example` 그대로입니다. 계정 장부의 `ANDROID_UPLOAD_KEY_PROPERTIES`에 그 경로를 적습니다.

③ 비밀번호가 화면에 보이는 그 순간, 사람이 비밀번호 관리자에 키 파일과 함께 옮깁니다. 업로드 키를 잃으면 구글에 재설정을 요청해야 하고 며칠 걸립니다.

④ 출시 빌드 때만 `store-release`가 장부의 경로를 `android/key.properties`로 연결(심볼릭 링크 — 다른 곳의 파일을 가리키는 바로가기)하고, 끝나면 지웁니다. 이 맥에서 연결한 채로 빌드했을 때 업로드 키로 서명되는 것을 확인했습니다.

## 지켜야 할 것

- **비밀번호를 평문으로 어디에도 적지 않습니다** — 워크플로 파일·주석·문서·커밋 메시지 모두입니다. 이전 앱에서 실제 사고가 있었습니다. 감시 훅이 커밋 전에 `storePassword=`·`keyPassword=` 바로 뒤에 값이 있는 줄을 찾아 막습니다. 예시 파일처럼 값 자리를 `<…>`·`${…}`로 비워 두면 걸리지 않습니다.
- `key.properties`·`*.jks`는 무시 목록(`.gitignore`)에 이미 있습니다. 프로젝트 안에 생겨도 올라가지 않지만, 애초에 프로젝트 안에 두지 않습니다.
- `storeFile`은 절대 경로로 씁니다. 상대 경로는 `android/app` 폴더 기준으로 풀려 엉뚱한 곳을 찾습니다.
