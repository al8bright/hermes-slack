# Hermes Launchpad — 설계 문서

> 상태: **개정 2판** · 대상 플랫폼: macOS (launchd) · 최종 수정: 2026-07-29
>
> 관련 문서: [`session-topology.md`](./session-topology.md) — 토폴로지 결정 근거 · [`cli-spec.md`](./cli-spec.md) — CLI 명령 스펙
>
> **개정 이력**
> - **2판 (2026-07-29)**: 토폴로지를 **역할별 프로세스 분리 → 프로필당 단일 프로세스 + 페르소나**로 변경. 프로필 `bateam` 도입. IPC·포트 계층 삭제. 근거는 [session-topology.md](./session-topology.md).
> - 1판: 역할별 프로세스 10개 + Gateway 1개.

---

## 1. 목표

[`roles/`](../roles/)에 정의된 10인 팀을 **하나의 게이트웨이 프로세스 안에 페르소나로 상주**시키고, 역할마다 **서로 다른 공급사/모델**을 부여하며, **Slack**을 통해 사람이 특정 역할을 지목해 대화할 수 있게 한다.

"런치패드"는 이 프로필을 **생성 · 등록 · 기동 · 감시**하는 계층을 가리킨다.

### 1차 범위

- 프로필 **`bateam`** 을 새로 생성한다. 게이트웨이 프로세스 1개 = launchd LaunchAgent 1개.
- `bateam` 안에 **10개 페르소나** (Lucas · Grace · Brian · Emma · Mia · Leo · David · Aiden · Jack · Oscar) 를 등록한다.
- 우선 검증 대상은 **Lucas · Grace** 2인. 나머지 8인은 등록만 하고 필요 시 활성화한다.
- **`default` 프로필은 건드리지 않는다.** `bateam`은 완전히 독립된 게이트웨이·자격증명·상태 저장소를 갖는다.

### 비범위 (1차 제외)

- 역할 간 자동 토론(페르소나 상호 호출) — 3단계로 미룸
- 코드 실행 권한, 저장소 쓰기 권한
- 웹 UI

---

## 2. 용어

| 용어 | 의미 |
| --- | --- |
| **Profile** | **게이트웨이 프로세스 1개 단위.** 자체 Slack 앱 · 자격증명 · 페르소나 집합 · 상태 저장소를 가진다. 예: `bateam`, `default` |
| **Persona** (= Agent) | 프로필 안의 역할 하나 (Lucas, Grace …). 프로세스가 아니라 **설정 + 페르소나 문서** |
| **Gateway** | 프로필의 실체. Slack 이벤트를 받아 페르소나를 골라 응답하는 프로세스 |
| **Provider** | 모델 공급사 어댑터 (Anthropic / OpenAI 호환 / 사내 게이트웨이) |

> **1판과의 차이**: 1판에서 "Session"은 역할별 프로세스를 뜻했다. 2판에서 역할은 프로세스가 아니므로 이 용어를 폐기하고 **Persona**로 대체한다.

---

## 3. 아키텍처

### 3.1 토폴로지

**프로필당 프로세스 1개.** 역할을 프로세스로 쪼개지 않는다.

판단 근거는 [session-topology.md](./session-topology.md)에 상세히 있고, 요지는 하나다 — **역할 세션에 프로세스 경계가 지킬 만한 고유 상태가 없다.** 페르소나는 `roles/*.md`에, 대화 히스토리는 디스크에, 설정은 YAML에 있다. 상주가 절약하는 것은 콜드스타트(200–500ms)뿐인데 LLM 응답이 2–20초이므로 전체의 2% 미만이다.

역할을 프로세스로 나누지 않음으로써 얻는 것:

- 유휴 메모리 **0.8–1.2GB → 80–120MB**
- **IPC·포트 계층 소멸** (1판의 로컬 HTTP, 포트 자동 배정, 공유 시크릿 인증이 전부 불필요)
- 역할 추가 시 **핫 리로드** (프로세스 기동·plist 등록·라우팅 갱신 불필요)
- 3단계 목표인 역할 간 토론이 **함수 호출**로 구현됨

### 3.2 프로필 경계는 왜 남기는가

