# BA Team on Hermes Agent

[`roles/`](../roles/) 에 정의한 10인 가상 개발팀을 [Hermes Agent](https://hermes-agent.nousresearch.com/docs/) 위에 **프로필 10개**로 구성하고, **Kanban 보드**로 협업시키는 구성 문서다.

---

## 구조

**Hermes에서 프로필 = 에이전트 1개 = `SOUL.md` 1개 = 모델 1개다.** 따라서 역할 10개는 프로필 10개가 된다.

```
~/.hermes/profiles/
├── default/          ← 기존. 손대지 않음 (gpt-5.6-sol)
├── bateam/           ← 템플릿. 여기서 10개를 복제한다
├── lucas/            ← Tech Lead · 조율자 · Slack 게이트웨이 보유
├── grace/            ← BA
├── brian/            ← Backend
├── emma/             ← Frontend / UX
├── mia/              ← QA
├── leo/              ← DevOps
├── david/            ← Data
├── aiden/            ← AI
├── jack/             ← Security
└── oscar/            ← Critic

~/.local/bin/<name>   ← 프로필마다 자동 생성되는 래퍼 (lucas chat, grace setup …)
```

각 프로필은 자기 `config.yaml`·`.env`·`SOUL.md`·`skills/`·`sessions/`·`memories/` 를 따로 가진다.

## 협업 방식 — Kanban

역할 간 협업은 [Kanban 보드](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban)가 담당한다. **태스크의 `--assignee` 가 프로필명**이고, 디스패처가 해당 프로필을 워커 프로세스로 기동한다. 역할 이름을 프로필 이름으로 쓴 이유가 여기 있다.

```
사람  ──▶  hermes kanban create "..." --assignee lucas
             │
             ▼
        lucas 게이트웨이 (디스패처 내장 · 60초 tick)
             │  ready 태스크 claim → assignee 프로필을 워커로 spawn
             │  부모 완료 시 자식을 todo → ready 승격
             ▼
   ┌─────────┼─────────┬─────────┐
   ▼         ▼         ▼         ▼
 jack      mia       leo      oscar    ← 각자 kanban_show() 로 시작, kanban_complete() 로 인계
   └─────────┴────┬────┴─────────┘
                  ▼
                lucas  ← 종합 (자식들의 summary·metadata 자동 전달)
```

상세는 [kanban-workflow.md](./kanban-workflow.md).

가벼운 질의(회의를 열 정도는 아닌 것)에는 [`ask-team.sh`](../scripts/ask-team.sh) 로 여러 역할에 직접 물어보는 편이 빠르다 — [team-workflow.md](./team-workflow.md).

## 문서

| 문서 | 내용 |
| --- | --- |
| [setup.md](./setup.md) | 프로필 10개 생성 · `SOUL.md` 배치 · 모델 배정 — **실행 절차** |
| [kanban-workflow.md](./kanban-workflow.md) | Kanban 보드 협업 — 보드 구성 · 오케스트레이터 · 태스크 흐름 |
| [team-workflow.md](./team-workflow.md) | 역할별 개별 대화 (칸반 없이 가볍게 물을 때) |
| [slack-setup.md](./slack-setup.md) | Slack 앱 발급 · 권한 · 토큰 · 이벤트 구독 — **실행 절차** |
| [gateway-slack.md](./gateway-slack.md) | Slack 연동 전략과 선택지 (앱을 몇 개 둘 것인가) |
| [archive/](./archive/) | 폐기된 초기 설계 (Hermes를 직접 만든다는 전제였음) |

## 스크립트

| 스크립트 | 용도 |
| --- | --- |
| [`install-souls.sh`](../scripts/install-souls.sh) | `roles/*.md` → 각 프로필 `SOUL.md` 설치 |
| [`set-models.sh`](../scripts/set-models.sh) | [`config/models.conf`](../config/models.conf) 대로 역할별 모델 배정 |
| [`set-descriptions.sh`](../scripts/set-descriptions.sh) | [`config/descriptions.conf`](../config/descriptions.conf) 대로 프로필 설명 설정 — **decomposer 라우팅의 전제** |
| [`ask-team.sh`](../scripts/ask-team.sh) | 여러 역할에 병렬 질의 · 취합 · Lucas 종합 |

## 확정 사항

| 항목 | 결정 | 근거 |
| --- | --- | --- |
| 역할 = 프로필 | 프로필 10개 | 프로필당 `SOUL.md`·모델이 하나뿐이므로 역할별 모델 차등의 유일한 방법 |
| 페르소나 | `roles/*.md` → 각 프로필 `SOUL.md` | `SOUL.md` 가 시스템 프롬프트 슬롯 #1 |
| 템플릿 | `bateam` 프로필에서 `--clone-from` | Codex 인증·스킬·터미널 백엔드를 상속 |
| 협업 | Kanban 보드 (slug `bateam`) | `assignee` = 프로필명. **전 구간 검증 완료** ([kanban-workflow.md §5.5](./kanban-workflow.md)) |
| 조율자 | `lucas` | 분해와 종합. `kanban.orchestrator_profile` |
| 게이트웨이 | `lucas` 1개 | Slack 앱 1개 |
| `default` 프로필 | 건드리지 않음 | — |

## 실측으로 확인된 것

구축 과정에서 문서에 없던 사실들이다.

| 항목 | 사실 |
| --- | --- |
| `config set model` | `model` 은 `{default, provider, base_url}` 딕셔너리다. 스칼라로 덮으면 프로필이 죽는다. `model.default` 를 써야 한다 ([setup.md §5.1](./setup.md)) |
| `hermes setup` | 현재 기본 프로필(`◆`)을 설정한다. 특정 프로필은 `<alias> setup` |
| `kanban.*` 설정 | 전역 `~/.hermes/config.yaml` 과 프로필 `config.yaml` 양쪽에 쓸 수 있다 |
| 칸반 보드 DB | 보드마다 별도 파일 (`~/.hermes/kanban/boards/<slug>/kanban.db`) |
| `SOUL.md` 차단 | Hermes 는 `SOUL.md` 를 시스템 프롬프트에 넣기 전 인젝션 스캔을 돌리고, **패턴 하나만 걸려도 파일 전체를 차단**한다. ZWJ 이모지(`👨‍💼` = `👨`+U+200D+`💼`) 하나로 Lucas 페르소나가 통째로 사라졌다. `install-souls.sh` 가 보이지 않는 유니코드를 제거한다 |
| decomposer 라우팅 | 프로필 **설명**(`profile.yaml`)을 읽고 배정한다. 설명이 없으면 전부 `default_assignee` 로 떨어진다 |
| 칸반 워커 툴 | **정상 동작.** 단 `hermes chat` + `HERMES_KANBAN_TASK` 로는 검증되지 않는다 — chat 모드와 디스패처 spawn 경로의 툴 등록이 다르다. 실제 태스크를 dispatch 해서 `kanban show <id>` 이벤트로 확인할 것 |

## 검증 완료 (2026-07-30)

안건 1개 → 역할별 6개 분해 → 병렬 검토 → 의존성 순서 → 종합 결정까지 실제로 돌았다. Oscar의 반박이 Lucas의 결론을 바꾼 것까지 확인했다 — [kanban-workflow.md §5.5](./kanban-workflow.md).

남은 것은 **Slack 게이트웨이 연결**뿐이다 — 절차는 [slack-setup.md](./slack-setup.md), 전략은 [gateway-slack.md](./gateway-slack.md).

## 미결 사항

1. **Codex OAuth 복제 여부** — `--clone-from` 이 `auth.json` 을 포함하는지 미확인. 프로필별 재인증이 필요할 수 있다.
2. **역할별 모델 차등** — 현재 인증 공급사가 OpenAI Codex뿐이라 `gpt-5.6-sol` / `terra` / `luna` 세 가지로만 나뉜다. OpenRouter를 붙이면 선택지가 넓어진다 ([setup.md §5.2](./setup.md)).
3. **`temperature` 프로필별 지정 가능 여부** — 가능하면 성향을 수치로도 반영한다.
4. **Slack 앱 발급 가능 수** — 게이트웨이 전략이 여기에 달렸다 ([gateway-slack.md](./gateway-slack.md)).
5. **`AGENTS.md` 컨텍스트 잘림** — `74568 chars exceeds limit of 65280` 경고. `context_file_max_chars` 를 올리거나 파일을 줄여야 한다.
6. **scratch 작업공간 보존** — 검토 성격의 태스크는 첨부로 충분하지만, 코드를 만지는 태스크에는 `--workspace dir:<절대경로>` 가 필요하다.
