# `hermes` CLI — 명령 스펙

> 상태: **개정 3판** · 상위 문서: [launchpad-design.md](./launchpad-design.md) · [session-topology.md](./session-topology.md)
>
> **개정 이력**
> - **3판 (2026-07-29)**: 토폴로지 B안 확정에 따라 개정. 프로필을 **게이트웨이 프로세스 단위**로 재정의(§2). 포트 관련 명령·검사 전면 삭제. `start`/`stop` 의미 재정의. `bateam` 프로필 도입.
> - 2판: 프로필 계층 제거, 평면 에이전트.
> - 1판: 프로필(역할 그룹) + 에이전트.

---

## 1. 설계 원칙

### 1.1 CLI는 설정파일의 대체재가 아니라 편집기다

`config/` 아래의 YAML이 **선언적 원본(source of truth)** 이다. CLI는 그 파일을 읽고 쓰는 도구일 뿐이다.

```
hermes agent create lucas    ──▶  config/profiles/bateam/agents/lucas.yaml  ◀── 사람이 직접 편집
  --profile bateam                              │
                                hermes apply ───┘
                                                ▼
                                     ~/Library/LaunchAgents/com.hermes.profile.bateam.plist
                                     실행 중인 게이트웨이 프로세스
```

- **git으로 이력이 남는다.** "Grace 모델을 언제 왜 바꿨나"가 diff로 추적된다.
- **재현이 된다.** 새 맥에서 클론하고 `hermes apply --profile bateam` 한 번이면 같은 구성이 선다.
- **손편집이 막히지 않는다.** 10개 역할의 temperature 일괄 조정은 에디터가 CLI보다 빠르다.

### 1.2 `apply`는 멱등하다

현재 설정과 실제 상태의 차이를 계산해 수렴시킨다. 몇 번을 실행해도 결과가 같다.

```console
$ hermes apply --profile bateam
  프로필 bateam

  + plist    com.hermes.profile.bateam    생성
  ~ agent    grace                        model: gpt-terra → gpt-terra-2
  + agent    oscar                        추가
    agent    lucas                        변경 없음
  ~ slack                                 커맨드 2개 추가 필요 (수동 등록)

  게이트웨이 재시작이 필요합니다 (진행 중 스레드 1건 유실).
  적용할까요? [y/N]
```

### 1.3 `default` 프로필은 건드리지 않는다

모든 명령의 `--profile` 기본값은 **명시적으로 지정된 현재 프로필**이다. `bateam` 작업 중 `default`의 설정·프로세스·자격증명은 어떤 경로로도 변경되지 않는다.

`config/defaults.yaml`(전역 기본값) 역시 수정하지 않는다. 프로필이 필요한 값은 `profile.yaml`의 `overrides`로 덮는다.

---

## 2. 프로필 = 게이트웨이 프로세스 단위

### 2.1 정의

**프로필 하나 = 게이트웨이 프로세스 하나 = LaunchAgent 하나 = Slack 앱 하나 + 페르소나 N개.**

```
default   ← 기존. 손대지 않음
bateam    ← 신규. 10개 페르소나 (Lucas … Oscar)
```

```
com.hermes.profile.default    (프로세스 1)
com.hermes.profile.bateam     (프로세스 1)   ← 페르소나 10개가 이 안에 산다
```

### 2.2 2판에서 프로필을 없앴다가 되살린 이유

2판에서 프로필을 제거한 근거는 *"프로필은 배타적 전환의 어휘인데 10명이 동시 상주한다"* 였다. 그때의 프로필은 **역할별**이었고, 그 정의에서는 타당한 지적이었다.

3판의 프로필은 **게이트웨이별**이다. 역할이 아니라 프로세스·Slack 앱·자격증명 경계에 대응하므로 어휘 충돌이 없다. `bateam`과 `default`는 실제로 별개 프로세스로 공존한다.

### 2.3 프로필이 격리하는 것

| 항목 | 격리 |
| --- | --- |
| 프로세스 | LaunchAgent 별도 · 한쪽이 죽어도 다른 쪽 무관 |
| Slack 앱 | 봇 토큰 · 앱 토큰 · 워크스페이스 별도 |
| 자격증명 | Keychain 항목 `hermes/<profile>/…` 로 분리 |
| 대화 히스토리 | `~/.hermes/profiles/<profile>/state/` |
| 로그 | `~/.hermes/profiles/<profile>/log/` |

