# 구축 절차 — 프로필 10개

> 대상: macOS · Hermes Agent 설치 완료 · `bateam` 프로필 생성 및 `bateam setup` 완료 상태
>
> 상위 문서: [README.md](./README.md)

각 단계는 **확인 → 실행 → 검증** 순으로 되어 있다. 앞 단계 검증이 통과하지 않으면 다음으로 넘어가지 말 것.

---

## 0. 사전 확인

```bash
hermes profile list
hermes doctor
```

기대 상태:

```
 Profile          Model                        Gateway      Alias
 ◆default         gpt-5.6-sol                  stopped      —
  bateam          gpt-5.6-terra                stopped      bateam
```

`bateam` 이 템플릿이 된다. **이 프로필에는 게이트웨이를 붙이지 않는다.** 복제 원본으로만 쓴다.

---

## 1. `roles/*.md` 를 맥으로 옮긴다

페르소나 문서 10개가 각 프로필의 `SOUL.md` 원본이 된다. 현재 이 저장소는 Windows(`P:\html\hermes`)에 있으므로 맥으로 가져와야 한다.

**권장: git 저장소로 만들어 클론.** 이후 페르소나를 고칠 때마다 복사할 필요가 없고, 변경 이력이 남는다.

```bash
# 맥에서
git clone <repo-url> ~/dev/hermes-bateam
cd ~/dev/hermes-bateam
ls roles/          # 10개 확인
```

저장소를 만들지 않는다면 `scp`·클라우드 드라이브·복사 붙여넣기 무엇이든 상관없다. 이후 명령은 **`~/dev/hermes-bateam`** 에 있다고 가정한다.

```bash
export BATEAM_SRC=~/dev/hermes-bateam
```

> **미결** — 저장소로 관리할지 결정 필요. 페르소나는 계속 다듬게 되므로 저장소를 권한다.

---

## 2. 템플릿 점검

복제 전에 `bateam` 이 원하는 기본 상태인지 확인한다. **여기서 잘못되면 10개 프로필에 그대로 복제된다.**

```bash
bateam config          # 현재 설정 확인
bateam doctor
```

확인할 것:

| 항목 | 기대 | 조정 명령 |
| --- | --- | --- |
| 모델 | `gpt-5.6-terra` | `bateam setup model` |
| 터미널 백엔드 | `local` | `bateam setup terminal` |
| 툴셋 | 최소 baseline (file, terminal) | `bateam setup tools` |
| 스킬 | 70개 동기화됨 | `bateam skills list` |

**툴셋을 지금 정해두는 편이 낫다.** 역할별로 필요한 툴이 다르지만(Brian은 코드 실행, David는 데이터 분석), 공통분모를 템플릿에 넣고 개별 프로필에서 추가하는 쪽이 10번 반복하는 것보다 낫다.

역할 수행에 최소한 필요할 것으로 보이는 것:

```bash
bateam setup tools     # 대화형
# 또는 개별 확인
bateam tools
```

> 현재 `Web Search & Extract`(EXA/TAVILY 등)와 `Skills Hub`(GITHUB_TOKEN)가 미설정 상태다. 팀이 조사·검색을 해야 한다면 여기서 채워두는 게 좋다. 10개 복제 후에 채우면 10번 해야 한다.

---

## 3. 프로필 10개 생성

```bash
for id in lucas grace brian emma mia leo david aiden jack oscar; do
  hermes profile create "$id" --clone-from bateam
done

hermes profile list
```

`--clone-from <source>` 가 지정한 프로필의 `config.yaml`·`.env`·`SOUL.md`·`skills` 를 복사한다. 세션과 메모리는 새로 시작한다.

전체(메모리·cron 포함)를 복제하려면 `--clone-from bateam --clone-all` 을 쓰지만, **여기서는 쓰지 않는다.** 역할마다 메모리가 독립적이어야 한다.

### 검증

```bash
hermes profile list        # 12개 (default, bateam, 역할 10)
ls ~/.local/bin/           # lucas grace brian … 래퍼 10개
lucas config               # 모델이 gpt-5.6-terra 로 상속됐는지
```

### ⚠ 인증 확인 — 실패 가능 지점