프로필은 역할 경계가 아니라 **게이트웨이·Slack 앱·자격증명 경계**다. 따라서 프로필이 늘어도 역할 수만큼 프로세스가 늘지 않는다.

| 프로필을 나누는 이유 | 설명 |
| --- | --- |
| Slack 앱 분리 | 프로필마다 다른 워크스페이스·앱 토큰을 물릴 수 있다 |
| 자격증명 분리 | `bateam`이 쓰는 API 키와 `default`가 쓰는 키를 분리 |
| 상태 격리 | 대화 히스토리·로그가 섞이지 않는다 |
| 독립 기동 | `bateam`을 내려도 `default`는 계속 돈다 |
| 실험 격리 | 같은 10인을 다른 모델로 구성한 `bateam-exp`를 나란히 띄울 수 있다 |

### 3.3 구성도

```
  Slack 워크스페이스
        │  Socket Mode
        ▼
┌────────────────────────────────────────────────────┐
│  Gateway :: profile=bateam                         │
│  LaunchAgent  com.hermes.profile.bateam            │
│                                                    │
│  ┌──────────────────────────────────────────────┐  │
│  │ 라우터   /lucas → lucas   /grace → grace ...  │  │
│  └───────────────────┬──────────────────────────┘  │
│                      ▼                             │
│  ┌──────────────────────────────────────────────┐  │
│  │ 페르소나 레지스트리 (10)                       │  │
│  │  lucas  Tech Lead    anthropic  claude-opus-5 │  │
│  │  grace  BA           terra      gpt-terra     │  │
│  │  brian  Backend      anthropic  claude-opus-5 │  │
│  │  emma   Frontend/UX  anthropic  claude-sonnet-5│ │
│  │  mia    QA           anthropic  claude-sonnet-5│ │
│  │  leo    DevOps       terra      gpt-terra     │  │
│  │  david  Data         terra      gpt-terra     │  │
│  │  aiden  AI           anthropic  claude-opus-5 │  │
│  │  jack   Security     anthropic  claude-sonnet-5│ │
│  │  oscar  Critic       anthropic  claude-opus-5 │  │
│  └───────────────────┬──────────────────────────┘  │
│                      ▼                             │
│  ┌──────────────────────────────────────────────┐  │
│  │ Provider 풀   anthropic · terra               │  │
│  └───────────────────┬──────────────────────────┘  │
└──────────────────────┼─────────────────────────────┘
                       ▼
              Anthropic API · 사내 게이트웨이

  ※ 프로세스 경계는 이 상자 하나뿐이다. 포트도 IPC도 없다.
```

`default` 프로필은 별도 LaunchAgent(`com.hermes.profile.default`)로 독립 구동되며 이 구성과 무관하다.

### 3.4 디렉터리 구조

```
hermes/                                    # git 저장소 (원본)
├── roles/                                 # 페르소나 문서 (작성 완료)
│   ├── lucas-tech-lead.md
│   └── … (10개)
├── config/
│   ├── defaults.yaml                      # 전역 공통값 — bateam 작업 중 수정하지 않음
│   ├── providers.yaml                     # 공급사 (키는 참조만)
│   └── profiles/
│       ├── default/                       # ← 기존. 손대지 않음
│       └── bateam/
│           ├── profile.yaml               # 게이트웨이 설정 (Slack · 오버라이드)
│           └── agents/
│               ├── lucas.yaml
│               ├── grace.yaml
│               └── … (10개)
├── src/
│   ├── core/
│   │   ├── provider/                      # 공급사 어댑터
│   │   │   ├── index.ts                   #   createProvider(spec) → Provider
│   │   │   ├── anthropic.ts
│   │   │   ├── openai-compatible.ts
│   │   │   └── types.ts
│   │   ├── persona.ts                     # roles/*.md → 시스템 프롬프트
│   │   ├── registry.ts                    # 페르소나 레지스트리 + 핫 리로드
│   │   ├── memory.ts                      # 대화 히스토리 저장/윈도잉
│   │   └── config.ts                      # 프로필 로드 · 검증
│   ├── gateway/
│   │   ├── main.ts                        # 프로세스 진입점 (Slack Bolt Socket Mode)
│   │   ├── router.ts                      # 커맨드/멘션 → personaId
│   │   ├── handler.ts                     # 요청 처리 (§9)
│   │   └── persona-post.ts                # username·icon 입혀 게시
│   └── cli/                               # hermes CLI
├── launchd/
│   ├── templates/profile.plist.tpl
│   └── (plist 생성은 `hermes apply` 가 담당)
└── docs/
    ├── launchpad-design.md                # 이 문서
    ├── cli-spec.md
    └── session-topology.md

~/.hermes/                                 # 런타임 상태 (git 아님)
├── state.json                             # 프로필별 마지막 apply 해시
└── profiles/
    ├── default/                           # 손대지 않음
    └── bateam/
        ├── gateway.pid
        ├── log/gateway.log
        └── state/<personaId>/*.jsonl      # 대화 히스토리

~/Library/LaunchAgents/
├── com.hermes.profile.default.plist       # 손대지 않음
└── com.hermes.profile.bateam.plist        # apply 가 생성
```

