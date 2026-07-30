# 팀 운영 — 역할별 개별 대화

> 상위 문서: [README.md](./README.md) · 선행: [01-setup.md](./01-setup.md)
>
> 이전 방식([archive/02-kanban-workflow.md](./02-kanban-workflow.md))은 Hermes v0.19.0에서 칸반 워커에게 `kanban_*` 툴이 노출되지 않아 보류했다.

---

## 1. 구조

**자동 팬아웃 대신 사람이 조율한다.** 프로필 10개·페르소나·역할별 모델은 그대로 살아 있고, 태스크를 주고받는 부분만 사람과 스크립트가 맡는다.

```
        사람
         │
    ① 안건 제시
         ▼
   ┌──────────┐
   │  lucas   │  분해안: 누구에게 무엇을 물을지
   └────┬─────┘
        │ ② 사람이 목록대로 질의 (ask-team.sh 가 병렬 처리)
   ┌────┴────┬────────┬────────┐
   ▼         ▼        ▼        ▼
 jack      mia      leo     oscar     ← 각자 자기 관점으로만 답변
   └────┬────┴────────┴────────┘
        │ ③ 답변을 모아서
        ▼
   ┌──────────┐
   │  lucas   │  종합 · 결정
   └──────────┘
```

칸반과 비교하면 이렇다.

| | 칸반 (보류) | 개별 대화 (현행) |
| --- | --- | --- |
| 역할별 모델 차등 | ✅ | ✅ |
| 페르소나 | ✅ | ✅ |
| 병렬 실행 | ✅ | ✅ (스크립트) |
| 팬아웃 지시 | Lucas가 `kanban_create` | Lucas가 분해안 제시 → 사람이 실행 |
| 결과 인계 | `kanban_complete(summary)` 자동 | 파일로 취합 |
| 이력 · 재시작 내성 | SQLite에 durable | `reviews/` 디렉터리 |
| 의존성 순서 제어 | 디스패처가 자동 | 사람이 순서 결정 |

**잃은 것은 자동화지 능력이 아니다.** 각 역할이 자기 성향으로 판단하고 서로 견제한다는 원래 목표는 그대로다.

---

## 2. 기본 흐름

### ① 분해안 받기

```bash
./scripts/ask-team.sh --plan "Flask 기반 API를 FastAPI로 전환하는 안"
```

Lucas가 직접 답하지 않고 누구에게 무엇을 물을지 제시한다.

```
검토가 필요한 항목

  jack   — 권한 모델 변경 여부와 신규 의존성의 공급망 위험
  mia    — 기존 동작 회귀를 어떻게 증명할 것인가
  leo    — 무중단 전환 경로와 롤백 절차
  grace  — 현업 업무 흐름에 생기는 변화와 예외 상황
  oscar  — 이 전환을 하지 않는 선택지

먼저 물을 것: jack, leo
```

### ② 병렬 질의

```bash
./scripts/ask-team.sh --roles jack,mia,leo,grace,oscar \
  "Flask 기반 API를 FastAPI로 전환하려 한다. 네 관점에서 검토해줘."
```

```
질문:  Flask 기반 API를 FastAPI로 전환하려 한다. 네 관점에서 검토해줘.
대상:  jack mia leo grace oscar
출력:  reviews/20260729-181203-Flask-기반-API를-FastAPI로

  ✓ jack   (1204 bytes)
  ✓ mia    (982 bytes)
  ✓ leo    (1130 bytes)
  ✓ grace  (1341 bytes)
  ✓ oscar  (1508 bytes)

취합: reviews/20260729-181203-.../_모음.md
```

### ③ 종합

```bash
./scripts/ask-team.sh --roles jack,mia,leo,grace,oscar --synthesize \
  "Flask 기반 API를 FastAPI로 전환하려 한다. 네 관점에서 검토해줘."
```

`--synthesize` 를 붙이면 답변을 모아 Lucas에게 넘기고 결정까지 받는다. 결과는 `_종합-lucas.md` 로 저장된다.

### 전원에게

```bash
./scripts/ask-team.sh --all "이번 분기 기술 부채 중 무엇을 먼저 갚아야 할까?"
```

`--all` 은 Lucas를 제외한 9명이다. Lucas는 종합하는 쪽이므로 검토 대상에 넣지 않는다.

---

## 3. 개별 대화

한 명과 길게 논의할 때는 그냥 그 역할과 대화한다.

```bash
grace chat                                    # 대화형 세션
jack  chat -q "외부 결제 API를 붙이려 한다"     # 일회성
mia   chat -q "이 변경 배포해도 될까?"
```

이전 대화를 이어가려면 세션을 재개한다.

```bash
hermes --resume <session-id> -p grace
hermes sessions browse                        # 세션 고르기
```

---

## 4. 다른 역할의 의견을 물려주기

한 역할의 답을 다른 역할에게 반박시키는 것이 이 팀 구성의 핵심이다. Oscar에게 특히 유용하다.

```bash
DIR=reviews/20260729-181203-Flask-기반-API를-FastAPI로

oscar chat -q "아래는 팀의 검토 의견이다. 전제를 반박해라.

$(cat $DIR/_모음.md)"
```

```bash
# Brian의 제안에 Jack이 답하게
jack chat -q "Brian의 의견이다. 보안 관점에서 검토해라.

$(cat $DIR/brian.md)"
```

`_team.md` 에 "다른 역할의 의견이 함께 주어지면 그것을 근거로 네 입장을 낸다"를 넣어뒀으므로, 이 형식이 그대로 먹는다.

---

## 5. 결과 보관

```
reviews/
└── 20260729-181203-Flask-기반-API를-FastAPI로/
    ├── 00-질문.md
    ├── jack.md
    ├── mia.md
    ├── leo.md
    ├── grace.md
    ├── oscar.md
    ├── _모음.md            ← 전체 취합
    └── _종합-lucas.md      ← 최종 결정
```

**이게 칸반의 `task_events` 를 대신한다.** 언제 무엇을 물었고 누가 뭐라 했는지가 파일로 남는다. 저장소에 커밋하면 이력이 git에도 남는다.

---

## 6. 한계

| 한계 | 대응 |
| --- | --- |
| 의존성 순서를 사람이 판단해야 함 | Lucas 분해안의 "먼저 물을 것" 을 따른다 |
| 역할이 스스로 다른 역할을 부를 수 없음 | 답변에서 담당자를 지목하게 하고 사람이 이어받는다 (`_team.md` 에 명시) |
| 중간 상태가 남지 않음 | `reviews/` 디렉터리가 그 역할을 한다 |
| 장시간 작업 추적 없음 | 현재 범위(검토·판단)에서는 필요 없다 |

---

## 7. 칸반으로 돌아가려면

Hermes에서 워커 툴 노출 문제가 해결되면 [archive/02-kanban-workflow.md](./02-kanban-workflow.md) 로 복귀한다. 그 문서 상단에 조사 결과(게이트 함수·설정 경로·실패한 시도 4가지)를 정리해 뒀다.

확인 방법:

```bash
hermes update
HERMES_KANBAN_TASK=<임의의-태스크-id> hermes -p lucas chat -q "kanban_show 를 호출해라"
```

툴 호출이 찍히면 복귀 가능하다. 프로필·페르소나·모델 설정은 그대로 재사용되고, `roles/_team.md` 와 `roles/_orchestrator.md` 의 협업 지침만 칸반 버전으로 되돌리면 된다.
