# Kanban 협업 운영

> 상위 문서: [README.md](./README.md) · 선행: [setup.md](./setup.md)
>
> 출처: [Kanban (Multi-Agent Board)](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban)
>
> **동작 확인됨 (2026-07-29)** — 디스패처가 spawn한 워커는 `kanban_*` 툴을 정상적으로 받는다.
> `kanban_show` · `kanban_heartbeat` · `kanban_attach` · `kanban_complete` 호출이 이벤트 로그로 확인되었다.
>
> ⚠ **`hermes chat` 으로는 검증할 수 없다.** `HERMES_KANBAN_TASK` 환경변수를 붙여 `hermes -p <id> chat` 을
> 실행해도 kanban 툴이 스키마에 올라오지 않는다. chat 모드와 디스패처 spawn 경로의 툴 등록이 다르기 때문이다.
> 검증은 반드시 **실제 태스크를 만들어 `hermes kanban dispatch`** 로 해야 하며,
> 결과는 `hermes kanban show <id>` 의 이벤트 목록에서 확인한다 (`completed` · `by: kanban_complete`).

---

10개 프로필이 팀으로 움직이는 메커니즘이다. **태스크의 `assignee`가 프로필명**이고, 디스패처가 해당 프로필을 워커 프로세스로 기동한다.

---

## 1. 왜 Kanban인가

Hermes에는 다른 에이전트를 부르는 수단이 둘 있다.

| | `delegate_task()` | **Kanban (채택)** |
| --- | --- | --- |
| 방식 | 동기 RPC — 부모가 자식 결과를 기다리며 블록 | 비동기 — 태스크를 보드에 올리고 각자 진행 |
| 지속성 | 프로세스 내 | SQLite에 durable · 재시작 후에도 살아있음 |
| 사람 개입 | 어려움 | 태스크에 코멘트·재배정·차단 해제 가능 |
| 이력 | 없음 | 전 전이가 `task_events` 에 기록 |
| 적합 | 짧은 병렬 조회 | **역할 경계를 넘는 작업** |

회의체 성격의 팀에는 Kanban이 맞다. Jack의 보안 검토가 30분 걸려도 Lucas가 블록되지 않고, 중간에 사람이 끼어들 수 있으며, 나중에 "왜 그렇게 결정했나"를 이력으로 되짚을 수 있다.

---

## 2. 보드 구성

```bash
hermes kanban init                                    # ~/.hermes/kanban.db 생성 (기본 보드)
hermes kanban boards create bateam \
  --name "BA Team" \
  --description "역할·성향을 분리한 10인 가상 개발팀" \
  --icon 🏗 \
  --switch

hermes kanban boards show                             # 활성 보드 확인
```

**보드 slug를 `bateam` 으로 둔다.** 프로필 이름은 역할별로 나갔으므로, 팀 이름은 보드가 이어받는다.

**보드마다 DB 파일이 따로 생긴다.**

```
~/.hermes/kanban.db                              ← kanban init 이 만드는 기본 보드
~/.hermes/kanban/boards/bateam/kanban.db         ← boards create 가 만드는 bateam 보드
```

`--switch` 를 붙였으므로 이후 `hermes kanban` 명령은 `bateam` 보드를 대상으로 한다. 현재 보드는 `hermes kanban boards show` 로 확인한다. 보드는 서로 격리되고 워커는 자기 보드만 본다(`HERMES_KANBAN_BOARD`). **보드 간 링크는 불가하다.**

---

## 3. 오케스트레이터 설정

```bash
hermes config set kanban.orchestrator_profile lucas
hermes config set kanban.default_assignee     lucas
hermes config set kanban.dispatch_in_gateway  true
hermes config set kanban.dispatch_interval_seconds 60
hermes config set kanban.max_in_progress_per_profile 1
```