> 맥 기준 저장소 경로는 `~/dev/hermes` 를 가정한다. 다르면 `HERMES_HOME` 만 바꾸면 된다.

**1판에서 사라진 것** — `src/session/`(역할별 프로세스 진입점), 포트 배정, Gateway↔세션 HTTP 클라이언트, 공유 시크릿 인증.

---

## 4. 프로필 구성

### 4.1 `config/profiles/bateam/profile.yaml`

게이트웨이 1개의 설정이다.

```yaml
id: bateam
displayName: BA Team
description: 역할과 성향을 분리한 10인 가상 개발팀

# 이 프로필이 쓰는 Slack 앱 (default 프로필과 별개)
slack:
  mode: socket
  botTokenRef: keychain:hermes/bateam/slack-bot
  appTokenRef: keychain:hermes/bateam/slack-app
  defaultChannel: "#bateam"

# config/defaults.yaml 위에 얹는 프로필 단위 오버라이드.
# defaults.yaml 자체는 수정하지 않는다.
overrides:
  historyWindow: 40
  maxOutputTokens: 4096
  requestTimeoutMs: 120000
  concurrency: 6          # 이 프로필이 동시에 처리할 최대 요청 수
```

**`defaults.yaml`을 건드리지 않는 방식.** 전역 기본값은 그대로 두고, 프로필이 필요한 값만 `overrides`로 덮는다. 병합 순서는 다음과 같다.

```
config/defaults.yaml  →  profile.yaml overrides  →  agents/<id>.yaml
     (전역, 불변)            (프로필 단위)              (페르소나 단위)
```

뒤쪽이 앞쪽을 이긴다. `bateam` 작업이 `default` 프로필의 동작에 영향을 줄 수 없다.

### 4.2 `config/profiles/bateam/agents/lucas.yaml`

페르소나 1명 = 파일 1개.

```yaml
id: lucas
displayName: Lucas
role: Tech Lead
persona: roles/lucas-tech-lead.md
tags: [core, lead]
enabled: true

provider: anthropic
model: claude-opus-5
temperature: 0.3

slack:
  command: /lucas
  username: "Lucas · Tech Lead"
  icon: ":man_office_worker:"
```

**설계 근거**

- **페르소나를 코드가 아니라 `roles/*.md`에서 읽는다.** 문서와 실제 동작이 갈라지지 않는다. 문서를 고치면 mtime 감지로 **재기동 없이** 반영된다.
- **파일을 나눈다.** 10명을 한 YAML에 몰면 서로 다른 역할을 수정할 때 diff가 충돌한다. `agent rm`도 파일 삭제로 끝난다.
- **`enabled` 플래그.** 프로세스가 하나이므로 "Grace를 중지"는 프로세스 종료가 아니라 플래그다. 비활성 페르소나를 호출하면 *"현재 비활성"* 이 안내된다 — 1판에서는 무응답이라 장애와 구분되지 않았다.
- **포트가 없다.** 프로세스 간 통신이 없으므로 배정할 것이 없다.
- **`temperature`를 역할 성향에 맞춘다.** 부록 참조.

---

## 5. 공급사 혼용 — Provider 추상화