**격리하지 않는 것**: `config/providers.yaml`(공급사 정의)과 `config/defaults.yaml`(전역 기본값)은 프로필이 공유한다. 공급사 API 키를 프로필마다 나누고 싶으면 `providers.yaml`에 항목을 따로 만든다.

---

## 3. `update` 네이밍 — 짚고 갈 부분

`hermes update`는 두 가지로 읽힌다.

| 해석 | 다른 도구의 관례 |
| --- | --- |
| **도구 자체를 최신 버전으로** | `brew update`, `apt update`, `rustup update` |
| **설정 변경을 실제 상태에 반영** | 이 의미로 `update`를 쓰는 CLI는 드물다 |

패키지 매니저 관례가 강해 `hermes update`는 대부분 "CLI를 업데이트한다"로 읽힌다. 설정 반영에는 **`hermes apply`**, 자체 갱신은 **`hermes self-update`** 를 권한다.

취향 영역이므로 `update`를 `apply` 별칭으로 두는 절충도 가능하다. **결정 필요.**

---

## 4. 명령

### 4.1 프로필

| 명령 | 설명 |
| --- | --- |
| `profile create <name> [--from-roles <dir>]` | 프로필 생성 (게이트웨이 1개) |
| `profile list` | 목록 · 페르소나 수 · 실행 상태 |
| `profile show <name>` | 상세 |
| `profile use <name>` | 이후 명령의 기본 대상 지정 |
| `profile rm <name> [--purge]` | 삭제 (`--purge`: plist·상태·로그까지) |

```console
$ hermes profile create bateam --from-roles ./roles
  프로필 bateam 을 생성합니다.

  roles/ 에서 10개 페르소나를 찾았습니다.

  id      역할              성향                     provider?    model?
  lucas   Tech Lead         균형형 · 조율자           [anthropic]  [claude-opus-5]
  grace   BA                보수적 · 정책 중심         [terra]      [gpt-terra]
  brian   Backend           진보적 · 기술 혁신         [anthropic]  [claude-opus-5]
  emma    Frontend / UX     창의적 · 경험 중심         [anthropic]  [claude-sonnet-5]
  mia     QA                보수적 · 검증 중심         [anthropic]  [claude-sonnet-5]
  leo     DevOps            현실주의 · 자동화 중심      [terra]      [gpt-terra]
  david   Data              객관적 · 데이터 중심        [terra]      [gpt-terra]
  aiden   AI                실험적 · 미래 지향         [anthropic]  [claude-opus-5]
  jack    Security          매우 보수적 · 위험 회피     [anthropic]  [claude-sonnet-5]
  oscar   Critic            회의적 · 반증 중심         [anthropic]  [claude-opus-5]

  temperature 는 성향에 따라 자동 제안됩니다 (검증 중심 0.1 ~ 창의적 0.8).

  생성:
    config/profiles/bateam/profile.yaml
    config/profiles/bateam/agents/*.yaml   (10개)

  default 프로필과 config/defaults.yaml 은 변경하지 않았습니다.
  `hermes apply --profile bateam` 으로 게이트웨이를 기동하세요.
```

`--from-roles`가 핵심이다. `roles/*.md`의 프론트매터(`name`·`role`·`disposition`)를 읽어 초기 등록을 자동화한다. `--yes`로 대화형을 건너뛴다.

```console
$ hermes profile list
  NAME      페르소나   상태       Slack        가동
  default   3          running    연결됨       12d 3h
  bateam    10         running    연결됨       2d 4h
```

### 4.2 페르소나 (에이전트)

`--profile` 생략 시 `profile use`로 지정한 현재 프로필을 대상으로 한다.

| 명령 | 설명 |
| --- | --- |
| `agent create <id> --persona <path> --provider <p> --model <m>` | 등록 |
| `agent import <dir>` | `roles/*.md` 일괄 등록 (멱등 — 없는 것만 추가) |
| `agent list [--tag <t>]` | 목록 |
| `agent show <id>` | 상세 |
| `agent set <id> --model <m> --temperature <t>` | 설정 변경 |
| `agent clone <id> <new-id> --model <m>` | 복제 (A/B 비교) |
| `agent enable <id>` / `agent disable <id>` | **활성 플래그** (§4.4) |
| `agent rm <id> [--purge]` | 제거 |

