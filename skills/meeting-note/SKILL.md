---
name: meeting-note
description: "Kanban 안건 하나의 검토가 끝났을 때 Notion에 회의록을 남긴다. 각 역할의 결론, 충돌 지점, 최종 결정을 기록한다."
version: 1.0.0
author: BA Team
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [notion, meeting-note, kanban, decision-record, 회의록, 의사결정]
---

# Meeting Note

BA Team의 안건 하나가 종합 단계까지 끝났을 때 **Notion에 회의록을 남긴다.** 종합 태스크를 수행하는 역할(보통 `lucas`)이 `kanban_complete` 직전에 실행한다.

목적은 보관이 아니라 **되짚기**다. 3개월 뒤 "왜 그렇게 결정했더라"에 답할 수 있어야 한다.

## 전제 — 없으면 건너뛴다

Notion MCP 툴(`mcp_notion_*`)과 환경변수 `NOTION_MEETING_DB` 가 있어야 한다. **둘 중 하나라도 없으면 회의록을 만들려 하지 말고 조용히 건너뛴 뒤 본래 작업(`kanban_complete`)을 마친다.** 이건 부가 기능이지 태스크의 성공 조건이 아니다.

---

## 1. 재료를 모은다

종합 태스크에는 이미 부모들의 `summary` 와 `metadata` 가 전달되어 있다. 추가로 필요한 것만 조회한다.

```bash
DB=~/.hermes/kanban/boards/bateam/kanban.db
ROOT=<루트 안건 태스크 id>

# 안건과 자식 전체
sqlite3 -json "$DB" "
SELECT t.id, t.title, t.assignee, t.status, t.result, t.completed_at
FROM tasks t
WHERE t.id = '$ROOT'
   OR t.id IN (SELECT child_id FROM task_links WHERE parent_id = '$ROOT')
ORDER BY t.created_at;"

# 각 역할이 남긴 인계 원문
sqlite3 -json "$DB" "
SELECT task_id, payload FROM task_events
WHERE kind = 'completed' AND task_id IN (
  SELECT child_id FROM task_links WHERE parent_id = '$ROOT'
);"

# 첨부 산출물
sqlite3 -json "$DB" "
SELECT task_id, filename FROM task_attachments;"
```

## 2. 쓴다

### 제목

```
<안건 제목> — <결론 한 줄>
```

예: `FastAPI 전환 검토 — 전환 No-Go, 비교 PoC만 Go`

**제목만 보고도 결론을 알 수 있어야 한다.** "FastAPI 전환 검토"만 쓰면 나중에 열어봐야 한다.

### 속성

DB 스키마를 먼저 조회해 **실제 속성 이름에 맞춘다.** 없는 속성에 쓰려 하지 마라.

| 속성 | 값 |
| --- | --- |
| 제목 | 위 형식 |
| 날짜 | 종합 완료일 |
| 결정 | `Go` / `No-Go` / `조건부` / `보류` 중 하나 |
| 참여 | 검토에 참여한 역할들 |
| 태스크 | 루트 태스크 id |

### 본문

```markdown
## 안건

<원 요청 그대로. 사람이 무엇을 물었는지>

## 결정

<최종 결론. 갈래가 여럿이면 표로>

| 안 | 판정 | 근거 |
| --- | --- | --- |

## 선행 조건

<결정이 유효하려면 먼저 충족해야 할 것>

## 검토 의견

### brian — Backend
<결론 한 줄>
<핵심 근거 2~3줄>

### jack — Security
...

## 갈린 지점

<누가 누구와 왜 어긋났는지. 이 절이 이 문서에서 가장 중요하다>

## 반증 검토

<oscar 의 반박과, 그것이 최종 결정에 어떻게 반영되었는지>

## 틀렸을 때의 신호

<이 결정이 잘못됐다면 무엇을 보고 알 수 있는가>

## 미해결

<답이 나오지 않은 질문들>

## 근거 문서

<첨부 파일 목록>
```

---

## 쓰는 원칙

**갈린 지점을 지우지 마라.** 회의록의 가치는 결론이 아니라 **결론에 이르는 과정의 대립**에 있다. 모두가 동의한 것처럼 정리하면 이 팀을 만든 이유가 사라진다.

**Oscar의 반박은 별도 절로 남긴다.** 반박이 결정을 바꿨다면 그 사실을 명시한다. 반박이 기각됐다면 왜 기각됐는지 쓴다. **반박이 없었다면 그것도 이상 신호이므로 적어둔다.**

**각 역할의 원문을 통째로 옮기지 마라.** 결론 한 줄과 근거 2~3줄. 전문은 첨부로.

**추측을 사실로 쓰지 마라.** 각 역할이 "확인하지 못했다"고 한 것은 미해결 절에 그대로 옮긴다.

**결정이 조건부면 조건을 빠뜨리지 마라.** "조건부 Go"만 쓰고 조건을 안 적으면 나중에 그냥 Go로 읽힌다.

---

## 3. 마무리

Notion 페이지 URL을 `kanban_complete` 의 `metadata` 에 넣는다.

```
kanban_complete(
  summary="<결론 요약>",
  metadata={"notion_url": "https://notion.so/...", "decision": "No-Go", ...}
)
```

이렇게 하면 Slack 완료 알림과 일일 요약이 이 링크를 이어받는다.

Notion 쓰기가 실패했으면 `summary` 에 그 사실을 한 줄로 남긴다. **실패를 삼키지 마라.** 다만 그것 때문에 태스크를 `block` 하지는 않는다 — 검토 결과 자체는 이미 나왔다.
