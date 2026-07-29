# hermes-slack

역할과 성향을 분리한 **10인 가상 개발팀(BA Team)** 을 [Hermes Agent](https://hermes-agent.nousresearch.com/docs/) 위에 프로필 10개로 구성하고, Kanban 보드로 협업시키기 위한 저장소다.

이 저장소는 **페르소나 정의와 구축 문서**를 담는다. 실행 코드는 없다 — Hermes Agent가 런타임을 전부 제공한다.

---

## 구성

```
roles/          페르소나 정의 10개 → 각 Hermes 프로필의 SOUL.md 원본
docs/           구축·운영 문서
  ├ setup.md            프로필 10개 생성 절차
  ├ kanban-workflow.md  Kanban 보드 협업
  ├ team-workflow.md    역할별 개별 대화 (가벼운 질의)
  ├ gateway-slack.md    Slack 연동 전략
  └ archive/            보류·폐기된 설계
scripts/        install-souls.sh · set-models.sh · ask-team.sh
config/         models.conf — 역할별 모델 배정
ai-development-team.md  팀 구성 원안
```

| 프로필 | 역할 | 성향 |
| --- | --- | --- |
| `lucas` | Tech Lead | 균형형 · 조율자 — **분해안 제시 · 종합** |
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

역할 간 협업은 **Kanban 보드**가 담당한다. 태스크의 `--assignee` 가 프로필명이고, 디스패처가 해당 프로필을 워커로 기동한다 — [docs/kanban-workflow.md](./docs/kanban-workflow.md).

가벼운 질의에는 `scripts/ask-team.sh` 로 여러 역할에 직접 물어보는 편이 빠르다 — [docs/team-workflow.md](./docs/team-workflow.md).

## 맥에서 시작하기

```bash
git clone git@github-al8bright:al8bright/hermes-slack.git ~/dev/hermes-slack
cd ~/dev/hermes-slack
```

이후 [`docs/setup.md`](./docs/setup.md) 를 순서대로 따른다. 요약하면:

```bash
# 1. 템플릿 프로필 확인 (bateam 이 이미 설정된 상태를 가정)
hermes profile list

# 2. 역할 프로필 10개 생성
for id in lucas grace brian emma mia leo david aiden jack oscar; do
  hermes profile create "$id" --clone-from bateam
done

# 3. 페르소나 설치 — roles/*.md → 각 프로필 SOUL.md
./scripts/install-souls.sh --dry-run
./scripts/install-souls.sh

# 4. 역할별 모델 배정 — config/models.conf 편집 후
./scripts/set-models.sh --dry-run
./scripts/set-models.sh

# 5. 동작 확인
for id in $(awk '!/^#/ && $1!~/^@/ && NF {print $1}' config/models.conf); do
  printf '%-8s ' "$id"; hermes -p "$id" chat -q '1+1은?' 2>&1 | tail -1
done
```

## 쓰는 법

```bash
# 안건 분해안 받기
./scripts/ask-team.sh --plan "Flask API를 FastAPI로 전환하는 안"

# 역할별 병렬 검토 + Lucas 종합
./scripts/ask-team.sh --roles jack,mia,leo,grace,oscar --synthesize   "Flask API를 FastAPI로 전환하려 한다. 네 관점에서 검토해줘."

# 개별 대화
grace chat
jack  chat -q "외부 결제 API를 붙이려 한다"
```

결과는 `reviews/<타임스탬프>-<슬러그>/` 에 역할별 파일로 남는다. 상세는 [`docs/team-workflow.md`](./docs/team-workflow.md).

## 착수 전 확인 필요

1. **Codex OAuth 복제 여부** — `--clone-from` 이 `auth.json` 을 포함하는지 불명확. 복제되지 않으면 프로필마다 재인증 필요
2. **사용 가능한 모델 목록** — 현재 인증된 공급사는 OpenAI Codex뿐. 역할별 모델 차등이 가능한지 `hermes model` 로 확인
3. **Slack 앱 발급 가능 수** — 게이트웨이 전략이 여기에 달림 ([`docs/gateway-slack.md`](./docs/gateway-slack.md))

## 제약

- **프로필은 상주하지 않는다.** 게이트웨이를 켠 프로필만 상주하고, 나머지는 질의할 때 기동되었다가 종료된다.
- **역할이 스스로 다른 역할을 부를 수 없다.** 답변에서 담당자를 지목하면 사람이 이어받는다.
- **`config set model` 을 쓰면 안 된다.** `model` 은 딕셔너리라 스칼라로 덮으면 프로필이 죽는다. `model.default` 를 쓰거나 `scripts/set-models.sh` 를 쓴다.