```bash
hermes agent create lucas --profile bateam \
  --persona roles/lucas-tech-lead.md \
  --provider anthropic --model claude-opus-5 --temperature 0.3 \
  --slack-command /lucas --slack-icon ":man_office_worker:" \
  --tags core,lead
```

**포트 옵션이 없다.** 프로세스 간 통신이 없으므로 배정할 것이 없다 (2판 대비 삭제).

A/B 비교는 `clone`으로 한다. 같은 프로필 안에 공존시켜도 되고, 프로필째 복제해도 된다.

```bash
hermes agent clone lucas lucas-v2 --model gpt-terra --slack-command /lucas2   # 같은 게이트웨이 안
hermes profile create bateam-exp --from bateam --provider-map anthropic=terra  # 게이트웨이째 분리
```

### 4.3 공급사

| 명령 | 설명 |
| --- | --- |
| `provider add <id> --kind <k> --base-url <u> --key-ref <r>` | 등록 (전역) |
| `provider list` | 목록 |
| `provider test <id>` | 실제 호출로 연결 확인 |

```bash
hermes provider add terra \
  --kind openai-compatible \
  --base-url https://llm.internal.example.com/v1 \
  --key-ref keychain:hermes/terra

hermes provider test terra
#  ✓ 연결 성공 · 모델 3개 확인 (gpt-terra, gpt-terra-mini, …) · 응답 412ms
```

**`provider test`를 별도 명령으로 둔 이유** — 게이트웨이가 안 뜰 때 원인이 자격증명인지, 네트워크인지, 페르소나 설정인지 즉시 갈라야 한다. 없으면 로그를 뒤지게 된다.

> 공급사는 프로필 간 공유된다(§2.3). 프로필별로 키를 나누려면 `terra-bateam` 처럼 항목을 따로 만든다.

### 4.4 수명주기 — **의미가 두 층으로 나뉜다**

프로세스가 프로필당 하나이므로, "Grace를 중지"와 "게이트웨이를 중지"는 다른 층위다.

| 층위 | 명령 | 동작 |
| --- | --- | --- |
| **프로세스** | `start` / `stop` / `restart --profile bateam` | 게이트웨이 프로세스 자체 |
| **페르소나** | `agent enable` / `agent disable <id>` | 활성 플래그 (프로세스 무관 · 즉시 반영) |

```bash
hermes stop --profile bateam            # 게이트웨이 종료 — 10명 전부 응답 불가
hermes agent disable grace              # Grace만 비활성 — 나머지 9명 정상
```

`agent disable grace` 후 `/grace`를 호출하면 **"Grace는 현재 비활성입니다"** 라고 안내된다. 1판(프로세스 분리)에서는 무응답이라 의도된 중지인지 장애인지 구분되지 않았다. 이쪽이 낫다.

| 명령 | 설명 |
| --- | --- |
| `apply [--profile <p>] [--dry-run]` | 설정 → 실제 상태 수렴 |
| `start` / `stop` / `restart [--profile <p>]` | 게이트웨이 프로세스 제어 |
| `status [--profile <p>]` | 상태 |
| `logs [--profile <p>] [-f] [-n 100]` | 로그 |

```console
$ hermes status --profile bateam
  프로필 bateam        running   PID 4471   가동 2d 4h   메모리 118MB
  Slack                연결됨 (Socket Mode)   앱: BA Team
  동시 처리             2 / 6

  ID       역할             공급사      모델              활성   태그
  lucas    Tech Lead        anthropic   claude-opus-5     ✓      core,lead
  grace    BA               terra       gpt-terra         ✓      core,policy
  brian    Backend          anthropic   claude-opus-5     ✓      core
  emma     Frontend/UX      anthropic   claude-sonnet-5   ✓      core,ux
  mia      QA               anthropic   claude-sonnet-5   ✓      core,review
  leo      DevOps           terra       gpt-terra         ✓      core
  david    Data             terra       gpt-terra         ✗      ext
  aiden    AI               anthropic   claude-opus-5     ✗      ext
  jack     Security         anthropic   claude-sonnet-5   ✓      ext,review
  oscar    Critic           anthropic   claude-opus-5     ✓      ext,review
```

**메모리가 한 줄로 끝난다.** 2판(프로세스 10개)에서는 세션별로 나열해야 했다.

### 4.5 Slack

