---
name: github-connect
description: 이 컴퓨터에서 이 프로젝트가 GitHub에 올라갈 수 있는 상태를 만든다 — git 설치 확인, gh·jq 자동 설치, GitHub 계정, gh 인증 토큰(이 컴퓨터의 소유별 계정 장부 ~/.config/harness/), 계정 확인, HTTPS push 인증 방식, 원격 저장소 생성, 첫 push까지 순서대로. 이미 된 단계는 건너뛰어 언제 다시 돌려도 안전하고, 사람 몫이 나오면 그 한 단계만 화면·버튼 이름 그대로 안내하고 멈췄다가 "됐어"에 이어간다. project-init 신규 적용 끝에서 대상 폴더 절대 경로를 인자로 받아 자동으로 불린다(인자가 없으면 세션 폴더). 트리거 예 "깃헙 연결해줘", "깃헙에 올려줘", "/github-connect".
---

# github-connect — 이 프로젝트를 GitHub에 잇기

목표는 하나다: **이 컴퓨터에서 이 프로젝트가 GitHub에 올라갈 수 있는 상태.** 끝나면 `new-task`(`git pull origin main`)와 `ship-task`(push·PR)가 바로 돈다.

메인 세션에서 돈다(fork 아님) — 중간에 사람 몫이 끼어 있어 사용자와 말을 주고받아야 해서다.

**대상 폴더** — 이 스킬이 GitHub에 잇는 프로젝트 폴더(절대 경로)다. 인자로 받으면 그 폴더(`project-init`이 옆 폴더 경로에서 새 폴더를 넘긴다), 없으면 세션 폴더의 최상위다. 아래의 「프로젝트」·「이 저장소」는 전부 대상 폴더를 뜻한다.

## 공통 규칙

- **역할 표시** — 각 단계에 **[AI]**(터미널 명령), **[Aside]**(브라우저 에이전트가 화면에서 하는 일), **[사람]**(가입·로그인·2FA·권한 창 클릭처럼 사람만 되는 일)을 붙였다. 뜻은 idea-to-mvp `4-0-backend-prep.md` §3과 같다.
- **재실행 안전** — 단계마다 먼저 「이미 됐나」를 확인하고, 됐으면 건너뛴다. 그래서 언제 다시 불러도 된다. 마무리 보고에 한 일과 건너뛴 일을 나눠 적는다.
- **사람 몫은 한 번에 한 단계** — 그 단계만 화면 이름·버튼 이름 그대로 안내하고 멈춘다. 사용자가 "됐어"라고 하면 그 단계를 [AI]가 다시 확인한 뒤 다음으로 간다. 여러 단계를 한꺼번에 떠넘기지 않는다.
- **비밀값은 대화에 남기지 않는다** — 토큰 값을 화면에 출력하지 않고, 셸 안에서 바로 파일로 보낸다. 사용자에게는 "채팅창에 붙여넣지 마세요 — 대화 기록에 남습니다"라고 분명히 말한다.
- **실패 한도** — `docs/account-check.md` 원칙 ⑥을 따른다. 로그인·가입·2FA·인증 코드는 1회 실패면 멈추고 사람에게. 토큰 발급은 2회. 401·403·404는 재시도하지 않고 원인을 바꾼다.
- **전역 설정은 건드리지 않는다** — `git config --global`, `gh auth switch`를 쓰지 않는다. 같은 컴퓨터에 소유가 다른 프로젝트가 있을 수 있다(`docs/account-check.md` 원칙 ②).
- **한 번에 한 단계씩 실행한다** — 단계 여럿을 한 Bash 호출에 `&&`로 묶지 않는다. 훅이 명령 하나를 막으면 묶인 앞 단계까지 통째로 실행되지 않는다(특히 ⑦·⑧·⑨).
- **모든 명령은 대상 폴더에서** — 대상 폴더가 세션 폴더와 다르면 이 스킬의 모든 명령(git·실행기·`.claude/owner` 읽기 포함)을 **매 호출마다 `cd <대상 절대 경로> && <명령>` 한 줄**로 부른다. 클로드 코드는 세션 폴더 밖으로 `cd`한 셸을 다음 호출 전에 되돌리니(실측 2026-10-20) 처음에 한 번 `cd`하는 것으로는 안 된다. 경로는 따옴표·`~`·변수 없이 절대 경로 그대로 쓴다 — 훅(`no-main-push`·`owner-runner-guard`)이 `cd` 조각을 글자 그대로 읽어 그 폴더 기준으로 검사한다. 이 `cd`는 단계를 묶는 것이 아니다. `AGENTS.md`는 `<대상>/AGENTS.md`를 읽고 쓰고, 파일 도구에는 절대 경로를 준다. 아래 명령 예시는 대상 폴더 안에서 부르는 모양으로 적었다.
- **윈도우** — 클로드 코드 윈도우판은 명령을 Git Bash에서 돌린다. 아래 명령(`sed`·`env` 포함)과 하네스 훅·실행기도 Git Bash에서 돌 것으로 보이지만 실측은 아직 없다 — 막히면 그 자리에서 멈추고 보고한다. 윈도우에서는 `chmod`가 파일 권한을 막지 못한다(사용자 폴더 권한에 기댄다).

