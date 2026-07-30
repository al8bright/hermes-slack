---
name: daily-log
description: "하루치 활동을 집계해 Notion 일일 요약을 남긴다. 회의록 링크, 차단 항목, 진행 중 태스크를 모은다."
version: 1.0.0
author: BA Team
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [notion, daily-log, kanban, report, retrospective, cron, 업무일지, 회고]
---

# Daily Log

BA Team Kanban 보드에서 **어제 하루 동안 일어난 일**을 집계해 Notion에 일일 요약을 남긴다. 매일 새벽 cron으로 실행되는 것을 전제로 한다.

> **안건별 회의록은 이 스킬이 쓰지 않는다.** 회의록은 종합이 끝나는 순간 [`meeting-note`](../meeting-note/SKILL.md) 스킬이 남긴다. 이 스킬은 그 링크를 모으고, **사람이 조치해야 할 것**을 드러내는 역할이다.

목적은 "어제 뭐 했더라"가 아니라 **"오늘 내가 뭘 해야 하나"** 에 답하는 것이다.

## 전제

- Kanban DB: `~/.hermes/kanban/boards/bateam/kanban.db`
- Notion MCP 툴이 등록되어 있어야 한다 (`mcp_notion_*`)
- 대상 Notion 데이터베이스 ID는 환경변수 `NOTION_DAILY_LOG_DB` 에 있다
- 회의록 링크는 각 루트 태스크의 `completed` 이벤트 `metadata.notion_url` 에 있다

셋 중 하나라도 없으면 **작업을 만들어내지 말고 무엇이 없는지 보고하고 끝낸다.**

---

## 1. 집계 범위를 정한다

새벽에 돌므로 대상은 **어제 00:00 ~ 오늘 00:00** 이다. 로컬 시간 기준으로 경계를 계산한다.

```bash
START=$(date -v-1d -v0H -v0M -v0S +%s)
END=$(date -v0H -v0M -v0S +%s)
YESTERDAY=$(date -v-1d +%Y-%m-%d)
DB=~/.hermes/kanban/boards/bateam/kanban.db
```

> Linux면 `date -d "yesterday 00:00" +%s` 를 쓴다.

## 2. 데이터를 모은다

### 완료된 태스크

```bash
sqlite3 -json "$DB" "
SELECT id, title, assignee, result, completed_at
FROM tasks
WHERE completed_at >= $START AND completed_at < $END
ORDER BY completed_at;"
```

### 새로 생성된 태스크

```bash
sqlite3 -json "$DB" "
SELECT id, title, assignee, status
FROM tasks
WHERE created_at >= $START AND created_at < $END
ORDER BY created_at;"
```

### 차단된 것 — 사람이 봐야 할 항목

```bash
sqlite3 -json "$DB" "
SELECT id, title, assignee, body
FROM tasks
WHERE status = 'blocked';"
```

### 인계 요약 (summary)

```bash
sqlite3 -json "$DB" "
SELECT task_id, kind, payload
FROM task_events
WHERE kind IN ('completed','blocked','decomposed')
  AND id IN (SELECT id FROM task_events WHERE task_id IN
      (SELECT id FROM tasks WHERE completed_at >= $START AND completed_at < $END))
ORDER BY id;"
```

`completed` 이벤트의 `payload` 에 각 역할이 남긴 `summary` 와 `metadata` 가 들어 있다. **일지의 본문은 이걸로 쓴다.**

### 부모–자식 관계

```bash
sqlite3 -json "$DB" "SELECT parent_id, child_id FROM task_links;"
```

안건(부모)별로 묶어서 정리하기 위해 필요하다.

## 3. 정리한다

**태스크를 나열하지 마라.** 안건 단위로 묶는다.

- 안건별로 **결론 한 줄 + 회의록 링크**. 상세는 회의록에 이미 있으므로 반복하지 않는다
- `metadata.notion_url` 이 없는 안건은 회의록이 없다는 뜻이다. 그 사실을 표시한다
- **차단된 항목이 이 문서의 핵심이다.** 사람이 조치하지 않으면 영원히 멈춰 있다
- 진행 중인 것과 오래 멈춘 것(하루 이상 `running`)을 구분한다
- 활동이 없었으면 "활동 없음" 한 줄로 끝낸다. 억지로 채우지 마라

## 4. Notion에 쓴다

`NOTION_DAILY_LOG_DB` 데이터베이스에 페이지를 하나 만든다.

### 속성

| 속성 | 값 |
| --- | --- |
| 제목 | `YYYY-MM-DD 일일 요약` |
| 날짜 | 어제 날짜 |
| 완료 | 완료 태스크 수 |
| 안건 | 안건(루트 태스크) 수 |
| 차단 | 차단된 태스크 수 — **0이 아니면 눈에 띄어야 한다** |
| 참여 | 그날 실행된 역할 이름들 |

속성 이름이 다르면 **DB 스키마를 먼저 조회해 실제 이름에 맞춘다.** 없는 속성에 쓰려 하지 마라.

### 본문 구성

```markdown
## 오늘 봐야 할 것

<차단된 항목이 있으면 여기부터. 없으면 "조치 필요 없음">

| 태스크 | 담당 | 사유 | 필요한 것 |
| --- | --- | --- | --- |

## 어제 결정된 것

| 안건 | 결정 | 회의록 |
| --- | --- | --- |
| FastAPI 전환 검토 | No-Go (PoC만 Go) | [링크] |

## 진행 중

| 태스크 | 담당 | 경과 |
| --- | --- | --- |

<하루 이상 running 인 것은 표시한다 — 멈춘 것일 수 있다>

## 통계

완료 N · 신규 N · 차단 N · 역할별 처리 건수
```

**"오늘 봐야 할 것"을 맨 위에 둔다.** 이 문서를 읽는 사람은 어제를 회고하려는 게 아니라 오늘 뭘 해야 하는지 알려는 것이다.

### 중복 방지

같은 날짜의 페이지가 이미 있으면 **새로 만들지 말고 갱신**한다. 먼저 DB를 날짜로 조회해 확인할 것.

## 5. 보고한다

Notion 페이지 URL과 함께 3~5줄 요약을 최종 응답으로 낸다. cron의 `--deliver` 설정에 따라 Slack 등으로 전달된다.

```
2026-07-30 일일 요약

조치 필요 1건
· 감사 로그 추가 — grace 가 보존 기간 확정을 기다리는 중 (18시간째)

어제 결정 1건
· FastAPI 전환 검토 → 전환 No-Go, 비교 PoC만 Go

완료 9 · 신규 3 · 차단 1
https://notion.so/...
```

**조치가 필요한 것을 먼저 말한다.** Slack으로 전달되므로 첫 두 줄이 실제로 읽히는 전부일 수 있다.

---

## 하지 말 것

- **없는 활동을 지어내지 마라.** 조용한 날은 조용했다고 쓴다.
- **태스크 ID를 나열하지 마라.** 사람이 읽는 글이다. ID는 필요한 곳에만.
- **회의록 내용을 반복하지 마라.** 결론 한 줄과 링크면 된다.
- **DB 스키마를 추측하지 마라.** 조회해서 실제 속성 이름을 쓴다.
- **실패를 삼키지 마라.** Notion 쓰기가 실패하면 그 사실을 보고에 명시한다.
