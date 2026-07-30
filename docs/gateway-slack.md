# Slack 게이트웨이 전략

> 상위 문서: [README.md](./README.md) · 선행: [setup.md](./setup.md)

프로필 10개를 Slack에 어떻게 노출할지의 문제다. 결론부터: **`lucas` 하나만 게이트웨이를 띄우고 시작한다.**

---

## 1. Hermes 게이트웨이의 성질

| 사실 | 근거 |
| --- | --- |
| 게이트웨이는 **프로필별 프로세스**다 | `lucas gateway start` / `grace gateway start` 가 각각 별개 프로세스로 뜬다 |
| 봇 토큰은 **프로필별 `.env`** 에 있다 | 프로필마다 다른 Slack 앱을 물릴 수 있다 |
| 같은 토큰을 두 프로필이 쓰면 **차단된다** | 두 번째 게이트웨이가 충돌 프로필명을 명시한 에러로 실패 |
| 디스패처가 **게이트웨이 안에서** 돈다 | `kanban.dispatch_in_gateway: true` (기본). 게이트웨이가 0개면 태스크가 진행되지 않는다 |
| `/kanban` 슬래시 커맨드가 **Slack에서 동작**한다 | 모든 `hermes kanban` 동사가 `/kanban` 으로 노출된다 |
| launchd 등록은 프로필별 | `lucas gateway install` |

**게이트웨이 개수 = Slack 앱 개수**다. 이게 선택의 핵심 제약이다.

---

## 2. 세 가지 안

### A. `lucas` 만 게이트웨이 — **채택**

```
Slack #bateam ──▶ [lucas 게이트웨이 + 디스패처]
                        │
                        └─▶ Kanban ─▶ grace · jack · mia · … (배정 시 기동)
```

| | |
| --- | --- |
| Slack 앱 | **1개** |
| 사람이 대화하는 상대 | Lucas |
| 다른 역할 호출 | `/kanban create "..." --assignee jack` |
| 상주 프로세스 | 1개 |

**장점** — 앱 발급·설치·승인이 한 번이면 끝난다. 팀 구조와도 맞는다. Lucas가 조율자이고 최종 결정자이므로, 사람이 Lucas에게 말하고 Lucas가 팀에 분배하는 흐름이 [`roles/`](../roles/) 의 설계와 일치한다.

**단점** — Grace에게 직접 말을 걸 수 없다. `/kanban` 을 거치거나 터미널에서 `grace chat` 을 써야 한다.

### B. 역할마다 게이트웨이

```
Slack ──▶ [lucas gw] [grace gw] [brian gw] … 10개
```

| | |
| --- | --- |
| Slack 앱 | **10개** (토큰 중복 시 차단되므로 반드시 별개) |
| 사람이 대화하는 상대 | 아무 역할이나 직접 |
| 상주 프로세스 | 10개 |

**장점** — `@Grace` 멘션, 역할별 DM이 된다. 각자 다른 아바타·이름으로 보인다.

**단점** — 워크스페이스에 앱 10개를 설치·승인받아야 한다. 사내 정책상 커스텀 앱 승인이 필요하면 현실적으로 막힌다. 상주 프로세스 10개의 메모리도 든다.

### C. 하이브리드 — 자주 쓰는 2~3명만

```
Slack ──▶ [lucas gw + 디스패처]  [grace gw]
                                  나머지 8명은 Kanban 워커
```

**A로 시작해 필요가 확인되면 옮겨가는 경로**로 둔다. 전환 비용이 낮다 — 프로필은 이미 다 있으므로 Slack 앱을 하나 더 발급하고 `grace gateway setup` 만 하면 된다.

---

## 3. 왜 A인가