### 계정 장부와 실행기 — gh 명령에만

토큰은 프로젝트 안이 아니라 **이 컴퓨터의 계정 장부**에 둔다 — `~/.config/harness/<소유>.env`(폴더 권한 700, 파일 600, git 저장소 밖이라 커밋되지 않는다). 소유는 프로젝트의 `.claude/owner` 한 줄(`owner=personal|company|org-<이름>`)이 정하고, 소유가 같은 프로젝트는 같은 장부 파일을 나눠 쓴다. 이 스킬이 장부에 쓰는 줄은 `GH_LOGIN`(GitHub 계정 이름)과 `GH_TOKEN`이다.

gh 명령은 실행기를 앞에 붙여 부른다. 실행기가 장부를 읽어 같은 호출 안에서 환경변수로 넣고 진짜 `gh` 프로그램을 띄운다(셸 함수를 거치지 않는다). **대상 폴더 안에서**(`cd <대상> && .claude/scripts/with-owner.sh …`) 대상 폴더의 실행기를 부른다 — 실행기는 자기 파일 위치로 프로젝트를 찾아 그 프로젝트의 `.claude/owner`를 읽고, 명령은 부른 폴더에서 돌린다. 다른 폴더(예: 하네스 저장소)의 실행기를 부르면 그 폴더의 소유 장부로 돈다.

```bash
.claude/scripts/with-owner.sh gh <명령>
.claude/scripts/with-owner.sh --check     # 소유·장부 자리·있는 키 이름·gh 계정 (키 값은 안 나옴)
```

**git 명령에는 실행기를 붙이지 않는다** — ⑦에서 거는 자격 증명 도우미가 실행기(`--git-credential`)로 토큰을 git에게만 건넨다. `git push`·`git pull`을 맨 형태로 부르면 되고, 사람이 자기 터미널에서 쳐도 똑같이 된다. git 앞에 무엇을 붙이면 훅이 명령을 제대로 못 볼 수 있다(훅은 첫 낱말 `git`으로 본다).

**장부에 키 한 줄 쓰기** — 값을 화면에 내지 않고 셸 안에서 바로 파일로 보낸다. 아래 모양을 한 Bash 호출 안에서 쓴다(`<값을 내는 명령>`은 단계마다 다르다). 다른 줄(다른 서비스 키)은 그대로 둔다.

```bash
o=$(sed -n 's/^owner=//p' .claude/owner); f="$HOME/.config/harness/$o.env"
v=$(<값을 내는 명령>) && [ -n "$v" ] && { grep -v '^GH_TOKEN=' "$f" 2>/dev/null; printf 'GH_TOKEN=%s\n' "$v"; } > "$f.tmp" && chmod 600 "$f.tmp" && mv "$f.tmp" "$f"
```

## 진행 순서

| 단계 | 이미 됐나 (확인) | 안 됐으면 | 역할 |
|---|---|---|---|
| ① git | `command git --version` 성공 | 설치 | [AI]·[사람] |
| ② gh | `command gh --version` 성공 | 묻지 않고 자동 설치 | [AI] (brew 없는 맥만 [사람]) |
| ③ jq | `command jq --version` 성공 | 묻지 않고 자동 설치 | [AI] |
| ④ GitHub 계정 | ⑤가 이미 됐거나, 사용자가 "있어" | 가입 안내 | [사람] (Aside는 화면만 열어 줌) |
| ⑤ 토큰 | 장부 토큰으로 `gh api user` 성공 (같은 소유의 다른 프로젝트가 받아 둔 것 포함) | 1순위 gh 로그인 → 2순위 Aside 발급 → 3순위 사람이 붙여넣기 | [AI]·[Aside]·[사람] |
| ⑥ 계정 확인 | (매번 한다) | — | [AI] |
| ⑦ push 인증 방식 | 로컬 도우미 설정이 아래와 같고 `git credential fill`이 `username=x-access-token`을 냄 | 로컬 git 설정 (혼자 먼저 실행) | [AI] |
| ⑧ 원격 저장소 | `git remote get-url origin` 성공 | `gh repo create` | [AI] |
| ⑨ 첫 push | 원격 main = 로컬 main | `git push -u origin main` | [AI] |

시작 전에 둘을 본다.

