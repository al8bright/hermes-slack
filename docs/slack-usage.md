# Slack 사용법

> 상위 문서: [README.md](./README.md) · 설치: [slack-setup.md](./slack-setup.md) · 보드 운영: [kanban-workflow.md](./kanban-workflow.md)

Slack에서 BA Team을 쓰는 네 가지 방법이다. **무엇을 하려는지에 따라 고른다.**

| 하려는 것 | 방법 | 응답하는 사람 |
| --- | --- | --- |
| 가볍게 물어보기 | DM 또는 `@BA Team` 멘션 | Lucas |
| 팀 전체 검토 (회의) | `/kanban create "안건"` | 역할별 분해 → Lucas 종합 |
| 특정 역할에게 맡기기 | `/kanban create "..." --assignee jack` | 그 역할만 |
| 진행 보기 · 개입 | `/kanban list` · `show` · `comment` | — |

---

## 1. 대화 — 가볍게 묻기

**DM** 또는 봇을 초대한 **채널에서 멘션**한다.

```
@BA Team FastAPI가 Flask보다 항상 빠른가요?
```

```
@BA Team 어제 결정한 전환 건, 핵심만 다시 정리해줘
```

Lucas가 Tech Lead 페르소나로 답한다. **보드에 기록이 남지 않는다** — 그냥 대화다.

### 스레드에서 이어가기

응답에 스레드로 답하면 맥락이 이어진다. 새 메시지로 물으면 새 대화가 된다.

```
@BA Team 그 근거가 뭐죠?          ← 스레드 안에서, 멘션 없이도 됨
```

### 파일 던지기

문서를 올리고 함께 물으면 읽는다 (`files:read` 스코프 필요).

```
[설계서.pdf 첨부]
@BA Team 이 설계 검토해줘
```

> **가벼운 질문을 태스크로 만들지 말 것.** `/kanban create` 로 만들면 6개로 분해되어 역할별 검토가 돌아간다. 한 줄 답이면 되는 질문에는 낭비다.

### ⚠ 대화로는 특정 역할을 직접 부를 수 없다

게이트웨이가 `lucas` 하나뿐이므로 **DM·멘션은 전부 Lucas에게 간다.** Grace나 Jack에게 직접 말을 거는 방법은 없다. 앱 1개 전략([gateway-slack.md](./gateway-slack.md))의 대가다.

대안은 셋이다.

| 방법 | 상태 | 비고 |
| --- | --- | --- |
| `/kanban create "..." --assignee jack` | ✅ 바로 됨 | 결과가 보드에 남아 되짚을 수 있다 |
| Lucas에게 중계 요청 | ⚠ 미검증 | 아래 참조 |
| 그 역할만 별도 Slack 앱 | 가능하나 제약 있음 | 아래 참조 |

**중계 요청** — `@BA Team 이건 보안 쪽 같은데 Jack에게 물어봐줘` 로 Lucas가 `kanban_create(assignee="jack")` 을 부르게 하는 그림이다. 대화 모드(디스패처 워커가 아님)에서 kanban 툴을 쓰려면 프로필 설정에 `kanban` 툴셋이 있어야 한다.

```bash
grep -n -A20 "platform_toolsets" ~/.hermes/profiles/lucas/config.yaml
```

`platform_toolsets` 는 **플랫폼별로 나뉜다**(`cli` · `slack` · `telegram` …). Slack 대화의 플랫폼은 `slack` 이므로 `platform_toolsets.slack` 에 `- kanban` 을 넣어야 한다. 백업 후 시험하고 `lucas tools --summary` 로 다른 툴이 빠지지 않았는지 확인할 것.

**앱 분리** — 진짜 `@Grace` 멘션과 역할별 DM을 원하면 그 역할용 Slack 앱을 따로 발급한다.

```bash
grace slack manifest --agent-view --write   # 이름을 "Grace" 로 수정
grace gateway setup
grace gateway install && grace gateway start
```