`--clone` 계열이 복사하는 파일 목록에 **`auth.json`(OAuth 자격증명)이 명시되어 있지 않다.** Codex는 API 키가 아니라 OAuth 로그인이므로, 복제된 프로필이 인증을 물려받지 못했을 수 있다.

```bash
lucas doctor
lucas chat -q "안녕"      # 실제 호출로 확인
```

인증 오류가 나면 프로필마다 한 번씩 재인증한다.

```bash
for id in lucas grace brian emma mia leo david aiden jack oscar; do
  echo "=== $id ==="
  "$id" setup model
done
```

> **미결** — `--clone-from` 이 `auth.json` 을 포함하는지 실제 확인 필요. 포함되면 위 재인증 루프는 불필요하다.

---

## 4. `SOUL.md` 배치

각 프로필의 `SOUL.md` 가 시스템 프롬프트 **슬롯 #1**, 즉 그 에이전트의 정체성이다. `roles/*.md` 를 여기에 넣는다.

```bash
declare -A SOUL=(
  [lucas]=lucas-tech-lead.md
  [grace]=grace-business-analyst.md
  [brian]=brian-backend.md
  [emma]=emma-frontend.md
  [mia]=mia-qa.md
  [leo]=leo-devops.md
  [david]=david-data-analyst.md
  [aiden]=aiden-ai-engineer.md
  [jack]=jack-security.md
  [oscar]=oscar-devils-advocate.md
)

for id in "${(@k)SOUL}"; do
  cp "$BATEAM_SRC/roles/${SOUL[$id]}" ~/.hermes/profiles/$id/SOUL.md
done
```

> zsh 기준이다. bash면 `"${!SOUL[@]}"` 로 바꾼다.

### 그대로 복사하면 안 되는 부분

`roles/*.md` 는 사람이 읽는 문서로 썼기 때문에 두 군데를 손봐야 한다.

**① 상대 링크가 깨진다.** `[Brian](./brian-backend.md)` 같은 링크는 프로필 디렉터리에서 의미가 없다. 이름만 남기거나 프로필명으로 바꾼다.

**② 팀 협업 지침이 없다.** 각 에이전트는 자기가 팀의 일원이고, Kanban으로 일을 주고받는다는 걸 알아야 한다. 아래를 `SOUL.md` 끝에 공통으로 덧붙인다.

```markdown
---

## 팀

너는 BA Team의 일원이다. 동료는 다음과 같고, 각자 프로필 이름으로 호출된다.

| 프로필 | 역할 | 성향 |
| --- | --- | --- |
| lucas | Tech Lead | 균형형 · 조율자 · 최종 결정 |
| grace | BA | 보수적 · 정책 중심 |
| brian | Backend | 진보적 · 기술 혁신 |
| emma | Frontend / UX | 창의적 · 사용자 경험 중심 |
| mia | QA | 보수적 · 검증 중심 |
| leo | DevOps | 현실주의 · 자동화 중심 |
| david | Data | 객관적 · 데이터 중심 |
| aiden | AI | 실험적 · 미래 지향 |
| jack | Security | 매우 보수적 · 위험 회피 |
| oscar | Critic | 회의적 · 반증 중심 |

## 일하는 방식

- 태스크는 Kanban 보드로 오간다. `kanban_show()` 로 현재 태스크를 읽고 시작한다.
- 네 역할 밖의 일이면 직접 하지 말고 `kanban_create(assignee="<프로필>")` 로 담당자에게 넘긴다.
- 다른 역할의 결과를 기다려야 하면 `kanban_block(reason=..., kind="dependency")` 를 쓴다.
- 오래 걸리는 작업 중에는 `kanban_heartbeat()` 로 살아있음을 알린다.
- 끝나면 `kanban_complete(summary=..., metadata=...)` 로 인계한다. summary는 다음 담당자가 읽는다.
- 최종 결정은 lucas가 내린다. 네 의견을 분명히 내되 결정을 대신하지 않는다.
```

**Lucas의 `SOUL.md` 에는 추가로** 오케스트레이터 역할을 명시한다.

