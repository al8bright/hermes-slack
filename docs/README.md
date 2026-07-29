# BA Team on Hermes Agent

[`roles/`](../roles/) 에 정의한 10인 가상 개발팀을 [Hermes Agent](https://hermes-agent.nousresearch.com/docs/) 위에 **프로필 10개**로 구성하고, **Kanban 보드**로 협업시키는 구성 문서다.

---

## 구조

**Hermes에서 프로필 = 에이전트 1개 = `SOUL.md` 1개 = 모델 1개다.** 따라서 역할 10개는 프로필 10개가 된다.

```
~/.hermes/profiles/
├── default/          ← 기존. 손대지 않음 (gpt-5.6-sol)
├── bateam/           ← 템플릿. 여기서 10개를 복제한다. 게이트웨이 미구동
├── lucas/            ← Tech Lead      · 오케스트레이터 · Slack 게이트웨이 보유
├── grace/            ← BA
├── brian/            ← Backend
├── emma/             ← Frontend / UX
├── mia/              ← QA
├── leo/              ← DevOps
├── david/            ← Data
├── aiden/            ← AI
├── jack/             ← Security
└── oscar/            ← Critic

~/.hermes/kanban.db   ← 전 프로필이 공유하는 협업 보드 (board slug: bateam)
~/.local/bin/<name>   ← 프로필마다 자동 생성되는 래퍼 (lucas chat, grace setup …)
```

각 프로필은 자기 `config.yaml`·`.env`·`SOUL.md`·`skills/`·`sessions/`·`memories/` 를 따로 가진다.

## 협업 방식 — Kanban

역할 간 협업은 [Kanban 보드](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban)가 담당한다. 이게 Hermes가 제공하는 다중 프로필 협업 메커니즘이다.

```
사람  ──▶  Slack (#bateam)
             │
             ▼
        lucas 게이트웨이  ── 대화 응답
             │
             ├─ 디스패처 (60초 주기, 게이트웨이 내장)
             │     · ready 태스크를 claim
             │     · assignee 프로필을 워커로 spawn
             │     · 부모 완료 시 자식을 todo → ready 승격
             ▼
        ~/.hermes/kanban.db  (board: bateam)
             │
   ┌─────────┼─────────┬─────────┐
   ▼         ▼         ▼         ▼
 grace     jack      mia      oscar     ← 배정될 때만 기동되는 워커
```

**핵심은 `--assignee`가 프로필명이라는 점이다.** `hermes kanban create "..." --assignee jack` 이면 디스패처가 `jack` 프로필을 워커로 띄운다. 역할 이름을 프로필 이름으로 쓴 이유가 여기에 있다.

## 문서

| 문서 | 내용 |
| --- | --- |
| [setup.md](./setup.md) | 프로필 10개 생성 · `SOUL.md` 배치 · 모델 배정 — **실행 절차** |
| [kanban-workflow.md](./kanban-workflow.md) | 보드 구성 · 오케스트레이터 · 태스크 흐름 · 운영 |
| [gateway-slack.md](./gateway-slack.md) | Slack 연동 전략과 선택지 |
| [archive/](./archive/) | 폐기된 초기 설계 (Hermes를 직접 만든다는 전제) |

## 확정 사항

| 항목 | 결정 | 근거 |
| --- | --- | --- |
| 역할 = 프로필 | 프로필 10개 | 프로필당 `SOUL.md`·모델이 하나뿐이므로 역할별 모델 차등의 유일한 방법 |
| 페르소나 | `roles/*.md` → 각 프로필 `SOUL.md` | `SOUL.md`가 시스템 프롬프트 슬롯 #1 |
| 템플릿 | `bateam` 프로필에서 `--clone-from` | 이미 Codex 인증·스킬·터미널 백엔드가 설정됨 |
| 협업 | Kanban 보드 (slug `bateam`) | `assignee` = 프로필명. Hermes 기본 제공 |
| 오케스트레이터 | `lucas` | Tech Lead 역할과 `kanban.orchestrator_profile` 의미가 일치 |
| 게이트웨이 | `lucas` 1개로 시작 | Slack 앱 1개. 디스패처가 게이트웨이에 내장되므로 최소 1개는 필요 |
| `default` 프로필 | 건드리지 않음 | — |

## 미결 사항

착수 전 확인이 필요한 항목이다. 상세는 각 문서에 표시했다.

1. **`roles/*.md` 를 맥으로 옮기는 방법** — 현재 이 저장소는 Windows(`P:\html\hermes`)에 있고 Hermes는 맥에 있다. git 저장소로 만들어 클론할지, 직접 복사할지 결정 필요.
2. **Codex OAuth 복제 여부** — `--clone` 은 `config.yaml`·`.env`·`SOUL.md`·`skills` 를 복사한다고 문서화되어 있으나 `auth.json`(OAuth 자격증명) 포함 여부가 불명확하다. 복제되지 않으면 프로필마다 재인증이 필요하다. ([setup.md §3](./setup.md))
3. **사용 가능한 모델 목록** — 현재 인증된 공급사는 OpenAI Codex뿐이다. 역할별 모델 차등을 실제로 하려면 Codex가 제공하는 모델 목록을 먼저 확인해야 한다. ([setup.md §5](./setup.md))
4. **`temperature` 등 샘플링 파라미터를 프로필별로 지정할 수 있는가** — 가능하면 성향 차이를 수치로도 반영한다. 불가하면 `SOUL.md` 서술로만 표현한다.
5. **Slack 앱을 몇 개 발급할 수 있는가** — 워크스페이스 정책에 따라 게이트웨이 전략이 갈린다. ([gateway-slack.md](./gateway-slack.md))

## 제약

- **Kanban은 단일 호스트 전용이다.** `~/.hermes/kanban.db` 는 로컬 SQLite이고 워커 PID도 로컬이다. 맥 한 대에서만 돌아간다.
- **워커는 CLI를 보지 못한다.** 디스패처가 띄운 워커는 `kanban_*` 툴로만 보드를 조작한다.
- **프로필 10개가 동시에 상주하지는 않는다.** 게이트웨이를 켠 프로필만 상주하고, 나머지는 태스크가 배정될 때 기동되었다가 종료된다.