| 명령 | 설명 |
| --- | --- |
| `slack link [--profile <p>]` | 앱 토큰 등록 (프로필별 Keychain 저장) |
| `slack sync [--profile <p>] [--print-all]` | 슬래시 커맨드 등록 상태 점검 |
| `slack test <id>` | 지정 채널에 페르소나 테스트 게시 |

Slack 슬래시 커맨드는 **API로 자동 생성할 수 없다.** 앱 관리 화면에서 수동 등록해야 한다. `slack sync`는 등록을 대행하는 게 아니라 **무엇을 등록해야 하는지 알려주는** 역할이다.

```console
$ hermes slack sync --profile bateam
  앱: BA Team (bateam 전용)

  ✓ /lucas   등록됨
  ✓ /grace   등록됨
  ✗ /brian   누락
  ✗ /emma    누락
  … 6개 더

  `--print-all` 로 전체 목록을 뽑아 앱 관리 화면에 옮겨 적으세요.
  Request URL 은 불필요합니다 (Socket Mode).
```

### 4.6 진단 · 직접 대화

| 명령 | 설명 |
| --- | --- |
| `doctor [--profile <p>]` | 설정 · 자격증명 · 페르소나 파일 · launchd 점검 |
| `chat <id> [--profile <p>]` | **터미널에서 직접 대화** (Slack·게이트웨이 없이) |

```console
$ hermes doctor --profile bateam
  ✓ config/profiles/bateam/profile.yaml   유효
  ✓ config/profiles/bateam/agents/        10개 유효
  ✓ 페르소나 파일                          roles/ 10개 모두 존재
  ✓ Keychain                               anthropic · terra · bateam/slack-bot · bateam/slack-app
  ✓ 공급사 연결                            anthropic 231ms · terra 412ms
  ⚠ Slack 커맨드                           6개 미등록 — `hermes slack sync`
  ⚠ launchd                                com.hermes.profile.bateam 미등록 — `hermes apply`

  default 프로필은 점검 대상에서 제외했습니다 (--profile default 로 별도 점검).
```

**포트 충돌 검사가 사라졌다** (2판 대비). 리스닝 포트를 쓰지 않으므로 점검 항목 자체가 없다.

`hermes chat lucas`가 개발 단계에서 가장 많이 쓰인다. 게이트웨이를 띄우지 않고 같은 코드를 직접 호출하므로, 설계문서 §10의 1~2단계가 이 명령 하나로 끝난다.

---

## 5. 파일 배치

```
hermes/                                    # git 저장소 (원본)
├── config/
│   ├── defaults.yaml                      # 전역 — 수정하지 않음
│   ├── providers.yaml                     # 공급사 (프로필 공유)
│   └── profiles/
│       ├── default/                       # ← 손대지 않음
│       └── bateam/
│           ├── profile.yaml               # 게이트웨이 설정
│           └── agents/
│               ├── lucas.yaml             # ★ 페르소나 1명 = 파일 1개
│               └── … (10개)
└── roles/*.md                             # 페르소나 문서

~/.hermes/                                 # 런타임 상태 (git 아님)
├── state.json                             # 프로필별 마지막 apply 해시 · 현재 프로필
└── profiles/
    ├── default/                           # 손대지 않음
    └── bateam/
        ├── gateway.pid
        ├── log/gateway.log
        └── state/<personaId>/*.jsonl      # 대화 히스토리

~/Library/LaunchAgents/
├── com.hermes.profile.default.plist       # 손대지 않음
└── com.hermes.profile.bateam.plist        # apply 가 생성 · 직접 편집 금지
```

**페르소나 1명 = 파일 1개인 이유** — 10명을 한 YAML에 몰면 서로 다른 역할을 수정할 때 diff가 충돌한다. `agent rm`이 파일 삭제로 끝난다.

**경계는 "사람이 정하는 것"과 "도구가 만드는 것"으로 나뉜다.** `config/`는 git에, `~/.hermes/`와 plist는 git 밖에 둔다. plist는 `apply`가 덮어쓰므로 직접 편집하면 안 된다.

**2판에서 사라진 것** — `state.json`의 포트 배정 항목. 프로세스 간 통신이 없다.

---

## 6. 전형적인 흐름