| 키 | 값 | 이유 |
| --- | --- | --- |
| `orchestrator_profile` | `lucas` | 분해된 태스크의 루트를 소유. **Tech Lead 역할과 정확히 일치** |
| `default_assignee` | `lucas` | LLM이 존재하지 않는 프로필을 지목했을 때의 폴백. 조율자에게 떨어지는 게 맞다 |
| `dispatch_in_gateway` | `true` (기본) | 디스패처가 게이트웨이 프로세스 안에서 돈다 → **게이트웨이가 최소 1개는 떠 있어야 한다** |
| `dispatch_interval_seconds` | `60` (기본) | 회의체 성격상 즉시성이 필요 없다. 급하면 대시보드의 "Nudge dispatcher" |
| `max_in_progress_per_profile` | `1` | 한 역할이 동시에 여러 태스크를 잡으면 맥락이 섞인다. 회의 발언이 겹치는 것과 같다 |
| `failure_limit` | `2` (기본) | 연속 실패 시 자동 차단 |

### 설정을 어디에 걸 것인가 — 전역 vs 프로필

`kanban.*` 는 **두 곳 모두에 쓸 수 있다.**

| 명령 | 기록 위치 |
| --- | --- |
| `hermes config set kanban.*` | `~/.hermes/config.yaml` — 전역 |
| `lucas config set kanban.*` | `~/.hermes/profiles/lucas/config.yaml` — 프로필 |

**디스패처는 게이트웨이 프로세스 안에서 돌므로, 게이트웨이를 띄우는 프로필(`lucas`)의 설정이 유효하다.** 따라서 위 명령은 `lucas config set ...` 으로 거는 것이 맞다.

다만 **두 곳의 값이 어긋나면 어느 쪽이 읽히는지 헷갈린다.** 특히 `auto_decompose` 를 프로필에만 `false` 로 두면 전역은 기본값 `true` 로 남아, 다른 경로로 디스패치가 일어날 때 자동 분해가 켜질 수 있다. 값을 양쪽에 동일하게 걸어두는 편이 안전하다.

```bash
for scope in "hermes" "lucas"; do
  $scope config set kanban.orchestrator_profile      lucas
  $scope config set kanban.default_assignee          lucas
  $scope config set kanban.max_in_progress_per_profile 1
  $scope config set kanban.auto_decompose            false
done
```

### `auto_decompose` — 켠다

```yaml
kanban:
  auto_decompose: true          # triage 태스크를 자동 분해
  auto_decompose_per_tick: 3    # tick 당 최대 분해 건수
auxiliary:
  kanban_decomposer:
    provider: "…"
    model: "…"
```

```bash
hermes config set kanban.auto_decompose true
lucas   config set kanban.auto_decompose true
lucas gateway restart
```

**초기 구축 때는 껐다가, 프로필 설명(§3.5)을 넣은 뒤 켜는 순서가 맞다.** 설명이 없으면 decomposer가 담당자를 못 골라 전부 한 프로필로 몰리고, 그 상태로 자동 분해가 돌면 쓰레기 태스크만 쌓인다.

설명을 넣어 라우팅이 검증된 뒤에는 켜는 편이 낫다. **특히 Slack에서 쓴다면 필수에 가깝다** — 안건을 던지고 나서 분해 명령을 치러 돌아와야 한다면 Slack 인터페이스의 이점이 사라진다.

```
/kanban create "결제 모듈에 외부 PG를 추가하려 한다"
   → 60초 내 자동 분해 → 역할별 병렬 검토 → Lucas 종합 → 스레드로 완료 알림
```

**모든 것을 태스크로 만들지는 말 것.** `auto_decompose` 가 켜지면 triage에 들어온 것이 전부 분해 대상이 된다. 한 줄짜리 질문까지 6개로 쪼개면 낭비다.

| 상황 | 방법 |
| --- | --- |
| 회의가 필요한 안건 | `/kanban create "..."` — 팀 전체 검토 |
| 단순 질문 | 그냥 대화 — Lucas가 바로 답함 |
| 특정 역할만 | `/kanban create "..." --assignee jack` — 분해 없이 그 사람에게 직행 |