역할마다 공급사가 다르므로 게이트웨이 코드가 특정 SDK에 묶이면 안 된다. **단일 프로세스에서 여러 공급사를 동시에 다루므로 1판보다 중요도가 올라간다.**

```ts
// src/core/provider/types.ts
export interface Provider {
  id: string;
  complete(req: CompletionRequest): Promise<CompletionResult>;
}

export interface CompletionRequest {
  system: string;               // 페르소나에서 생성
  messages: Message[];          // { role: 'user'|'assistant', content: string }
  model: string;
  temperature?: number;
  maxOutputTokens?: number;
  signal?: AbortSignal;
}

export interface CompletionResult {
  text: string;
  usage: { inputTokens: number; outputTokens: number };
  stopReason: string;
  raw: unknown;                 // 디버깅용 원본
}
```

| kind | 대상 | 구현 |
| --- | --- | --- |
| `anthropic` | Claude 계열 | `@anthropic-ai/sdk` · `system` 은 최상위 파라미터 |
| `openai-compatible` | gpt-terra · OpenRouter · vLLM · Ollama | `openai` SDK + `baseURL` 교체 · `system` 은 첫 메시지 |

두 스펙의 가장 큰 차이는 **system 프롬프트 위치**와 **토큰 사용량 필드명**이다. 어댑터가 이를 흡수하면 핸들러는 공급사를 몰라도 된다.

Provider 인스턴스는 **프로필당 1개씩 만들어 재사용**한다. 페르소나 10개가 같은 `anthropic` 인스턴스를 공유하므로 커넥션 풀이 효율적으로 쓰인다 — 1판(프로세스 10개)에서는 불가능했던 이점이다.

> **확인 필요**: `gpt-terra`가 OpenAI 호환 스펙인지, 자체 스키마인지에 따라 어댑터가 하나 더 필요할 수 있다. base URL과 샘플 요청/응답이 필요하다.

---

## 6. Slack 연동

### 6.1 결정: 프로필당 앱 1개 + 페르소나 게시

`bateam` 프로필은 **자체 Slack 앱 하나**를 갖는다. 그 앱이 10개 페르소나를 연기한다.

**런타임 구조와 Slack 구조가 일치한다** — 프로세스 하나가 여러 페르소나를 연기하고, 봇 하나가 여러 페르소나로 말한다.

| | A. 역할별 별도 앱 | **B. 프로필당 앱 1개 (채택)** | C. 채널 분리 |
| --- | --- | --- | --- |
| 응답 발신자 분리 | 완전 | **완전** (`username`·`icon` 커스터마이즈) | 봇 1개로 보임 |
| `@Lucas` 유저 멘션 | 가능 | **불가** | 불가 |
| 지목 호출 | 멘션 · DM · 커맨드 | 슬래시 커맨드 · 텍스트 프리픽스 | 채널 자체 |
| 1:1 DM | 역할별 가능 | 단일 DM 창 | 불가 |
| 관리 비용 | 역할 10 × (앱·토큰·승인) | **앱 1개** | 앱 1 + 채널 10 |

**포기하는 것은 `@Lucas` 유저 멘션과 역할별 DM 둘뿐이다.** 이 둘은 봇 유저가 실제로 따로 있어야만 가능하고, 앱 분리 없이는 불가능하다. 10인 워크스페이스 설치·승인 비용이 그보다 크다.

나중에 Lucas·Grace만 멘션이 필요하다고 판명되면 **그 둘만 별도 앱으로 승격**하는 하이브리드가 가능하다. 라우터가 personaId 단위이므로 전환 비용이 낮다.

### 6.2 호출

```
/lucas 이번 스프린트 아키텍처 리뷰 부탁합니다
/grace 반품 정책에서 부분취소 예외가 빠진 것 같은데 확인해줘

# 스레드 안에서는 프리픽스로도 지목
@lucas 위 의견에 대해 어떻게 보세요?
```

**Socket Mode를 쓴다.** 공개 HTTPS 엔드포인트가 필요 없어 맥 로컬에서 바로 돌고, 사내망/방화벽 뒤에서도 동작한다. 슬래시 커맨드는 3초 안에 ack해야 하므로 **즉시 ack → 페르소나 호출 → 완료 시 스레드에 게시**하는 비동기 구조로 만든다.