1. 대상 폴더가 git 저장소의 최상위인지 — `git rev-parse --show-toplevel`의 출력이 **대상 폴더와 같아야** 한다. 저장소가 아니면 멈추고 하네스 적용(`project-init`)부터 하자고 안내한다 — 저장소를 만드는 `git init -b main`은 project-init 몫이다. 다른 폴더가 나오면(예: 하네스 저장소) 멈추고 보고한다 — 그대로 가면 남의 저장소를 보고 「이미 연결됨」으로 거짓 성공을 낸다.
2. `.claude/owner`와 장부 파일이 있는지(`.claude/scripts/with-owner.sh --check`). `.claude/owner`가 없으면 project-init 신규 적용 1번 질문(소유 — 개인·회사·조직)을 한 번 묻고 그 파일과 `AGENTS.md` 소유 문장을 함께 쓴다. 장부 파일이 없으면 만든다(키는 ⑤가 채운다).
   ```bash
   o=$(sed -n 's/^owner=//p' .claude/owner); mkdir -p "$HOME/.config/harness" && chmod 700 "$HOME/.config/harness" && touch "$HOME/.config/harness/$o.env" && chmod 600 "$HOME/.config/harness/$o.env"
   ```

### ① git 확인·설치

[AI] `command git --version`. 되면 건너뛴다.

없으면 "git(코드 변경 이력을 저장하는 도구)을 설치해도 되겠습니까?" 한 번 묻고, 허락받으면:

- **맥** — [AI] `xcode-select --install` → [사람] 뜨는 창에서 「설치」를 누르고 사용권 계약에 「동의」. 끝나면 "됐어"라고 말해 달라고 한다. 맥은 `git --version`만 쳐도 이 창이 먼저 뜰 수 있다 — 그 창이면 그대로 설치하면 된다.
- **윈도우** — [AI] `winget install --id Git.Git -e` → [사람] "이 앱이 디바이스를 변경하도록 허용하시겠어요?" 창에서 「예」. 클로드 코드 윈도우판은 Git for Windows(Git Bash)가 있어야 돌아서 보통 이미 깔려 있다(최신 확인 — 쓴 시점 기준).

설치 뒤 `command git --version`으로 다시 확인한다. 윈도우에서 새로 깔았는데 인식이 안 되면 앱을 껐다 켜 달라고 한다(명령 경로가 새 창에서만 잡힌다).

### ② gh 확인·자동 설치

gh는 GitHub을 터미널에서 다루는 공식 도구(GitHub CLI)다. 작업 보내기(`done-task`)가 이 도구로 돈다.

**확인은 진짜 실행 파일로 한다** — `command gh --version`(zsh·bash 공통). 셸 설정에 `gh`라는 이름의 함수(편의 함수)를 둔 컴퓨터에서는 `which gh`·`command -v gh`가 실행 파일이 없어도 함수를 찾아 「있음」처럼 보인다. `command`는 함수를 건너뛰고 실행 파일만 부른다. 되면 건너뛴다.