`--assignee` 를 주면 `triage` 를 건너뛰고 바로 `ready` 가 되므로 분해되지 않는다. 반대로 담당자를 비우면 `triage` 로 들어가 분해 대상이 된다.

---

## 4. 태스크 흐름

### 상태

```
triage ──▶ todo ──▶ ready ──▶ running ──▶ done
             │         ▲          │
             │         └──────────┤
             ▼                    ▼
          (부모 대기)          blocked ──▶ (unblock) ──▶ ready
                                              │
                                              ▼
                                          archived
```

| 상태 | 의미 |
| --- | --- |
| `triage` | 아직 다듬지 않은 아이디어 |
| `todo` | 백로그. 부모 의존이 있으면 여기서 대기 |
| `ready` | 디스패처가 claim 하고 워커를 띄울 대상 |
| `running` | 워커 프로세스가 실행 중 |
| `blocked` | 입력·역량·외부 조건 대기 |
| `done` | 완료 + 인계(summary·metadata) |
| `archived` | 기본 뷰에서 숨김 |

### 디스패처가 매 tick 하는 일

1. 만료된 claim 회수
2. 크래시한 워커 감지 (PID 없는데 TTL 남음) → `ready` 로 복구
3. **부모가 모두 `done` 인 자식을 `todo → ready` 승격**
4. `ready` 태스크를 원자적으로 claim
5. `hermes run <profile> --kanban-task <id>` 로 워커 기동

3번이 회의 진행 순서를 만든다. "보안 검토와 테스트 전략이 끝나야 최종 판단을 한다"를 의존 관계로 표현하면 디스패처가 순서를 지켜준다.

---

## 5. 실제 회의 흐름

### 사람이 안건을 올린다

```bash
hermes kanban create "FastAPI 전환 검토" \
  --body "현재 Flask 기반 API를 FastAPI로 전환하는 안. 비용과 리스크를 판단해달라." \
  --assignee lucas \
  --priority 1
```

Slack에서는 슬래시 커맨드로도 된다.

```
/kanban create "FastAPI 전환 검토" --assignee lucas
```

### Lucas가 역할별로 분해한다

디스패처가 `lucas` 를 띄우면, Lucas는 `kanban_show()` 로 안건을 읽고 `kanban_create()` 로 쪼갠다.

```
kanban_create(title="보안 검토",        assignee="jack",  parents=["t_root"])
kanban_create(title="테스트 커버리지 확보 방안", assignee="mia",   parents=["t_root"])
kanban_create(title="배포·롤백 전략",    assignee="leo",   parents=["t_root"])
kanban_create(title="현업 요구사항 영향", assignee="grace", parents=["t_root"])
kanban_create(title="전환 설계와 성능 근거", assignee="brian", parents=["t_root"])
kanban_create(title="이 결정에 대한 반박", assignee="oscar", parents=["t_root"])
kanban_create(title="종합 판단",         assignee="lucas",
              parents=["t_sec","t_qa","t_ops","t_ba","t_be","t_critic"])
kanban_complete(summary="6개 검토 태스크로 분해, 종합은 lucas")
```

**여기서 팀 구성의 의도가 실제로 작동한다.** [`roles/`](../roles/) 문서에 적어둔 충돌 구조 — Brian이 제안하고 Jack이 보안을, Mia가 검증을, Leo가 운영을, Grace가 요구사항을 묻고, Oscar가 전제를 반박하고, Lucas가 종합 — 이 그대로 태스크 그래프가 된다.

### 각 역할이 병렬로 진행한다

디스패처가 6개를 각자 프로필로 띄운다. 각 워커는 자기 페르소나로 검토하고 인계한다.

```
kanban_complete(
  summary="권한 모델 변경 없음. 단 의존성 3개가 CVE 이력 있음. 조건부 승인.",
  metadata={"cve": ["CVE-2025-xxxx"], "residual_risk": ["공급망 검토 미실시"]}
)
```

`summary` 는 **다음 담당자가 읽는 글**이다. 이 점을 `SOUL.md` 에 명시해 뒀다 ([setup.md §4](./setup.md)).

