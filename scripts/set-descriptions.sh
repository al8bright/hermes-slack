#!/usr/bin/env bash
#
# config/descriptions.conf 대로 각 프로필의 설명을 설정한다.
#
#   ./scripts/set-descriptions.sh --dry-run    실행할 명령만 출력
#   ./scripts/set-descriptions.sh              적용
#   ./scripts/set-descriptions.sh --only jack  한 명만
#   ./scripts/set-descriptions.sh --show       현재 설정된 설명 확인
#
# 설명은 Kanban decomposer 가 태스크를 배정할 때 읽는다.
# 설명이 없으면 decomposer 가 담당자를 못 골라 전부 kanban.default_assignee 로 떨어진다.
# 저장 위치: <profile_dir>/profile.yaml

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$REPO_ROOT/config/descriptions.conf"

DRY_RUN=0
SHOW=0
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --show)    SHOW=1; shift ;;
    --only)    ONLY="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
done

[ -f "$CONF" ] || { echo "설정 파일 없음: $CONF" >&2; exit 1; }
command -v hermes >/dev/null 2>&1 || { echo "hermes 를 찾을 수 없다" >&2; exit 1; }

# ── 현재 설정 확인 ───────────────────────────────────────────────
if [ "$SHOW" -eq 1 ]; then
  while IFS='|' read -r id _desc; do
    case "$id" in ''|\#*) continue ;; esac
    [ -n "$ONLY" ] && [ "$ONLY" != "$id" ] && continue
    printf '%-8s ' "$id"
    hermes profile describe "$id" 2>&1 | head -1
  done < "$CONF"
  exit 0
fi

echo "설정 파일: $CONF"
[ "$DRY_RUN" -eq 1 ] && echo "모드:      dry-run (적용하지 않음)"
echo

applied=0
failed=0

while IFS='|' read -r id desc; do
  case "$id" in ''|\#*) continue ;; esac
  [ -n "$ONLY" ] && [ "$ONLY" != "$id" ] && continue

  if [ -z "${desc:-}" ]; then
    echo "  ✗ $id — 설명이 비어 있다"
    failed=$((failed + 1))
    continue
  fi

  if [ ! -d "$HOME/.hermes/profiles/$id" ]; then
    echo "  ✗ $id — 프로필 없음"
    failed=$((failed + 1))
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  · %-8s %s…\n' "$id" "$(printf '%s' "$desc" | cut -c1-60)"
  else
    if hermes profile describe "$id" --text "$desc" >/dev/null 2>&1; then
      printf '  ✓ %-8s (%d자)\n' "$id" "${#desc}"
    else
      echo "  ✗ $id  (설정 실패)"
      failed=$((failed + 1))
      continue
    fi
  fi
  applied=$((applied + 1))
done < "$CONF"

echo
if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry-run 완료 — 대상 ${applied}개"
  echo "실제 적용: ./scripts/set-descriptions.sh"
else
  echo "적용 완료 — ${applied}개, 실패 ${failed}개"
  echo
  echo "확인:"
  echo "  ./scripts/set-descriptions.sh --show"
  echo
  echo "라우팅 검증 — 역할별로 배정되는지:"
  echo "  hermes kanban create \"<안건>\" --body \"<내용>\" --triage"
  echo "  hermes kanban decompose <task-id>"
  echo "  hermes kanban list          # assignee 가 갈리는지 확인"
fi