### 6.3 필요 스코프

| 스코프 | 용도 |
| --- | --- |
| `commands` | 슬래시 커맨드 수신 |
| `chat:write` | 메시지 게시 |
| `chat:write.customize` | **페르소나 이름·아이콘 지정 (필수)** |
| `app_mentions:read` | 스레드 내 재호출 |
| `channels:history` | 스레드 맥락 읽기 |
| `users:read` | 발화자 식별 |

### 6.4 제약

Slack 앱의 슬래시 커맨드는 **API로 자동 생성할 수 없다.** 앱 관리 화면에서 수동 등록해야 한다. 10개를 옮겨 적는 작업이 필요하며, `hermes slack sync`가 목록을 뽑아준다 (CLI 스펙 §4.5).

부담이 크면 `/bateam lucas ...` 하나로 통합하는 대안이 있다 — 커맨드는 1개만 등록하면 되지만 매번 타이핑이 길어진다. **결정 필요.**

---

## 7. launchd 등록

### 7.1 프로필당 LaunchAgent 1개

사용자 세션에서 돌리므로 **LaunchDaemon이 아니라 LaunchAgent**를 쓴다. Keychain 접근과 로그 확인이 쉽다.

```
~/Library/LaunchAgents/
├── com.hermes.profile.default.plist       # 기존 — 손대지 않음
└── com.hermes.profile.bateam.plist        # 신규
```

**1판의 11개(역할 10 + Gateway)에서 1개로 줄었다.**

### 7.2 plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>              <string>com.hermes.profile.bateam</string>

  <key>ProgramArguments</key>
  <array>
    <string>{{HERMES_HOME}}/scripts/run-gateway.sh</string>
    <string>bateam</string>
  </array>

  <key>WorkingDirectory</key>   <string>{{HERMES_HOME}}</string>
  <key>RunAtLoad</key>          <true/>

  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>   <false/>   <!-- 비정상 종료 시에만 재시작 -->
  </dict>
  <key>ThrottleInterval</key>   <integer>10</integer>

  <key>StandardOutPath</key>    <string>{{HOME}}/.hermes/profiles/bateam/log/gateway.out.log</string>
  <key>StandardErrorPath</key>  <string>{{HOME}}/.hermes/profiles/bateam/log/gateway.err.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>HERMES_HOME</key>      <string>{{HERMES_HOME}}</string>
    <key>HERMES_PROFILE</key>   <string>bateam</string>
    <key>NODE_ENV</key>         <string>production</string>
    <!-- API 키는 여기 넣지 않는다 — §8 -->
  </dict>
</dict>
</plist>
```

**`KeepAlive`를 `SuccessfulExit: false`로 둔 이유** — 무조건 재시작이면 설정 오류로 즉사하는 게이트웨이가 무한 재기동 루프에 빠진다. 정상 종료(`exit 0`)는 의도된 중지로 보고 재시작하지 않는다. `ThrottleInterval 10`으로 크래시 루프도 10초 간격으로 묶는다.

**단일 프로세스라 `KeepAlive`의 중요도가 1판보다 높다.** 게이트웨이가 죽으면 10개 페르소나가 전부 멈추기 때문이다. 다만 무상태 구조라 수 초 내 복구되고 진행 중이던 요청만 유실된다.

### 7.3 운영 명령

```bash
hermes apply --profile bateam          # plist 생성 + bootstrap (권장 경로)
hermes restart --profile bateam
hermes status
hermes logs --profile bateam -f