> ⚠ [issue #59739](https://github.com/NousResearch/hermes-agent/issues/59739) — Slack 어댑터가 `SLACK_APP_TOKEN` 을 프로세스 환경변수에서 읽어, 여러 프로필이 동시에 게이트웨이를 띄우면 전부 기본 프로필의 앱으로 붙는 문제가 보고되어 있다. **두 번째 게이트웨이를 띄우기 전에 이것부터 확인할 것.**

---

## 2. 회의 — 팀 전체 검토

```
/kanban create "결제 모듈에 외부 PG를 추가하려 한다"
```

```
Created t_2904a01b  (triage, assignee=-)
(subscribed — you'll be notified when t_2904a01b completes or blocks)
```

이후 자동으로 진행된다 (`auto_decompose: true` 기준).

```
60초 내   decomposer 가 역할별로 분해
          ├─ brian   구현 방식과 개발 비용
          ├─ jack    권한·데이터 흐름·공급망 위험
          ├─ mia     회귀 위험과 검증 계획
          ├─ leo     배포·롤백 절차
          ├─ oscar   전제 반박          ← 위 넷이 끝난 뒤 실행
          └─ lucas   종합 Go/No-Go      ← 전부 끝난 뒤 실행

완료 시    이 스레드로 알림
```

**본문을 함께 주면 분해 품질이 올라간다.**

```
/kanban create "결제 모듈에 외부 PG를 추가하려 한다" --body "현재 자체 PG만 지원. 해외 결제 요구가 늘어 Stripe 추가를 검토 중. 기존 결제 이력·정산 로직과의 호환이 관건."
```

### 자주 쓰는 옵션

| 옵션 | 용도 |
| --- | --- |
| `--body "..."` | 배경·제약 설명. 분해 정확도가 크게 달라진다 |
| `--priority 1` | 우선순위 (낮을수록 먼저) |
| `--assignee <프로필>` | 분해 없이 그 역할에게 직행 |
| `--triage` | 명시적으로 triage 에 넣기 |
| `--workspace dir:/절대/경로` | 산출물을 보존할 디렉터리 |

---

## 3. 특정 역할 지목

`--assignee` 를 주면 **분해를 건너뛰고** 그 역할만 실행한다.

```
/kanban create "신규 PG 연동의 권한 모델을 검토해줘" --assignee jack
/kanban create "이 기능 배포해도 되는지 판단해줘" --assignee mia
/kanban create "지금 결정에 반대해봐" --assignee oscar
```

역할 이름은 프로필명 그대로다.

| 프로필 | 맡는 것 |
| --- | --- |
| `lucas` | 종합 판단 · Go/No-Go · 우선순위 |
| `grace` | 요구사항 · 정책 · 예외 상황 |
| `brian` | 구현 방식 · 성능 · 기술 부채 |
| `emma` | 화면 흐름 · 사용자 경험 |
| `mia` | 검증 · 회귀 위험 · 릴리스 판정 |
| `leo` | 배포 · 롤백 · 운영 안정성 |
| `david` | 지표 · 측정 방법 · 수치 검증 |
| `aiden` | AI·자동화 적용 |
| `jack` | 권한 · 데이터 흐름 · 공급망 위험 |
| `oscar` | 전제 반박 · 대안 · 실패 시나리오 |

---

## 4. 진행 보기와 개입

### 현황

```
/kanban list                      전체
/kanban list --status running     실행 중인 것만
/kanban list --assignee jack      담당자별
/kanban list --mine               내가 만든 것
/kanban stats                     요약
```

### 상세

```
/kanban show t_2904a01b           본문·이벤트·결과·의존 관계
/kanban runs t_2904a01b           시도 이력
/kanban log t_2904a01b            워커 출력 (실패 원인이 여기 있다)
```

### 중간 개입

```
/kanban comment t_2904a01b "이 CVE는 이미 패치됐습니다"
/kanban reassign t_2904a01b leo   담당 변경
/kanban block t_2904a01b "요구사항 확정 대기"
/kanban unblock t_2904a01b
/kanban archive t_2904a01b        치우기
```

**코멘트는 워커가 읽는다.** `kanban_show()` 에 이전 코멘트가 함께 실리므로, 재실행 전에 정보를 보태거나 방향을 잡아줄 수 있다.

> `/kanban` 은 에이전트가 실행 중일 때도 동작한다. Lucas가 답하는 중에도 보드를 조작할 수 있다.

### 수동 분해

`auto_decompose` 를 꺼뒀다면 직접 돌린다.

```
/kanban decompose t_2904a01b      역할별로 분해
/kanban specify t_2904a01b        분해 없이 스펙만 다듬기 (한 줄 → 목표·접근·인수기준)
```

---

## 5. 결과 받기

완료되면 **태스크를 만든 스레드로 알림이 온다** (`auto_subscribe_on_create: true`).

근거 문서는 첨부로 남는다.

```
/kanban attachments t_b5f61135
/kanban show t_b5f61135           summary 와 결론
```

> ⚠ **scratch 작업공간은 완료 시 삭제된다.** 워커가 `kanban_attach` 로 올린 것만 보드에 남는다. 파일을 직접 만들게 하려면 `--workspace dir:/절대/경로` 를 준다.

---

## 6. 알아둘 것

**슬래시 커맨드 응답은 본인에게만 보인다.** `나에게만 표시` 표시가 붙는 것이 정상이다. 팀에 공유하려면 결과를 복사하거나 채널에서 대화로 물어야 한다.

**봇은 자동으로 채널에 들어가지 않는다.** 쓰려는 채널마다 초대한다.

```
/invite @BA Team
```

**허용된 사용자만 쓸 수 있다.** `SLACK_ALLOWED_USERS` 에 없는 사람은 응답을 받지 못한다. 팀원을 추가하려면 그 사람의 Member ID를 `.env` 에 넣고 게이트웨이를 재시작한다.

```bash
# ~/.hermes/profiles/lucas/.env
SLACK_ALLOWED_USERS=U01ABC2DEF3,U02XYZ7890AB
```

```bash
lucas gateway restart
```

**한 역할은 동시에 하나만 처리한다** (`max_in_progress_per_profile: 1`). 같은 사람에게 두 건을 맡기면 하나는 대기한다. 맥락이 섞이지 않게 하려는 설정이다.

---

## 7. 전형적인 하루

```
아침
  @BA Team 어제 올린 PG 연동 건 결론 나왔어?
       → Lucas가 요약

새 안건
  /kanban create "관리자 페이지에 감사 로그를 추가한다" \
    --body "규정 대응. 누가 언제 무엇을 바꿨는지 추적 필요."
       → 자동 분해 → grace·jack·brian·mia·oscar·lucas

진행 중
  /kanban list --status running
  /kanban comment t_xxx "감사 로그 보존 기간은 3년입니다"

결론
  (스레드 알림)  ✓ t_xxx completed
  /kanban show t_xxx
  /kanban attachments t_xxx
```

---

## 8. 명령 요약

| 명령 | 용도 |
| --- | --- |
| `@BA Team <질문>` | 대화 (Lucas 응답, 기록 없음) |
| `/kanban create "<안건>" --body "<배경>"` | 회의 열기 (자동 분해) |
| `/kanban create "..." --assignee <역할>` | 특정 역할에게 직행 |
| `/kanban list [--status\|--assignee\|--mine]` | 현황 |
| `/kanban show <id>` | 상세·결과 |
| `/kanban comment <id> "<메모>"` | 정보 보태기 |
| `/kanban reassign <id> <역할>` | 담당 변경 |
| `/kanban block <id> "<사유>"` / `unblock <id>` | 보류 / 재개 |
| `/kanban decompose <id>` | 수동 분해 |
| `/kanban attachments <id>` | 산출물 목록 |
| `/kanban archive <id>` | 치우기 |
| `/kanban stats` | 보드 요약 |

터미널에서는 `hermes kanban <동사>` 로 동일하게 쓴다. 역할과 직접 길게 논의하려면 `grace chat` 처럼 프로필 별칭을 쓴다 — [team-workflow.md](./team-workflow.md).
