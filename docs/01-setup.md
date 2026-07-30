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

**`roles/*.md` 를 그대로 복사하면 안 된다.** 사람이 읽는 문서로 썼기 때문에 세 가지를 손봐야 한다.

| 문제 | 처리 |
| --- | --- |
| YAML 프론트매터가 시스템 프롬프트에 섞임 | 제거 |
| `[Brian](../roles/brian-backend.md)` 같은 상대 링크가 프로필 디렉터리에서 깨짐 | 링크 평탄화 → `Brian` |
| 팀의 일원이라는 것과 Kanban 사용법을 모름 | `roles/_team.md` 를 덧붙임 (lucas 에겐 `_orchestrator.md` 추가) |

이걸 매번 손으로 하면 역할을 다듬을 때마다 10번 반복해야 한다. 스크립트로 처리한다.

```bash
cd ~/dev/hermes-slack        # 저장소 위치
./scripts/install-souls.sh --dry-run    # 무엇이 쓰일지 먼저 확인
./scripts/install-souls.sh              # 설치
```

```
저장소:   /Users/ethan/dev/hermes-slack
프로필:   /Users/ethan/.hermes/profiles

  ✓ lucas  →  /Users/ethan/.hermes/profiles/lucas/SOUL.md  (4821 bytes) (+ 오케스트레이터 지침)
  ✓ grace  →  /Users/ethan/.hermes/profiles/grace/SOUL.md  (3204 bytes)
  … 10개

설치 완료 — 10개, 건너뜀 0개
```

기존 `SOUL.md`(템플릿에서 상속된 것)는 `SOUL.md.bak` 으로 백업된다.

> **`$BATEAM_SRC` 같은 환경변수가 필요 없다.** 스크립트가 자기 위치로 저장소 루트를 찾는다. 이전 절차에서 `cp: /roles/...: No such file or directory` 가 났다면 그 변수가 비어 있었던 것이다.

### 페르소나를 고칠 때

`roles/*.md` 를 수정하고 스크립트를 다시 돌리면 된다. 한 명만 바꿀 수도 있다.

```bash
vim roles/grace-business-analyst.md
./scripts/install-souls.sh --only grace
```

팀 공통 지침(동료 목록·Kanban 사용법)은 `roles/_team.md`, Lucas의 오케스트레이터 지침은 `roles/_orchestrator.md` 에 있다. 이 둘을 고치면 전원에게 반영된다.

### 검증

```bash
head -20 ~/.hermes/profiles/grace/SOUL.md    # 프론트매터가 사라졌는지
tail -40 ~/.hermes/profiles/lucas/SOUL.md    # 오케스트레이터 지침이 붙었는지
grep -c "](\./" ~/.hermes/profiles/*/SOUL.md # 링크 평탄화 확인 — 전부 0 이어야 한다

# ⚠ 차단 여부 확인 — 가장 중요하다
grep -h "blocked" ~/.hermes/profiles/*/logs/agent.log | tail -5

grace chat -q "너는 누구고 팀에서 무슨 일을 하지?"
```

Grace가 "예외 상황도 정의해야 합니다" 류의 반응을 보이고 동료 이름을 알고 있으면 페르소나가 먹은 것이다.

### ⚠ 페르소나가 안 먹을 때 — 인젝션 스캔 차단

일반 Hermes 어시스턴트처럼 답한다면 `SOUL.md` 가 **통째로 차단**된 것이다. Hermes 는 시스템 프롬프트에 넣기 전 `_scan_context_content()` 로 인젝션 패턴을 검사하고, **하나만 걸려도 파일 전체를 버린다.**

```bash
grep "blocked" ~/.hermes/profiles/<id>/logs/agent.log | tail -3
```

```
WARNING agent.prompt_builder: Context file SOUL.md blocked: invisible_unicode_U+200D
```

실제로 `👨‍💼`(= `👨` + U+200D ZWJ + `💼`) 하나 때문에 Lucas 페르소나가 전부 사라졌다. **ZWJ 조합 이모지를 페르소나 문서에 쓰지 말 것.** `install-souls.sh` 가 보이지 않는 유니코드를 제거하지만, 원본에서도 피하는 편이 낫다.

스캔 범위는 *classic injection · promptware/C2 · role-play hijack* 이다. 페르소나 문서에 명령형 코드 블록이나 은닉 문자가 들어가면 같은 일이 생긴다.

---

## 5. 역할별 모델 배정

### 5.1 명령 형태 — ⚠ `model` 이 아니라 `model.default`

`model` 은 스칼라가 아니라 딕셔너리다.

```
Model: {'default': 'gpt-5.6-terra', 'provider': 'openai-codex', 'base_url': 'https://chatgpt.com/backend-api/codex'}
```

여기에 `config set model gpt-5.6-sol` 을 하면 **딕셔너리 전체가 문자열로 덮여** `provider` 와 `base_url` 이 사라진다. 그 프로필은 다음 호출부터 이렇게 죽는다.