# launchctl 직접 (디버깅용)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.hermes.profile.bateam.plist
launchctl bootout   gui/$(id -u)/com.hermes.profile.bateam
launchctl kickstart -k gui/$(id -u)/com.hermes.profile.bateam
```

> macOS 10.11+ 에서 `load`/`unload`는 deprecated다. `bootstrap`/`bootout`/`kickstart`를 쓴다.

---

## 8. 보안 — 자격증명 관리

**plist와 YAML에는 평문 키를 절대 넣지 않는다.** plist는 `~/Library/LaunchAgents`에 평문으로 남고 백업·동기화에 딸려간다.

macOS Keychain에 저장하고 기동 래퍼에서 주입한다. **프로필별로 항목을 분리**해 `bateam`과 `default`의 자격증명이 섞이지 않게 한다.

```bash
# 최초 1회
security add-generic-password -a "$USER" -s "hermes/anthropic"          -w
security add-generic-password -a "$USER" -s "hermes/terra"              -w
security add-generic-password -a "$USER" -s "hermes/bateam/slack-bot"   -w
security add-generic-password -a "$USER" -s "hermes/bateam/slack-app"   -w
```

```bash
# scripts/run-gateway.sh
#!/usr/bin/env bash
set -euo pipefail
PROFILE="$1"

keyfor() { security find-generic-password -a "$USER" -s "$1" -w 2>/dev/null; }

export ANTHROPIC_API_KEY="$(keyfor hermes/anthropic)"
export TERRA_API_KEY="$(keyfor hermes/terra)"
export SLACK_BOT_TOKEN="$(keyfor "hermes/${PROFILE}/slack-bot")"
export SLACK_APP_TOKEN="$(keyfor "hermes/${PROFILE}/slack-app")"

exec node "$HERMES_HOME/dist/gateway/main.js" --profile "$PROFILE"
```

`exec`를 쓰는 이유 — 래퍼가 부모로 남으면 launchd가 실제 Node 프로세스의 종료 상태를 보지 못해 `KeepAlive` 판정이 틀어진다.

### 추가 원칙

- **네트워크 리스닝 포트가 없다.** Socket Mode는 아웃바운드 연결만 쓴다. 1판의 "127.0.0.1 바인딩" 주의사항 자체가 사라졌다 — 공격 표면이 줄었다.
- `~/.hermes/profiles/bateam/state/`의 대화 로그에는 사내 정보가 쌓인다. 저장소 밖에 두고 커밋하지 않는다.
- Slack 이벤트는 서명 검증을 거친 것만 처리한다 (Socket Mode는 자동).
- 프로필별 Keychain 분리로, `bateam` 유출이 `default`로 번지지 않는다.

---

## 9. 요청 처리 흐름

```
슬래시 커맨드 수신 (/grace ...)
  → 3초 내 ack ("Grace가 검토 중…")
  → 라우터: /grace → personaId=grace
  → 레지스트리 조회: config/profiles/bateam/agents/grace.yaml
       · enabled=false 면 "현재 비활성" 안내 후 종료
  → 페르소나 로드: roles/grace-business-analyst.md (캐시 · mtime 감시)
  → 시스템 프롬프트 조립: defaults → profile.overrides → agent
  → 히스토리 복원: ~/.hermes/profiles/bateam/state/grace/<channel>-<thread>.jsonl
  → Provider(terra).complete(model=gpt-terra, temperature=0.2)
  → 히스토리 저장
  → chat.postMessage(username="Grace · BA", icon=":clipboard:", thread_ts)
```

**프로세스 경계를 한 번도 넘지 않는다.** 1판에서 이 흐름 중간에 있던 로컬 HTTP 왕복이 사라졌다.

### 컨텍스트 키

`{personaId}/{channelId}-{threadTs}` 단위로 저장한다. 채널 단위로 묶으면 서로 다른 안건이 뒤섞이고, 메시지 단위면 맥락이 끊긴다. **스레드가 회의 하나에 대응**한다.

### 시스템 프롬프트 조립

```
[페르소나]   roles/<id>.md 전문
[운영 규칙]  · 너는 Slack에서 팀과 대화한다
             · 답변은 Slack 마크다운, 400자 이내를 기본으로 한다
             · 네 역할 범위를 벗어난 질문은 담당 역할을 지목해 넘긴다
