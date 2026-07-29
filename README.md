# hermes-slack

역할과 성향을 분리한 **10인 가상 개발팀(BA Team)** 을 [Hermes Agent](https://hermes-agent.nousresearch.com/docs/) 위에 프로필 10개로 구성하고, Kanban 보드로 협업시키며 Slack에서 대화하기 위한 저장소다.

이 저장소는 **페르소나 정의와 구축 문서**를 담는다. 실행 코드는 없다 — Hermes Agent가 런타임을 전부 제공한다.

---

## 구성

```
roles/          페르소나 정의 10개 → 각 Hermes 프로필의 SOUL.md 원본
docs/           구축·운영 문서
  ├ setup.md            프로필 10개 생성 절차
  ├ kanban-workflow.md  팀 협업 운영
  ├ gateway-slack.md    Slack 연동 전략
  └ archive/            폐기된 초기 설계 (Hermes를 직접 만든다는 전제였음)
ai-development-team.md  팀 구성 원안
```

| 프로필 | 역할 | 성향 |
| --- | --- | --- |
| `lucas` | Tech Lead | 균형형 · 조율자 — **오케스트레이터** |
| `grace` | BA | 보수적 · 정책 중심 |
| `brian` | Backend | 진보적 · 기술 혁신 |
| `emma` | Frontend / UX | 창의적 · 사용자 경험 중심 |
| `mia` | QA | 보수적 · 검증 중심 |
| `leo` | DevOps | 현실주의 · 자동화 중심 |
| `david` | Data | 객관적 · 데이터 중심 |
| `aiden` | AI | 실험적 · 미래 지향 |
| `jack` | Security | 매우 보수적 · 위험 회피 |
| `oscar` | Critic | 회의적 · 반증 중심 |

## 전제

**Hermes에서 프로필 = 에이전트 1개 = `SOUL.md` 1개 = 모델 1개다.** 따라서 역할 10개는 프로필 10개가 된다. 하나의 프로필 안에 여러 페르소나를 두는 구조는 제품이 지원하지 않는다.

역할 간 협업은 [Kanban 보드](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban)가 담당한다. 태스크의 `--assignee` 가 프로필명이고, 디스패처가 해당 프로필을 워커로 기동한다.

## 맥에서 시작하기

```bash
git clone git@github.com:al8bright/hermes-slack.git ~/dev/hermes-slack
cd ~/dev/hermes-slack
export BATEAM_SRC=$PWD
```

이후 [`docs/setup.md`](./docs/setup.md) 를 순서대로 따른다. 요약하면:

```bash
# 1. 템플릿 프로필 준비 (이미 완료된 상태를 가정)
hermes profile list                      # bateam 확인

# 2. 역할 프로필 10개 생성
for id in lucas grace brian emma mia leo david aiden jack oscar; do
  hermes profile create "$id" --clone-from bateam
done

# 3. SOUL.md 배치 — docs/setup.md §4 참조 (그대로 복사하면 안 됨)

# 4. Kanban 보드
hermes kanban init
hermes kanban boards create bateam --name "BA Team" --icon 🏗 --switch
hermes config set kanban.orchestrator_profile lucas
hermes config set kanban.auto_decompose false

# 5. Slack 게이트웨이 (lucas 하나만)
lucas gateway setup
lucas gateway install && lucas gateway start
```

각 단계의 검증 방법과 실패 지점은 [`docs/setup.md`](./docs/setup.md) 에 있다.

## 착수 전 확인 필요

1. **Codex OAuth 복제 여부** — `--clone-from` 이 `auth.json` 을 포함하는지 불명확. 복제되지 않으면 프로필마다 재인증 필요
2. **사용 가능한 모델 목록** — 현재 인증된 공급사는 OpenAI Codex뿐. 역할별 모델 차등이 가능한지 `hermes model` 로 확인
3. **Slack 앱 발급 가능 수** — 게이트웨이 전략이 여기에 달림 ([`docs/gateway-slack.md`](./docs/gateway-slack.md))

## 제약

- **Kanban은 단일 호스트 전용이다.** `~/.hermes/kanban.db` 는 로컬 SQLite. 맥 한 대에서만 동작한다.
- **프로필 10개가 동시에 상주하지 않는다.** 게이트웨이를 켠 프로필만 상주하고, 나머지는 태스크 배정 시 기동되었다가 종료된다.