1. **Slack 앱 10개 발급·승인 비용이 크다.** 사내 워크스페이스면 관리자 승인이 앱마다 필요할 수 있다. 이 비용은 확실하고, `@Grace` 멘션의 가치는 아직 불확실하다.
2. **디스패처가 게이트웨이에 있으므로 최소 1개는 필수다.** 어차피 하나는 띄워야 하고, 그게 오케스트레이터인 Lucas인 게 자연스럽다.
3. **`/kanban` 이 대안을 제공한다.** 다른 역할을 지목하는 수단이 이미 Slack 안에 있다. 없는 기능을 우회하는 게 아니라 원래 그렇게 쓰도록 만들어진 것이다.
4. **되돌리기 쉽다.** 프로필과 페르소나는 전략과 무관하게 이미 완성되어 있다. B나 C로 옮기는 건 앱을 더 발급하고 `gateway setup` 을 돌리는 일이다.

---

## 4. 구성 절차

**Slack 앱 발급·스코프·이벤트 구독의 상세 절차는 [slack-setup.md](./slack-setup.md) 에 있다.** 여기서는 흐름만 적는다.

```bash
# 1. 매니페스트 생성 → api.slack.com 에서 앱 생성
lucas slack manifest --agent-view --write

# 2. 토큰 등록 (대화형)
lucas gateway setup

# 3. 동작 확인 (포그라운드) — 오류가 바로 보인다
lucas gateway run

# 4. 정상이면 launchd 서비스로 등록
lucas gateway install
lucas gateway start
lucas gateway status

# 5. 전체 프로필 게이트웨이 현황
hermes gateway list
```

`gateway run` 으로 먼저 포그라운드 확인을 하는 게 낫다. 바로 `install` 하면 오류가 로그로만 남는다.

> ⚠ **`SLACK_ALLOWED_USERS` 를 설정하지 않으면 게이트웨이가 모든 메시지를 거부한다.** 안전장치이지 버그가 아니다. 봇이 아무 반응이 없을 때 가장 먼저 볼 곳이다.

### 검증

```
# Slack에서
안녕하세요, 팀 소개해주세요.          → Lucas가 응답
/kanban list                          → 보드 조회
/kanban create "테스트" --assignee jack  → 태스크 생성 · 디스패처가 jack 기동
```

`/kanban` 은 에이전트 실행 중에도 동작한다 — "agent running" 가드를 우회하도록 되어 있어, Lucas가 답하는 중에도 보드를 조작할 수 있다.

---

## 5. 사람이 특정 역할과 직접 말하는 법

A안에서 Grace에게 직접 물어야 할 때의 선택지다.

| 방법 | 명령 | 비고 |
| --- | --- | --- |
| **터미널** | `grace chat` | 가장 직접적. 맥 앞에 있을 때 |
| **일회성 질의** | `grace chat -q "부분취소 예외 정의해줘"` | 대화 세션 없이 답만 |
| **Kanban 경유** | `/kanban create "부분취소 예외 정의" --assignee grace` | Slack에서. 결과가 보드에 남음 |
| **Lucas에게 요청** | `@Lucas Grace에게 이거 물어봐줘` | Lucas가 `kanban_create` 로 넘김 |

**세 번째가 기본 흐름이 되도록 설계했다.** 결과가 보드에 남아 나중에 되짚을 수 있고, 다른 역할이 그 결과를 이어받을 수 있다.

---

## 6. 미결 사항

1. **Slack 앱을 몇 개 발급할 수 있는가.** 워크스페이스 정책 확인 필요. 10개가 가능하면 B안도 선택지가 된다.
2. **`lucas gateway setup` 이 요구하는 Slack 앱 설정** — Socket Mode 여부, 필요 스코프, 봇 토큰·앱 토큰 형식. 대화형 마법사가 안내하겠지만 앱을 먼저 만들어 둬야 한다.
3. **게이트웨이가 죽으면 디스패처도 멈춘다.** `gateway install` 로 launchd에 등록해 자동 재시작되게 할 것. 다만 디스패처를 게이트웨이에서 분리할 수 있는지(`HERMES_KANBAN_DISPATCH_IN_GATEWAY=0` + 별도 프로세스) 확인해 두면 이중화 여지가 생긴다.
4. **Slack에서 각 역할의 발신자 표시** — A안에서는 Lucas 봇 하나만 보인다. Kanban 워커의 결과가 Slack에 어떻게 통지되는지(`auto_subscribe_on_create: true` 로 원 채팅에 완료 통지가 간다고 문서화됨) 실제 표시 형태를 확인할 것.