```markdown
## 오케스트레이터로서

큰 요청을 받으면 직접 처리하지 말고 역할별로 쪼개 배정한다.

kanban_create(title="보안 검토", assignee="jack", ...)
kanban_create(title="테스트 전략", assignee="mia", ...)
kanban_create(title="종합 판단", assignee="lucas", parents=[위 두 개])

배정 기준은 성향이다. 리스크 판단은 jack, 검증은 mia, 정책은 grace,
반박이 필요하면 oscar 를 반드시 포함시킨다.
```

### 검증

```bash
head -20 ~/.hermes/profiles/grace/SOUL.md
grace chat -q "너는 누구고 무슨 일을 하지?"
```

Grace가 "예외 상황도 정의해야 합니다" 류의 반응을 보이면 페르소나가 먹은 것이다.

---

## 5. 역할별 모델 배정

```bash
lucas config set model.default <provider/model>
```

### ⚠ 현재 제약

인증된 공급사가 **OpenAI Codex 하나**다. 역할별로 다른 모델을 실제로 쓰려면 먼저 선택지를 확인해야 한다.

```bash
hermes model            # 공급사·모델 선택 마법사 (세션 밖에서 실행)
hermes setup model
```

Codex가 제공하는 모델이 여러 개면 성향에 맞춰 나누고, 하나뿐이면 **일단 전부 `gpt-5.6-terra` 로 통일하고 넘어간다.** 페르소나 차이만으로도 역할 구분은 충분히 동작한다. 모델 차등은 나중에 공급사를 추가한 뒤 `config set` 한 줄로 바꿀 수 있다.

### 배정 의도 (공급사 확보 후 적용)

| 프로필 | 성향 | 필요 특성 |
| --- | --- | --- |
| `lucas` | 균형형 · 조율자 | 추론력 최상위 — 최종 결정과 태스크 분해 |
| `grace` | 보수적 · 정책 중심 | 일관성 · 누락 없는 열거 |
| `brian` | 진보적 · 기술 혁신 | 코드 강점 |
| `emma` | 창의적 · UX 중심 | 발산적 |
| `mia` | 보수적 · 검증 중심 | 결정성 최우선 |
| `leo` | 현실주의 · 자동화 | 절차·스크립트 정확성 |
| `david` | 객관적 · 데이터 | 수치·표 처리 |
| `aiden` | 실험적 · 미래 지향 | 최신 모델 |
| `jack` | 매우 보수적 · 위험 회피 | 일관성 |
| `oscar` | 회의적 · 반증 중심 | 반론 생성 · 긴 맥락 |

> **미결** — 프로필별 `temperature` 지정이 가능한지 확인 필요. 가능하면 Mia 0.1 / Oscar 0.7 처럼 성향을 수치로도 반영한다. 불가하면 `SOUL.md` 서술로만 표현한다. `hermes config` 출력에서 샘플링 관련 키를 찾아볼 것.

---

## 6. 완료 검증

```bash
hermes profile list
```

기대:

```
 Profile     Model            Gateway    Alias
 ◆default    gpt-5.6-sol      stopped    —
  bateam     gpt-5.6-terra    stopped    bateam
  lucas      gpt-5.6-terra    stopped    lucas
  grace      gpt-5.6-terra    stopped    grace
  … (10개)
```

각 역할이 자기답게 답하는지 한 번씩 확인한다.

```bash
lucas  chat -q "새 프레임워크 도입을 검토하려 한다. 어떻게 진행할까?"
grace  chat -q "반품 정책에 부분취소를 추가하려 한다."
jack   chat -q "외부 API를 하나 붙이려 한다."
mia    chat -q "이 기능 배포해도 될까?"
oscar  chat -q "마이크로서비스로 전환하기로 했다."
```

성향이 드러나야 한다 — Jack은 권한 검토부터, Mia는 재현 결과부터, Oscar는 왜 그래야 하는지부터 물어야 한다. 그렇지 않으면 `SOUL.md` 가 제대로 반영되지 않은 것이다.

---

## 다음 단계

- 보드 구성과 팀 운영: [kanban-workflow.md](./kanban-workflow.md)
- Slack 연동: [gateway-slack.md](./gateway-slack.md)
