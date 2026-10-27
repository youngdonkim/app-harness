# Flutter 하네스 개편안 (검토본)

이 문서는 지금 이 폴더에 들어 있는 웹사이트용 하네스(website-harness를 복사해 온 것)를 **Flutter 앱을 처음부터 만드는 서비스용 하네스**로 바꾸는 계획입니다. 하네스는 「AI가 따르는 규칙·절차 문서와 자동 검사 장치를 모아 둔 묶음」을 말합니다. 이 문서는 검토 단계의 결과물이라, 하네스 파일은 아직 하나도 고치지 않았습니다.

새 하네스의 전제는 다섯 줄로 요약됩니다.

1. 앱은 Flutter로 만들고, **안드로이드를 먼저** 구글 플레이에 냅니다. iOS는 같은 코드로 나중에 붙입니다.
2. 백엔드는 **Firebase**(구글이 운영하는, 로그인·DB·파일 저장·서버 함수·알림·분석을 한데 묶은 서비스)입니다.
3. 개발은 **iOS 시뮬레이터**(맥 안의 가상 아이폰)와 **USB로 연결한 실제 안드로이드폰**으로 합니다. Firebase 에뮬레이터(Firebase를 내 컴퓨터에서 흉내 내는 도구)는 개발에 쓰지 않고, 개발 중에도 클라우드 Firebase에 붙습니다.
4. 그래서 Firebase 프로젝트를 **개발용과 실서비스용 둘**로 나눕니다.
5. 플레이 개발자 계정은 **사업자(조직) 계정**입니다.

읽는 순서는 이렇습니다. ① 무엇이 그대로 남고 무엇이 바뀌는지(§1) → ② 파일 하나하나를 어떻게 할지(§2) → ③ 새로 짜야 하는 영역의 설계(§3) → ④ 사용자가 정해야 할 것(§4) → ⑤ 고치는 순서(§5)입니다.

> ⚠ 도구의 판 번호·화면 위치·정책·가격은 이 글을 쓴 날(2026-10-20) 기준입니다. 구현할 때 공식 문서로 다시 확인합니다. 이번에 공식 자료로 직접 확인한 것은 네 가지입니다 — X 광고의 MMP 필수 조건, AppsFlyer 요금, 플레이의 광고 ID 권한 요건, Firebase 보안 규칙 테스트가 에뮬레이터를 쓴다는 점(맨 아래 「참고한 바깥 자료」).
>
> 이 문서 곳곳의 「이전 앱에서 확인한 교훈」은 사용자가 예전에 Flutter + Firebase로 만들어 플레이에 낸 앱을 조사해 얻은 것입니다.

## 목차