```bash
# ── 최초 구성 ──────────────────────────────────
hermes provider add anthropic --kind anthropic --key-ref keychain:hermes/anthropic
hermes provider add terra --kind openai-compatible \
  --base-url $TERRA_URL --key-ref keychain:hermes/terra
hermes provider test terra

# ── bateam 프로필 생성 (게이트웨이 1개 + 10 페르소나) ──
hermes profile create bateam --from-roles ./roles
hermes profile use bateam

# ── Slack 없이 먼저 검증 ────────────────────────
hermes chat lucas
hermes chat grace

# ── 게이트웨이 기동 ─────────────────────────────
hermes apply --dry-run          # 무엇이 바뀌는지 먼저 확인
hermes apply                    # plist 생성 + bootstrap
hermes status

# ── Slack 연결 ─────────────────────────────────
hermes slack link
hermes slack sync --print-all   # 커맨드 10개 목록 → 앱 관리 화면에 등록
hermes slack test lucas --channel '#bateam'

# ── 이후 운영 ──────────────────────────────────
hermes agent set grace --model gpt-terra-2
hermes apply                            # 게이트웨이 재시작
hermes agent disable david              # 재시작 없이 즉시 반영
hermes agent clone lucas lucas-v2 --model gpt-terra --slack-command /lucas2
hermes logs -f

# default 프로필은 위 어느 명령에도 영향받지 않는다.
```

---

## 7. 구현 메모

- **`apply`의 차이 계산**은 `config/profiles/<p>/` 하위 파일별 해시와 `~/.hermes/state.json`의 마지막 적용 해시를 비교한다.
- **재시작이 필요한 변경과 아닌 변경을 구분한다.** 이게 B안의 실익이다.

  | 변경 | 재시작 |
  | --- | --- |
  | `agents/*.yaml` (모델·temperature·enabled) | **불필요** — 파일 감시로 핫 리로드 |
  | `roles/*.md` (페르소나 문서) | **불필요** — mtime 감지 |
  | `profile.yaml` (Slack 토큰·concurrency) | 필요 |
  | `providers.yaml` | 필요 |
  | `defaults.yaml` | 필요 (**모든 프로필**) |

  `apply --dry-run`이 재시작 여부와 유실될 진행 중 스레드 수를 미리 알려야 한다.
- **`defaults.yaml` 수정은 전 프로필 재시작을 유발한다.** `bateam` 작업 중 이 파일을 건드리지 않기로 한 실무적 이유이기도 하다.
- **핫 리로드가 IPC를 대신한다.** 1판에서 Gateway가 세션에 HTTP로 지시하던 것을, 이제 프로세스가 자기 설정 파일을 감시해 스스로 반영한다. 제어 채널이 필요 없다.
- **`hermes chat`은 게이트웨이에 붙지 않는다.** 같은 핸들러를 in-process로 호출한다. 게이트웨이가 안 떠 있어도 동작하는 것이 이 명령의 요점이다.
- **CLI 배포**는 1차에 `pnpm link` 또는 `~/.local/bin` 심볼릭 링크로 충분하다. Homebrew tap은 안정화 후 검토.

---

## 8. 결정 필요

1. **`update` vs `apply`** — §3. `update`를 `apply` 별칭으로 둘 것인가?
2. **슬래시 커맨드 10개 수동 등록** — §4.5. 부담이면 `/bateam lucas ...` 통합 커맨드 1개로 대체 가능. 등록은 1회로 끝나지만 매번 타이핑이 길어진다.
3. **`default` 프로필의 기존 Keychain 항목명** — `bateam`이 `hermes/bateam/*` 를 쓰므로 충돌 가능성은 낮으나, 기존 항목이 `hermes/slack-bot` 처럼 프로필 없는 이름이면 규칙을 통일할지 결정 필요. (기존 것을 바꾸지 않기로 했으므로 신규만 프로필 네임스페이스를 쓰는 비대칭을 허용할 수도 있다.)

---

## 부록 — 2판 → 3판 삭제 목록

토폴로지 변경으로 사라진 항목이다. 구현 시 참고.

| 항목 | 사유 |
| --- | --- |
| `--port` 옵션 | 프로세스 간 통신 없음 |
| `state.json` 포트 배정 | 동일 |
| `doctor` 포트 충돌 검사 | 동일 |
| 세션별 `start`/`stop` | `agent enable`/`disable` 로 대체 |
| 세션별 로그 파일 10개 | 게이트웨이 로그 1개 |
| `--tag` 로 일부만 상주 | 유휴 비용이 없어 불필요. 태그는 **호출 대상 묶음** 의미만 남음 |
| Gateway↔세션 공유 시크릿 | 프로세스 경계 없음 |
