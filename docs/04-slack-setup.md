# Slack 앱 발급과 연동

> 상위 문서: [README.md](./README.md) · 전략 결정: [03-gateway-slack.md](./03-gateway-slack.md)
>
> 출처: [Slack | Hermes Agent](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/slack)

`lucas` 프로필에 Slack 게이트웨이를 붙이는 절차다. 앱 발급 → 권한 → 토큰 → 허용 사용자 → 기동 순으로 진행한다.

---

## 0. 왜 Socket Mode인가

Hermes는 **WebSocket(Socket Mode)** 으로 Slack에 붙는다. 공개 HTTPS 엔드포인트가 필요 없으므로 맥 로컬·사내망·방화벽 뒤에서 그대로 동작한다. Request URL을 설정할 일이 없다.

토큰이 **두 개** 필요하다.

| 토큰 | 접두어 | 용도 | 발급 위치 |
| --- | --- | --- | --- |
| Bot Token | `xoxb-` | 메시지 송수신 | Install App |
| App-Level Token | `xapp-` | Socket Mode 연결 | Basic Information → App-Level Tokens |

---

## 1. 앱 생성 — 매니페스트 (권장)

스코프를 하나씩 클릭하는 대신 Hermes가 매니페스트를 만들어 준다.

```bash
lucas slack manifest --agent-view --write
cat ~/.hermes/profiles/lucas/slack-manifest.json
```

### ⚠ 이름부터 고친다

매니페스트의 앱 이름은 **`Hermes` 로 하드코딩**되어 있다. `lucas` 프로필로 생성해도 마찬가지이며, `--name` 옵션은 없다(`--long-description` 계열만 있다). **붙여넣기 전에 JSON을 고친다.**

```bash
MF=~/.hermes/profiles/lucas/slack-manifest.json

python3 - "$MF" <<'PY'
import json, sys
p = sys.argv[1]
NAME = "BA Team"
DESC = "역할과 성향을 분리한 10인 가상 개발팀"

d = json.load(open(p, encoding="utf-8"))
d["display_information"]["name"] = NAME
d["display_information"]["description"] = DESC
d.setdefault("features", {}).setdefault("bot_user", {})["display_name"] = NAME
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(f"{p} → {NAME}")
PY
```

바뀌는 필드는 셋이다.

| 필드 | 나타나는 곳 |
| --- | --- |
| `display_information.name` | 앱 목록 · 설치 화면 |
| `display_information.description` | 앱 소개 |
| `features.bot_user.display_name` | **대화창의 발신자 이름 · `@멘션` 대상** |

Slack 제한: 앱 이름 35자, 봇 표시명 80자, 설명 140자.

**이름을 `Lucas` 가 아니라 `BA Team` 으로 하는 이유** — 이 봇 하나가 팀 전체의 출력을 나른다. Lucas의 대화 응답뿐 아니라 Kanban 워커(jack·mia·oscar…)의 완료 통지도 같은 봇으로 나간다. `Lucas` 라고 이름 붙이면 Jack의 보안 검토 결과가 Lucas 이름으로 오게 된다. 대화 상대가 누구인지는 응답 본문에서 밝혀진다("저는 Lucas입니다").

> 앱 생성 후에도 **Settings → Basic Information → Display Information** 에서 언제든 바꿀 수 있다.

### 앱 생성