1. [바뀌지 않는 것과 바뀌는 것](#1-바뀌지-않는-것과-바뀌는-것)
2. [파일별 처분표](#2-파일별-처분표)
   - [2.1 처분 네 가지의 뜻](#21-처분-네-가지의-뜻)
   - [2.2 규칙·설정 파일](#22-규칙설정-파일)
   - [2.3 idea-to-mvp 스킬](#23-idea-to-mvp-스킬)
   - [2.4 design-system 스킬](#24-design-system-스킬)
   - [2.5 그 밖의 스킬·에이전트](#25-그-밖의-스킬에이전트)
   - [2.6 훅·스크립트·틀](#26-훅스크립트틀)
   - [2.7 새로 생기는 파일](#27-새로-생기는-파일)
3. [영역별 설계안](#3-영역별-설계안)
   - [3.1 하네스 원본으로 독립하기](#31-하네스-원본으로-독립하기)
   - [3.2 2-0 개발환경 준비](#32-2-0-개발환경-준비)
   - [3.3 고정 스택과 폴더 구조](#33-고정-스택과-폴더-구조)
   - [3.4 2·3단계의 데이터와 상태 화면](#34-23단계의-데이터와-상태-화면)
   - [3.5 디자인 시스템](#35-디자인-시스템)
   - [3.6 목업 캔버스](#36-목업-캔버스)
   - [3.7 3단계 배포 — 플레이 내부 테스트](#37-3단계-배포--플레이-내부-테스트)
   - [3.8 Firebase 프로젝트 둘 — 개발용과 실서비스용](#38-firebase-프로젝트-둘--개발용과-실서비스용)
   - [3.9 4단계 백엔드 — Firebase](#39-4단계-백엔드--firebase)
   - [3.10 계측과 설치 출처](#310-계측과-설치-출처)
   - [3.11 6단계 출시와 측정](#311-6단계-출시와-측정)
   - [3.12 검증 — 화면 밖 검사 목록](#312-검증--화면-밖-검사-목록)
   - [3.13 머지와 출시 — 「머지 = 배포」의 재정의](#313-머지와-출시--머지--배포의-재정의)
   - [3.14 계정 장부·실행기·감시 훅](#314-계정-장부실행기감시-훅)
   - [3.15 AGENTS.md가 바뀌는 자리](#315-agentsmd가-바뀌는-자리)
4. [사용자가 정해야 할 것](#4-사용자가-정해야-할-것)
   - [4.1 확정된 것](#41-확정된-것)
   - [4.2 아직 정할 것](#42-아직-정할-것)
5. [구현 순서](#5-구현-순서)

---

## 1. 바뀌지 않는 것과 바뀌는 것

**그대로 두는 뼈대** — 6단계 흐름(1 Intent 인터뷰 → 2 Mockup → 3 FrontendBuild → 4 BackendBuild → 5 MarketResearch → 6 MvpLaunch)과 철학은 그대로입니다.

- 먼저 돌아가는 물건을 끝까지 만들고, 광고로 온 낯선 사람의 **행동**으로 거릅니다. 판정은 6단계 한 번뿐입니다.
- 화면을 만든 순간부터 코드가 화면의 정본(SoT — 진실의 원천, 가장 믿을 기준)입니다. 브리프는 말투·고정 문구·결정 이유의 정본으로 남습니다.
- 화면을 눈으로 보고 판정하는 일은 사람 몫입니다. AI는 화면 밖 검사까지만 합니다.
- git 브랜치 흐름(`/new-task` → 작업 → `/done-task`), 자동 임시 저장 훅, main 직접 올리기 금지, 위임 규칙, 계정·소유 관리(계정 장부와 실행기)는 그대로입니다.

**바뀌는 것** — 스택과 그에 딸린 절차입니다.

| 영역 | 지금(웹) | 바뀐 뒤(Flutter) |
|---|---|---|
| 앱 | Next.js·React·TypeScript | Flutter(구글이 만든, 코드 하나로 안드로이드·iOS 앱을 함께 만드는 도구)·Dart 언어 |
| 판 고정 | fnm·`.nvmrc`(Node 판) | 앱은 fvm(Flutter 판 관리 도구)·`.fvmrc`. 서버 함수와 Firebase CLI용 Node는 fnm·`.nvmrc`를 그대로 씁니다(§3.2) |
| 부품·스타일 | Tailwind·shadcn·CSS 변수 3층 | Material 3 부품·ThemeData·ThemeExtension(§3.5) |
| 화면 보기 | 브라우저의 목업 캔버스(iframe) | iPad 시뮬레이터에 띄우는 Flutter 목업 캔버스 + iOS 시뮬레이터·안드로이드폰 + 골든 그림(§3.6) |
| 2·3단계 저장소 | 브라우저 localStorage | 기기 안 작은 저장소(shared_preferences) |
| 백엔드 | Supabase(로컬 도커 + 클라우드 하나) | Firebase 클라우드 프로젝트 둘(개발용·실서비스용), 로컬 흉내 없음(§3.8) |
| 서버 코드 | Vercel 서버 함수 | Cloud Functions(Firebase가 돌려 주는 서버 함수, TypeScript)(§3.9) |
| 권한 벽 | Supabase RLS(행 단위 접근 규칙) | Firestore·Storage 보안 규칙(Security Rules)(§3.9) |
| 배포 | Vercel, main 머지 = 자동 배포 | 앱은 구글 플레이 트랙, 백엔드는 `firebase deploy`. 둘 다 머지와 따로(§3.13) |
| 웹 페이지 | Vercel의 웹사이트 전체 | Firebase Hosting의 작은 웹 — 랜딩·개인정보처리방침·계정 삭제 요청(§3.9) |
| 검색 노출 | 4단계 SEO | 없음 — 대신 스토어 등록정보(§3.11) |
| 6단계 유입 구분 | 주소 꼬리표(UTM) | MMP(여러 광고 매체의 설치를 한곳에서 갈라 주는 서비스)(§3.10) |
| 폐기 방향 | 「나중에 React Native로 옮긴다」 | 폐기. iOS는 같은 코드로 나중에 붙이는 선택 절차 |

---

## 2. 파일별 처분표

### 2.1 처분 네 가지의 뜻

- **그대로** — 고치지 않습니다.
- **일부 고침** — 뼈대는 두고 웹·Supabase에 묶인 문장·명령만 바꿉니다.
- **새로 씀** — 같은 자리·같은 역할로 내용을 통째로 다시 씁니다.
- **삭제** — 지웁니다(git 이력에는 남습니다).

### 2.2 규칙·설정 파일

| 파일 | 처분 | 무엇을 왜 |
|---|---|---|
| `AGENTS.md` | 일부 고침(큼) | 「하네스 수정」을 「이 저장소가 원본」으로(§3.1), 「이 프로젝트가 쓰는 도구」와 그 아래 Supabase 세 절(배포와 마이그레이션·로컬 DB 리셋·클라우드 시드)을 Firebase 기준으로 다시 씁니다. 계정 표에서 Supabase·Vercel 행을 빼고 Firebase 두 프로젝트·플레이 콘솔·광고·MMP 행을 넣습니다. 상세는 §3.15 |
| `CLAUDE.md` | 그대로 | `@AGENTS.md` 한 줄짜리 포인터입니다 |
| `.claude/harness-version` | 새로 씀 | 「이 저장소가 원본이고, 어디서 갈라져 나왔나」 기록으로(§3.1) |
| `.claude/owner` | 그대로 | 소유 선언(`owner=personal`)은 스택과 무관합니다. 플레이 계정은 사용자 개인사업자 명의라 `personal`이 맞습니다(§4.1) |
| `.claude/settings.json` | 그대로 | 훅 등록만 들어 있습니다 |
| `.claude/rules/markdown-style.md` | 그대로 | 목차 규칙이라 스택과 무관합니다 |
| `.claude/rules/security-baseline.md` | 새로 씀 | 1부(밖에서 닿는 위협)를 앱 기준으로 — 앱 파일은 뜯어볼 수 있다, 앱 안 비밀값 금지, 딥링크로 들어온 값 검증, 로그에 토큰·개인정보 금지. 2부(Supabase RLS 규칙)를 Firestore·Storage 보안 규칙과 보호 필드 원칙으로(§3.9). 자동으로 읽히는 파일 조건(`paths`)을 `firestore.rules`·`storage.rules`·`functions/**`·`lib/core/firebase/**`·`lib/features/**/data/**`로 |
| `.gitignore` | 새로 씀 | 웹 것 → Flutter·Firebase 것(`build/`·`.dart_tool/`·`.fvm/flutter_sdk`·`android/key.properties`·`*.jks`·`*.keystore`·`functions/node_modules/`·`functions/lib/`·`.firebase/`·`env/*.json`(예시 파일은 남김)·`fastlane/report.xml`). FlutterFire 설정 파일은 올립니다(§3.8) |
| `.github/workflows/ci.yml` | 새로 씀 | Node 빌드·린트 → Flutter 검사(형식·분석·테스트·디버그 빌드) + 서버 함수 검사(린트·빌드·단위 테스트) + 보안 규칙 테스트(§4.1). 「밀린 마이그레이션 확인」 단계는 마이그레이션이 없어져 삭제합니다(§3.12) |
| `docs/account-check.md` | 일부 고침 | Vercel·Supabase 항목 → 플레이 콘솔(조직 계정)·Firebase 두 프로젝트·구글 클라우드 서비스 계정·광고 계정·MMP 항목. 원칙 ①~⑥은 그대로 |
| `docs/git-workflow.md` | 일부 고침 | 「main에 머지되면 Vercel이 배포」·「Vercel 즉시 되돌리기」를 앱 출시·백엔드 배포 흐름과 「더 높은 번호로 다시 올리기」로(§3.13) |
| `docs/flutter-harness-plan.md` | (이 문서) | 구현이 끝나면 지워도 됩니다 |

### 2.3 idea-to-mvp 스킬

| 파일 | 처분 | 무엇을 왜 |
|---|---|---|
| `SKILL.md` | 일부 고침 | 설명 줄의 「리액트」「데스크톱 폭·폰 폭」「Vercel」을 Flutter·폰 폭·플레이 내부 테스트로. §1.1의 「React Native로 옮긴다」를 「iOS는 같은 코드로 나중에(선택 절차)」로. §1.2 판별의 `package.json` → `pubspec.yaml`, `.vercel/` 문장 삭제. 4단계 설명의 「백엔드·DB」를 Firebase로. 아티팩트 캔버스 호환(§1.2 0번)은 이 하네스로 시작하는 프로젝트에 해당이 없어 삭제 |
| `references/1-intent.md` | 일부 고침 | 참고 디자인 질문에서 앱 화면 캡처(Mobbin 등)를 먼저 권합니다. 「폰에서 쓰나 컴퓨터에서 쓰나」 질문은 「폰」을 전제로 둡니다(태블릿은 지원하지 않음 — §4.1). 브리프의 누르는 크기 바닥선을 48dp(dp는 화면 밀도와 무관한 길이 단위)로. 1단계 끝에 「서비스 이름이 정해졌나 → 패키지 이름」 확인을 더합니다(§3.7) |
| `references/intent-examples/*.html` (4개) | 일부 고침 | 예시 안의 「웹」「목업 캔버스 폭」 낱말만 점검합니다 |
| `references/2-0-dev-setup.md` | 새로 씀 | 도구 점검표·판 맞추기·앱 뼈대 만들기(flavor 포함)·폰 연결·변경 종류별 반영 표까지 통째로(§3.2). 아티팩트 캔버스 옮겨 오기 절은 삭제 |
| `references/2-1-mockup.md` | 일부 고침(큼) | 기능 목록·화면 목록·일곱 갈래·상태 표 절은 그대로입니다. 「화면 짓는 규칙」을 Dart 기준으로, 「주소」 칸을 앱 안 경로(go_router 경로)로, 목업 캔버스 쓰는 법·코멘트 반영을 iPad 캔버스 기준으로(§3.6). 견본 지도 규칙은 Flutter 지도 부품으로 |
| `references/2-2-mockup-design-upgrade.md` | 일부 고침 | 절차(규칙 먼저 → A판·B판 → 사람이 고름 → 토큰·부품에 넣어 전체 적용)는 그대로입니다. 「범위 클래스로 비교안 값 덮기」를 「비교안만 감싸는 Theme 덮개」로, 비교안 폴더를 `lib/dev/drafts/`로, 컨테이너 쿼리를 LayoutBuilder로(§3.5) |
| `references/3-frontend-build.md` | 일부 고침(큼) | 남은 화면·대조·모션 절의 뼈대는 그대로입니다. 배포 전 검사 ①(Dart판 `design-check.sh`)·②(Flutter 코드 품질 점검표)·③(`.tsx` → `.dart`)을 바꾸고, 배포 절을 플레이 내부 테스트로 새로 씁니다(§3.7). 색인 제외·`/dev` 404·Vercel 체크리스트는 삭제 |
| `references/4-0-backend-prep.md` | 일부 고침(큼) | 계정 확정·비밀값 장부·소셜 로그인 절의 틀은 남깁니다. Supabase·Vercel 절 → 「Firebase 두 프로젝트 만들기·요금제와 예산 알림·리전·플레이 콘솔·구글 클라우드 서비스 계정」(§3.8). 장부 표에 「어느 프로젝트(개발/실서비스)」 칸을 더합니다 |
| `references/4-1-backend-db.md` | 새로 씀 | 표·마이그레이션·로컬 리셋·pgTAP 이야기가 전부 SQL 것이라, Firestore 데이터 모양(컬렉션·문서)·보안 규칙·보호 필드 표·색인 파일·개발용 시드와 정리 스크립트로 다시 씁니다(§3.9). 「shared_preferences에 넣던 구조를 읽고 컬렉션으로 옮긴다」는 출발점은 그대로입니다 |
| `references/4-2-backend-auth.md` | 일부 고침 | 앞부분(동의·온보딩·약관)은 그대로입니다. 「정본부터 받아온다」 원칙은 두고 대상을 FlutterFire 공식 예제·문서로, 세션 층 이야기를 「세션은 Firebase Auth가 기기에 저장·갱신한다」로, 소셜 로그인을 서명 지문(SHA-1) 등록·카카오 커스텀 토큰으로(§3.9) |
| `references/4-3-backend-deploy.md` | 일부 고침(큼) | SEO 절 삭제. 스모크 테스트를 「보안 규칙 테스트 + 서버 함수 단위 테스트 + 기기 통합 테스트」로. 계측을 Firebase Analytics·MMP로(§3.10), 에러 관측을 Crashlytics로. 배포를 「실서비스 배포 전 확인」을 거친 `firebase deploy` + 플레이 트랙 올리기로(§3.8·§3.13). 베타 공유를 비공개 테스트 트랙으로(§3.7) |
| `references/5-market-research.md` | 일부 고침 | 비교 기준 「배포 주소」를 「스토어 링크(또는 시험 트랙 링크)」로, 경쟁자 발견에 플레이 스토어 검색·리뷰를 기본 출처로 더합니다 |
| `references/6-mvp-launch.md` | 일부 고침(큼) | 퍼널에 「스토어 방문 → 설치 → 첫 실행」을, 광고 매체를 구글·메타·X 앱 설치 캠페인으로, 채널 구분을 MMP로 바꿉니다. 「정식 출시 준비」를 1부 앞에 둡니다(§3.11) |

### 2.4 design-system 스킬

| 파일 | 처분 | 무엇을 왜 |
|---|---|---|
| `SKILL.md` | 새로 씀 | 철칙·결정 트리·안티패턴 표가 전부 Tailwind 클래스 말로 적혀 있습니다. 같은 생각(3층 토큰 + 조립 계층, 강조색 세 자리, 컴포넌트 우선)을 Dart 말로 다시 씁니다(§3.5). 「강조색은 어디에 쓰나」 절은 거의 그대로 옮깁니다 |
| `references/bootstrap-project.md` | 새로 씀 | shadcn init·CSS 진입 파일 → 토큰 파일 셋·ThemeExtension·`context.colors` 확장·ThemeData 조립·감싸개 부품·디자인 시스템 페이지 |
| `references/naming-taxonomy.md` | 일부 고침 | 이름 문법·유형표의 생각은 그대로, 표기를 CSS 변수(`--primary`)에서 Dart 이름(`colors.primary`·`space.s4`)으로 |
| `references/component-taxonomy.md` | 일부 고침 | 역할 분류·범용/전용·동의어 규칙은 그대로입니다. 「cva variant」 → 「감싸개 부품의 variant 열거형」, 「고친 shadcn 부품 목록」 삭제, 인벤토리 색인 명령을 `lib/shared/components/**`·`lib/features/*/widgets/**` 기준으로 |
| `references/layout-frames.md` | 일부 고침 | 셸·영역·크기 예산 생각은 그대로입니다. 반응형 계약의 컨테이너 쿼리 → LayoutBuilder, 안전 영역 → SafeArea·`MediaQuery.paddingOf` |
| `references/common-patterns.md` | 일부 고침 | WCAG 항목의 웹 전용 줄을 시스템 글자 크기 키우기 대응으로 바꾸고, 「큰 글자 배율에서 넘치는 세 자리」(§3.5)를 점검 항목으로 더합니다 |
| `references/visual-polish.md` | 일부 고침 | 점검 항목 A~I는 그대로입니다. 폰 화면 옮기기 R1~R9는 「작은 폰·큰 폰」 기준으로 다시 고릅니다 |
| `references/reference-analysis.md` | 일부 고침 | 「분석값 → 1층 램프·2층 shadcn 변수」를 「→ foundation 상수·ColorScheme」으로, 색 형식을 `Color(0xFF…)`로. 대비 계산은 하네스가 주는 Dart 대비 계산 도우미로(§3.5) |
| `references/font-loading.md` | 새로 씀 | 웹폰트 → 앱에 서체 파일을 넣는 방식(pubspec 등록), 한글 서체 용량 줄이기, 실행 중 내려받는 `google_fonts` 패키지를 쓰지 않는 결정 |

### 2.5 그 밖의 스킬·에이전트

| 파일 | 처분 | 무엇을 왜 |
|---|---|---|
| `skills/project-init/SKILL.md` | 일부 고침(큼) | 원본 자리를 이 저장소로, 「이 저장소 자신이 원본이면 동기화하지 않는다」 갈래를 맨 앞에, 「새 폴더에 깔기」는 잠금(§3.1) |
| `skills/github-connect/SKILL.md` | 그대로 | git·gh·jq·GitHub 연결은 스택과 무관합니다 |
| `skills/new-task/SKILL.md` | 그대로 | |
| `skills/done-task/SKILL.md` | 일부 고침 | 코드 정리 판단의 「`src/`를 고친 브랜치」를 「`lib/`·`functions/src/`를 고친 브랜치」로 |
| `skills/ship-task/SKILL.md` | 일부 고침 | 「머지하면 Vercel이 자동 배포」 문장들을 「머지는 출시가 아니다」로. 스모크 관문의 `npm run smoke`를 §3.12의 명령으로, 허용 도구 줄도 함께 |
| `skills/rewind-task/SKILL.md` | 그대로 | |
| `skills/code-cleanup/SKILL.md` | 일부 고침 | 대상 거르기의 제외 규칙을 `lib/dev/`·생성 파일(`*.g.dart`·`firebase_options_*.dart`) 기준으로, 「색·크기는 2층 이름」 문장을 Dart 토큰 말로 |
| `skills/transfer-ownership/SKILL.md` | 일부 고침(큼) | Supabase 조직·Vercel 이전 → Firebase 두 프로젝트의 소유자 이전(구글 클라우드 조직 사이 이동)·플레이 앱 이전(개발자 계정 사이 이전)·업로드 키·서비스 계정·MMP·광고 계정 이전으로 |
| `skills/harness-diet/SKILL.md` | 일부 고침 | 「[하네스 제안] → website-harness에 반영」을 「이 저장소에서 바로 고침」으로 |
| `skills/deep-research/SKILL.md` | 그대로 | |
| `agents/git-flow.md` | 그대로 | |
| `agents/harness-auditor.md` | 일부 고침 | 점검 F의 「Next.js + `src/` 구조에서 글롭이 걸리는지」를 Flutter·Firebase 구조(`lib/`·`android/`·`ios/`·`functions/`·`firestore.rules`) 기준으로 |
| `agents/ux-writing-reviewer.md` | 일부 고침 | 설명 줄의 「Next.js 화면·컴포넌트」를 「Flutter 화면(.dart)과 다국어 문구 파일(.arb)」로. 스토어 등록정보 문구(`fastlane/metadata/`)와 Hosting 페이지 문구도 검토 대상이라고 더합니다 |
| `agents/delegation-integrator.md` | 그대로 | |

### 2.6 훅·스크립트·틀

| 파일 | 처분 | 무엇을 왜 |
|---|---|---|
| `hooks/auto-wip-commit.sh` | 그대로 | |
| `hooks/no-main-push.sh` | 일부 고침 | 주석의 「Vercel 등이 자동 배포」 설명만 바꿉니다. 막는 동작은 그대로입니다 |
| `hooks/owner-runner-guard.sh` | 일부 고침 | `vercel`·`supabase` 갈래를 지우고 `firebase`·`flutterfire`·`fastlane` 갈래를 넣습니다. 실서비스 프로젝트를 건드리는 명령의 추가 조건도 여기서 막습니다(§3.14) |
| `scripts/with-owner.sh` | 일부 고침 | 장부 이름 목록을 바꿉니다 — Vercel·Supabase 이름을 빼고 Firebase 로그인 계정·플레이 서비스 계정 키 파일 경로를 넣습니다(§3.14). 안내 예시 교체 |
| `scripts/design-check.sh` | 새로 씀 | grep 검사를 Dart 코드 기준으로 다시 짭니다(§3.5) |
| `templates/mockup-canvas/` 전체 | 새로 씀 | Next.js 라우트·iframe 캔버스·Playwright → iPad 시뮬레이터용 Flutter 캔버스 진입점·코멘트 서버·Dart 도구 스크립트(§3.6). 옛 `.tsx`·`.ts`·`.mjs` 틀은 전부 삭제 |
| `templates/sample-map/` 전체 | 새로 씀 | MapLibre GL JS(웹) → Flutter 지도 부품. 키 없는 OpenFreeMap 스타일과 「출처 표시를 지우지 않는다」는 결정은 그대로 둡니다 |
| `templates/status-template.md`·`sources-template.md` | 그대로 | |

### 2.7 새로 생기는 파일

| 파일 | 무엇 |
|---|---|
| `.claude/skills/store-release/SKILL.md` | 앱을 플레이 트랙에 올리는 절차 스킬. main 확인 → 빌드 번호 → 앱 번들 → 서명 확인 → fastlane으로 올리기 → 태그. 결과가 밖으로 나가는 일이라 **메인이 직접** 실행합니다(§3.7·§3.13) |
| `.claude/skills/backend-release/SKILL.md` | 실서비스 Firebase에 보안 규칙·색인·서버 함수·Hosting을 배포하는 절차 스킬. 「실서비스 배포 전 확인」(§3.8)을 거쳐 메인이 직접 실행합니다 |
| `.claude/skills/idea-to-mvp/references/3-flutter-quality.md` | 배포 전 검사 ②의 Flutter 코드 품질 점검표. 웹에서 Vercel 플러그인 스킬이 맡던 자리를 하네스가 직접 갖습니다(§3.12) |
| `.claude/templates/firebase/` | `firebase.json`·`.firebaserc` 예시·`firestore.rules` 뼈대(기본 전부 거부 + 보호 필드 자리)·`storage.rules` 뼈대·`functions/` 뼈대(TypeScript, 기능별 폴더, 리전 상수)·보안 규칙 테스트 뼈대(§3.9) |
| `.claude/templates/hosting-site/` | Firebase Hosting용 작은 웹 — 랜딩·개인정보처리방침·계정 삭제 요청 폼, 출시 단계 변수로 랜딩 모드 전환(§3.9) |
| `.claude/templates/fastlane/` | `Fastfile`(올리기·트랙 지정을 한곳에)·`Appfile`·스토어 정보 폴더 뼈대(`metadata/android/ko-KR/`)·스크린샷 동기화 스크립트(§3.7·§3.11) |
| `.claude/templates/store-listing.md` | 스토어 등록정보·데이터 보안 신고·광고 ID 신고 답안 초안 틀 — 6단계가 씁니다(§3.10·§3.11) |
| `.claude/templates/android-signing/` | 서명 설정 gradle 조각(`key.properties`가 있으면 release 서명, 없으면 debug)과 `key.properties` 예시(§3.7) |

---

## 3. 영역별 설계안

### 3.1 하네스 원본으로 독립하기

**지금 상태** — 이 폴더의 `.claude/`는 website-harness에서 복사한 사본입니다. 그래서 세 군데가 「여기서 고치지 마라, 원본에서 고쳐 동기화하라」고 말합니다.

1. `AGENTS.md` 「하네스 수정」 절
2. `.claude/harness-version` — `repo=youngdonkim/website-harness`, `commit=9fe65a79857e`
3. `project-init` — 이 파일이 있으면 「동기화 모드」로 들어가 `~/dev/website-harness`의 파일로 덮으려 합니다

**그대로 두면 어떻게 될까요?** 누가 「하네스 동기화해줘」라고 하는 순간, Flutter용으로 고친 파일이 전부 웹 원본으로 덮이려 합니다. 그래서 세 군데를 모두 바꿉니다.

**이 폴더는 「하네스 원본 겸 첫 제품」입니다(확정).** 실제 앱 하나를 끝까지 만들어 봐야 하네스가 맞는지 알기 때문입니다. 두 번째 Flutter 프로젝트가 생기면 그때 하네스 부분만 떼어 별도 저장소로 옮기고, 이 폴더는 평범한 제품 저장소가 됩니다.

**바꾸는 방법**

- **`.claude/harness-version`** — 아래 모양으로 다시 씁니다. `origin=self`가 「이 저장소가 원본」이라는 표시입니다.

  ```
  origin=self
  repo=youngdonkim/<첫 제품 저장소>
  forked-from=youngdonkim/website-harness@9fe65a79857e
  date=<개편을 마친 날>
  ```

  저장소 이름은 처음 폴더 이름을 임시로 쓰고, 서비스 이름이 정해지면 하네스 개편이 끝난 뒤 저장소 이름과 원본 기록을 함께 바꿉니다(§4.1).
- **`project-init`** — 전제 확인의 맨 앞에 갈래 하나를 더합니다: 「대상 폴더의 `harness-version`에 `origin=self`가 있으면 이 저장소가 원본이다. 동기화하지 않고 『이 저장소가 Flutter 하네스 원본이라 동기화할 곳이 없습니다』라고 알린다.」 「새 폴더에 깔기」 기능은 「아직 준비 안 됨」으로 잠가 둡니다 — 웹 원본에 있던 `payload/` 구조가 여기엔 없어서, 열어 두면 반쯤 돌다 멈춥니다.
- **`AGENTS.md` 「하네스 수정」** — 「이 저장소의 `.claude/`·`docs/`·`.github/`가 Flutter 하네스의 원본이다. 고칠 일이 생기면 여기서 바로 고친다(브랜치 규칙은 똑같이 지킨다). website-harness의 개선은 저절로 들어오지 않는다 — 가져올 가치가 있으면 사람이 골라 손으로 옮긴다.」
- **함께 바꿀 문장** — 「하네스 사본이라 고치지 않는다」를 전제로 쓴 곳이 셋 더 있습니다. `2-0-dev-setup.md`의 「`.claude/templates/` 원본은 고치지 않는다」, `3-frontend-build.md`의 「하네스 틀을 고칠 문안을 사용자에게 준다」, `harness-diet`의 [하네스 제안] 안내입니다. 셋 다 「틀 원본을 이 저장소에서 고친다」로 바꿉니다.

### 3.2 2-0 개발환경 준비

**도구 점검표를 새로 짭니다.** 2-0을 시작할 때 확인 명령을 한 번에 돌려 표로 보여 주고, 필요한 도구는 AI가 묻지 않고 깝니다. 다만 **용량이 큰 것과 약관 동의가 필요한 것은 묻습니다.**

| 도구 | 하는 일 | 확인 명령 | 언제 | 없으면 |
|---|---|---|---|---|
| git·gh·jq | 지금과 같음 | 지금과 같음 | 이미 있음 | 지금과 같음 |
| fvm | 프로젝트마다 Flutter 판을 골라 쓰게 해 주는 도구 | `fvm --version` | 2-0 | AI가 깝니다(Homebrew) |
| Flutter SDK | 앱을 만드는 도구 본체(수백 MB) | `fvm flutter --version` | 2-0 | fvm이 `.fvmrc`에 적힌 판을 받습니다 |
| Xcode + iOS 시뮬레이터 | iOS 빌드 도구와 가상 아이폰·아이패드. **개발 기기이자 목업 캔버스 자리**라 지금 필요합니다 | `xcodebuild -version`, `xcrun simctl list devices` | 2-0 | **묻습니다** — 수십 GB이고 앱 스토어에서 받아 약관에 동의해야 합니다. 설치·약관은 사람, 시뮬레이터 런타임 받기는 AI |
| CocoaPods | iOS 쪽 플러그인을 묶는 도구 | `pod --version` | 2-0 | AI가 깝니다(Homebrew) |
| Android Studio + Android SDK | 안드로이드 빌드 도구 | `fvm flutter doctor` | 2-0 | AI가 Homebrew로 깔고, SDK 약관 동의(`flutter doctor --android-licenses`)는 사람이 누릅니다(확정) |
| JDK 17 이상 | 안드로이드 빌드 도구(Gradle)가 쓰는 자바 | `java -version` | 2-0 | Android Studio에 든 것을 씁니다 |
| 실제 안드로이드폰 | 개발 기기. USB로 연결 | `fvm flutter devices`에 보이는지 | 2-0 | [사람] 폰의 「개발자 옵션 → USB 디버깅」을 켜고, 처음 연결할 때 폰에 뜨는 「이 컴퓨터를 허용」을 누릅니다. AI는 켜는 위치를 폰 화면 이름 그대로 안내합니다 |
| Node.js(fnm·`.nvmrc`) | 서버 함수(TypeScript)·Firebase CLI·보안 규칙 테스트가 돕니다 | 지금과 같음 | 2-0(가벼움) | 지금과 같음 — 웹 하네스의 fnm 규칙을 그대로 씁니다 |
| Firebase CLI | 배포·프로젝트 관리 명령 도구 | `fnm exec --using=.nvmrc -- npx firebase --version` | 4-0 | `functions/`가 아닌 저장소 최상위 `package.json`의 개발 의존성으로 깔아 판을 고정합니다 |
| FlutterFire CLI | 앱에 Firebase 설정 파일을 만들어 주는 도구 | `flutterfire --version` | 4-0 | `fvm dart pub global activate flutterfire_cli` |
| Ruby + fastlane | 플레이에 스토어 정보·앱 번들을 올리는 도구 | `bundle exec fastlane --version` | 6단계 앞(자동화 때) | `fastlane/Gemfile`로 판을 고정해 깝니다(§3.7) |
| Aside | 견본 이미지 검색 | 지금과 같음 | 2-0 | 지금과 같음 |

**없어지는 도구** — Docker Desktop·Supabase CLI·Vercel CLI·Chrome(캔버스용)입니다. 로컬 DB를 띄우지 않고(§3.8), 캔버스를 웹으로 띄우지 않기 때문입니다(§3.6).

**명령 앞붙이기 규칙이 둘이 됩니다.**

- **flutter·dart 명령은 언제나 `fvm flutter …`·`fvm dart …`로, 저장소 최상위 폴더에서 부릅니다.** fvm은 그 폴더의 `.fvmrc`를 읽어 판을 고르므로 셸 설정 파일을 고칠 필요가 없습니다.
- **node·npm·npx 명령(Firebase CLI 포함)은 지금처럼 `fnm exec --using=.nvmrc --`를 붙입니다.** 키가 필요한 명령은 실행기가 맨 앞입니다(§3.14).

**판 맞추기 자리**

| 자리 | 맞추는 법 |
|---|---|
| `.fvmrc` | Flutter 판 한 줄(정본) |
| `pubspec.yaml`의 `environment` | Dart·Flutter 하한을 같은 판에 맞춥니다 |
| CI | Flutter 설치 단계가 `.fvmrc`를 읽게 합니다. **「stable 최신」으로 두지 않습니다** — 이전 앱에서 확인한 교훈: CI만 판이 앞서가 빌드가 어긋났습니다 |
| `.nvmrc`·`package.json` | Node 판과 Firebase CLI 판 |
| `android/` Gradle·Kotlin·JVM 타깃 | Flutter 판을 올릴 때마다 함께 확인합니다 — 이전 앱에서 확인한 교훈: Flutter를 올리자 안드로이드 JVM 타깃이 어긋나 빌드가 깨졌습니다 |

판 숫자는 문서에 박지 않고 ADR에 적는 원칙은 그대로입니다.

**패키지를 들이기 전에 확인합니다.** pub.dev(Flutter 패키지 저장소)에서 「최근 발행일·지원 플랫폼·관리 주체」를 보고, 1년 넘게 발행이 없거나 iOS·안드로이드 중 하나를 지원하지 않으면 들이지 않습니다. 이전 앱에서 확인한 교훈: 관리가 끊긴 아이콘 패키지 하나 때문에 Flutter를 올리자 컴파일이 깨졌습니다. 이 확인을 2-0과 `3-flutter-quality.md`에 넣습니다.

**앱 뼈대 만들기** — 2-0에서 `fvm flutter create --org <패키지 앞부분>`으로 만들고, 바로 **flavor 두 개(`dev`·`prod`)** 를 둡니다. flavor는 「같은 코드로 설정만 다른 앱 두 벌을 빌드하는 장치」입니다. 2·3단계에는 Firebase가 아직 없지만, 패키지 이름과 flavor 구조는 처음부터 고정해야 나중에 옛 이름이 남지 않습니다(§3.7·§3.8).

**Vercel 플러그인 절은 삭제합니다.** 대신 Dart·Flutter 공식 MCP 서버(분석기·패키지 검색을 AI가 직접 부르는 도구)를 쓸 수 있는지 그때 확인해 선택 항목으로 안내합니다.

**변경 종류별 반영 표를 규칙으로 둡니다.** 개발 중에 코드를 고치면 반영하는 방법이 종류마다 다릅니다. 이걸 모르면 「고쳤는데 안 바뀌었다」를 버그로 착각합니다. 이전 앱에서 확인한 교훈으로, AI가 작업을 끝내고 사람에게 「이제 무엇을 누르면 보이는지」를 이 표대로 알립니다.

| 바꾼 것 | 반영 방법 | 사람이 하는 일 |
|---|---|---|
| 화면 글자·색·배치(위젯의 `build` 안) | 핫 리로드(hot reload — 앱을 켠 채 바뀐 코드만 끼워 넣기) | 실행 중인 터미널에서 `r` |
| provider 초기값·`main()`·전역 값·열거형 | 핫 리스타트(hot restart — 앱 상태를 비우고 처음부터 다시 그리기) | `R` |
| Riverpod 코드 생성 대상 | `build_runner`가 다시 만든 뒤 핫 리로드 | AI가 `build_runner watch`를 띄워 둠 |
| 패키지 추가·네이티브 설정(AndroidManifest·Info.plist·Gradle·Podfile)·flavor·Firebase 설정 파일·서체·이미지 자산 | 앱을 멈추고 다시 빌드해 실행 | `q` 뒤 AI가 알려 준 실행 명령 |
| 보안 규칙·색인·서버 함수 | 개발용 Firebase에 배포 — 앱은 그대로 둠 | 없음(AI가 `--project dev`로 배포) |
| Remote Config 값 | 콘솔에서 게시 — 앱은 다음 받아오기 때 반영 | 앱을 껐다 켬 |
| 스토어 등록정보 | fastlane 또는 콘솔 | 콘솔 검토 대기 |

### 3.3 고정 스택과 폴더 구조

웹 하네스처럼 **스택은 고정하고 프로젝트마다 다시 고르지 않습니다.**

| 영역 | 고정 | 이유 |
|---|---|---|
| 언어·SDK | Flutter stable + Dart, fvm으로 판 고정 | §3.2 |
| 지원 기기 | **폰만**(안드로이드 먼저, iOS는 나중) | 캔버스 창·화면 규칙·검사가 하나씩 줄어듭니다(확정) |
| 부품 바탕 | Material 3 | 구글이 직접 관리하고, 접근성(화면 읽기·글자 키우기·누르는 크기)이 기본으로 들어 있습니다. 테마로 모양을 거의 다 바꿀 수 있습니다 |
| 상태 관리 | **Riverpod 3** + `riverpod_generator`(코드 생성) + `riverpod_lint`(Riverpod 전용 린트) | 아래 |
| 화면 이동 | **go_router**(Flutter 팀이 관리하는 경로 기반 화면 이동 패키지) | 아래 |
| 2·3단계 저장 | `shared_preferences`(기기 안 이름=값 저장소)에 JSON으로 | localStorage와 같은 자리 |
| 백엔드 | FlutterFire(Firebase 공식 Flutter 플러그인 모음) | §3.9 |
| 오류 모양 | `Result<T>` + `AppError` | 아래 |
| 다국어 | Flutter 공식 다국어(`flutter_localizations` + `.arb` 문구 파일) | 문구를 처음부터 파일 한곳에 모읍니다. MVP는 한국어만 넣습니다(§4.1) |
| 린트 | `flutter_lints` + `riverpod_lint` + 우리 규칙 몇 개 | 웹의 eslint 자리 |
| 테스트 | `flutter_test`(내장) + 골든 테스트 도우미 하나 + `integration_test` | 새로 깔 것을 최소로 |

**상태 관리를 Riverpod으로 고르는 이유** — 이 하네스에 꼭 필요한 성질이 셋 있습니다.

1. **저장·조회 코드를 통째로 갈아끼울 수 있어야 합니다.** 2·3단계는 기기 저장소, 4단계는 Firestore입니다. 저장·조회 코드를 provider(앱 어디서나 꺼내 쓰는 공급자) 하나로 두면, 4단계에서 그 구현만 바꾸고 화면은 한 줄도 안 고칩니다.
2. **목업 캔버스가 화면마다 다른 상태를 동시에 띄워야 합니다.** Riverpod의 덮어쓰기(`ProviderScope` overrides)로 같은 화면을 「빈 상태」「오류」로 나란히 띄웁니다(§3.6).
3. **테스트에서 가짜 데이터를 넣기 쉽습니다.** 위와 같은 덮어쓰기로 됩니다.

코드 생성은 이전 앱에서 실제로 쓴 방식이고 Riverpod 3의 권장 방식이라 처음부터 씁니다. 대신 `build_runner`라는 별도 단계가 생기므로, 반영 표(§3.2)와 검사 목록(§3.12)에 넣습니다. 생성 파일(`*.g.dart`)은 git에 올리고, CI가 「다시 만들었더니 달라졌다」를 잡게 합니다.

**화면 이동을 go_router로 고르는 이유** — 웹 하네스의 「화면 하나 = 주소 하나」 규칙을 그대로 살릴 수 있어서입니다. 화면마다 `/meetings/m-01` 같은 경로가 생기고, 주소 모음(`lib/app/paths.dart`)·화면 목록 「주소」 칸·목업 캔버스·딥링크(알림이나 링크를 눌러 앱 안 특정 화면으로 바로 가는 것)가 모두 같은 경로를 씁니다.

**코드 규칙 넷** — 이전 앱에서 확인한 교훈을 그대로 규칙으로 둡니다.

1. **오류는 `Result<T>`로 돌려줍니다.** 저장·조회 함수는 예외를 화면까지 던지지 않고 「성공(값) 또는 실패(`AppError`)」를 돌려줍니다. `AppError`는 「네트워크·권한 없음·찾을 수 없음·알 수 없음」처럼 화면이 고를 수 있는 몇 갈래로 나눕니다. 그래서 화면의 오류 상태가 「상태 표」와 한 줄씩 맞습니다.
2. **Firebase 객체는 생성자로 받습니다.** 저장·조회 코드는 `FirebaseFirestore.instance`를 직접 부르지 않고, provider가 만들어 넣어 준 객체를 씁니다. 그래야 테스트에서 가짜를 넣을 수 있고, 개발용·실서비스용 프로젝트가 섞일 틈이 없습니다. 검사: `lib/features`·`lib/shared`에서 `.instance` 0건.
3. **글자 배율에 견딥니다** — §3.5.
4. **계측 이벤트는 정의와 호출을 함께 검증합니다** — §3.10.

**폴더 구조**

```
lib/
  main_dev.dart           개발용 진입점 — 개발용 Firebase, lib/dev 도구 켬
  main_prod.dart          실서비스 진입점 — 실서비스 Firebase, lib/dev 금지
  main_canvas.dart        목업 캔버스 진입점(§3.6) — Firebase 없음, 가짜 저장소만
  app/                    앱 바깥 틀 — 라우터·주소 모음(paths.dart)·셸·앱 시작 순서
  core/
    design/               디자인 토큰 세 층과 테마(§3.5)
    firebase/             flavor별 Firebase 설정 파일과 Firebase 객체 provider(§3.8)
    analytics/            계측 이벤트 한 파일(§3.10)
    result/               Result<T>·AppError
  features/<흐름>/
    screens/              화면. 한 화면 = 한 파일
    widgets/              이 흐름 전용 부품
    data/                 저장·조회 코드(repository)와 데이터 모양(model)
  shared/components/
    ui/                   범용 부품(Material 감싸개 — 버튼·입력칸 등)
    common/               여러 흐름에 반드시 나오는 공통 부품
  l10n/                   .arb 문구 파일
  dev/                    개발 빌드 전용 — 목업 캔버스·디자인 시스템 페이지·비교안(drafts)·상태 흉내
tool/                     Dart 도구 스크립트(목록 만들기·상태 칸 채우기·코멘트 서버)
test/                     단위·위젯 테스트, test/goldens/ 골든 그림
integration_test/         기기에서 도는 통합 테스트(Robot 패턴)
functions/                서버 함수(TypeScript) — src/<기능>/ 폴더별
firestore.rules  storage.rules  firestore.indexes.json  firebase.json  .firebaserc
rules-test/               보안 규칙 테스트(TypeScript, §3.8)
hosting/                  Firebase Hosting 웹(§3.9)
fastlane/                 스토어 정보·올리기 설정(§3.7)
android/ ios/             플랫폼 폴더
```

`lib/dev/`는 `main_dev.dart`와 `main_canvas.dart`에서만 불립니다. `main_prod.dart`가 `lib/dev/`를 불러오지 못하게 검사로 막습니다(웹의 「`/dev`는 실서비스에서 404」 자리).

### 3.4 2·3단계의 데이터와 상태 화면

웹 하네스의 「저장·조회 코드」 규칙은 거의 그대로 옮깁니다.

- 저장·조회는 각 흐름의 `data/` 폴더에 모읍니다. 화면은 `shared_preferences`를 직접 부르지 않습니다 — `features/*/screens`·`features/*/widgets`·`shared/`에서 `SharedPreferences` 0건.
- 함수는 처음부터 `Future<Result<T>>`(나중에 답이 오는 값)를 돌려줍니다. 4단계에서 Firestore로 바뀌어도 화면을 안 고칩니다.
- 엔티티마다 「소유자」 주석 한 줄을 남깁니다. 4단계 보안 규칙의 근거가 됩니다. 결제·구독·카운터처럼 **사용자가 직접 바꾸면 안 되는 값**에는 「보호 필드」 주석을 답니다(§3.9).

**상태 흉내(`?state=empty|loading|error|forbidden`, `?as=guest`)** — 앱에서는 `devStateProvider`(개발 빌드에서만 값이 있는 provider)로 바꿉니다. 저장·조회 코드가 이 값을 먼저 보고 빈 결과·느린 응답·오류를 돌려주고, 화면은 상태를 직접 읽지 않습니다. 값을 넣는 길은 둘입니다.

1. 목업 캔버스는 창마다 provider 덮어쓰기로 넣습니다.
2. 시뮬레이터·폰에서 개발용 앱을 돌릴 때는 개발 빌드의 go_router가 경로 뒤 질의 `?state=empty`를 읽어 넣습니다. 그래서 화면 목록·상태 표의 `?state=` 칸 표기는 **그대로 둡니다.**

실서비스 진입점에서는 이 provider가 늘 비어 있도록 하고, 검사(§3.12)로 확인합니다.

### 3.5 디자인 시스템

**3층 토큰 + 조립 계층을 Flutter로 옮기는 방법**

| 층 | 웹 | Flutter |
|---|---|---|
| 1층 foundation(원래 값) | `1-foundation/*.css`의 색 램프·글자 크기·간격 원본 | `lib/core/design/foundation.dart` — `const` 값 모음. 색 램프(`Color(0xFF…)`)·간격 단계·글자 크기·둥글기·모션 길이(`Duration`)·곡선(`Curve`). **숫자·색 값을 쓸 수 있는 유일한 파일** |
| 2층 semantic(역할 이름) | `2-semantic.css`의 shadcn 이름 | `lib/core/design/semantic.dart` — Material `ColorScheme`(primary·onPrimary·surface 등 역할 이름 세트)를 1층으로 채우고, Material에 없는 역할(성공·경고·희미한 글자·간격·카드 둥글기·모션·글자 단계 `h1`~`b2`)은 `ThemeExtension`(테마에 우리만의 값 묶음을 덧붙이는 장치)으로 둡니다 |
| 3층 component | shadcn 복사본·`3-components.css` | `lib/core/design/theme.dart`에서 2층으로 `ThemeData`를 조립합니다. 부품은 `lib/shared/components/ui/`의 감싸개(`AppButton` 등) — variant는 열거형으로, shadcn의 cva 자리 |
| 조립 계층 | frame(셸)·pattern | 그대로 — 셸은 `lib/app/shell.dart`, 하단 탭·상단 바·안전 영역을 셸이 맡습니다 |

**화면 코드가 값을 꺼내는 길은 하나뿐입니다.** `context.colors.primary`·`context.space.s4`·`context.text.b1`처럼 `BuildContext`에 붙인 짧은 이름(확장 기능)으로만 꺼냅니다. 웹의 「2층 이름 클래스만 쓴다」 철칙이 이 문장으로 바뀝니다. 그래서 2-2가 1·2층 값을 바꾸면 화면이 따라오는 성질이 그대로 삽니다. 이전 앱에서도 같은 방식(토큰 파일 + ThemeExtension + `context.colors`)을 썼습니다.

**대비 계산 도우미** — 글자색과 바탕색의 대비(WCAG 기준 4.5:1 등)를 Dart 함수로 계산하는 작은 도우미를 하네스가 줍니다. 2-2에서 색을 바꿀 때와 디자인 시스템 페이지에서 「이 조합은 대비 몇」을 보여 줄 때 씁니다. 단위 테스트로 「2층의 글자색·바탕색 짝은 모두 기준 이상」을 검사합니다 — 화면을 보지 않고 숫자로 거를 수 있는 몇 안 되는 디자인 검사입니다.

**글자 배율 규칙** — 폰 설정에서 글자를 키우면 앱 글자도 커집니다. 이전 앱에서 확인한 교훈: 큰 글자에서 넘치는 곳은 거의 늘 세 자리였습니다.

1. 높이를 숫자로 고정한 상자 안의 글자 → 높이를 고정하지 않고 최소 높이만 둡니다.
2. `Row`(가로 줄) 안의 `Text` → `Expanded`·`Flexible`로 감싸거나 줄바꿈을 허용합니다.
3. `GridView`의 가로세로 비율 고정 → 글자 배율에 따라 비율을 바꾸거나 높이를 내용에 맞춥니다.

이 셋을 `common-patterns.md` 점검 항목과 위젯 테스트(글자 배율 2.0에서 넘침 오류가 없는지)로 둡니다. 「넘침 오류 없음」은 화면 밖 검사로 잡히고, 「보기 좋은가」는 여전히 사람이 봅니다.

**shadcn 자리는 「Material 감싸개」입니다.** 버튼·입력칸처럼 variant와 누르는 크기(48dp)가 걸린 부품은 반드시 감싸개를 거칩니다. 목록·카드처럼 테마만으로 충분한 부품은 Material 것을 바로 써도 되지만, 화면에서 `style:`·`color:`·`padding: EdgeInsets.all(13)`처럼 겉모양을 덮어쓰지 않습니다.

**반응형** — 폰만 지원하므로 화면 폭으로 메뉴를 바꾸는 갈래는 없습니다. 부품 크기 대응은 `LayoutBuilder`(부품이 받은 자리의 폭을 읽는 위젯)로 하고, 화면 전체 폭(`MediaQuery.sizeOf`)은 셸만 읽습니다.

**비교안(2-2)** — 「비교안 화면을 `Theme`으로 감싸 2층 값만 바꾼 테마를 준다」로 바뀝니다.

**`design-check.sh`를 Dart 기준으로** — 판정 기준은 문서(3단계 검사 ①)에 두고 스크립트는 명령만 돌리는 구조, 늘 exit 0인 구조는 그대로입니다. 검사 대상은 `lib/features`·`lib/shared/components`(감싸개 폴더 `ui/`와 `lib/core/design/`은 제외), `lib/dev/drafts`는 넣습니다.

| # | 검사 |
|---|---|
| 1 | `Color(0x`·`Color.fromARGB`·`Colors.`·`CupertinoColors.` 0건, `EdgeInsets.*(숫자)`·`SizedBox(height: 숫자)`·`fontSize:`·`BorderRadius.circular(숫자)` 0건(0은 허용) |
| 2 | 화면·부품이 `foundation.dart`를 import하는 곳 0건 |
| 3 | `MediaQuery.of(context).size`·`MediaQuery.sizeOf` 사용이 셸 밖에서 0건 |
| 4 | 부품 파일 목록 ↔ 부품 인벤토리 색인 대조 |
| 5 | `onSubmitted`·`TextInputAction` 쓰는 곳을 찍어 한글 조합 중 제출 사례를 눈으로 확인(구현 때 실측) |
| 6 | 하단 고정 요소가 셸 밖에 있는지, 셸이 `SafeArea`를 쓰는지 |
| 7 | `Theme.of(context).colorScheme` 직접 사용 0건 — 우리 확장 이름만 |
| 8 | `MediaQuery.disableAnimationsOf`(시스템 「애니메이션 줄이기」)를 읽는 전역 장치가 한 곳 있는지 |
| 9 | `Duration(milliseconds:`·`Curves.` 사용이 `foundation.dart` 밖에서 0건 |
| 10 | 화면 파일마다 주 버튼(`AppButton(variant: AppButtonVariant.primary`) 개수 ↔ 화면 목록 「주 행동」 칸 |
| 11 | 화면이 부르는 `context.space.*` 이름이 「12. 화면 규칙」 허용 목록 안인지 |
| 12 | 높이를 숫자로 고정한 `SizedBox`·`Container` 안의 `Text` 찍기(글자 배율 1번 규칙) |
| 13 | `main_prod.dart`와 그것이 부르는 파일이 `lib/dev/`를 import하는 곳 0건 |
| 14 | `lib/features`·`lib/shared`에서 Firebase `.instance` 직접 호출 0건 |

grep으로 못 잡는 것이 남는 한계는 지금과 같습니다. 오탐·누락이 두 번 이상 문제가 되면 Dart 분석기 플러그인(우리 규칙을 `flutter analyze` 안에 넣는 장치)으로 옮깁니다.

**디자인 시스템 페이지** — 개발 빌드 전용 경로(`/dev/design-system`)로 둡니다. 값은 실제 테마에서 읽어 보여 주고, 색 짝마다 대비 숫자를 함께 보여 줍니다.

**서체** — 한글 서체 파일을 앱에 넣고(`pubspec.yaml` 등록) 1층에서 이름을 정합니다. 실행 중 인터넷으로 서체를 받는 `google_fonts`는 쓰지 않습니다 — 첫 실행·오프라인에서 글자가 바뀌어 보입니다. 쓰는 굵기만 넣고, 가변 서체가 있으면 그것을 씁니다.

### 3.6 목업 캔버스

**사람이 해야 하는 일은 그대로입니다** — 2단계 내내 「모든 화면과 상태를 한눈에 펼쳐 놓고, 고칠 곳을 짚어 AI에게 알리는 것」.

**먼저 캔버스를 어디에 띄울지가 문제입니다.** 개발 기기가 iOS 시뮬레이터와 안드로이드폰이라는 점, 그리고 Firebase·폰 전용 플러그인이 기기마다 되는 곳과 안 되는 곳이 있다는 점 때문입니다. 후보를 비교했습니다.

| 후보 | 무엇인가 | 넓은 판 | 실제와 닮음 | 폰 전용 플러그인 | 사람의 손 | 만드는 비용 |
|---|---|---|---|---|---|---|
| A1. Chrome(Flutter 웹) | 캔버스 진입점을 웹으로 빌드해 브라우저에 띄움 | ◎ 창 크기 마음대로 | △ 웹 그리기 엔진이라 글자 모양·스크롤 느낌이 폰과 다름 | ✕ 카메라·카카오 로그인·설치 출처 등 대부분 웹에서 안 돎. Firebase도 웹용 설정을 따로 만들어야 함 | ○ | 중간 — 웹 전용 예외 처리가 계속 늘어남 |
| A2. macOS 데스크톱 앱 | 캔버스를 맥 앱으로 빌드 | ◎ 창 크기 마음대로, 파일도 직접 씀 | ○ 맥용 그리기 — 폰보다는 다름 | ✕ 폰 전용 플러그인 대부분 안 돎. Firebase는 일부만, 맥용 권한 설정이 따로 필요 | ◎ 마우스·키보드 | 큼 — 맥 앱 설정(권한·서명)이 하나 더 생김 |
| A3. iPad 시뮬레이터 | 캔버스를 iOS 앱으로 빌드해 가상 아이패드에 띄움 | ○ 13인치 아이패드 크기(폰 틀 6~8개를 줄여 나란히) + 확대·이동 | ◎ 아이폰과 같은 iOS 엔진 — 글자·스크롤이 iOS 시뮬레이터와 같음 | ◎ iOS 플러그인이 그대로 돎 | ○ 마우스로 누르기 | 작음 — Xcode·시뮬레이터는 개발 기기라 어차피 있음 |
| B. Widgetbook | 부품·화면 카탈로그 도구 | △ 나무 목록에서 하나씩 | 띄우는 곳에 따름 | 띄우는 곳에 따름 | △ | 중간 |
| C. iOS 시뮬레이터·안드로이드폰 | 앱을 직접 실행 | ✕ 한 번에 한 화면 | ◎ 진짜 | ◎ | ◎ | 없음 |
| D. 골든 그림 모음 | 테스트가 화면×상태마다 그림을 찍어 한 페이지에 모음 | ◎ | ○ | 해당 없음(가짜로 대체) | ✕ 정지 그림 | 작음 |

**추천 — A3(iPad 시뮬레이터 캔버스)를 주 도구로, D를 미리보기·회귀 검사로, C를 손맛 확인으로 함께 씁니다.**

- **A3를 고른 이유** — 세 가지입니다. ① 개발 기기와 같은 iOS 엔진이라 「캔버스에서 본 것 = 시뮬레이터에서 본 것」이 됩니다. 웹 캔버스는 글자 모양부터 달라, 캔버스에서 고친 것을 폰에서 다시 확인하는 일이 생깁니다. ② 폰 전용 플러그인이 그대로 돌아, 웹처럼 「캔버스에서는 자리 표시」 예외가 거의 없습니다. ③ 새로 깔 것이 없습니다.
- **A3의 약점과 대응**
  - 판이 13인치 아이패드 크기로 묶입니다 → 캔버스가 폰 틀을 줄여 흐름 순서로 펼치고, 두 손가락 확대·끌기(`InteractiveViewer`)로 넓은 판을 돌아다닙니다. 한 흐름 묶음씩 고르는 기능(웹 캔버스에 있던 것)이 그대로 쓰입니다.
  - 앱이 「폰만 지원」으로 설정돼 있으면 아이패드에서 아이폰 크기 창으로 뜹니다 → **캔버스용 빌드만 아이패드를 지원하게** 따로 설정합니다(캔버스 전용 iOS 빌드 설정, 묶음 F에서 실측). 실서비스 앱은 폰만 그대로입니다.
  - 안드로이드 쪽 모습은 안 보입니다 → 안드로이드는 C(USB 폰)로 봅니다. 두 플랫폼 겉모습 차이는 Material 테마로 거의 없앱니다.
- **캔버스는 Firebase에 붙지 않습니다.** `main_canvas.dart`는 Firebase를 켜지 않고, 모든 저장·조회 provider를 가짜(견본 데이터)로 덮어씁니다. 2단계에는 어차피 Firebase가 없고, 4단계 뒤에도 캔버스가 실제 데이터를 건드리면 「빈 상태」 같은 흉내가 깨지기 때문입니다. 그래서 「Firebase가 어느 기기에서 도나」 문제가 캔버스에서는 사라집니다.
- **D(골든 그림)** 는 웹의 Playwright 미리보기 그림 자리입니다. 맥에서 `flutter test`로 찍으므로 기기가 필요 없습니다. 찍은 그림은 ① 캔버스가 멀리서 보여 주는 썸네일, ② 겉모습이 의도치 않게 바뀌었는지 보는 회귀 검사, ③ 6단계 스토어 스크린샷의 초안으로 씁니다. 기준 그림은 이 맥에서만 다시 찍고 CI에서는 돌리지 않습니다.
- **지난 단계 보기** — 캔버스 왼쪽 사이드바에서 「흐름 묶음」을 「단계」로 바꾸면 단계마다 한 띠(2-1 처음 목업 → 비교안 → 고른 뒤 → … → 지금 앱)로 같은 화면이 같은 세로줄에 놓입니다. 지난 단계의 화면 코드는 판을 고르며 덮여 지금 앱에 없으므로, 단계 이름표(`stage/*` 태그)의 코드를 임시 폴더(git worktree)에 꺼내 주요 화면의 평소 모습(비교안 단계는 비교안 창)만 그림으로 찍어 `.canvas-stages/`에 둡니다(`stage-shots.sh`). 캔버스는 그 그림만 보여 주고, 그림은 git에 올리지 않습니다(이름표가 GitHub에 있어 언제든 다시 찍음). 옛 코드의 골든 테스트에는 늦게 그려지는 사진이 빈 자리로 찍히던 버그가 남은 판이 있어, 찍을 때 지금 하네스의 골든 테스트를 덮어 씌웁니다.
- **C(시뮬레이터·폰)** 는 움직임·키보드·뒤로 가기·실제 손맛·Firebase가 붙은 동작을 볼 때 씁니다. 3단계 이후 「사람이 앱을 본다」는 C로 합니다.
- **A1(웹)을 버리는 이유** — 웹 캔버스는 넓은 판이 장점이지만, 폰 전용 플러그인과 Firebase 웹 설정 때문에 예외가 쌓이고, 글자 모양이 개발 기기와 다릅니다. **A2(맥 앱)** 는 넓은 판이 장점이지만 같은 플러그인 문제에 맥 앱 설정이 하나 더 생깁니다.
- **B(Widgetbook)는 넣지 않습니다.** 부품 카탈로그는 디자인 시스템 페이지가, 화면 펼쳐 보기는 A3가 맡습니다.

**정적 HTML 시안 단계는 두지 않습니다.** 이전 앱은 「HTML 시안을 브라우저로 본다 → Flutter 화면으로 옮긴다」 순서였습니다. 이 하네스는 2-1에서 바로 Flutter 화면을 만들어 캔버스로 보므로, 옮기는 단계가 없어집니다. 1단계의 인터뷰 예시 HTML은 그대로 참고 자료로 남습니다.

**기존 기능 중 살릴 것과 버릴 것**

| 기능 | 처분 | 이유 |
|---|---|---|
| 흐름 순서로 펼치기·흐름 묶음 고르기 | 살림 | 화면 목록 「흐름 묶음」 칸이 그대로 쓰입니다 |
| 데스크톱 폭 + 폰 폭 한 쌍 | 바꿈 | 보통 폰(아이폰 16 폭) 창 하나. 작은 폰(갤럭시 S 폭) 창은 보기만 힘들고 차이가 거의 없어 뺐고, 좁은 폭 넘침은 글자 배율 2.0·작은 폰 폭 화면 테스트가 잡습니다 |
| 멀리서는 그림, 가까이서는 실제 화면 | 살림 | 그림은 골든(D) |
| 크게 보기·눌러 보기 | 살림 | 실제 위젯이라 눌러 볼 수 있습니다 |
| 코멘트 핀(`mvp/canvas-comments.json`) | 살림 | 「코멘트 반영해줘」가 가장 쓸모 있던 기능입니다. 시뮬레이터 앱은 저장소 파일을 직접 못 쓰므로, 맥에서 도는 작은 Dart 서버(`tool/canvas_server.dart` — 코멘트 파일 읽기·쓰기만 함)에 보냅니다. 시뮬레이터는 맥의 `localhost`에 바로 닿습니다. 파일 모양(`screenId`·`state`·`status`·`resolution`)은 그대로 |
| 요소 복사(React Grab) | 일단 버림 | 코멘트 핀이 「화면 ID·상태·누른 자리의 위젯 종류·그 안의 글자」를 함께 적습니다. 디버그 정보로 「파일:줄」까지 싸게 뽑히면 묶음 F에서 넣습니다(§4.1) |
| 폰으로 같은 와이파이에서 열기 | 버림 | 폰은 USB 실행으로 봅니다 |
| 실서비스에서 404로 막기 | 바꿈 | 캔버스 진입점이 따로라 실서비스 앱에 아예 안 들어갑니다(검사 13번) |
| 상태 표 칸 자동 채우기 | 살림 | Dart 스크립트로 옮깁니다 |

**AI가 시뮬레이터를 조작해 화면을 판정하지 않습니다.** 이전 앱에서는 AI가 시뮬레이터를 눌러 보며 「계약서 대비 통과·실패」 보고서를 남긴 적이 있습니다. 참고는 하되, 하네스는 「화면 판정은 사람」 원칙을 지킵니다. 사용자가 명시적으로 시킬 때만 돌립니다.

### 3.7 3단계 배포 — 플레이 내부 테스트

**바뀌는 핵심 하나부터** — 웹에서는 「링크 하나 보내면 누구나 바로 연다」가 3단계 배포의 값이었습니다. 앱에서는 **안드로이드 폰을 가진 사람만, 시험 참가 링크를 눌러 플레이 스토어에서 받아야** 씁니다. 지인에게 미리 알려야 합니다.

**트랙** — 플레이 콘솔의 시험 트랙 중 3단계는 **내부 테스트**(이메일 목록으로 최대 100명, 검토 없이 금방 받음)를 씁니다. 4단계의 베타 공유는 **비공개 테스트**(검토를 거침)를 씁니다 — 아래 「Draft App 제약」 때문입니다.

**계정은 사업자(조직) 계정입니다.** 그래서 개인 계정에만 붙는 「정식 출시 전 닫힌 테스트 12명·14일」 요건은 해당이 없습니다. 대신 조직 계정은 처음 만들 때 확인할 것이 많습니다.

- 한국 사업자는 콘솔에 **사업자등록번호와 통신판매업 신고번호**를 넣어야 합니다(이전 앱에서 확인). 신고번호가 없으면 먼저 신고해야 하니, 4-0이 아니라 **3단계 배포 전**에 확인합니다.
- 조직 확인에 D-U-N-S 번호(기업 식별 번호) 등 서류가 필요할 수 있어 며칠 걸립니다. 정확한 요건은 그때 콘솔 안내로 확인합니다.

**Draft App 제약 — 첫 판은 손으로 합니다.** 이전 앱에서 확인한 교훈입니다. 한 번도 비공개 테스트 이상으로 출시해 검토를 통과한 적 없는 앱(Draft App)에는, 명령 도구로 스토어 정보나 「완료」 상태 릴리스를 올릴 수 없습니다(`Only releases with status draft may be created on draft app` 오류). 그래서 순서가 이렇게 정해집니다.

1. **3단계** — [사람] 콘솔에서 앱 만들기·앱 설정·기본 언어(한국어) 스토어 정보를 손으로 입력하고, 첫 앱 번들을 내부 테스트에 손으로 올립니다.
2. **4단계 베타 공유** — 비공개 테스트 트랙으로 내고 검토를 통과시킵니다. 이 순간부터 Draft App에서 풀립니다.
3. **6단계 앞** — fastlane 자동화를 켭니다(확정). 이때는 이미 풀린 상태라 막히지 않습니다.

**처음 한 번 하는 일과 매번 하는 일**

| 일 | 누가 | 메모 |
|---|---|---|
| 조직 계정 정보(사업자등록번호·통신판매업 신고번호) | [사람] | 3단계 배포 전 |
| 플레이 콘솔에서 앱 만들기(앱 이름·기본 언어·무료/유료) | [사람] | 무료 앱은 나중에 유료로 못 바꿉니다 — 앱 안 결제는 무료 앱에서도 됩니다 |
| 패키지 이름 확정 | [사람]이 정하고 AI가 넣음 | 아래 「패키지 이름」 |
| 업로드 키 만들기 | [AI] `keytool` | 아래 「서명」 |
| 플레이 앱 서명 켜기 | [사람] | 진짜 서명 키는 구글이 보관하고, 우리는 업로드 키만 갖습니다 |
| 앱 콘텐츠 신고(개인정보처리방침 주소·데이터 보안·광고 ID·콘텐츠 등급·대상 연령·광고 여부) | [사람] 답을 고르고, [AI]가 초안 | 개인정보처리방침은 웹 주소가 필요합니다 → Firebase Hosting(§3.9). 3단계에는 Firebase가 없으니 이 페이지만 먼저 띄웁니다(아래) |
| 첫 앱 번들 올리기 | [사람] 콘솔 | Draft App 제약 |
| 이후 판 올리기(3~4단계) | [사람] 콘솔, AI가 번들을 만들어 줌 | |
| 이후 판 올리기(6단계 앞부터) | [메인 직접] `store-release` 스킬 | fastlane |
| 시험 참가자 목록·참가 링크 | [사람] | |
| 실기기에서 눌러 보기 | [사람] | AI가 대신 판정하지 않습니다 |

**3단계에 개인정보처리방침 페이지가 먼저 필요합니다.** 내부 테스트라도 앱 콘텐츠 신고에 주소가 필요할 수 있습니다. 그래서 Firebase 실서비스 프로젝트와 Hosting만 3단계 배포 전에 먼저 만들 수 있게, 4-0의 「Firebase 프로젝트 만들기」 절을 3단계에서 앞당겨 부를 수 있는 독립 절로 씁니다(§3.8). 앱은 아직 Firebase에 붙지 않습니다.

**패키지 이름(앱 고유 이름, 예: `com.<회사>.<이름>`)** — 플레이에 한 번 올리면 **바꿀 수 없습니다.** 이전 앱에서 확인한 교훈: 출시 뒤 이름을 바꿨다가 iOS 번들 ID·테스트·문서 곳곳에 옛 이름이 남았습니다. 이 이름을 안드로이드 패키지 이름·iOS 번들 ID·Firebase 앱 등록·딥링크 주소·테스트·문서에 한꺼번에 넣고, 검사로 옛 이름(`com.example` 등) 0건을 확인합니다.

**서명** — 이전 앱의 방식을 그대로 틀로 둡니다.

- Gradle 설정이 `android/key.properties`가 **있으면 release 서명, 없으면 debug 서명**으로 빌드합니다. 그래서 키가 없는 컴퓨터·CI에서도 빌드 확인은 됩니다. 대신 `store-release`는 올리기 전에 앱 번들의 서명이 업로드 키인지 확인합니다(debug로 서명된 번들을 올리는 실수 방지).
- 업로드 키 파일(`*.jks`)은 **프로젝트 폴더 밖**, 이 컴퓨터의 계정 장부 폴더 아래(`~/.config/harness/keys/<패키지 이름>-upload.jks`, 파일 권한 600)에 둡니다. `key.properties`에는 그 경로만 적고 git에 올리지 않습니다.
- 비밀번호는 AI가 만들어 같은 폴더의 `<패키지 이름>-upload.properties`에 넣고(장부에는 적지 않음 — 앱마다 따로라서), 보이는 그 순간 사용자의 비밀번호 관리자에 키 파일과 함께 옮기라고 알립니다.
- **워크플로 파일·주석·문서에 비밀번호를 평문으로 적지 않습니다.** 이전 앱에서 실제 사고가 있었습니다. 감시 훅이 커밋 전에 `storePassword=`·`keyPassword=` 같은 줄을 찾아 막는 검사를 더합니다(§3.14).
- 비밀값 장부에 「업로드 키」 행을 둡니다 — 만든 곳·저장된 곳·다시 볼 수 있나·잃었을 때 재설정 길(구글에 업로드 키 재설정 요청, 며칠 걸림).

**앱 번들과 버전 번호**

- 플레이에는 앱 번들(AAB — 구글이 기기마다 알맞게 쪼개 주는 묶음 파일)을 올립니다: `fvm flutter build appbundle --release --flavor prod -t lib/main_prod.dart`.
- 버전은 `pubspec.yaml`의 `version: 0.3.0+12` 꼴입니다. `+` 뒤 숫자(빌드 번호 = 안드로이드 versionCode)는 **올릴 때마다 반드시 커져야** 하고, 같은 번호는 두 번 못 올립니다. 규칙: 「빌드 번호는 올리기 직전에 한 번만 올리고, 그 커밋에 태그를 남긴다」. 앞 숫자는 3단계 `0.x`, 6단계 정식 출시 때 `1.0.0`.
- 플레이는 「목표 안드로이드 판(target API level)」 하한을 해마다 올립니다. 올리기 전에 그 해 요건을 확인합니다.

**fastlane 자동화(6단계 앞)** — 이전 앱의 방식을 다듬어 틀로 둡니다.

- fastlane(스토어 올리기를 명령으로 하는 도구)의 `supply`(플레이용 기능)로 **로케일별 스토어 정보**(앱 이름·짧은 설명·자세한 설명·`changelogs/<빌드 번호>.txt` 변경 내역·아이콘·그래픽 이미지·스크린샷)와 앱 번들을 올립니다.
- 이전 앱은 명령을 그때그때 쳤습니다. 개선안은 **`Fastfile` 한 파일에 올리기와 트랙 지정(internal·alpha·beta·production)을 모으고, 스토어 정보 폴더를 git으로 관리**하는 것입니다. 그래서 스토어 문구도 코드처럼 브랜치·PR로 고칩니다.
- 권한: 구글 클라우드에 서비스 계정(사람 대신 API를 부르는 계정)을 만들고 키 파일을 받아 → 플레이 콘솔 「사용자 및 권한」에서 그 서비스 계정 이메일을 앱에 초대합니다. **권한 반영에 최대 24시간** 걸리므로 자동화를 켜기 하루 전에 해 둡니다.
- 어디서 돌리나 — 이전 앱은 GitHub Actions 수동 실행(트랙을 골라 AAB 업로드)이었습니다. 이 하네스의 추천은 **이 맥에서 메인이 `store-release`로 직접**입니다. 업로드 키와 서비스 계정 키가 이 컴퓨터를 떠나지 않고, 「배포는 위임 금지, 사람이 중간에 낀 채로」 원칙과 맞습니다. GitHub Actions 방식은 쓰지 않습니다(§4.1).

**스토어 스크린샷** — 이전 앱에서 쓴 방식 두 가지 중 하나를 6단계에서 고릅니다(§3.11). 둘 다 결과 그림은 `fastlane/metadata/android/<로케일>/images/`로 모읍니다.

**웹 하네스의 3단계 체크리스트에서 없어지는 것** — Vercel 프로젝트 이름·git 연동·`.env*` 함정·팀 주소 보호·`/dev` 404 확인·Node 판·색인 제외.

### 3.8 Firebase 프로젝트 둘 — 개발용과 실서비스용

**왜 둘로 나누나요?** 에뮬레이터를 쓰지 않으니 개발 중에도 클라우드 Firebase에 붙습니다. 프로젝트가 하나뿐이면 어떻게 될까요? 개발하며 넣은 연습 데이터·테스트 계정·시험 이벤트가 실서비스 데이터와 분석 숫자에 섞이고, 보안 규칙을 시험 삼아 바꾸는 순간 실사용자에게 바로 적용됩니다. 이전 앱에서 확인한 교훈도 바로 이것입니다 — 개발용·실서비스용을 나누지 않은 것이 반면교사였습니다. 그래서 둘로 나눕니다(확정).

| | 개발용 | 실서비스용 |
|---|---|---|
| 프로젝트 ID 예 | `<이름>-dev` | `<이름>-prod` |
| 누가 붙나 | iOS 시뮬레이터·USB 안드로이드폰의 개발용 앱, 통합 테스트 | 플레이에서 받은 앱, Hosting 웹 |
| 앱 패키지 이름 | `<패키지>.dev` | `<패키지>` |
| 데이터 | 시드·테스트 계정, 언제든 지움 | 실사용자 — 지우는 스크립트 금지 |
| 보안 규칙·서버 함수 배포 | 작업 브랜치에서 AI가 자유롭게 | main에서, 「실서비스 배포 전 확인」 뒤 메인이 직접 |
| 분석·크래시 | 개발 이벤트만 쌓임(실서비스 숫자 오염 없음) | 6단계 판정 숫자 |
| 요금제 | Blaze(종량제 — 서버 함수에 필요) + 낮은 예산 알림 | Blaze + 예산 알림 |
| 리전 | 같은 리전(`asia-northeast3` 서울 — 이전 앱과 같음) | 같음 |

**리전은 처음에 정하면 못 바꿉니다.** Firestore의 위치는 한 번 정하면 바꿀 수 없어, 두 프로젝트 모두 같은 리전으로 처음부터 만듭니다. 서버 함수도 같은 리전 상수(`functions/src/config/region.ts`) 하나로 맞춥니다.

**앱이 두 프로젝트 중 하나를 고르는 방법 — flavor + 진입점 둘**

dart-define(빌드할 때 값을 넣는 방법)만으로는 부족합니다. 안드로이드의 `google-services.json`과 iOS의 `GoogleService-Info.plist`(Firebase가 앱에 주는 설정 파일)는 빌드 도구가 파일 자리로 읽기 때문입니다. 그래서 flavor로 나눕니다.

| 자리 | 개발용 | 실서비스용 |
|---|---|---|
| 실행 명령 | `fvm flutter run --flavor dev -t lib/main_dev.dart` | `fvm flutter build appbundle --flavor prod -t lib/main_prod.dart` |
| Dart 설정 파일(FlutterFire CLI가 만듦) | `lib/core/firebase/firebase_options_dev.dart` | `lib/core/firebase/firebase_options_prod.dart` |
| 안드로이드 설정 파일 | `android/app/src/dev/google-services.json` | `android/app/src/prod/google-services.json` |
| iOS 설정 파일 | `ios/config/dev/GoogleService-Info.plist` | `ios/config/prod/GoogleService-Info.plist` |
| iOS 빌드 설정 | Xcode 빌드 설정 `Debug-dev`·`Release-dev`와 scheme `dev` | `Debug-prod`·`Release-prod`와 scheme `prod` |
| 앱 이름(홈 화면) | 「<이름> 개발」 | 「<이름>」 |

- 설정 파일은 FlutterFire CLI로 flavor마다 한 번씩 만듭니다: `flutterfire configure --project=<이름>-dev --out=lib/core/firebase/firebase_options_dev.dart --android-package-name=<패키지>.dev --ios-bundle-id=<번들>.dev` (정확한 옵션 이름은 그때 FlutterFire 공식 문서로 확인). iOS 설정 파일은 빌드 단계 스크립트가 scheme에 맞는 것을 앱에 복사합니다.
- **설정 파일은 git에 올립니다.** 안의 값(API 키 등)은 「이 앱이 어느 프로젝트에 붙나」를 가리키는 공개 식별값이고, 막는 일은 보안 규칙과 App Check가 합니다(§3.9). 올려 두어야 CI도 빌드할 수 있습니다. 대신 구글 클라우드 콘솔에서 안드로이드 API 키를 「이 패키지 이름 + 서명 지문」으로만 쓰이게 제한합니다.
- 패키지 이름이 달라서 **한 폰에 개발용·실서비스용 앱을 함께 깔 수 있습니다.** 홈 화면 이름도 달라 헷갈리지 않습니다.
- 그 밖의 공개 설정(MMP 앱 키·카카오 앱 키 등)은 `env/dev.json`·`env/prod.json`에 두고 `--dart-define-from-file`로 넣습니다. 예시 파일(`env/*.example.json`)만 git에 올립니다.
- 개발 도구(Android Studio·VS Code)의 실행 설정에 두 flavor를 미리 넣어 두어, 사람이 버튼으로 고를 수 있게 합니다.

**잘못 붙는 사고를 막는 장치 셋**

1. `.firebaserc`에 별칭 `dev`·`prod`를 두고, 모든 `firebase` 명령은 `--project dev` 또는 `--project prod`를 **반드시 적어** 부릅니다. 별칭 없는 명령과 「기본 프로젝트」는 감시 훅이 막습니다(§3.14).
2. 검사 스크립트가 「`firebase_options_prod.dart`·`android/app/src/prod/google-services.json`·`ios/config/prod/…plist` 세 파일의 프로젝트 ID가 모두 `.firebaserc`의 `prod`와 같은가」, 개발용도 같은 식으로 확인합니다. CI에서 돕니다.
3. 개발용 앱은 화면 구석에 「개발」 띠를 그려, 사람이 지금 어느 쪽에 붙었는지 화면에서 바로 알게 합니다.

**계정 표에 두 프로젝트를 적는 법** — 계정 표는 「누구의 계정인가」만 답합니다(값·만료일은 비밀값 장부).

| 서비스 | 계정 |
|---|---|
| Firebase 개발용 프로젝트 | `<이름>-dev` — 소유 구글 계정·구글 클라우드 조직 |
| Firebase 실서비스 프로젝트 | `<이름>-prod` — 소유 구글 계정·구글 클라우드 조직 |
| Firebase CLI 로그인 계정 | 이메일 |

**비밀값 장부(`mvp/backend-build.md`)에 「어느 프로젝트」 칸을 더합니다.** 서버 함수의 비밀값(AI 제공사 키 등 — Secret Manager에 들어감)은 **프로젝트마다 따로** 넣어야 하므로, 같은 이름이라도 행을 둘로 씁니다. 개발용에는 가능하면 사용 한도가 낮은 별도 키를 씁니다.

| 이름 | 프로젝트 | 들어간 자리 | 만든 곳 | 다시 볼 수 있나 | 만료 | 잃었을 때 |
|---|---|---|---|---|---|---|
| (예) `AI_API_KEY` | 개발용 | 서버 함수 비밀값 | AI 제공사 콘솔 | 못 봄 | 없음 | 새로 만들어 교체 |
| (예) `AI_API_KEY` | 실서비스 | 서버 함수 비밀값 | 〃(다른 키) | 못 봄 | 없음 | 〃 |
| 업로드 키·비밀번호 | 해당 없음 | 장부 폴더 | `keytool` | 비밀번호 관리자 | 없음 | 구글에 재설정 요청 |
| 플레이 서비스 계정 키 | 해당 없음 | 장부 폴더(경로만 장부에) | 구글 클라우드 | 못 봄 | 없음 | 새 키 발급 |
| App Check 디버그 토큰 | 개발용 | 개발용 프로젝트 콘솔 | 기기 첫 실행 로그 | 콘솔에서 봄 | 없음 | 다시 등록 |

**실서비스 배포 전 확인** — `backend-release`(서버 쪽)와 `store-release`(앱 쪽)가 맨 앞에서 돌립니다. 하나라도 어긋나면 멈추고 보고합니다.

1. main에 서 있고, 작업 트리가 깨끗하고, 원격 main과 같은가.
2. 같은 변경이 개발용 프로젝트에 먼저 배포됐고, 사람이 개발용 앱에서 확인했다고 말했는가.
3. 명령이 `--project prod`를 적었고, 그 별칭의 ID가 계정 표의 실서비스 프로젝트와 같은가.
4. 이번에 바뀐 것만 고르는가 — `--only firestore:rules,firestore:indexes,functions:<함수1>,functions:<함수2>,hosting`처럼. 이전 앱에서 확인한 교훈: 영향받는 함수만 골라 배포했습니다. 바뀐 함수 목록은 `functions/src/<기능>/` 폴더의 git 차이로 뽑습니다.
5. 보안 규칙 테스트가 통과했는가(방식은 §4.1).
6. 보호 필드를 건드렸으면, 규칙·보호 필드 표·규칙 테스트 세 곳이 같은 커밋에서 함께 바뀌었는가(§3.9).
7. 무언가를 **없애는** 변경(필드·컬렉션·함수 삭제, 규칙 조이기)이면, 옛 판 앱이 아직 그것을 쓰는지 — Remote Config의 최소 판과 플레이 콘솔의 판별 사용자 수를 보고 판단했는가(§3.13).
8. 앱 쪽이면, 위 「설정 파일 세 개의 프로젝트 ID」 검사가 실서비스 쪽으로 통과했는가.

**보안 규칙 테스트를 에뮬레이터 없이 어떻게 하나요?** Firebase 공식 규칙 테스트 도구(`@firebase/rules-unit-testing`)는 에뮬레이터 위에서만 돕니다. 로그인한 척을 흉내 낼 수 있는 것도 이 도구뿐입니다. 그래서 길이 셋이고, **사용자가 정합니다(§4.1).**

| 길 | 어떻게 | 좋은 점 | 나쁜 점 |
|---|---|---|---|
| (a) 규칙 테스트만 CI에서 에뮬레이터 예외 | GitHub Actions에서만 `firebase emulators:exec`로 Firestore·Storage 에뮬레이터를 잠깐 띄워 `rules-test/`를 돌림. 내 컴퓨터에서는 에뮬레이터를 안 씀 | 공식 방식, 실제 데이터에 안 닿음, 로그인 흉내 가능, 매 PR 자동 | 「에뮬레이터 안 씀」에 예외가 하나 생김. CI에 자바·Node가 필요. 결과는 PR에서야 봄 |
| (b) 개발용 프로젝트에 실제로 질의 | 테스트 계정 몇 개로 로그인해 개발용 Firestore에 읽기·쓰기를 시도하고 막히는지 봄 | 에뮬레이터 0 | 테스트 계정 비밀값 관리, 느림, 데이터가 남음, 규칙을 먼저 개발용에 배포해야 함, 「다른 사람인 척」 같은 경우를 다 만들기 어려움 |
| (c) 콘솔의 규칙 놀이터(Rules Playground)로 손 확인 | 사람이 콘솔에서 경우마다 눌러 봄 | 설치 0 | 자동 아님, 빠뜨리기 쉬움, 보호 필드 같은 것을 매번 확인하기 어려움 |

추천은 **(a)** 입니다. 보안 규칙이 앱의 유일한 벽이라(§3.9), 이 테스트만큼은 자동이어야 합니다. 「개발에 에뮬레이터를 쓰지 않는다」는 화면 개발 이야기이고, CI 안에서 잠깐 뜨는 규칙 시험장은 개발 흐름에 끼어들지 않습니다.

### 3.9 4단계 백엔드 — Firebase

**쓰는 Firebase 기능과 자리**

| 기능 | 무엇에 | 메모 |
|---|---|---|
| Authentication | 로그인 | 아래 「로그인」 |
| Firestore | DB(문서·컬렉션 구조) | 보안 규칙이 권한 벽 |
| Storage | 사진 등 파일 | 별도 `storage.rules` |
| Cloud Functions(TypeScript) | 비밀값이 필요한 일·보호 필드 쓰기·카운터·결제 검증·알림 보내기 | `functions/src/<기능>/` 기능별 폴더, 리전 상수 하나 |
| Cloud Messaging(FCM) | 푸시 알림 | 안드로이드 13 이상은 알림 권한을 앱이 물어야 함. iOS는 APNs 키가 필요해 iOS 출시 때 |
| Analytics | 퍼널 계측 | §3.10 |
| Crashlytics | 강제 종료·오류 수집 | **release 빌드에서만 켭니다**(이전 앱과 같음) — 개발 중 오류가 섞이지 않게 |
| Remote Config | 앱을 다시 내지 않고 바꾸는 설정 — 특히 최소·최신 판 | 아래 「강제 업데이트」 |
| App Check | 「진짜 우리 앱에서 온 요청인가」 확인 | 아래 |
| Hosting | 랜딩·개인정보처리방침·계정 삭제 요청 | 아래 |

**가장 중요한 보안 차이 — 앱 안에 든 값은 전부 공개된 값입니다.** 앱 파일은 누구나 내려받아 뜯어볼 수 있고, 앱은 서버 없이 기기에서 Firestore에 바로 붙습니다. 그래서:

- 앱에 넣는 값은 Firebase 설정 파일과 공개 앱 키뿐입니다(§3.8).
- **AI 제공사 키·결제 비밀값 같은 비밀은 절대 앱에 넣지 않습니다.** 그런 일은 서버 함수로 옮기고, 키는 서버 함수 비밀값(Secret Manager)에 프로젝트마다 둡니다.
- 그래서 **보안 규칙이 유일한 벽**입니다. 「모든 컬렉션에 규칙, 기본은 전부 거부」로 시작합니다.

**보호 필드 원칙** — 이전 앱에서 확인한 교훈을 그대로 규칙으로 둡니다.

1. 결제·구독 상태·포인트·카운터(좋아요 수 등)처럼 **사용자가 직접 바꾸면 안 되는 필드**는 보안 규칙으로 앱의 쓰기를 막고, **서버 함수만** 씁니다(서버 함수는 관리자 권한이라 규칙을 거치지 않음).
2. 카운터는 **서버 한 곳에서만** 올리고 내립니다. 앱과 서버 둘 다 올리면 숫자가 두 번 셉니다.
3. `4-1`이 **보호 필드 표**(컬렉션·필드·누가 쓰나·어느 함수가 쓰나)를 두고, **규칙·표·규칙 테스트를 한 묶음으로** 고칩니다. 하나만 바뀌면 실서비스 배포 전 확인 6번에서 멈춥니다.
4. 웹 폼으로 받는 컬렉션(계정 삭제 요청 등)은 **누구나 `create`만** 되고 읽기·고치기·지우기는 막습니다(이전 앱과 같음).

**App Check** — 안드로이드는 Play Integrity, iOS는 App Attest, 개발용 앱은 디버그 공급자(기기 첫 실행 때 로그에 뜨는 디버그 토큰을 개발용 프로젝트 콘솔에 등록)를 씁니다. 이전 앱의 방식대로 **앱에서는 처음부터 켜고, 서버 쪽 강제는 점진적으로** 켭니다. ① 콘솔에서 「확인된 요청 비율」을 먼저 보고 → ② 비율이 충분히 높아지면 Firestore·Storage·서버 함수 순서로 강제를 켭니다. 처음부터 강제하면 옛 판 앱과 설정이 덜 된 기기가 한꺼번에 막힙니다.

**강제 업데이트** — Remote Config에 `min_version`(이보다 낮은 판은 막음)·`latest_version`(이보다 낮으면 권함)을 둡니다. 앱은 시작할 때 읽어, 최소 판보다 낮으면 일곱 갈래 「시스템」에 이미 있는 「강제 업데이트 화면」을 띄웁니다. 앱은 옛 판이 사용자 폰에 오래 남기 때문에, 백엔드에서 무언가를 없애기 전에 이 값을 먼저 올립니다(§3.13).

**로그인**

- **구글 로그인** — 기기 안 로그인 창(`google_sign_in`)으로 받은 토큰을 Firebase Auth에 넘깁니다. 안드로이드는 **서명 지문(SHA-1)** 을 Firebase 안드로이드 앱에 등록해야 하고, 지문이 프로젝트마다 다릅니다.
  - 개발용 앱(`<패키지>.dev`): 이 맥의 디버그 키 지문.
  - 실서비스 앱(`<패키지>`): **플레이 앱 서명 키 지문**(콘솔에서 확인) + 업로드 키 지문 + (실서비스 flavor를 이 맥에서 돌려 볼 일이 있으면) 디버그 키 지문.
  - 하나만 넣으면 「내 폰에선 되는데 스토어 판에선 안 되는」 사고가 납니다. 지문을 더한 뒤에는 `google-services.json`을 다시 받아야 합니다. 이 둘을 4-0의 함정으로 적습니다.
  - iOS 시뮬레이터에서도 구글 로그인을 하려면 iOS 설정 파일의 「역방향 클라이언트 ID」를 URL 스킴으로 등록해야 합니다.
- **카카오 로그인** — 카카오는 Firebase가 기본으로 지원하는 로그인 수단이 아닙니다. 기본안은 ① 앱이 카카오 SDK로 로그인해 카카오 토큰을 받고 → ② 서버 함수가 그 토큰을 카카오에 확인한 뒤 Firebase 커스텀 토큰을 만들어 돌려주고 → ③ 앱이 그 토큰으로 Firebase에 로그인하는 방식입니다. 다른 길(Identity Platform의 OIDC 연결)이 더 싼지는 4-2에서 공식 문서로 확인합니다. 카카오도 앱 키 해시(서명 지문)를 등록해야 하고, 「카카오 콘솔은 사람이 연다」 규칙은 그대로입니다.
- **페이스북 로그인은 MVP에서 쓰지 않습니다.** 이전 앱에서 확인한 교훈: 소셜 로그인 플러그인, 특히 페이스북 것은 iOS를 붙일 때 호환 문제가 컸습니다.
- **이메일 링크 로그인을 쓰면** 앱으로 돌아오는 링크가 필요합니다. 예전의 Firebase Dynamic Links는 서비스가 종료됐으므로 쓰지 않고, Hosting 도메인으로 안드로이드 앱 링크를 겁니다(공식 문서로 확인).
- **iOS를 붙일 때의 메모** — 다른 소셜 로그인을 쓰는 앱은 애플 로그인도 함께 내야 한다는 앱스토어 심사 지침이 있습니다. iOS 출시 절차 문서에 적어 둡니다(문서는 안드로이드 출시 뒤에 씁니다 — 확정).
- 4-2의 세션 이야기는 「세션은 Firebase Auth가 기기에 저장·갱신한다 — 앱이 따로 캐시하지 않는다」와 「로그인 뒤 돌아갈 화면은 go_router의 로그인 문지기 한 곳에서만 정한다」로 바꿉니다.

**데이터 넣기와 지우기 — 로컬 리셋 자리** — 로컬 DB가 없으므로 웹 하네스의 「로컬 리셋」·「클라우드에 시드 넣기」 절이 이렇게 바뀝니다.

- **시드 스크립트**(`functions/scripts/seed.ts` — 관리자 권한으로 Firestore·Storage에 견본 데이터를 넣음)는 **개발용 프로젝트만** 대상으로 합니다. 문서 ID를 고정값으로 쓰고, 모든 시드 문서에 「시드」 표시 필드를 붙입니다.
- **정리 스크립트**는 「시드」 표시가 붙은 문서와 테스트 계정만 지웁니다. 컬렉션 통째 지우기는 쓰지 않습니다.
- 두 스크립트는 대상 프로젝트 ID가 `prod`면 **시작하지 않고 멈춥니다.** 실서비스에 견본 데이터가 꼭 필요하면(예: 처음 보여 줄 공지) 별도 스크립트로 사람이 확인한 뒤 메인이 돌립니다.

**웹 페이지 — Firebase Hosting(확정)** — 앱만 있어도 플레이는 ① 개인정보처리방침 **웹 주소**와 ② 계정을 만드는 앱이면 **앱 밖에서 계정 삭제를 요청할 수 있는 웹 주소**를 요구합니다(앱 안 삭제 기능도 따로 필요). 이전 앱의 방식을 틀(`templates/hosting-site/`)로 둡니다.

- 실서비스 프로젝트의 Hosting에 **랜딩 + 개인정보처리방침 + 계정 삭제 요청 폼**을 둡니다. 폼은 Firestore의 「누구나 create만」 컬렉션에 요청을 쌓고, 처리는 사람이 하거나 서버 함수가 합니다.
- **출시 단계 변수**(`RELEASE_PHASE` = 사전 등록·베타·정식)로 랜딩 모드를 바꿉니다 — 사전 등록 중엔 「곧 나옵니다」, 정식이면 스토어 버튼.
- 안드로이드 앱 링크용 확인 파일(`/.well-known/assetlinks.json`)도 여기서 내보냅니다.
- 주소는 기본 주소(`<프로젝트>.web.app`)로 시작하고, 자기 도메인은 6단계 전에 검토합니다(§4.1). 검색 노출이 목적이 아니라 SEO 절은 되살리지 않습니다.

**스모크 테스트가 바뀝니다.** 웹의 HTML 계약(공개 화면 200·OG 태그·사이트맵 등)은 없어집니다.

| 확인 | 어떻게 | 언제 |
|---|---|---|
| 남의 데이터는 못 읽고 못 쓴다, 보호 필드는 앱이 못 쓴다, 웹 폼 컬렉션은 create만 | 보안 규칙 테스트(§3.8 결정 1) | 매 PR |
| 서버 함수의 판단 로직 | `functions/`의 단위 테스트(Firebase 없이 순수 함수로 짠 부분만) | 매 PR |
| 핵심 흐름(가입 → 핵심 행동)이 끝까지 돈다 | `integration_test`를 개발용 flavor로 실제 기기(시뮬레이터나 USB 폰)에서 — 개발용 Firebase에 붙음 | `done-task` 전, 사람이 기기를 연결해 둔 때 |

이전 앱에서 확인한 교훈 둘을 함께 적습니다. ① Firebase가 필요한 통합 테스트를 `flutter test`(기기 없이 도는 테스트)로 만들면 플랫폼 연결이 없어 실패하므로 만들지 않습니다 — Firebase는 가짜로 바꾼 위젯 테스트와, 기기에서 도는 `integration_test`로 나눕니다. ② 기기 통합 테스트는 Robot 패턴(화면 조작을 「로그인 로봇」 같은 도우미 객체로 묶는 방식) + 위젯 이름표 모음(`TestKeys`)으로 짜야 화면이 바뀌어도 덜 깨집니다.

**결제** — 앱 안에서 **디지털 상품**(구독·유료 기능·코인 등)을 팔면 구글 플레이 결제를 써야 합니다(정책 세부·예외는 그때 확인). 실물·오프라인 서비스 결제는 PG를 쓸 수 있습니다. 디지털 상품이면 「플레이 결제 + 영수증 검증 서버 함수 + 구독 상태는 보호 필드」입니다. 결제 테스트는 플레이의 라이선스 테스터로 합니다.

**4-0 준비 목록이 바뀝니다**

1. 계정 확정 — 계정 표(§3.15)를 화면의 로그인 이메일과 대조.
2. Firebase 두 프로젝트 만들기(3단계에서 실서비스 쪽을 이미 만들었으면 개발용만) — 같은 구글 클라우드 조직 아래, 같은 리전.
3. 두 프로젝트를 Blaze 요금제로 바꾸고 **예산 알림**을 겁니다(개발용은 월 1만 원 수준, 실서비스는 6단계 광고 예산과 따로 — §4.1). 서버 함수에는 Blaze가 필요합니다.
4. 각 프로젝트에 안드로이드 앱·iOS 앱 등록(패키지 이름 `.dev` 붙이고 안 붙이고), FlutterFire로 설정 파일 만들기.
5. 서명 지문 등록(위 「구글 로그인」).
6. App Check 등록, 개발용 디버그 토큰.
7. Firebase CLI 로그인 방식 정하기(§4.1).
8. 소셜 로그인 콘솔(카카오·구글 OAuth 동의 화면) — 사람.
9. 비밀값 장부 만들기 — 「어느 프로젝트」 칸 포함.

### 3.10 계측과 설치 출처

**계측 도구는 Firebase Analytics입니다.** 웹 하네스는 Supabase 이벤트 표에 쌓아 SQL로 퍼널을 셌습니다. 앱에서는 Firebase Analytics(GA4 — 구글의 앱·웹 분석 서비스)가 이벤트 수집·퍼널 화면·구글 광고 연결을 함께 줍니다. 퍼널을 SQL로 직접 세고 싶으면 BigQuery 내보내기(분석 데이터를 구글의 데이터 창고로 매일 옮기는 기능)를 켭니다(선택).

**이벤트는 한 파일에, 「정의 + 호출」을 함께 검증합니다.** 이전 앱에서 확인한 교훈: 퍼널 이벤트를 보내는 함수를 20여 개 만들어 놓고 실제로는 부르지 않아, 출시 뒤에야 숫자가 비어 있는 것을 알았습니다. 그래서:

- 이벤트는 `lib/core/analytics/events.dart` 한 파일에 함수로만 정의합니다. 화면이 `logEvent('…')`를 직접 부르는 것은 검사로 막습니다.
- 검사 스크립트가 「정의된 이벤트 함수마다 그 파일 밖에서 부르는 곳이 한 곳 이상 있나」를 확인합니다. 0곳이면 실패입니다.
- `launch-plan.md`의 퍼널 단계표 ↔ 이벤트 함수 목록도 대조합니다(단계마다 이벤트 하나 이상).
- 개발용 앱은 개발용 프로젝트로 보내므로, 시험 이벤트가 판정 숫자를 오염시키지 않습니다. 개발 중 이벤트가 들어오는지는 Analytics의 DebugView(디버그 모드 기기의 이벤트를 바로 보여 주는 화면)로 사람이 확인합니다.

**설치 출처를 매체별로 가르는 방법** — 광고를 구글 앱 캠페인·메타(페이스북·인스타그램)·X 등 **여러 매체**에 겁니다(확정). 「누가 어느 매체를 보고 설치했나」를 가르는 길은 셋입니다.

| 길 | 어떻게 | 구글 | 메타 | X | 발품 링크 | 매체 겹침 정리 | 비용 |
|---|---|---|---|---|---|---|---|
| (1) Firebase/GA4 + Play Install Referrer만 | Install Referrer(설치 직전 사용자가 누른 스토어 링크의 꼬리표를 앱이 읽게 해 주는 플레이 기능)를 우리가 읽어 Analytics에 넣음 | ◎ 기본 연동 | △ 메타는 꼬리표를 암호화해 보내 우리가 풀기 어려움 | **✕ X는 승인된 MMP가 연결돼 있어야 앱 설치 캠페인에 입찰조차 할 수 있음** | ○ 꼬리표 붙인 스토어 링크 | ✕ 없음 | 0 |
| (2) 매체 SDK 각각 + (1) | 메타 SDK 등 매체마다 SDK를 앱에 넣음 | ◎ | ○ 메타 SDK | ✕ X는 직접 SDK 길이 없음(MMP 경유) | ○ | ✕ 매체마다 「내 덕」이라 셈 — 합이 실제 설치보다 커짐 | 0, 대신 SDK·개인정보 신고가 늘어남 |
| (3) **MMP 하나** + Firebase Analytics | AppsFlyer·Adjust·Branch·Airbridge 같은 MMP의 SDK 하나를 넣고, 각 매체를 MMP 화면에서 연결 | ◎ | ◎ | ◎ | ◎ 매체별·커뮤니티별 추적 링크를 MMP가 만들어 줌 | ◎ 한 설치는 한 매체에만 | 소규모는 무료 범위(아래) |

**추천 — (3) MMP 하나 + Firebase Analytics.** 이유는 셋입니다.

1. **X 때문에 MMP가 사실상 필수입니다.** X 광고 도움말은 앱 설치 캠페인에 입찰하려면 승인된 MMP를 연결해야 한다고 정합니다(2026-10-20 확인).
2. **판정이 매체별 숫자에 달렸습니다.** 매체마다 SDK를 넣으면 각 매체가 같은 설치를 「내 덕」이라 셉니다. MMP는 한 설치를 한 매체에만 돌려, 6단계 「어느 채널이 통했나」를 믿을 수 있게 합니다.
3. **발품 링크도 같은 곳에서 갈립니다.** 커뮤니티마다 MMP 추적 링크를 만들어 돌리면, 광고 채널과 발품 채널이 같은 표에 섞이지 않고 나란히 나옵니다. Install Referrer는 MMP SDK가 대신 읽으므로 따로 플러그인을 넣지 않습니다.

**MMP 고르기와 비용** — 소규모 MVP라 무료 범위 안에서 끝날 가능성이 큽니다. 가격은 바뀌므로 고르기 직전에 다시 확인합니다.

| MMP | 무료 범위(조회한 내용) | X 승인 파트너 | 메모 |
|---|---|---|---|
| AppsFlyer | Growth 요금제 — 첫해 12,000건 무료(「건」은 광고·링크 덕으로 잡힌 설치·재참여, 자연 설치는 셈하지 않음), 넘으면 건당 $0.07. 무료 Zero 요금제는 유료 광고용이 아님 | 예 | 가장 널리 쓰여 자료가 많음. 공식 페이지로 확인 |
| Airbridge | Core 요금제 — 광고 덕 설치 15,000건까지 무료로 안내(첫 고객 조건·기간 문구가 페이지마다 다름), 넘으면 건당 $0.05 | 확인 필요 | 한국 회사라 한국 매체·한국어 지원이 강점 |
| Adjust | 무료 Base 요금제 — 월 1,500건, 최대 12개월(제3자 자료, 공식 확인 필요) | 예 | |
| Branch | 공개 가격이 불분명 | 예 | 딥링크가 강점 |

추천 순서는 **AppsFlyer(Growth)** 를 기본으로, X 파트너 여부가 확인되면 Airbridge를 비교 후보로 둡니다. 고르는 것은 §4.1입니다.

**매체 최적화 신호와 판정 숫자를 나눕니다.**

- **매체가 광고를 최적화하는 데 쓰는 신호** — 구글은 Firebase Analytics를 구글 광고에 연결해 「가입」 같은 앱 안 이벤트를 넘깁니다(구글 쪽 공식 연동). 메타·X는 MMP가 이벤트를 넘깁니다. 같은 이벤트를 구글에 두 길(Firebase와 MMP)로 보내지 않습니다 — 두 번 셉니다.
- **6단계 판정 숫자의 정본** — 「채널별 설치」는 MMP 화면, 「설치 뒤 행동(가입·핵심 행동·재방문)」은 Firebase Analytics입니다. 두 숫자를 잇기 위해, 첫 실행 때 MMP SDK가 알려 주는 출처(매체·캠페인)를 Firebase Analytics의 사용자 속성(`acq_source`·`acq_campaign`)으로 저장합니다. 그래서 Analytics에서 「채널별 퍼널」을 바로 봅니다.
- **꼬리표 없는 설치**(스토어에서 검색해 찾아온 사람)는 MMP가 「자연 설치(organic)」로 따로 셉니다. 웹 하네스의 「검색 유입」 자리를 이어받아 제3의 채널로 세고, 판정은 발품·광고 두 축으로 합니다.

**개인정보에 닿는 것** — MMP와 광고 연동을 넣으면 신고할 것이 늘어납니다. 6단계 전에 한 번에 맞춥니다.

| 자리 | 바뀌는 것 |
|---|---|
| 광고 ID 권한 | MMP SDK가 광고 ID(GAID — 안드로이드 기기의 광고용 식별값)를 읽습니다. 안드로이드 13 이상을 대상으로 하는 앱은 앱 설정 파일에 `com.google.android.gms.permission.AD_ID` 권한을 선언해야 합니다(SDK가 자동으로 넣어 주기도 함 — 빌드 결과에서 확인) |
| 플레이 콘솔 「광고 ID」 신고 | 「광고 ID를 쓴다 — 광고·분석 목적」으로 답합니다 |
| 플레이 「데이터 보안」 신고 | 「기기 또는 기타 ID」(광고 ID·Firebase 설치 ID)·「앱 활동」(이벤트)·「앱 정보 및 성능」(Crashlytics의 비정상 종료 기록·진단)을 「수집함」으로, 광고 매체로 넘어가는 것은 「공유함 — 광고 목적」으로. 수집 주체마다(Firebase·MMP·광고 매체) 무엇을 하는지 `store-listing.md` 표에 적어 답안의 근거로 둡니다 |
| 개인정보처리방침(Hosting) | 처리 위탁 받는 곳(Firebase·MMP)과 제공받는 곳(광고 매체), **개인정보 국외 이전**(해외 서버로 가는 경우의 받는 자·나라·항목·기간), 광고 ID 수집과 거부 방법(폰 설정에서 광고 ID 삭제) |
| iOS를 붙일 때 | 앱 추적 투명성(ATT — 광고 추적 전에 사용자 허락을 묻는 iOS 창)이 필요합니다. iOS 출시 문서에 적어 둡니다 |

정확한 답 항목 이름은 콘솔 화면이 바뀌므로 6단계에서 그 화면 그대로 확인합니다.

### 3.11 6단계 출시와 측정

**1부 앞에 「정식 출시 준비」가 생깁니다.** 광고를 켜려면 앱이 플레이 스토어에 **정식 공개**돼 있어야 합니다. 조직 계정이라 닫힌 테스트 기간 요건은 없지만, 그 전에 할 일이 있습니다.

1. fastlane 자동화 켜기 — 서비스 계정 권한 반영에 최대 24시간(§3.7).
2. MMP 붙이기 — SDK·매체 연결·추적 링크(§3.10). 광고 계정(구글 광고·메타·X)을 계정 표와 대조.
3. 데이터 보안·광고 ID 신고와 개인정보처리방침을 MMP·광고 기준으로 갱신(§3.10).
4. 스토어 등록정보 완성.
5. 프로덕션 트랙 심사 — 며칠 걸릴 수 있습니다.

이 시간을 `launch-plan.md`의 기간 계획에 넣습니다. 동결(광고 전 기준 확정) 원칙은 그대로입니다.

**스토어 등록정보가 랜딩 페이지 자리입니다.** 광고를 누른 사람은 웹 랜딩이 아니라 스토어 페이지로 갑니다. AI가 초안을 만드는 것에 「앱 이름·짧은 설명(80자)·자세한 설명·스크린샷·그래픽 이미지」가 더해지고, 문구는 `ux-writing-reviewer`를 거칩니다. 모두 `fastlane/metadata/android/ko-KR/`에 파일로 두고 git으로 관리합니다. 측정 기간 중 「랜딩 카피 수정 금지」는 「스토어 등록정보 수정 금지」로 바뀝니다. Hosting 랜딩은 `RELEASE_PHASE=production`으로 바꿔 스토어 버튼을 보여 줍니다.

**스토어 스크린샷 만드는 법** — 이전 앱에서 쓴 두 방식 중 고릅니다.

| 방식 | 어떻게 | 좋은 점 |
|---|---|---|
| (가) 앱 화면 그대로 | Maestro(화면 조작을 짧은 설정 파일로 적어 기기에서 자동 실행하는 도구)로 로케일별로 앱을 돌며 촬영 | 실제 화면 그대로 |
| (나) 꾸민 그림 | 1080×1920 HTML 틀에 골든 그림이나 화면 캡처를 넣고 문구를 얹음 → Playwright로 PNG → 스크립트가 fastlane 폴더로 옮김 | 설명 문구·배경을 넣은 광고형 스크린샷 |

하네스 틀에는 (나)의 HTML 틀과 옮기기 스크립트를 넣고, (가)는 선택 안내로 둡니다. 스크린샷은 사람이 보고 고릅니다.

**퍼널에 「스토어 방문 → 설치 → 첫 실행」을 넣습니다.**

| # | 단계 | 어디서 재나 |
|---|---|---|
| 1 | 광고 노출·클릭 | 각 광고 매체 화면, MMP |
| 2 | **스토어 방문** | 플레이 콘솔 획득 보고서 |
| 3 | **설치** | MMP(채널별) + 플레이 콘솔(전체) |
| 4 | **첫 실행** | Firebase Analytics `first_open`(채널 속성 포함) |
| 5 | 가입 | Analytics |
| 6 | 핵심 행동 | Analytics |
| 7 | 재방문(7일 내) | Analytics |
| 8 | 결제(또는 지불 의사 대리 지표) | Analytics·플레이 결제 |

「스토어 방문 → 설치」 전환율은 스토어 등록정보의 힘을 재므로, 「유입은 되는데 설치가 낮다」는 실패 갈래(→ 스토어 등록정보 다시 짜기, 단계 이동 없음)를 실패 갈래 표에 더합니다. 숫자가 여러 화면에 흩어지므로 launch-retro에 「어느 화면에서 옮겨 적었나」를 단계마다 적습니다. 설치하고 첫 실행 전에 지운 사람은 Analytics에 안 잡히는 것도 함께 적습니다.

**광고 매체**

- **구글 앱 캠페인** — Firebase Analytics를 구글 광고에 연결해 설치와 앱 안 이벤트를 최적화 신호로 씁니다. 소액 예산에서는 「설치」를 목표로 시작하고, 가입 이벤트가 충분히 쌓이면 바꿉니다.
- **메타 앱 설치 광고** — MMP를 통해 연결합니다. 메타 SDK를 따로 넣지 않습니다.
- **X 앱 설치 광고** — MMP 연결이 입찰 조건입니다.
- 매체마다 광고 예산·기간·소재를 `launch-plan.md`에 나란히 적어, 매체별 비교가 판정에 쓰일 수 있게 합니다.

**채널 구분** — 매체 광고는 MMP가 자동으로 가릅니다. 발품 채널(커뮤니티 글 등)은 커뮤니티마다 MMP 추적 링크를 만들어 돌립니다. 플레이 콘솔의 「맞춤 스토어 등록정보」(채널마다 다른 스토어 페이지)는 측정 기간 중 등록정보를 바꾸지 않는 규칙과 부딪힐 수 있어 쓰지 않습니다.

**표본의 한계 한 줄** — 안드로이드만 출시하므로 iOS 사용자는 퍼널에 들어오지 않습니다. 타겟 중 iOS 비율이 높으면 결과가 그만큼 치우친다는 것을 launch-plan의 비목표·한계에 적습니다.

### 3.12 검증 — 화면 밖 검사 목록

「화면은 사람이 보고, AI는 화면 밖 검사까지」 원칙은 그대로입니다. 검사 목록만 바뀝니다.

| 검사 | 명령 | 언제 | CI |
|---|---|---|---|
| 형식 | `fvm dart format --output=none --set-exit-if-changed .` | 매번 | 돎 |
| 정적 분석(린트·타입) | `fvm flutter analyze` | 매번 | 돎 |
| 단위·위젯 테스트 | `fvm flutter test --exclude-tags golden` | 매번 | 돎 |
| 생성 코드 최신 | `fvm dart run build_runner build` 뒤 git 차이 0 | 매번 | 돎 |
| 골든 테스트 | `fvm flutter test --tags golden` | 화면을 바꾼 뒤, 이 맥에서만 | 안 돎(운영체제마다 그림이 다름) |
| 디자인 규칙 검사 | `bash .claude/scripts/design-check.sh` | 2-1 끝·3단계 배포 전·코드가 바뀔 때마다 | 안 돎(판정은 메인) |
| 디버그 빌드 | `fvm flutter build apk --debug --flavor dev -t lib/main_dev.dart` | 매번 | 돎 |
| 실서비스 빌드 | `fvm flutter build appbundle --release --flavor prod -t lib/main_prod.dart` | 출시 전 | 안 돎(업로드 키가 CI에 없음) |
| Firebase 설정 파일 대조 | §3.8 「잘못 붙는 사고를 막는 장치」 2번 | 매번 | 돎 |
| 계측 정의 + 호출 | §3.10 | 매번 | 돎 |
| 서버 함수 린트·빌드·단위 테스트 | `functions/`에서 `npm run lint && npm run build && npm test` | `functions/`를 바꿨을 때 | 돎 |
| 보안 규칙 테스트 | §3.8 결정 1(추천: CI에서만 에뮬레이터) | 규칙을 바꿨을 때 | 결정에 따름 |
| 기기 통합 테스트(스모크) | `fvm flutter test integration_test --flavor dev` | 4단계부터, `done-task` 전 | 안 돎(기기 필요) |
| 패키지 상태 | `fvm flutter pub outdated`, 새 패키지의 최근 발행일 | 3단계 배포 전·패키지를 들일 때 | — |

**`flutter test`만으로는 부족합니다.** 이전 앱에서 확인한 교훈: `flutter test`는 테스트가 import하지 않은 파일의 오류를 잡지 못합니다. 그래서 `flutter analyze`를 언제나 함께 돌리고, 둘 중 하나만 통과한 것을 「통과」로 보고하지 않습니다.

「빌드 둘을 동시에 돌리지 않는다」는 Gradle도 같은 폴더를 쓰므로 남깁니다. 「공용 dev 서버를 죽이지 마라」는 「사용자가 띄운 시뮬레이터·연결한 폰·실행 중인 `flutter run`·캔버스 서버·`build_runner watch`를 끄지 마라」로 바뀝니다.

**배포 전 검사 ②(코드 품질)** 는 하네스가 가진 점검표(`3-flutter-quality.md`)로 sonnet 에이전트 하나가 리뷰합니다. 실제로 잘 터지는 것 위주입니다: 비동기 작업 뒤 `BuildContext` 사용(`mounted` 확인), 컨트롤러·구독을 `dispose`하지 않음, 목록에 key가 없어 상태가 섞임, 큰 이미지를 원본 크기로 디코딩, `build` 안에서 무거운 계산·저장소 호출, 기기 저장소 읽기 실패 처리 없음, Firebase 실시간 구독을 화면이 사라져도 안 끊음, Firestore 읽기를 목록 항목마다 따로 함(비용), 관리가 끊긴 패키지.

**속도 판정** — 「디버그 빌드로 속도를 재지 않는다 — `flutter run --profile`이나 시험 트랙 빌드로 잰다」.

### 3.13 머지와 출시 — 「머지 = 배포」의 재정의

웹 하네스는 「main에 머지 = 실서비스 배포」라서 `done-task`가 사람의 「보내줘」 한마디를 「사람이 화면을 봤다」는 증거로 썼습니다. 앱은 **머지해도 아무 데도 나가지 않습니다.** 그래서 셋으로 나눕니다.

1. **머지(`/done-task`)** — 「이 코드를 main에 합쳐도 된다」. 사람이 시뮬레이터·폰·캔버스로 화면을 본 뒤 「보내줘」라고 할 때 부르는 것은 그대로입니다. 작업 중 개발용 Firebase에 규칙·함수를 배포한 것은 머지 전이어도 괜찮습니다 — 개발용은 웹 하네스의 로컬 DB 자리입니다.
2. **백엔드 출시(`/backend-release`)** — 「main의 이 커밋의 규칙·색인·함수·Hosting을 실서비스 Firebase에 배포한다」. 사람이 「올려줘」라고 할 때만, 메인이 직접. 「실서비스 배포 전 확인」(§3.8)을 먼저 돌립니다.
3. **앱 출시(`/store-release`)** — 「main의 이 커밋을 플레이 트랙에 올린다」. 사람이 「올려줘」라고 할 때만, 메인이 직접. 빌드 번호를 올리는 커밋은 작업 브랜치 → PR로 넣고, 머지된 커밋에 `v<판>+<빌드 번호>` 태그를 남깁니다.

**실서비스에 나가는 것은 언제나 main의 커밋에서 만듭니다** — 웹의 「CLI 수동 배포는 로컬 작업 트리를 올려 실서비스 = main 보장을 깬다」와 같은 이유입니다.

**백엔드와 앱의 순서** — 웹의 「더하는 마이그레이션은 밀고 나서 머지, 없애는 것은 배포된 뒤」 규칙이 이렇게 바뀝니다. 핵심은 **옛 판 앱이 사용자 폰에 오래 남는다**는 점입니다.

| 변경 | 순서 |
|---|---|
| 더하는 것(새 필드·새 함수·규칙 넓히기) | 백엔드 출시 먼저 → 그다음 앱 출시. 새 앱이 기대하는 것이 먼저 있어야 합니다 |
| 없애는 것(필드·함수 삭제, 규칙 조이기) | 새 앱 출시 → Remote Config `min_version`을 올려 옛 판을 막거나, 옛 판 사용자가 충분히 줄어든 것을 콘솔에서 확인 → 그다음 백엔드에서 없앰. MVP 기간에는 필드를 지우지 않고 남겨 두는 쪽이 기본 |
| 둘이 함께 바뀌어야 하는 것 | 「더하는 것 + 나중에 없애는 것」 두 번으로 쪼갭니다 |

**되돌리기가 달라집니다** — 플레이는 한 번 올린 빌드 번호로 되돌아갈 수 없습니다. 앱에 문제가 생기면 ① 단계적 출시(사용자 일부에게만 먼저 내보내기)를 멈추고 → ② 고친 커밋(또는 되돌린 커밋)을 **더 높은 빌드 번호로** 다시 올립니다. 백엔드는 이전 커밋의 규칙·함수를 다시 배포해 되돌립니다. `docs/git-workflow.md`의 되돌리기 절을 이렇게 바꿉니다.

### 3.14 계정 장부·실행기·감시 훅

**실행기(`with-owner.sh`)** 는 그대로 「장부를 읽어 키를 환경변수로 넣고 명령을 돌린다」입니다. 장부 이름이 바뀝니다.

| 장부 이름 | 무엇 | 비고 |
|---|---|---|
| `GH_TOKEN` | 그대로 | |
| `FIREBASE_ACCOUNT` | Firebase CLI가 쓸 구글 계정 이메일(값이 아님) | §4.1의 (a)일 때. 실행기가 `firebase` 명령에 `--account <이메일>`을 붙여 줍니다 — Firebase CLI는 여러 계정을 등록해 두고 명령마다 고를 수 있습니다 |
| `FIREBASE_SA_DIR` | 배포용 서비스 계정 키 파일 폴더 경로 | §4.1의 (b)일 때. 실행기가 `--project` 별칭으로 프로젝트 ID를 찾아 그 키 파일을 `GOOGLE_APPLICATION_CREDENTIALS`로 넣습니다 |
| `PLAY_SERVICE_ACCOUNT_FILE` | 플레이 올리기용 서비스 계정 키 파일 경로 | fastlane이 읽습니다. 키 파일은 JSON이라 장부에는 경로만 |
| (장부에 두지 않음) `ANDROID_UPLOAD_KEY_PROPERTIES` | 업로드 키 비밀번호 파일 경로 | 앱마다 따로라 장부에 적지 않습니다. 실행기가 `applicationId`로 `~/.config/harness/keys/<패키지 이름>-upload.properties`를 정해 넣고, `store-release`가 빌드 때만 프로젝트로 연결 |
| (삭제) `VERCEL_*`·`SUPABASE_ACCESS_TOKEN` | | |

키 파일은 모두 장부 폴더(`~/.config/harness/keys/`, 권한 600) 안에 둡니다. 새로 만든 구글 클라우드 조직은 보안 기본값으로 **서비스 계정 키 만들기가 막혀 있을 수 있습니다** — 막히면 조직 관리자가 해당 프로젝트에만 예외를 열어야 하므로, 4-0과 6단계 앞 준비에 「키 만들기가 막히면 멈추고 사람에게」를 넣습니다.

**감시 훅(`owner-runner-guard.sh`)** 이 막는 것

| 명령 | 막는 조건 |
|---|---|
| `firebase …`(`npx firebase` 포함) | 실행기 없이 부를 때. `--project dev`·`--project prod` 둘 다 없을 때. `--version`·`--help`는 예외 |
| `firebase deploy --project prod`, `firebase functions:secrets:set --project prod` 등 실서비스를 바꾸는 명령 | 현재 브랜치가 main이 아닐 때 |
| `firebase firestore:delete`·데이터 지우기 스크립트 | `--project prod`이면 언제나 |
| `flutterfire configure` | 실행기 없이 부를 때 |
| `fastlane`(`bundle exec fastlane` 포함) | 실행기 없이 부를 때. main이 아닐 때 |
| `git commit` | 올리려는 변경에 `storePassword=`·`keyPassword=`·`-----BEGIN PRIVATE KEY-----`·`"private_key":` 같은 줄이 있을 때(§3.7 평문 사고 방지) |

`npx`·`fnm exec` 건너뛰기는 그대로 두고(Firebase CLI가 Node로 돌기 때문), `fvm`·`bundle exec` 건너뛰기를 더합니다.

### 3.15 AGENTS.md가 바뀌는 자리

| 절 | 바뀌는 것 |
|---|---|
| 맨 위 | 「website-harness 하네스의 `/idea-to-mvp`」 → 「이 저장소가 원본인 Flutter 하네스의 `/idea-to-mvp`」. 「이 저장소가 만드는 것」은 1단계 인터뷰에서 채우는 그대로 |
| 소유와 계정 — 문장 | 「CLI 키(gh·Vercel·Supabase)」 → 「CLI 키와 키 파일 경로(gh·Firebase·플레이 서비스 계정)」 + 「업로드 키는 앱마다 따로라 장부에 적지 않고 `keys/<패키지 이름>-upload.*`에 둔다」 |
| 소유와 계정 — 표 | 아래 표로 바꿉니다 |
| 작업 원칙 — 브랜치 | `done-task` 설명의 「머지는 곧 실서비스 배포」 → 「머지는 main에 합치기, 실서비스는 `backend-release`·`store-release`」(§3.13). 「화면을 확인하셨다면 보내도 되겠습니까?」 물음은 그대로 |
| 작업 원칙 — 위임 | 「배포는 위임 금지」의 예에 「실서비스 Firebase 배포·스토어 올리기·콘솔 신고 답안 제출」을 더합니다 |
| 하네스 수정 | §3.1대로 다시 씁니다 |
| 검증 | 속도·공용 서버 줄을 §3.12대로. 「보안이 걸린 브랜치」 목록을 「로그인·보안 규칙·보호 필드·결제·업로드·서명·딥링크」로. 「버그는 재현부터 고정한다」의 예를 「규칙 테스트·위젯 테스트·서버 함수 단위 테스트」로. 변경 종류별 반영 표(§3.2)를 넣습니다 |
| 디자인 시스템 연결 정보 | 항목을 Dart 기준으로: 토큰 세 파일·테마 조립 파일·감싸개 부품 목록·인벤토리 위치·셸·화면 패턴 목록·디자인 규칙 검사 예외 줄·적용 규칙 요약(글자 배율 세 자리 포함). `components.json`·고친 shadcn 부품 목록 삭제 |
| 이 프로젝트가 쓰는 도구 | Supabase CLI·Vercel CLI·Docker 줄 삭제. fvm·Flutter·Xcode·Android Studio·안드로이드폰·Firebase CLI·FlutterFire CLI·fastlane 줄 추가. Node·fnm 줄은 「서버 함수·Firebase CLI용」으로 남김. gh·jq 줄 그대로. 「환경은 2단」을 「Firebase 개발용·실서비스용 두 프로젝트, 에뮬레이터는 개발에 안 씀」으로 |
| 배포와 마이그레이션 | 「백엔드와 앱의 순서」 표(§3.13)로 |
| 로컬 DB 리셋 | 「개발용 데이터 넣기와 지우기」(§3.9)로 — 시드·정리 스크립트는 개발용만, 고정 ID·시드 표시만 지움 |
| 클라우드에 시드 넣기 | 삭제. 「실서비스에 견본 데이터가 필요하면 사람이 확인한 뒤 메인이 별도 스크립트로」 한 줄 |
| 키 이름 참고(Supabase) | 삭제 |

**계정 표(바뀐 뒤)**

| 서비스 | 계정 |
|---|---|
| GitHub | 그대로 |
| 커밋 작성자 (git) | 그대로 |
| 구글 플레이 콘솔 개발자 계정 | 조직(사업자) 계정 이름·소유 이메일 |
| 구글 클라우드 조직 | 두 Firebase 프로젝트가 속한 조직 |
| Firebase 개발용 프로젝트 | 프로젝트 ID |
| Firebase 실서비스 프로젝트 | 프로젝트 ID |
| Firebase CLI 로그인 계정 | 이메일 |
| 플레이 올리기용 서비스 계정 | 서비스 계정 이메일 |
| 플레이 업로드 키 보관 위치 | 자리(값이 아님) |
| 카카오 developers | (확인 필요) |
| 광고 계정(구글 광고·메타·X) | 각 계정 이름·이메일 |
| MMP | 계정 이메일 |
| AI 제공사 키 | (확인 필요) — 키는 서버 함수 비밀값에만 |
| 애플 개발자 계정 | 해당 없음(iOS 출시 때) |
| 브라우저 작업 프로필 | (확인 필요) |
| 2FA 수단·복구 코드 보관 위치 | (확인 필요) |

`next dev`가 붙이는 `<!-- BEGIN:nextjs-agent-rules -->` 구역을 지우지 말라는 문장들(2-0·2-1·project-init)은 모두 없어집니다.

---

## 4. 사용자가 정해야 할 것

### 4.1 확정된 것

아래는 사용자가 확정한 것입니다. 구현 묶음 지시서에 그대로 넣습니다.

| 항목 | 확정 |
|---|---|
| 이 폴더 | 하네스 원본 겸 첫 제품(§3.1) |
| 플레이 계정 | 사업자(조직) 계정 — 닫힌 테스트 12명·14일 요건 해당 없음(§3.7) |
| 백엔드 | Firebase — Auth·Firestore·Storage·Cloud Functions(TypeScript)·FCM·Analytics·Crashlytics·Remote Config·App Check·Hosting(§3.9) |
| 에뮬레이터 | 개발에 쓰지 않음. 개발은 iOS 시뮬레이터 + USB 안드로이드폰, 클라우드에 붙음(§3.8). 규칙 테스트 예외 여부만 결정 1 |
| Firebase 프로젝트 | 개발용·실서비스용 둘(§3.8) |
| 광고 매체 | 구글 앱 캠페인 + 메타 + X 등 여럿(§3.10) |
| 상태 관리·화면 이동 | Riverpod 3(코드 생성·린트 포함) + go_router(§3.3) |
| Android Studio | AI가 설치, 약관 동의만 사람(§3.2) |
| 지원 기기 | 폰만(§3.3) |
| iOS 절차 문서 | 안드로이드 출시 뒤에 씀. iOS 시뮬레이터는 개발 기기로 지금부터 씀 |
| 플레이 올리기 | 첫 판은 손으로, 6단계 앞에서 fastlane 자동화(§3.7) |
| 개인정보처리방침·계정 삭제 페이지 | Firebase Hosting(§3.9) |
| 서비스 이름 | 첫 제품 프로젝트에서 정함(이 하네스 문서와 무관) |
| 소유 | 개인(`.claude/owner`는 `personal` 유지). 플레이 계정은 사용자 개인사업자 명의의 사업자 계정 |
| 패키지 이름 | `app.<이름>`(개발용 앱은 `app.<이름>.dev`) — 가진 도메인 기준 |
| Firebase 프로젝트 ID | `<이름>-dev`·`<이름>-prod`(이미 쓰이면 끝에 숫자) |
| 저장소 이름 | 하네스 개편이 끝난 뒤 서비스 이름으로 바꿈(원본 기록 §3.1도 함께) |
| 보안 규칙 테스트 | 규칙 테스트만 CI에서 에뮬레이터 예외(§3.8) |
| MMP | AppsFlyer Growth(§3.10) |
| Firebase CLI 로그인 | `firebase login`으로 계정 등록 + 실행기가 명령마다 `--account`. 안 먹는 명령이 실측되면 서비스 계정 키 파일로(§3.14) |
| 목업 캔버스 자리 | iPad 시뮬레이터(§3.6) |
| 앱 올리기 | 이 맥에서 메인이 `store-release`로(§3.7) |
| 예산 알림 | 개발용 월 1만 원 수준, 실서비스는 6단계 광고 예산과 별도로 정함 |
| 다국어 | 한국어만, 문구 파일 구조는 처음부터 다국어 |
| Hosting 주소 | 기본 주소로 시작, 6단계 전에 자기 도메인 검토 |
| 골든 테스트 | 내장 골든 + 작은 도우미 패키지, 기준 그림은 이 맥에서만 |
| 요소 복사 | 코멘트 핀에 단서만 담기로 시작, 묶음 F에서 「파일:줄」이 싸게 되면 넣음 |
| 스토어 스크린샷 | HTML 틀 → PNG를 기본 틀로, Maestro 촬영은 선택 |

### 4.2 아직 정할 것

없습니다. 결정할 것은 모두 §4.1에 확정으로 옮겼습니다.

---

## 5. 구현 순서

묶음끼리는 **같은 파일을 건드리지 않게** 나눴습니다. 난이도 표시는 AGENTS.md의 모델 고르기 기준에 맞춘 것입니다 — **기계적**(haiku), **명세 분명**(sonnet), **설계 판단**(opus 이상).

| 묶음 | 건드리는 파일 | 하는 일 | 난이도 | 먼저 끝나야 할 것 |
|---|---|---|---|---|
| A. 원본 독립 | `.claude/harness-version`, `skills/project-init/SKILL.md`, `skills/harness-diet/SKILL.md` | §3.1 | 명세 분명 | — |
| B. AGENTS.md와 사람용 문서 | `AGENTS.md`, `docs/account-check.md`, `docs/git-workflow.md` | §3.15 표대로, §3.13의 머지·출시·순서·되돌리기, §3.2 반영 표 | 명세 분명 | A, §4.1 |
| C. 실행기·훅·CI·무시 목록 | `scripts/with-owner.sh`, `hooks/owner-runner-guard.sh`, `hooks/no-main-push.sh`(주석), `.github/workflows/ci.yml`, `.gitignore` | §3.14 장부 이름·막는 조건, §3.12 CI(Flutter·서버 함수·규칙 테스트·설정 파일 대조·계측 검사) | **설계 판단**(실서비스를 막는 훅 조건과 평문 비밀번호 검사는 틀리면 사고 — 실제 명령으로 막히는지·통과하는지 시험) | §4.1 |
| D. design-system 스킬 | `skills/design-system/` 전체 | §3.5. 3층 토큰·`context.colors`·대비 도우미·글자 배율 규칙·감싸개 규칙·서체 | **설계 판단** — 이후 모든 화면 규칙의 바탕 | — |
| E. 디자인 규칙 검사 | `scripts/design-check.sh` | §3.5 표의 14개 검사 | 명세 분명 | D |
| F. 목업 캔버스·지도 틀 | `templates/mockup-canvas/` 전체, `templates/sample-map/` 전체 | §3.6. iPad 시뮬레이터용 캔버스 진입점(캔버스 전용 아이패드 지원 설정 포함)·폰 틀·흐름 펼치기·provider 덮어쓰기·가짜 저장소·코멘트 서버·목록·상태 스크립트·골든 미리보기 | **설계 판단**(가장 큼 — 임시 폴더의 빈 Flutter 앱을 iPad 시뮬레이터에 실제로 띄우며 만듦. F1 캔버스·코멘트, F2 스크립트·골든으로 나눠 차례로) | D, §4.1 |
| G. 앱 뼈대 틀 | 새 `templates/firebase/`, 새 `templates/android-signing/` | §3.3 폴더 구조·코드 규칙 넷(Result·생성자 주입), §3.8 flavor 두 개·진입점 셋·설정 파일 자리·대조 스크립트, §3.9 규칙·함수·규칙 테스트 뼈대, §3.7 서명 gradle 조각 | **설계 판단**(flavor·iOS scheme·설정 파일 복사는 빈 앱에서 시뮬레이터·폰으로 실측) | D, §4.1 |
| H. idea-to-mvp 1·2단계 문서 | `SKILL.md`, `references/1-intent.md`, `references/intent-examples/*`, `references/2-0-dev-setup.md`, `references/2-1-mockup.md`, `references/2-2-mockup-design-upgrade.md` | §3.2·§3.3·§3.4·§3.6. 2-0 새로 쓰기(도구표·Xcode·폰 연결·flavor·반영 표·패키지 이름 확인), 2-1·2-2를 Dart·iPad 캔버스 기준으로 | **설계 판단**(2-0) + 명세 분명(나머지). 2-0과 나머지를 다른 에이전트로 차례로 | D·F·G, §4.1 |
| I. 3단계 문서와 앱 출시 | `references/3-frontend-build.md`, 새 `references/3-flutter-quality.md`, 새 `skills/store-release/SKILL.md`, 새 `templates/fastlane/`, 새 `templates/store-listing.md` | §3.7·§3.12. 검사 ①②③, 배포 절(조직 계정·Draft App·서명·버전), 출시 스킬, Fastfile·스토어 정보 폴더·스크린샷 틀 | **설계 판단**(store-release — 밖으로 나가는 절차) + 명세 분명(문서) | E·F·G, §4.1 |
| J. 4단계 문서·보안 규칙·백엔드 출시 | `references/4-0-backend-prep.md`, `4-1-backend-db.md`, `4-2-backend-auth.md`, `4-3-backend-deploy.md`, `rules/security-baseline.md`, 새 `skills/backend-release/SKILL.md`, 새 `templates/hosting-site/` | §3.8·§3.9. 두 프로젝트·리전·요금제·예산, 보호 필드, App Check 단계, 강제 업데이트, 로그인(지문·카카오 커스텀 토큰), 시드·정리, Hosting 웹, 스모크, 결제, 실서비스 배포 전 확인 | **설계 판단**(보안·로그인 — 공식 문서 확인을 지시서에 넣음). 4-1+security-baseline / 4-0+4-2 / 4-3+backend-release+hosting-site 셋으로 나눠 차례로 | B·G, §4.1 |
| K. 계측·5·6단계 문서 | `references/5-market-research.md`, `references/6-mvp-launch.md`, (J가 만든) `4-3`의 계측 절은 건드리지 않고 참조만 | §3.10·§3.11. MMP·매체 연결·사용자 속성·정의+호출 검사 안내·개인정보 신고·정식 출시 준비·퍼널 | 명세 분명(MMP 가격·X 파트너는 웹 확인 — 재시도 한도 넣음) | J, §4.1 |
| L. 나머지 스킬·에이전트 | `skills/ship-task/SKILL.md`, `skills/done-task/SKILL.md`, `skills/code-cleanup/SKILL.md`, `skills/transfer-ownership/SKILL.md`, `agents/harness-auditor.md`, `agents/ux-writing-reviewer.md` | §2.5 표대로 | 명세 분명(transfer-ownership은 Firebase·플레이 이전 순서를 공식 문서로 확인) | B·I·J |
| M. 잔재 점검 | (읽기만, 보고서) | 하네스 전체에서 `Next`·`Vercel`·`Supabase`·`supabase`·`RLS`·`pgTAP`·`Docker`·`tsx`·`Tailwind`·`shadcn`·`localStorage`·`src/app`·`website-harness`·`React Native`·`닫힌 테스트 12명` 잔재 0건(Node·fnm은 서버 함수 용도로 남는 것이 맞는지 확인), 목차 앵커·교차 참조 확인. `harness-diet`로 한 회 돌려도 됨 | 기계적 | A~L 전부 |

**차례로 돌릴 것과 함께 돌려도 되는 것**

- 먼저 §4.1의 확정을 지시서에 넣습니다.
- 1차(서로 파일이 안 겹침, 함께 띄워도 됨): A, C, D.
- 2차: B(A 뒤), E·F·G(D 뒤 — F와 G는 둘 다 빈 Flutter 앱을 띄우므로 서로 다른 임시 폴더에서).
- 3차: H(D·F·G 뒤), J(B·G 뒤).
- 4차: I(E·F·G 뒤), K(J 뒤).
- 5차: L, 그다음 M.

**구현 묶음 지시서에 꼭 넣을 것** — 「재위임 금지」, 「`git checkout`·`git restore` 금지, 자동 임시 저장 커밋은 정상」, 「도구 판·정책·가격은 공식 문서로 확인하고 숫자를 문서에 박지 않는다(ADR에 적는 원칙)」, 「AGENTS.md 응답·문서 작성 규칙(합쇼체·처음 나오는 용어 풀이)」, 「판올림 문서 규칙 — 이전 판 연계 표기를 본문에 넣지 않는다」, 「이전 앱 교훈은 『이전 앱에서 확인한 교훈』으로만 쓰고 그 앱의 이름·경로·파일 이름은 적지 않는다」. F·G처럼 실제 앱을 돌려 보며 만드는 묶음은 「임시 폴더의 빈 Flutter 앱에서 시험하고, 하네스에는 틀만 남긴다」·「화면은 사람이 본다 — 분석·테스트·빌드까지만」·「Firebase 실제 프로젝트는 만들지 않는다(설정 파일은 가짜 값으로)」를 넣습니다. 웹을 조회하는 묶음(J·K·L)은 「같은 실패 2회면 멈추고 보고, 401·403·404 재시도 금지, 로그인 필요한 곳은 들어가지 않음」을 넣습니다.

---

**참고한 바깥 자료**

- X 비즈니스 도움말 — 앱 설치 캠페인의 모바일 측정·귀속(승인된 MMP 필요): <https://business.x.com/en/help/campaign-setup/create-an-app-installs-campaign/mobile-app-measurement-and-attribution>
- X Ads API — 모바일 전환 개요: <https://developer.x.com/en/docs/x-ads-api/measurement/mobile-conversions/overview>
- AppsFlyer 요금 안내(Zero·Growth, 첫해 12,000건, 건당 $0.07): <https://www.appsflyer.com/pricing/>
- Airbridge 요금 안내: <https://www.airbridge.io/en/pricing>
- Airbridge의 MMP 요금 비교 글(경쟁사가 쓴 글이라 참고만 — Adjust 무료 범위 출처): <https://www.airbridge.io/tips/mobile-attribution-pricing-plans-contract-terms>
- 플레이 콘솔 도움말 — 광고 ID 선언(AD_ID 권한): <https://support.google.com/googleplay/android-developer/answer/6048248>
- Firebase 문서 — Firestore 보안 규칙 테스트(에뮬레이터와 `@firebase/rules-unit-testing`): <https://firebase.google.com/docs/firestore/security/test-rules-emulator>
- Firebase 문서 — 보안 규칙 단위 테스트: <https://firebase.google.com/docs/rules/unit-tests>
- Alchemist 골든 테스트 안내(VGV): <https://verygood.ventures/blog/alchemist-golden-tests-tutorial/>
