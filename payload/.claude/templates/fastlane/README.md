# 플레이 올리기 틀 (fastlane)

fastlane(스토어 올리기를 명령으로 하는 도구)으로 구글 플레이에 앱 번들과 스토어 정보를 올리는 묶음입니다. 플레이용 기능 이름은 `supply`이고, Fastfile 안에서는 `upload_to_play_store`라는 이름으로 부릅니다. 앱 출시 절차 전체는 `store-release` 스킬이 정본이고, 이 README는 틀 파일을 프로젝트에 넣는 법과 스토어 정보·스크린샷 파일을 다루는 법을 적습니다.

**언제 넣나** — 6단계 앞, Draft App 제약(한 번도 검토를 통과해 출시된 적 없는 앱에는 명령 도구로 올릴 수 없음)이 4단계 비공개 테스트 검토로 풀린 뒤입니다. 그 전에는 사람이 콘솔에서 손으로 올립니다. 스크린샷 틀(§5)과 스토어 정보 점검(§4)은 그보다 먼저, 3단계 스토어 등록정보 초안 때부터 써도 됩니다.

## 목차

1. [파일](#1-파일)
2. [프로젝트에 넣는 차례](#2-프로젝트에-넣는-차례)
3. [부르는 꼴](#3-부르는-꼴)
4. [스토어 정보 폴더](#4-스토어-정보-폴더)
5. [스크린샷 만들기](#5-스크린샷-만들기)
6. [이전 앱에서 확인한 교훈](#6-이전-앱에서-확인한-교훈)
7. [지켜야 할 것](#7-지켜야-할-것)

---

## 1. 파일

| 틀 파일 | 프로젝트에 넣는 자리 · 하는 일 |
|---|---|
| `Gemfile` | 프로젝트 맨 위 `Gemfile` — fastlane 판을 묶습니다. `bundle install`이 만드는 `Gemfile.lock`과 함께 git에 올립니다 |
| `fastlane/Appfile` | `fastlane/Appfile` — 패키지 이름과 서비스 계정 키 경로(장부의 환경변수). `__PACKAGE_NAME__`을 실서비스 패키지 이름으로 바꿉니다 |
| `fastlane/Fastfile` | `fastlane/Fastfile` — 올리기·트랙 지정·단계적 출시·멈추기·트랙 옮기기를 한곳에 모은 lane들. 맨 위 주석이 lane 목록입니다 |
| `fastlane/check_metadata.rb` | `fastlane/check_metadata.rb` — 스토어 정보 점검(글자 수·틀 자리 표시·그림 크기·투명 채널·변경 내역 파일). fastlane 없이 `ruby`로 어느 브랜치에서나 돕니다. Fastfile도 올리기 전에 부릅니다 |
| `fastlane/metadata/android/ko-KR/` | 같은 자리 — 스토어 정보 폴더(§4). 지금은 한국어만 둡니다 |
| `fastlane/screenshots/frame.html` | 같은 자리 — 스크린샷 한 장의 HTML 틀(1080×1920) |
| `fastlane/screenshots/slides.tsv` | 같은 자리 — 스크린샷 목록(그림·문구) |
| `fastlane/screenshots/render.sh` | 같은 자리 — 목록대로 찍어 스토어 정보 폴더에 PNG로 둡니다 |

## 2. 프로젝트에 넣는 차례

작업 브랜치에서, 프로젝트 맨 위 폴더에서 합니다. 서비스 계정 만들기·플레이 콘솔 권한은 `store-release` 스킬 「fastlane 처음 켜기」가 정합니다.

① **복사합니다** — `Gemfile`은 프로젝트 맨 위로, `fastlane/` 폴더는 통째로 프로젝트 맨 위에 복사합니다.

② **자리 표시를 바꿉니다** — `fastlane/Appfile`의 `__PACKAGE_NAME__`을 실서비스 패키지 이름(개발용 `.dev`가 붙지 않은 것)으로, `fastlane/screenshots/frame.html`의 `__FONT_FILE__`을 앱에 넣은 서체 파일 이름으로 바꾸고, `:root`의 색을 앱 1층 토큰 값으로 맞춥니다.

③ **Ruby와 fastlane을 깝니다** — 맥에 기본으로 든 Ruby는 오래된 판일 수 있어 Homebrew(맥용 패키지 설치 도구)의 Ruby를 씁니다. 판 숫자는 문서에 적지 않고, 고른 판과 이유를 `mvp/adr.md`에 적습니다.

```bash
bundle install          # Gemfile.lock이 생깁니다 — git에 올립니다
bundle exec fastlane --version
```

④ **스토어 정보를 채웁니다** — `mvp/store-listing.md`(서식 `.claude/templates/store-listing.md`)의 확정 문구를 §4의 파일로 옮기고, §5로 스크린샷을 만들고, `ruby fastlane/check_metadata.rb`가 「문제 없음」을 낼 때까지 고칩니다.

⑤ **`.gitignore`를 확인합니다** — `fastlane/report.xml`·`fastlane/README.md`(fastlane이 lane 목록으로 자동으로 쓰는 파일)는 올리지 않아도 됩니다. **`fastlane/metadata/`는 무시 목록에 넣지 않습니다** — 이전 앱에서 확인한 교훈입니다(§6).

⑥ **PR로 합칩니다.** 그다음 main에서 `store-release`의 「fastlane 처음 켜기」 5번(키 확인)부터 이어 갑니다.

## 3. 부르는 꼴

```bash
.claude/scripts/with-owner.sh bundle exec fastlane <lane> [이름:값 ...]
```

- **실행기를 앞에 붙입니다** — 실행기가 계정 장부의 `PLAY_SERVICE_ACCOUNT_FILE`을 환경변수로 넣어 줍니다. 빼면 감시 훅이 막고, 훅을 지나도 Fastfile이 키가 없다고 멈춥니다.
- **main에서만 돕니다** — 감시 훅이 main이 아니면 막고, Fastfile의 `before_all`도 main·깨끗한 작업 트리를 확인합니다. 그래서 스토어 정보를 고칠 때는 작업 브랜치 → PR로 고치고, 올리기는 합친 뒤 main에서 합니다.
- **lane 목록과 옵션은 `fastlane/Fastfile` 맨 위 주석**이 정본입니다. 어떤 lane을 언제 쓰는지는 `store-release` 스킬이 정합니다.
- 실제로 올리기 전에 `dry_run:true`로 플레이에 「검사만」 요청할 수 있습니다(fastlane의 `validate_only`).
- `upload` lane은 스토어 정보를 바꾸지 않습니다 — 앱 번들과 그 빌드 번호의 변경 내역만 올립니다. 스토어 정보는 `listing` lane으로 따로 올립니다. 6단계 측정 기간에 스토어 정보가 실수로 바뀌지 않게 하려는 것입니다.

## 4. 스토어 정보 폴더

**git으로 관리합니다.** 스토어 정보도 코드처럼 브랜치·PR로 고칩니다. 콘솔에서 손으로 바꾼 것은 다음 `listing` 때 이 폴더 내용으로 덮이니, 콘솔에서 바꿨으면 같은 내용을 이 폴더에도 옮깁니다.

```
fastlane/metadata/android/ko-KR/
  title.txt                 앱 이름
  short_description.txt     짧은 설명
  full_description.txt      자세한 설명
  changelogs/<빌드 번호>.txt  그 빌드 번호의 변경 내역(예: 12.txt — pubspec.yaml version의 + 뒤 숫자)
  images/
    icon.png                아이콘 512×512 PNG
    featureGraphic.png      그래픽 이미지 1024×500, 투명 채널 없음
    phoneScreenshots/       폰 스크린샷 — 파일 이름 순서대로 보입니다(01_ko-KR.png …)
```

- 파일 이름과 폴더 모양은 fastlane 공식 문서의 것입니다. 이름이 다르면 fastlane이 읽지 않습니다. `changelogs/default.txt`는 두지 않습니다 — 빌드 번호마다 변경 내역을 쓰게 하려는 것이고, 오래된 문구가 새 판에 붙는 일을 막습니다.
- 글자 수와 그림 크기는 플레이 콘솔 입력칸·도움말 기준입니다. `check_metadata.rb` 맨 위 `LIMITS`에 모여 있고, 콘솔이 다른 한도를 보이면 거기를 고칩니다. 지금 점검하는 것 — 앱 이름 30자·짧은 설명 80자·자세한 설명 4000자·변경 내역 500자, 아이콘 512×512, 그래픽 이미지 1024×500(투명 채널 없음), 스크린샷 2~8장·변마다 320~3840 화소·긴 변이 짧은 변의 2배 이하·투명 채널 없음.
- 틀 파일에 남은 `<…>` 자리 표시가 하나라도 있으면 점검이 실패합니다 — 자리 표시가 그대로 스토어에 올라가는 사고를 막습니다.
- 빈 폴더를 git에 남기려고 둔 `.gitkeep`은 fastlane이 그림으로 읽지 않습니다.
- 문구는 올리기 전에 `ux-writing-reviewer`를 거칩니다(3단계 문서 「검사 ③」과 같은 차례).

## 5. 스크린샷 만들기

**기본은 「꾸민 그림」입니다** — 앱 화면 그림을 폰 테두리에 넣고 위에 설명 문구를 얹은 1080×1920 그림입니다. 광고를 누르고 스토어에 온 사람이 첫눈에 무엇을 하는 앱인지 알게 하려는 것입니다.

1. **재료 그림을 고릅니다** — 초안은 목업 캔버스의 골든 그림(`test/goldens/canvas/<창 열쇠>.png`)을 씁니다. 골든 그림은 테스트가 화면을 그림 파일로 찍어 둔 것으로, 보통 폰 그림이 390×844 화소라 크게 늘리면 흐립니다. 실제로 올릴 판은 더 또렷한 재료를 씁니다 — 폰에서 개발용 앱을 띄워 찍은 화면(USB로 연결한 폰이면 `adb exec-out screencap -p > shot.png`, 또는 폰의 화면 캡처)이나, 그림 배율을 높여 다시 찍은 골든 그림. 골든 그림 자체(390×844)는 긴 변이 짧은 변의 2배를 넘어 그대로는 스크린샷으로 못 올립니다 — 반드시 이 틀에 넣어 1080×1920으로 만듭니다.
2. **목록을 적습니다** — `fastlane/screenshots/slides.tsv`에 한 줄에 한 장: 순서·그림 경로·큰 문구·작은 문구(탭으로 나눔). 큰 문구 안 `*별표*`는 강조색이 됩니다. 문구는 `mvp/store-listing.md`의 스크린샷 계획에서 옵니다.
3. **찍습니다** — `bash fastlane/screenshots/render.sh`. 맥의 Google Chrome을 화면 없이 띄워 찍고, macOS 기본 도구 `sips`로 투명 채널을 뺀 PNG를 `images/phoneScreenshots/`에 둡니다. Chrome이 없으면 `npx playwright screenshot`으로 찍습니다. 먼저 보고 고르려면 `--out <폴더>`로 다른 폴더에 찍습니다.
4. **사람이 보고 고릅니다** — 그림이 괜찮은지, 문구가 잘리지 않았는지는 사람이 봅니다. AI는 그림을 판정하지 않고 `check_metadata.rb`의 크기·장수 점검까지만 합니다.

**선택 — 앱 화면 그대로 찍기** — Maestro(화면 조작을 짧은 설정 파일로 적어 기기에서 자동으로 돌리는 도구)로 개발용 앱을 돌며 화면을 찍는 방식도 있습니다. 실제 화면 그대로라는 점이 좋지만 도구를 하나 더 깔아야 합니다. 쓰기로 하면 찍은 그림을 위 1번의 재료로 넣거나, 꾸밈 없이 바로 `phoneScreenshots/`에 둡니다. 판과 설치법은 그때 공식 문서로 확인합니다.

## 6. 이전 앱에서 확인한 교훈

- **명령을 그때그때 치면 무엇을 어디에 올렸는지 남지 않습니다** — 이전 앱은 Fastfile 없이 `supply` 명령만 직접 쳤습니다. 그래서 이 틀은 올리기·트랙 지정을 Fastfile 한 파일에 모았습니다.
- **스토어 정보 폴더를 무시 목록에 넣으면 스토어 문구의 이력이 사라집니다** — 이 틀은 git으로 관리합니다.
- **Draft App에는 명령 도구로 「완료」 상태 릴리스를 못 올립니다** — `Only releases with status draft may be created on draft app`. 4단계 비공개 테스트 검토를 통과하기 전에는 콘솔에서 손으로 올립니다.
- **서비스 계정 권한은 반영에 최대 하루가 걸리고, 앱을 다른 개발자 계정으로 옮기면 자동으로 따라오지 않습니다.**
- **`supply init`이 끝에 `undefined method 'name' for nil`을 내도 받기는 된 경우가 있습니다** — 특정 fastlane·Ruby 판 조합의 버그입니다. 받은 파일이 폴더에 다 있는지 확인합니다.
- **패키지 이름은 첫 업로드 뒤 바꿀 수 없습니다** — `Appfile`의 이름을 올리기 전에 계정 표·flavor 설정과 맞춥니다.

## 7. 지켜야 할 것

- **키·비밀번호를 이 폴더 어디에도 적지 않습니다** — 서비스 계정 키 파일은 장부 폴더의 `keys/`에, 경로는 장부에만 둡니다. Fastfile·Appfile·주석·커밋 메시지에 키 내용이나 비밀번호를 적지 않습니다. 감시 훅이 `"private_key":` 같은 줄을 커밋 전에 막습니다.
- **올리기는 main에서, 실행기를 붙여, `store-release` 절차로만 합니다.**
- **Fastfile을 고칠 일이 생기면 하네스 틀도 같이 고칩니다** — 프로젝트마다 따로 고치면 다음 프로젝트가 같은 문제를 다시 만납니다. 프로젝트마다 바뀌는 것은 `Appfile`의 패키지 이름, 스토어 정보 폴더, 스크린샷 목록·색·서체뿐입니다.