[맥락]       프로필명 · 채널명 · 발화자 · 현재 시각
```

### 동시성

`profile.yaml`의 `concurrency`로 프로필 단위 동시 요청 수를 제한한다. 이벤트 루프가 하나이므로 무제한이면 공급사 rate limit에 걸린다. 초과 요청은 큐에 넣고 Slack에는 대기 안내를 보낸다.

---

## 10. 단계별 진행

| 단계 | 범위 | 완료 기준 |
| --- | --- | --- |
| **1** | Provider 추상화 + 페르소나 로더 | `hermes chat lucas` 로 Lucas 페르소나 응답 확인 |
| **2** | 두 번째 공급사 연결 | `hermes chat grace` 가 terra 경유로 응답 |
| **3** | `bateam` 프로필 + 10인 등록 | `hermes agent import ./roles --profile bateam` 후 `agent list` 10개 |
| **4** | Gateway + Slack | `/lucas`, `/grace` 로 페르소나 응답 게시 |
| **5** | launchd 등록 | 재부팅 후 자동 기동 · `hermes status` 정상 |
| **6** | 스레드 맥락 유지 | 같은 스레드 연속 질문에서 이전 대화 반영 |
| **7** | 핫 리로드 | `roles/*.md` 수정이 재기동 없이 반영 |

**1~2단계는 launchd 없이 `hermes chat`으로 검증한다.** 상주화를 먼저 하면 오류 원인이 launchd 설정인지 코드인지 구분이 어려워진다. 1판 대비 **5단계가 뒤로 밀렸고 부담도 줄었다** — 등록할 LaunchAgent가 11개에서 1개가 되었기 때문이다.

---

## 11. 열린 질문

1. **`gpt-terra`의 API 스펙** — OpenAI 호환인가, 자체 스키마인가? base URL과 인증 헤더 형식이 필요하다.
2. **런타임** — Node/TypeScript를 가정했다. Python(FastAPI) 선호가 있으면 §3.4 구조를 그대로 옮길 수 있다.
3. **저장소 경로** — 맥에서의 실제 경로 (`~/dev/hermes` 가정). git 저장소로 관리할 것인가?
4. **Slack 앱 설치 권한** — `bateam` 전용 앱을 워크스페이스에 설치할 수 있는가? 사내 승인이 필요하면 §6.4의 통합 커맨드 대안이 유리해진다.
5. **슬래시 커맨드 10개 vs 통합 커맨드 1개** — §6.4. 결정 필요.
6. **비용 한도** — 페르소나별 일일 토큰 상한을 둘 것인가? 단일 프로세스라 프로필 단위 집계가 쉬워졌다.
7. **`default` 프로필의 현재 내용** — 손대지 않기로 했으나, 포트·Keychain 항목이 겹치지 않는지 확인이 필요하다. (B안에서는 포트를 쓰지 않으므로 충돌 가능성은 Keychain 항목명뿐이다.)

---

## 부록 — 역할별 모델 배정 초안

성향에 맞춰 배정하면 팀 구성의 의도가 실제 동작에도 반영된다.

| ID | 역할 | 성향 | temperature | 태그 |
| --- | --- | --- | --- | --- |
| `lucas` | Tech Lead | 균형형 · 조율자 | 0.3 | core, lead |
| `grace` | BA | 보수적 · 정책 중심 | 0.2 | core, policy |
| `brian` | Backend | 진보적 · 기술 혁신 | 0.5 | core |
| `emma` | Frontend / UX | 창의적 · 사용자 경험 중심 | 0.8 | core, ux |
| `mia` | QA | 보수적 · 검증 중심 | 0.1 | core, review |
| `leo` | DevOps | 현실주의 · 자동화 중심 | 0.3 | core |
| `david` | Data | 객관적 · 데이터 중심 | 0.2 | ext |
| `aiden` | AI | 실험적 · 미래 지향 | 0.7 | ext |
| `jack` | Security | 매우 보수적 · 위험 회피 | 0.2 | ext, review |
| `oscar` | Critic | 회의적 · 반증 중심 | 0.7 | ext, review |

> Mia는 같은 입력에 같은 판정을 내려야 하므로 가장 낮게, Oscar는 검토되지 않은 각도를 끌어내야 하므로 높게 둔다.

**B안에서는 태그의 용도가 달라졌다.** 1판에서 태그는 "비용 절감을 위해 일부만 상주"용이었으나, 이제 유휴 비용이 없으므로 **호출 대상 묶음** 의미만 남는다 — 예: `/bateam review 이 설계 검토해줘` 로 Mia · Jack · Oscar 를 동시 소집.