**묻지 않고 AI가 깐다** — jq(③)와 같은 원칙이다. 하네스가 2단계까지 쓰는 도구는 AI가 묻지 않고 깐다(`idea-to-mvp` `2-0-dev-setup.md` §2.1 도구 점검표). 패키지 이름은 gh 공식 설치 안내(<https://github.com/cli/cli#installation>)가 정본이다 — 안 맞으면 거기서 지금 이름을 확인한다.

- **맥, brew 있음** (`brew --version` 성공) — [AI] `brew install gh`
- **맥, brew 없음** — brew를 새로 들이지 않는다. [사람] `https://cli.github.com` 에서 「Download for Mac」 → 받은 `.pkg` 파일을 열어 「계속」 → 「설치」 → 맥 로그인 비밀번호 입력. 끝나면 "됐어". (맥 로그인 비밀번호는 사람만 넣을 수 있어 이 갈래만 사람 몫이다.)
- **윈도우** — [AI] `winget install --id GitHub.cli -e` → [사람] 권한 창에서 「예」. 인식이 안 되면 앱을 껐다 켠다.

설치 뒤 `command gh --version`으로 다시 확인한다. 같은 실패가 2번 나면 멈추고 어느 명령이 무엇으로 실패했는지 보고한다.

### ③ jq 확인·자동 설치

jq는 JSON(프로그램끼리 주고받는 데이터 형식)을 읽는 작은 도구다. 하네스 훅(hook — 클로드 코드가 명령 전후에 저절로 돌리는 검사 스크립트)이 쓴다 — 없으면 main 브랜치로 바로 올리기를 막는 훅이 안전을 위해 `git push`를 전부 막고, 자동 중간 저장(wip 커밋)도 쉰다. 그래서 하네스를 처음 적용할 때(`project-init` → 이 스킬) 깔려 있어야 한다.

**묻지 않고 AI가 깐다** — 하네스가 2단계까지 쓰는 도구는 AI가 묻지 않고 까는 것이 원칙이다(`idea-to-mvp` `2-0-dev-setup.md` §2.1 도구 점검표). jq는 실행 파일 하나뿐인 작은 도구이고 하네스 안전장치가 쓰는 것이라, 묻고 기다리는 왕복 없이 바로 깐다.

[AI] `command jq --version`. 되면 건너뛴다. 없으면 아래대로 깐다. 패키지 이름·받을 파일 이름은 jq 공식 내려받기 페이지(<https://jqlang.org/download/>)가 정본이다 — 안 맞으면 거기서 지금 이름을 확인한다.

- **맥, brew 있음** (`brew --version` 성공) — `brew install jq`. 최근 macOS에는 애플이 넣어 둔 `/usr/bin/jq`가 있어 보통 이 단계까지 오지 않는다.
- **맥, brew 없음** — brew를 새로 들이지 않는다. jq 공식 GitHub 릴리스에서 이 맥의 CPU에 맞는 실행 파일 하나를 사용자 폴더에 받는다. 받을 폴더는 `echo "$PATH"`에 이미 들어 있는 사용자 폴더(`~/.local/bin`·`~/bin` 등)다.
  ```bash
  case "$(uname -m)" in arm64) f=jq-macos-arm64 ;; *) f=jq-macos-amd64 ;; esac
  mkdir -p ~/.local/bin && curl -fsSL -o ~/.local/bin/jq "https://github.com/jqlang/jq/releases/latest/download/$f" && chmod +x ~/.local/bin/jq
  ```
  PATH에 든 사용자 폴더가 없으면 `~/.local/bin`에 받고, 그 폴더를 PATH에 넣는 한 줄(`~/.zprofile`에 `export PATH="$HOME/.local/bin:$PATH"`)은 셸 설정을 바꾸는 일이라 사용자에게 안내한다.
- **윈도우(Git Bash)** — `winget install --id jqlang.jq -e`. winget이 없거나 실패하면 공식 릴리스의 윈도우 실행 파일을 `~/bin/jq.exe`로 받는다 — Git for Windows가 Git Bash를 열 때 `$HOME/bin`을 PATH 맨 앞에 넣는다(Git for Windows `env.sh`).
  ```bash
  case "${PROCESSOR_ARCHITECTURE:-AMD64}" in ARM64) f=jq-windows-arm64.exe ;; *) f=jq-windows-amd64.exe ;; esac
  mkdir -p ~/bin && curl -fsSL -o ~/bin/jq.exe "https://github.com/jqlang/jq/releases/latest/download/$f"
  ```

설치 뒤 `command jq --version`으로 다시 확인한다. 깔았는데 명령을 못 찾으면 「jq를 깔았습니다. 새 명령이 잡히도록 클로드 코드를 껐다 켜 주세요」 한 줄만 알린다(명령 경로가 새 창에서만 잡힌다). 같은 실패가 2번 나면 멈추고 어느 명령이 무엇으로 실패했는지 사용자에게 보고한다 — 사람에게 넘기는 건 그때뿐이다.

### ④ GitHub 계정

⑤가 이미 돼 있으면(토큰이 살아 있으면) 건너뛴다. 아니면 묻는다 — "GitHub 계정이 있으십니까?" 대상 폴더의 `AGENTS.md` 「소유와 계정」 표의 GitHub 행에 값이 있으면 "표에는 <계정>으로 적혀 있는데, 이 계정으로 진행하시겠습니까?"로 묻는다.

없으면 가입은 **항상 [사람]**이다. 자동 가입은 하지 않는다 — 가입 자동화는 계정 제재로 이어진다(`docs/account-check.md` 원칙 ⑥).

- **Aside가 있으면** (`command -v aside` 성공) — [Aside]가 표의 「브라우저 작업 프로필」로 `https://github.com/signup` 화면만 열어 준다. [사람] 이메일 → 비밀번호 → 사용자 이름(username) → 사람 확인 퍼즐 → 메일로 온 코드 입력까지 직접 채운다.
- **Aside가 없으면** — 주소(`https://github.com/signup`)를 주고 사용자가 자기 브라우저에서 한다.

가입·로그인이 한 번 실패하면 다시 시도하지 않고 멈춰서 무엇이 떴는지 사용자에게 묻는다. 끝나면 사용자 이름을 받아 둔다(⑥에서 표와 대조).

### ⑤ 토큰 — 장부의 `GH_TOKEN`

**확인** — 아래가 계정 이름을 답하면 건너뛴다. 같은 소유의 다른 프로젝트가 이미 받아 둔 토큰이면 장부를 나눠 쓰는 것이니 **다시 받지 않는다.** 401(토큰 죽음)이면 같은 토큰으로 다시 부르지 않고 새로 받는다.

```bash
.claude/scripts/with-owner.sh gh api user --jq .login
```

실행기가 「옛 `.env.cli`를 읽었습니다」라고 알리면 옛 프로젝트다 — 여기서 옮기지 않고 project-init 동기화(「하네스 동기화해줘」)가 장부로 옮긴다고 마무리 보고에 적는다.

**토큰에 필요한 권한(스코프 — 토큰이 할 수 있는 일의 범위)** — `repo`·`workflow`·`read:org`. 근거는 `docs/account-check.md` gh 항목(실측 2026-09-29): gh 로그인의 기본 스코프는 `repo`·`read:org`·`gist`뿐이고, 하네스가 올리는 `.github/workflows/ci.yml`을 push하려면 `workflow`가 따로 있어야 한다.

아래 셋을 순서대로 시도한다. 앞 길이 막히면 다음 길로 간다.

#### 1순위 [AI] gh 로그인으로 토큰 꺼내기

1. [AI] 로그인 전에 이 컴퓨터에 저장된 gh 계정 목록을 적어 둔다 — 7번에서 로그아웃할지 가르는 값이다.
   ```bash
   env -u GH_TOKEN gh auth status 2>&1
   ```
2. [AI] 로그인 명령을 **백그라운드로** 띄운다(Bash `run_in_background`) — 사람이 승인할 때까지 기다리는 명령이라 앞에서 돌리면 코드를 못 보여준다.
   ```bash
   env -u GH_TOKEN gh auth login --web --git-protocol https --skip-ssh-key --scopes workflow
   ```
   클로드 코드의 셸은 대화형이 아니라서 gh가 "Git 자격 증명을 설정할까?"를 묻지 않고 넘어간다 — 전역 git 설정을 안 건드리는 대신 `workflow` 스코프도 자동으로 안 붙으니 `--scopes workflow`를 꼭 단다(gh 소스 실측 2026-09-29).
3. [AI] 출력에서 일회용 코드(`XXXX-XXXX`)와 주소(`https://github.com/login/device`)를 읽어 사용자에게 보여준다.
4. [사람] 안내 (Aside가 있으면 [Aside]가 표의 프로필로 주소를 열어 준다):
   - 주소를 연다 → GitHub 로그인 화면이 나오면 로그인(비밀번호·2FA는 사람 몫).
   - 「Device Activation」 화면에서 로그인된 계정 이름이 표의 계정인지 본다 → 코드 8자리 입력 → 「Continue」.
   - 권한 승인 화면에서 「Authorize github」 (버튼 이름은 최신 확인).
   - 끝나면 "됐어".
5. [AI] 백그라운드 명령이 `Logged in as <계정>`으로 끝났는지 본다. 코드 입력·승인이 한 번 실패했으면 다시 띄우지 않고 멈춰 사람에게 묻는다.
6. [AI] 토큰을 **화면에 찍지 않고** 장부로 바로 보낸다(위 「장부에 키 한 줄 쓰기」 모양). 다른 줄(다른 서비스 키)은 그대로 둔다.
   ```bash
   login=<5번의 계정>; o=$(sed -n 's/^owner=//p' .claude/owner); f="$HOME/.config/harness/$o.env"
   v=$(env -u GH_TOKEN gh auth token --hostname github.com --user "$login") && [ -n "$v" ] && { grep -v '^GH_TOKEN=' "$f" 2>/dev/null; printf 'GH_TOKEN=%s\n' "$v"; } > "$f.tmp" && chmod 600 "$f.tmp" && mv "$f.tmp" "$f"
   .claude/scripts/with-owner.sh gh api user --jq .login   # "$login"과 같아야 한다
   ```
7. [AI] **1번 목록에 이 계정이 없었으면** 저장된 로그인 세션을 지운다.
   ```bash
   env -u GH_TOKEN gh auth logout --hostname github.com --user "$login"
   ```
   로그아웃은 이 컴퓨터의 저장본만 지우고 토큰을 폐기하지 않는다(`gh auth logout --help` 실측) — 장부의 사본은 그대로 살아 있다. 세션을 남겨 두면 전역 활성 계정이 이 계정으로 바뀐 채라, 장부 없이 도는 다른 도구가 조용히 이 계정으로 돈다. **1번 목록에 이미 있던 계정이면 지우지 않는다** — 사용자가 원래 쓰던 세션이다. 이때 로그인 전 활성 계정이 다른 계정이었으면 "전역 활성 계정이 <계정>으로 바뀌었습니다"를 마무리 보고에 남긴다.

**2순위로 넘어가는 경우** — 브라우저 승인이 안 되거나, 회사 조직 정책이 GitHub CLI 앱을 막아 조직 저장소가 403으로 안 보일 때.

#### 2순위 [Aside] 화면에서 개인 접근 토큰 발급

Aside가 없으면 "브라우저 에이전트(Aside)를 설치해도 되겠습니까?" 묻고, 허락받으면 맥·리눅스는 `curl -fsSL https://releases.aside.com/install.sh | bash`로 설치한 뒤 `aside guide`를 읽고 쓴다. **윈도우는 설치 방법이 확인되지 않았다** — 윈도우에서 Aside가 없으면 3순위로 간다.

1. [Aside] 표의 「브라우저 작업 프로필」로 github.com을 열고, 화면에 로그인된 계정을 표와 대조한다(`docs/account-check.md` 원칙 ④). 로그인·2FA가 필요하면 [사람].
2. [Aside] Settings → Developer settings → Personal access tokens → Tokens (classic) → 「Generate new token (classic)」 (바로 가는 주소 `https://github.com/settings/tokens/new`).
   - Note(이름): **용도·기기로 짓는다** — 예 `gh-cli-<기기 이름>`. 프로젝트 이름을 붙이지 않는다 — 소유 계정당 하나를 여러 프로젝트가 나눠 쓰는 토큰이라, 프로젝트가 끝났을 때 남이 쓰는 토큰을 지우게 된다(`4-0-backend-prep.md` §3).
   - Expiration(만료): 사용자에게 묻는다. 만료를 두면 날짜를 마무리 보고에 적는다 — 4단계 준비에서 비밀값 장부(만료일 기록)로 옮긴다.
   - Select scopes: `repo`, `workflow`, `read:org`. 고른 표시가 화면에 다 뜬 것을 확인한 뒤 만든다.
   - classic으로 만든다 — gh 도움말이 세분화 토큰(fine-grained)은 자원 범위 때문에 헷갈리는 동작을 낼 수 있다고 적고 있다.
3. 비밀값 절차 넷(`4-0-backend-prep.md` §3): 화면에서 읽어 **세션 폴더의 임시 파일로만** 저장(대화에 값 출력 금지 — 읽는 방법은 `docs/account-check.md` Aside 함정) → 그 값으로 `gh api user`를 한 번 불러 유효한지 확인 → 장부의 `GH_TOKEN=` 줄로 설치(1순위 6번과 같은 방식, 다른 줄 보존) → 임시 파일 삭제.
4. **값을 못 읽었으면 그 토큰을 살려 두지 않는다** — 같은 화면에서 즉시 「Delete」로 폐기한 뒤 다시 발급한다(원칙 ⑤). 발급이 2번 실패하면 멈추고 보고한다.

#### 3순위 [사람] 직접 발급해 파일에 붙여넣기

1. [AI] 장부 파일에 빈 `GH_TOKEN=` 줄을 준비한다(다른 줄은 그대로).
   ```bash
   o=$(sed -n 's/^owner=//p' .claude/owner); f="$HOME/.config/harness/$o.env"
   { grep -v '^GH_TOKEN=' "$f" 2>/dev/null; echo 'GH_TOKEN='; } > "$f.tmp" && chmod 600 "$f.tmp" && mv "$f.tmp" "$f"
   ```
2. [사람] 순서대로 안내한다 (한 번에 한 화면씩):
   1. 브라우저에서 `https://github.com/settings/tokens/new` 를 연다(로그인 화면이 나오면 로그인).
   2. 「Note」 입력란에 `gh-cli-<기기 이름>`.
   3. 「Expiration」에서 기간을 고른다.
   4. 「Select scopes」에서 `repo`, `workflow`, `read:org` 세 항목을 체크.
   5. 맨 아래 「Generate token」.
   6. 초록 상자에 뜬 `ghp_`로 시작하는 값을 복사 — 이 화면을 벗어나면 다시 보여주지 않습니다.
3. [AI] 편집기로 장부 파일을 열어 준다 — 맥 `open -e "$HOME/.config/harness/<소유>.env"`, 윈도우 `notepad "$HOME/.config/harness/<소유>.env"`. 이 파일은 프로젝트 밖(사용자 폴더 안)에 있고, 소유가 같은 프로젝트들이 나눠 쓴다고 한 줄 알린다.
4. [사람] `GH_TOKEN=` 바로 뒤에 붙여넣고 저장 → "됐어". **채팅창에는 붙여넣지 마세요 — 대화 기록에 남습니다.**
5. [AI] 확인 명령으로 검증한다. 실패하면 앞뒤 공백·따옴표가 끼지 않았는지 한 번만 봐 달라고 하고, 그래도 안 되면 그 토큰을 지우고 다시 발급하게 한다.

### ⑥ 계정 확인

[AI] 토큰이 답하는 계정을 대상 폴더의 `AGENTS.md` 「소유와 계정」 표의 GitHub 행과 대조한다.

```bash
.claude/scripts/with-owner.sh gh api user --jq .login
```

- **같다** → 장부에 `GH_LOGIN=<계정>` 줄이 없으면 넣는다(「장부에 키 한 줄 쓰기」 모양에서 `GH_TOKEN`을 `GH_LOGIN`으로, 값은 계정 이름). 그다음으로.
- **표가 비어 있거나 `(확인 필요)`** → "GitHub 계정을 <계정>으로 표에 적겠습니다. 맞습니까?"로 확인받은 뒤 채운다. 이메일은 `.claude/scripts/with-owner.sh gh api user --jq .email`로 읽는다(비어 있으면 `.claude/scripts/with-owner.sh gh api user/emails --jq '.[] | select(.primary) | .email'`). 그래도 비면 사용자에게 한 번 묻고(예: "GitHub에 쓰는 이메일이 무엇입니까? 없으면 『없음』이라고 답해 주세요."), 답이 없으면 `(확인 필요 — GitHub 계정에 공개 이메일 없음)`으로 두고 진행한다 — 이 칸은 뒤 단계가 멈출 조건이 아니다.
- **다르다** → 멈추고 사용자에게 알린다. 저장소를 만들지 않는다(원칙 ①). 토큰이 다른 계정 것이면 ⑤로 표의 계정 토큰을 새로 받고, 표가 틀렸으면 사용자가 표를 고친다.

### ⑦ push 인증 방식 — HTTPS + 토큰

SSH 대신 HTTPS + 토큰으로 통일한다. 설정은 **이 저장소의 로컬 git 설정에만** 한다. **⑦은 ⑧·⑨와 한 호출에 묶지 않고 혼자 먼저 실행한다** — 묶은 호출을 훅이 막으면 ⑦까지 실행되지 않고, 그 상태로 push하면 git이 이 컴퓨터의 전역 도우미(다른 계정)로 인증해 비공개 저장소가 「없음」으로 보인다.

**확인** — 아래 출력이 정확히 두 줄(빈 줄, 그리고 아래 설정의 `!f() { … }; f` 함수 한 줄)이면 설정은 건너뛰고 바로 「설정 확인」으로 간다.

```bash
git config --local --get-all credential.helper
```

**설정**:

```bash
git config --local --unset-all credential.helper 2>/dev/null
git config --local credential.helper ''
git config --local --add credential.helper '!f() { "$(git rev-parse --show-toplevel)/.claude/scripts/with-owner.sh" --git-credential; }; f'
```

- 빈 값 줄은 「위에서 물려받은 도우미 목록을 여기서 비운다」는 표시다 — 전역에 걸린 맥 키체인·윈도우 자격 증명 관리자가 저장해 둔 다른 계정 비밀번호를 먼저 내밀지 못하게 한다.
- 세 번째 줄은 git이 GitHub 비밀번호를 물을 때마다 실행기를 불러, 이 프로젝트 소유의 장부에서 `GH_TOKEN`을 git에게만 건네는 도우미다(사용자명은 `x-access-token`). 장부의 토큰을 갈아 끼우면 다음 push부터 바로 새 토큰을 쓴다. 실행기는 출력이 터미널이면 값을 내지 않는다.
- 그래서 git 명령에는 실행기가 필요 없다. gh 명령만 위 「계정 장부와 실행기」대로 앞에 붙인다.
- **원격 주소가 ssh 형식**(`git@github.com:`·`ssh://`)인 옛 프로젝트면, https로 바꿀지 사용자에게 한 번 묻는다. 바꾸면 `git remote set-url origin https://github.com/<주인>/<저장소>.git`. 안 바꾸면 SSH 확인(`docs/account-check.md` 「GitHub SSH 키」)을 그대로 따른다.

**설정 확인** — 도우미가 실제로 토큰을 건네는지 본다. 비밀번호 줄은 값을 가리고 있는지만 찍는다.

```bash
printf 'protocol=https\nhost=github.com\n\n' | GIT_TERMINAL_PROMPT=0 git credential fill | sed -E 's/^password=.+/password=(있음)/'
```

`username=x-access-token`과 `password=(있음)`이 나와야 ⑧로 간다. 안 나오면 ⑤(장부에 토큰이 있는지 — `with-owner.sh --check`)와 위 설정을 다시 본다. 같은 실패가 2번이면 멈추고 보고한다.

### ⑧ 원격 저장소

**확인** — `git remote get-url origin`이 성공하면 만들지 않는다. 주소가 표 소유자의 저장소를 가리키는지만 보고, 다르면 멈춘다.

없으면:

1. 저장소 이름은 대상 폴더 이름이 기본(`basename <대상 절대 경로>`), 주인은 표의 GitHub 계정(회사 조직이 주인이면 그 조직), **비공개가 기본**이다 — 공개는 사용자가 공개로 하자고 말했을 때만.
2. "GitHub에 `<주인>/<이름>` 비공개 저장소를 만들겠습니다" 하고 한 번 보여준다. 이름을 바꾸자고 하면 따른다.
3. [AI] 만들기 직전에 ⑥ 대조를 같은 걸음에서 한 번 더 하고 만든다.
   ```bash
   .claude/scripts/with-owner.sh gh repo create <주인>/<이름> --private --source=. --remote=origin
   ```
   그다음 호출에서 따로 확인한다.
   ```bash
   git remote get-url origin   # https://github.com/... 이어야 한다
   ```
   주소가 ssh 형식으로 붙었으면(gh 전역 설정의 영향) `git remote set-url origin https://github.com/<주인>/<이름>.git`로 바꾼다.
4. 같은 이름 저장소가 이미 있다고 실패하면 다시 시도하지 않는다 — 그 저장소에 이을지, 다른 이름으로 만들지 사용자에게 묻는다.
5. `--push`는 붙이지 않는다 — push는 ⑨에서 `no-main-push` 훅이 검사하는 `git push`로, 따로 한 호출에서 한다.

### ⑨ 첫 push

**확인** — 올릴 게 없거나 이미 올라가 있으면 건너뛴다.

```bash
git rev-parse --verify -q main                    # 비면 로컬 main에 커밋이 없다 → 건너뜀
git ls-remote --heads origin main                 # 원격 main의 sha
```

원격 main sha가 로컬 main과 같으면 건너뛴다.

**이 push는 하네스 첫 적용의 부트스트랩 예외다** — "main에 직접 push하지 않는다"의 유일한 예외로, 프로젝트 `AGENTS.md` 브랜치 절에 적혀 있다. 예외가 되는 건 **원격 main이 없거나, GitHub에서 저장소를 만들 때 생긴 첫 커밋(README·.gitignore·LICENSE)뿐일 때**만이다. 원격 main에 이미 이 프로젝트의 작업 이력이 있으면 예외가 아니다 — 멈추고 브랜치 흐름(`/new-task` → `/done-task`)으로 안내한다.

- **원격 main 없음** →
  ```bash
  git push -u origin main
  ```
- **원격에 GitHub이 만든 첫 커밋이 있음** → 먼저 그 위로 올린 뒤 push한다. 충돌이 나면 `git rebase --abort`로 되돌리고 멈춰 보고한다. 강제 push(force push)는 하지 않는다.
  ```bash
  git pull --rebase origin main
  git push -u origin main
  ```

**`no-main-push` 훅** — 훅은 원격에 main이 아직 없을 때만 이 첫 push를 허용한다(강제 push는 제외). project-init 옆 폴더 경로에서는 하네스 저장소 세션의 같은 훅이 `cd <대상> && git push -u origin main`을 대상 폴더 기준으로 검사한다 — `cd` 없이 부르면 하네스 저장소의 원격 main을 보고 막는다. 예외 경로 직후 같은 세션에서는 훅이 잡혀 있을 수도, 아닐 수도 있다. 훅이 막으면 메시지로 이유를 가른다.

- **「원격 main 조회 실패 — 저장소를 찾지 못했습니다」** → main push 금지가 아니라 키 문제일 수 있다. `.claude/scripts/with-owner.sh --check`와 ⑦ 「설정 확인」을 다시 보고, 고친 뒤 같은 push를 한 번 더 한다.
- **「main branch 직접 push 금지」** → 원격 main이 이미 있다. **부트스트랩으로 밀어붙이지 않는다** — 우회하지 말고 브랜치 흐름(`/new-task` → `/done-task`)으로 간다. 다른 명령 형태(`gh repo create --push` 등)로 피해 가지 않는다.

push가 `refusing to allow an OAuth App to create or update workflow` 류로 거부되면 토큰에 `workflow` 스코프가 없는 것이다 — 같은 push를 되풀이하지 말고 ⑤로 돌아가 스코프를 갖춘 토큰으로 바꾼다.

## 마무리 보고

보고·안내는 ~입니다 체로 쓴다. 사용자에게 알린다:

- **단계별 결과** — ①~⑨마다 「했음 / 이미 돼 있어 건너뜀 / 사람이 함」. 토큰은 몇 순위 길로 받았는지(같은 소유 장부에 이미 있어 다시 받지 않았으면 그렇게), 만료일이 있으면 그 날짜. 장부 파일 자리(`~/.config/harness/<소유>.env`)도 알린다 — 값은 알리지 않는다.
- **원격 주소** — `https://github.com/<주인>/<이름>` (비공개/공개).
- **남길 경고** — 전역 활성 계정이 바뀌었으면 그 사실, 표와 다른 점이 있었으면 그 내용.
- **project-init에서 불렸으면** 이 보고를 project-init 마무리 안내와 합쳐 한 번에 한다. 마지막 말(새 세션 열기, 또는 예외 경로의 앱 재시작 한 번)은 project-init 10단계가 정한다 — 여기서 따로 붙이지 않는다.

## 안 하는 것 (의도적)

- ❌ GitHub 자동 가입·로그인 반복 — 가입은 늘 사람, 로그인 실패는 1회면 멈춘다 (원칙 ⑥)
- ❌ 토큰 값을 대화·화면에 출력 — 셸 안에서 장부 파일로만 보낸다
- ❌ 프로젝트 안에 키 파일 만들기 — 키는 장부(`~/.config/harness/`)에만 둔다
- ❌ 전역 설정 변경 — `git config --global`, `gh auth switch`, 전역 `gh auth setup-git`
- ❌ 공개 저장소 기본 생성 — 사용자가 말했을 때만 공개
- ❌ 강제 push, 훅 우회 — 막히면 브랜치 흐름으로
- ❌ 부트스트랩이 아닌 main push — 원격 main에 작업 이력이 있으면 브랜치 흐름으로