```
It looks like Hermes isn't configured yet -- no API keys or providers found.
```

반드시 하위 키를 지정한다.

```bash
lucas config set model.default gpt-5.6-sol          # 별칭
hermes -p lucas config set model.default gpt-5.6-sol   # 동일
```

> `hermes config set` 의 usage 예시는 `hermes config set model anthropic/claude-sonnet-4` 인데, 이건 값에 `공급사/모델` 형태가 들어가 Hermes가 provider를 추론할 수 있을 때만 안전하다. `gpt-5.6-terra` 처럼 공급사 접두어 없는 값에는 쓰면 안 된다.

### 5.1.1 이미 깨진 프로필 복구

```bash
./scripts/set-models.sh --with-provider
```

`config/models.conf` 의 `@provider` · `@base_url` 값으로 `model.provider` 와 `model.base_url` 을 되살린다. 값이 맞는지는 손대지 않은 프로필에서 확인한다.

```bash
bateam config | grep -A1 "◆ Model"    # 템플릿 — 정상 형태
brian  config | grep -A1 "◆ Model"    # 문자열로 보이면 깨진 것
```

> `hermes setup` 은 **현재 기본 프로필**(`hermes profile list` 의 `◆` 표시)을 설정한다. `brian` 을 고치려면 `brian setup` 또는 `hermes -p brian setup` 이어야 한다.

### 5.2 선택 가능한 모델 확인이 먼저다

```bash
hermes model            # 공급사·모델 선택 마법사 — 목록이 여기서 보인다
hermes profile list     # 현재 배정 상태
```

**인증된 공급사가 OpenAI Codex 하나면 선택지가 `gpt-5.6-terra` / `gpt-5.6-sol` 정도로 제한된다.** 역할 10개를 실제로 다르게 배정하려면 공급사를 늘려야 한다.

```bash
hermes setup model      # Anthropic · OpenRouter · Copilot · Nous Portal 추가
```

**OpenRouter를 권한다.** API 키 하나로 여러 공급사의 모델에 접근할 수 있어, 10개 역할에 서로 다른 모델을 물리기가 가장 쉽다. Anthropic·OpenAI를 개별 계약하는 것보다 초기 구성이 빠르다.

> ⚠ **인증 없이 모델만 바꾸면 설정은 되지만 호출에서 실패한다.** 공급사를 먼저 붙이고 모델을 배정할 것.

### 5.3 배정 적용

10개를 매번 손으로 치지 않도록 [`config/models.conf`](../config/models.conf) 에 배정을 적고 스크립트로 적용한다.

```
# config/models.conf
lucas   gpt-5.6-terra
grace   gpt-5.6-terra
...
```

```bash
vim config/models.conf                  # 배정 수정
./scripts/set-models.sh --dry-run       # 실행될 명령 확인
./scripts/set-models.sh                 # 적용
./scripts/set-models.sh --only mia      # 한 명만
```

`config/models.conf` 상단에 역할별로 **어떤 특성이 필요한지** 주석으로 적어뒀다. 실제 모델명은 사용 가능한 것 중에서 고른다.

| 프로필 | 필요 특성 | 이유 |
| --- | --- | --- |
| `lucas` | 추론력 최상위 | 최종 결정과 태스크 분해. 가장 좋은 모델을 준다 |
| `grace` | 일관성 · 열거 | 예외 상황을 빠짐없이 나열해야 한다 |
| `brian` | 코드 강점 | 구현 방식과 성능 근거 |
| `emma` | 발산적 | 새 UI·경험 안을 여러 개 내야 한다 |
| `mia` | 결정성 최우선 | 같은 입력에 같은 판정. 흔들리면 QA가 아니다 |
| `leo` | 절차 정확성 | 배포·롤백 순서를 틀리면 안 된다 |
| `david` | 수치 · 표 처리 | 계산이 틀리면 근거가 무너진다 |
| `aiden` | 최신 모델 | 새 기술을 다루는 역할이므로 |
| `jack` | 일관성 | 보안 판단은 매번 같아야 한다 |
| `oscar` | 반론 생성 · 긴 맥락 | 검토되지 않은 각도를 끌어내야 한다 |

### 5.4 검증 — 설정과 실제 호출은 다르다

`hermes profile list` 는 **설정된 값**만 보여준다. 인증이 없으면 여기선 멀쩡해 보이고 실제 대화에서 실패한다. 전 프로필을 한 번씩 호출해 확인한다.

```bash
for id in $(awk '!/^#/ && $1!~/^@/ && NF {print $1}' config/models.conf); do
  printf '%-8s ' "$id"
  hermes -p "$id" chat -q '1+1은?' 2>&1 | tail -1
done
```

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

- 보드 구성과 팀 운영: [02-kanban-workflow.md](./02-kanban-workflow.md)
- Slack 연동: [03-gateway-slack.md](./03-gateway-slack.md)