### Lucas가 종합한다

6개가 모두 `done` 이 되면 디스패처가 종합 태스크를 `ready` 로 승격한다. Lucas는 각 자식의 `summary + metadata` 를 자동으로 받아 최종 결정을 낸다.

### 사람이 개입한다

```bash
hermes kanban show t_root                    # 현황
hermes kanban comment t_sec "이 CVE는 이미 패치됨"
hermes kanban unblock t_qa                   # 막힌 것 풀기
hermes kanban reassign t_ops leo             # 담당 변경
hermes kanban watch --kinds completed,blocked  # 실시간 관찰
```

---

## 5.5 검증된 실행 (2026-07-30)

실제로 끝까지 돌린 기록이다. 안건 하나가 6개 태스크로 분해되어 병렬 검토된 뒤 종합까지 갔다.

```bash
hermes kanban create "FastAPI 전환 검토"   --body "Flask 기반 API 전환안. 비용과 리스크를 판단해달라." --triage
hermes kanban decompose t_4393ad16
```

decomposer가 **프로필 설명을 읽고** 역할별로 배정했다.

| 태스크 | 담당 | 결과 |
| --- | --- | --- |
| 전환 범위와 개발 비용 산정 | `brian` | done |
| 배포·운영 비용과 전환 절차 | `leo` | done |
| 회귀 위험과 검증 계획 | `mia` | done |
| 보안·의존성 위험 | `jack` | done |
| **전제와 낙관적 추정 반박** | `oscar` | done — 위 4개를 부모로 물고 실행 |
| **종합 Go/No-Go** | `lucas` | done — 위 5개를 부모로 물고 실행 |

의존성이 순서를 만들었다. Oscar는 네 검토가 끝난 뒤에야 깨어나 그것들을 읽고 반박했고, Lucas는 다섯 개가 모두 끝난 뒤 종합했다.

### 견제가 실제로 작동했다

넷이 "점진 전환"으로 수렴하자 Oscar가 합의 자체를 공격했다.

> 네 검토가 모두 실제 코드/트래픽을 확인하지 못한 채 점진 공존으로 수렴한 것은 **관성에 가깝다.**
> FastAPI 성능 우위가 입증되지 않았고, 비용 추정은 문서 간 불일치(10~20인주 대 2~5인월)와 이중 운영·제거 비용 누락이 있다.

Lucas는 이를 반영해 결론을 갈랐다.

> FastAPI 전환 자체는 현재 **No-Go**. 인벤토리·기준선(3~5영업일)과 비교 PoC(2~3주)만 Go.
> Flask 유지·최적화는 Go, 제한적 카나리는 계약·보안·QA·운영·복구 게이트를 모두 충족한 뒤 별도 승인.
> 점진적 전체 전환과 전면 전환은 No-Go.

**Oscar가 없었다면 "점진 전환 Go"로 끝났을 안건이다.** 반증 역할을 정식 멤버로 넣은 이유가 여기서 확인된다.

### 산출물

각 워커가 `kanban_attach` 로 근거 문서를 남겼다.

```
fastapi-transition-devils-advocate.md   7,735 bytes  (oscar)
fastapi-go-no-go-decision.md           12,785 bytes  (lucas)
```

`summary` 에는 결론만, 근거는 첨부로 — `_team.md` 의 인계 규칙대로다.

> ⚠ **scratch 작업공간은 완료 시 삭제된다.** 첨부(`kanban_attach`)로 올린 것만 보드에 남는다. 파일 산출물을 보존하려면 `--workspace dir:<절대경로>` 를 쓴다.

---

## 6. 운영

### 관찰

```bash
hermes dashboard                    # GUI — Kanban 탭 · "Lanes by profile" 로 역할별 레인
hermes kanban list --status running
hermes kanban stats
hermes kanban tail t_abcd           # 태스크 하나 추적
hermes kanban log  t_abcd           # 워커 출력 로그
hermes kanban runs t_abcd           # 시도 이력
```

