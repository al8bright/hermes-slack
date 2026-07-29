# BA Team on Hermes Agent

[`roles/`](../roles/) 에 정의한 10인 가상 개발팀을 [Hermes Agent](https://hermes-agent.nousresearch.com/docs/) 위에 **프로필 10개**로 구성하고, 역할별 개별 대화로 협업시키는 구성 문서다.

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

## 협업 방식 — 역할별 개별 대화

```
        사람
         │
    ① 안건 제시            ./scripts/ask-team.sh --plan "..."
         ▼
   ┌──────────┐
   │  lucas   │  분해안: 누구에게 무엇을 물을지
   └────┬─────┘
        │ ② 병렬 질의       ./scripts/ask-team.sh --roles jack,mia,leo "..."
   ┌────┴────┬────────┬────────┐
   ▼         ▼        ▼        ▼
 jack      mia      leo     oscar     ← 각자 자기 관점으로만 답변
   └────┬────┴────────┴────────┘
        │ ③ 종합            --synthesize
        ▼
   ┌──────────┐
   │  lucas   │  충돌 정리 · 결정
   └──────────┘
```

결과는 `reviews/<타임스탬프>-<슬러그>/` 에 역할별 파일로 남는다. 상세는 [team-workflow.md](./team-workflow.md).

> Hermes의 [Kanban 보드](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban)로 자동 협업시키는 방식을 먼저 시도했으나, v0.19.0에서 **칸반 워커에게 `kanban_*` 툴이 노출되지 않아** 보류했다. 조사 결과와 복귀 조건은 [archive/kanban-workflow.md](./archive/kanban-workflow.md) 상단에 있다.

## 문서

| 문서 | 내용 |
| --- | --- |
| [setup.md](./setup.md) | 프로필 10개 생성 · `SOUL.md` 배치 · 모델 배정 — **실행 절차** |
| [team-workflow.md](./team-workflow.md) | 역할별 개별 대화로 팀을 운영하는 방법 |
| [gateway-slack.md](./gateway-slack.md) | Slack 연동 전략과 선택지 |
| [archive/](./archive/) | 보류·폐기된 설계 (칸반 방식, 초기 자체구현 설계) |

## 스크립트

| 스크립트 | 용도 |
| --- | --- |
| [`install-souls.sh`](../scripts/install-souls.sh) | `roles/*.md` → 각 프로필 `SOUL.md` 설치 |
| [`set-models.sh`](../scripts/set-models.sh) | [`config/models.conf`](../config/models.conf) 대로 역할별 모델 배정 |
| [`ask-team.sh`](../scripts/ask-team.sh) | 여러 역할에 병렬 질의 · 취합 · Lucas 종합 |

## 확정 사항

| 항목 | 결정 | 근거 |
| --- | --- | --- |
| 역할 = 프로필 | 프로필 10개 | 프로필당 `SOUL.md`·모델이 하나뿐이므로 역할별 모델 차등의 유일한 방법 |
| 페르소나 | `roles/*.md` → 각 프로필 `SOUL.md` | `SOUL.md` 가 시스템 프롬프트 슬롯 #1 |
| 템플릿 | `bateam` 프로필에서 `--clone-from` | Codex 인증·스킬·터미널 백엔드를 상속 |
| 협업 | 역할별 개별 대화 + `ask-team.sh` | 칸반 워커 툴 노출 문제로 보류 |
| 조율자 | `lucas` | 분해안 제시와 종합을 맡는다. 검토 대상에서는 제외 |
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
| 칸반 워커 툴 | **노출되지 않음** — nudge는 뜨는데 툴이 없다. 제품 불일치로 보임 |

## 미결 사항

1. **Codex OAuth 복제 여부** — `--clone-from` 이 `auth.json` 을 포함하는지 미확인. 프로필별 재인증이 필요할 수 있다.
2. **역할별 모델 차등** — 현재 인증 공급사가 OpenAI Codex뿐이라 `gpt-5.6-sol` / `terra` / `luna` 세 가지로만 나뉜다. OpenRouter를 붙이면 선택지가 넓어진다 ([setup.md §5.2](./setup.md)).
3. **`temperature` 프로필별 지정 가능 여부** — 가능하면 성향을 수치로도 반영한다.
4. **Slack 앱 발급 가능 수** — 게이트웨이 전략이 여기에 달렸다 ([gateway-slack.md](./gateway-slack.md)).
5. **`AGENTS.md` 컨텍스트 잘림** — `74568 chars exceeds limit of 65280` 경고. `context_file_max_chars` 를 올리거나 파일을 줄여야 한다.