1. [api.slack.com/apps](https://api.slack.com/apps) → **Create New App**
2. **From an app manifest** 선택
3. 워크스페이스 선택 → **수정한** JSON 붙여넣기 → **Create**

매니페스트에 스코프·이벤트 구독·Socket Mode 설정이 모두 들어 있다. **§2와 §3은 확인용**이며, 매니페스트를 썼다면 건너뛰어도 된다.

> 매니페스트 경로는 프로필에 따라 다르다. `lucas` 별칭으로 실행하면 `~/.hermes/profiles/lucas/` 아래에 생긴다.

### 수동 생성

매니페스트를 쓰지 않는다면 **From scratch** 로 만들고 §2~§5를 직접 설정한다.

---

## 2. Bot Token Scopes

**Features → OAuth & Permissions → Scopes → Bot Token Scopes**

| 스코프 | 용도 |
| --- | --- |
| `chat:write` | 메시지 전송 |
| `app_mentions:read` | `@봇` 멘션 감지 |
| `channels:history` | **공개 채널 메시지 읽기** |
| `channels:read` | 공개 채널 목록 |
| `groups:history` | **비공개 채널 메시지 읽기** |
| `groups:read` | 비공개 채널 목록 |
| `im:history` | DM 읽기 |
| `im:read` | DM 정보 |
| `im:write` | DM 열기 |
| `mpim:history` | 그룹 DM 읽기 |
| `mpim:read` | 그룹 DM 정보 |
| `users:read` | 사용자 조회 |
| `files:read` | 첨부 파일 읽기 |
| `files:write` | 파일 업로드 |

선택:

| 스코프 | 용도 |
| --- | --- |
| `assistant:write` | 봇 이름 옆에 "is thinking…" 상태 표시 |

> ⚠ **`channels:history` · `groups:history` 가 없으면 채널에서 아무 메시지도 못 받는다.** DM에서만 동작한다. 가장 흔한 누락이다.
>
> ⚠ **`files:read` 가 없으면 사용자가 올린 첨부를 읽지 못한다.** 회의에 문서를 던져 넣는 흐름이면 필수다.

---

## 3. Socket Mode 활성화

**Settings → Socket Mode**

1. **Enable Socket Mode** → ON
2. App-Level Token 생성 요청이 뜬다
   - 이름: `hermes-socket` (아무거나)
   - 스코프: **`connections:write`**
   - **Generate**
3. `xapp-` 로 시작하는 토큰 복사 → **`SLACK_APP_TOKEN`**

나중에 다시 찾으려면 **Settings → Basic Information → App-Level Tokens**.

---

## 4. Event Subscriptions

**Features → Event Subscriptions**

1. **Enable Events** → ON
2. **Subscribe to bot events** 에 추가

| 이벤트 | 대상 |
| --- | --- |
| `message.im` | DM |
| `message.mpim` | 그룹 DM |
| `message.channels` | **공개 채널** |
| `message.groups` | **비공개 채널** |
| `app_mention` | 봇 멘션 |

3. **Save Changes**

> ⚠ **DM은 되는데 채널에서 반응이 없다면 `message.channels`(공개) / `message.groups`(비공개) 누락이다.** 스코프가 있어도 이벤트 구독이 없으면 Slack이 아예 전달하지 않는다.

---

## 5. App Home — DM 허용

**Features → App Home → Show Tabs**

1. **Messages Tab** → ON
2. **Allow users to send Slash commands and messages from the messages tab** 체크

이걸 빼먹으면 사용자에게 *"Sending messages to this app has been turned off"* 가 뜬다.

---

## 6. 슬래시 커맨드

**Features → Slash Commands** 에서 등록한다. Socket Mode를 쓰므로 **Request URL은 비워둔다.**

칸반 구조에서는 하나면 충분하다.

| Command | Description |
| --- | --- |
| `/kanban` | BA Team 보드 조작 (list · create · show · comment · decompose …) |

`hermes kanban` 의 모든 하위 명령이 `/kanban` 으로 노출된다.

```
/kanban create "FastAPI 전환 검토" --triage
/kanban decompose t_abc123
/kanban list
/kanban show t_abc123
```

> 역할을 직접 지목하고 싶다면 `/lucas` · `/grace` … 를 추가로 등록할 수 있다. 다만 **앱이 하나이므로 응답 발신자는 봇 하나로 보인다.** 역할별로 아바타를 분리하려면 앱을 나눠야 한다 — [03-gateway-slack.md §2](./03-gateway-slack.md).
>
> 스코프나 이벤트를 나중에 바꾸면 **앱을 재설치해야 반영된다.**

---

## 7. 앱 설치와 봇 토큰

**Settings → Install App**

1. **Install to Workspace**
2. 권한 확인 → **Allow**
3. **Bot User OAuth Token** (`xoxb-`) 복사 → **`SLACK_BOT_TOKEN`**

---

## 8. 허용 사용자 — 보안상 필수

> ⚠ **`SLACK_ALLOWED_USERS` 를 설정하지 않으면 게이트웨이가 모든 메시지를 거부한다.** 이건 버그가 아니라 안전장치다. 설정하지 않으면 봇이 아무에게도 응답하지 않는다.

Member ID 찾는 법:

1. Slack에서 사용자 이름/아바타 클릭
2. **View full profile**
3. **⋮** (더보기) → **Copy member ID**

`U01ABC2DEF3` 형태다. 본인과 허용할 사람들의 ID를 모은다.

---

## 9. Hermes 설정

프로필별 `.env` 에 넣는다. **`lucas` 프로필이므로 `~/.hermes/profiles/lucas/.env` 다.**

```bash
lucas gateway setup      # 대화형 — 이 방법을 권한다
```

직접 편집한다면:

```bash
# ~/.hermes/profiles/lucas/.env

SLACK_BOT_TOKEN=xoxb-...
SLACK_APP_TOKEN=xapp-...
SLACK_ALLOWED_USERS=U01ABC2DEF3,U02XYZ7890AB

# 선택 — cron·알림이 나갈 기본 채널
SLACK_HOME_CHANNEL=C01234567890
SLACK_HOME_CHANNEL_NAME=bateam
```

| 변수 | 필수 | 설명 |
| --- | --- | --- |
| `SLACK_BOT_TOKEN` | ✅ | `xoxb-` |
| `SLACK_APP_TOKEN` | ✅ | `xapp-` |
| `SLACK_ALLOWED_USERS` | ✅ | 쉼표 구분 Member ID. **없으면 전부 거부** |
| `SLACK_HOME_CHANNEL` | | 예약 메시지·알림용 채널 ID |
| `SLACK_HOME_CHANNEL_NAME` | | 표시용 이름 |

> 이 저장소의 `.gitignore` 가 `.env` 를 막고 있다. 토큰을 저장소에 커밋하지 말 것.

---

## 10. 기동

```bash
# 1. 포그라운드로 먼저 확인 — 오류가 바로 보인다
lucas gateway run
```

연결이 되면 Slack에서 채널에 봇을 초대한다. **봇은 자동으로 채널에 들어가지 않는다.**

```
/invite @BA Team
```

DM으로 말을 걸어 응답을 확인한 뒤, 서비스로 등록한다.

```bash
# 2. launchd 서비스 등록
lucas gateway install
lucas gateway start
lucas gateway status

# 3. 전체 프로필 게이트웨이 현황
hermes gateway list
```

> `hermes gateway status` 는 **현재 기본 프로필** 기준으로 답한다. `lucas` 를 보려면 `lucas gateway status` 이거나 `hermes gateway list` 의 "Other profiles" 줄을 봐야 한다.

---

## 11. 검증

```
# DM 또는 초대한 채널에서

안녕하세요, 팀 소개해주세요.
      → Lucas 페르소나로 응답해야 한다

/kanban list
      → 보드 조회

/kanban create "테스트 안건" --triage
/kanban decompose <task-id>
      → 역할별로 태스크가 갈리는지
```

디스패처가 게이트웨이 안에 있으므로, 게이트웨이가 뜬 뒤로는 **60초마다 자동으로** `ready` 태스크를 집어 워커를 띄운다. 더 이상 `hermes kanban dispatch` 를 수동으로 칠 필요가 없다.

### ⚠ `--assignee` 없이 만들면 `triage` 에 멈춘다

```
/kanban create "팀 소개: 각자 자기 역할을 한 줄로 정리"
   → Created t_2904a01b  (triage, assignee=-)
```

담당자가 없으면 디스패처가 띄울 대상이 없어 `triage` 로 들어간다. `kanban.auto_decompose` 가 꺼져 있으면 **여기서 그대로 멈춘다.**

Slack에서 쓸 거라면 자동 분해를 켜는 것을 권한다 — 안건을 던지고 분해 명령을 치러 돌아와야 한다면 Slack에서 쓰는 이점이 없다.

```bash
hermes config set kanban.auto_decompose true
lucas   config set kanban.auto_decompose true
lucas gateway restart
```

수동으로 진행하려면:

```
/kanban decompose t_2904a01b
```

자세한 판단 기준은 [02-kanban-workflow.md §3](./02-kanban-workflow.md) 참조.

---

## 12. 문제 해결

| 증상 | 원인 | 조치 |
| --- | --- | --- |
| 봇이 아무에게도 응답하지 않음 | `SLACK_ALLOWED_USERS` 미설정 | Member ID 추가 후 재기동 |
| DM은 되는데 채널에서 무응답 | `message.channels` / `message.groups` 이벤트 미구독 | §4 추가 후 **앱 재설치** |
| 채널에서 메시지를 못 읽음 | `channels:history` / `groups:history` 스코프 없음 | §2 추가 후 **앱 재설치** |
| "Sending messages to this app has been turned off" | App Home의 Messages Tab 꺼짐 | §5 |
| 첨부 파일을 못 읽음 | `files:read` 없음 | §2 추가 후 재설치 |
| 채널에서 반응 없음 (설정은 정상) | 봇이 채널에 없음 | `/invite @<봇이름>` |
| 스코프를 바꿨는데 그대로 | 재설치 안 함 | Settings → Install App → Reinstall |
| 태스크가 `ready` 에서 안 움직임 | 게이트웨이가 꺼짐 (디스패처가 그 안에 있음) | `lucas gateway status` |

로그는 여기서 본다.

```bash
lucas logs -f
lucas logs --level WARNING
tail -f ~/.hermes/profiles/lucas/logs/gateway.log
```

---

## 13. 알려진 제약

**프로필별로 다른 Slack 앱을 물리려 할 때 주의가 필요하다.** Slack 어댑터가 `SLACK_APP_TOKEN` 을 프로세스 환경변수에서 읽어, 여러 프로필이 동시에 게이트웨이를 띄우면 모두 기본 프로필의 앱으로 붙는 문제가 보고되어 있다 ([issue #59739](https://github.com/NousResearch/hermes-agent/issues/59739)).

지금 구성은 **`lucas` 하나만 게이트웨이를 띄우므로 해당되지 않는다.** 나중에 역할별 앱 분리(가령 `grace` 에게도 별도 앱)로 확장할 때 이 제약을 먼저 확인할 것.

---

## 다음

- **Slack에서 쓰는 법: [05-slack-usage.md](./05-slack-usage.md)**
- 게이트웨이 전략과 선택지: [03-gateway-slack.md](./03-gateway-slack.md)
- 보드 운영: [02-kanban-workflow.md](./02-kanban-workflow.md)