대시보드의 **"Lanes by profile"** 이 In Progress를 담당자별로 나눠 보여준다. 지금 누가 무엇을 하는지 한눈에 보인다.

### 작업 공간

```bash
--workspace scratch                 # 기본. 임시 디렉터리, 완료 시 삭제
--workspace dir:/Users/ethan/dev/myproject    # 공유 디렉터리 (절대경로 필수)
--workspace worktree                # git worktree, 완료 후 보존
```

**검토·설계 성격의 태스크는 `scratch` 로 충분하다.** 실제 코드를 만지는 태스크(Brian, Leo)에만 `dir:` 또는 `worktree` 를 준다.

> 참고: 이 저장소의 작업 원칙상 git worktree는 명시적 요청이 있을 때만 쓴다. 기본은 `scratch` 또는 `dir:`.

### 정리

```bash
hermes kanban archive t_abcd
hermes kanban gc --event-retention-days 30 --log-retention-days 14
```

---

## 7. 자주 걸리는 지점

| 증상 | 원인 | 대응 |
| --- | --- | --- |
| 태스크가 `ready` 에서 안 움직임 | 게이트웨이가 꺼져 있음 (디스패처가 그 안에 있음) | `lucas gateway start` · 급하면 `hermes kanban dispatch` 로 1회 수동 실행 |
| `spawn_failed` 후 자동 차단 | assignee 프로필이 없음 | `hermes profile list` 로 철자 확인. `failure_limit` 회 실패 시 차단됨 |
| 자식이 `todo` 에서 안 올라옴 | 부모가 아직 `done` 아님 | `hermes kanban show <부모>` · 필요하면 `promote` |
| 워커가 응답 없이 오래 감 | 하트비트 없음 | `dispatch_stale_timeout_seconds` (기본 4시간) 후 회수. `kanban log` 로 확인 |
| 한 역할이 여러 태스크를 동시에 잡음 | `max_in_progress_per_profile` 미설정 | `1` 로 설정 |
| 엉뚱한 담당자가 지정됨 | `auto_decompose` 가 켜져 있음 | 끄고 Lucas가 명시 분해하도록 |

---

## 8. 첫 실행 체크리스트

```bash
# 1. 보드
hermes kanban init
hermes kanban boards create bateam --name "BA Team" --icon 🏗 --switch

# 2. 디스패처 설정
hermes config set kanban.orchestrator_profile lucas
hermes config set kanban.default_assignee lucas
hermes config set kanban.max_in_progress_per_profile 1
hermes config set kanban.auto_decompose false

# 3. 게이트웨이 (디스패처 호스트)
lucas gateway start

# 4. 드라이런 — 실제 spawn 없이 무엇이 잡힐지 확인
hermes kanban create "테스트 안건: 팀 소개" --assignee lucas
hermes kanban dispatch --dry-run

# 5. 실제 실행
hermes kanban dispatch
hermes kanban tail <task-id>
```

`--dry-run` 을 먼저 돌리는 것을 습관으로 둘 것. 배정이 잘못된 상태로 10개 워커가 뜨면 되돌리기 번거롭다.

### 게이트웨이 없이 먼저 검증한다

태스크를 만들면 CLI가 이렇게 경고한다.

```
⚠  No gateway is running — the task will sit in 'ready' until you start it.
```

**이 경고를 따라 바로 게이트웨이를 띄우지 말 것.** `hermes kanban dispatch` 가 게이트웨이 없이 **1회성 디스패치**를 수행한다. 순서를 이렇게 나눈다.

| 단계 | 검증 대상 |
| --- | --- |
| 1. `hermes kanban dispatch` (수동) | 보드·배정·워커 spawn·`kanban_*` 툴 호출 |
| 2. `lucas gateway setup` + `start` | Slack 연결과 자동 디스패치 |

동시에 붙이면 실패했을 때 칸반 문제인지 Slack 문제인지 갈리지 않는다. 위 경고는 "자동 반복 디스패치가 없다"는 뜻이지 "지금 실행할 수 없다"는 뜻이 아니다.
