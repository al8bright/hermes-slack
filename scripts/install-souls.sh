#!/usr/bin/env bash
#
# roles/*.md 를 각 Hermes 프로필의 SOUL.md 로 설치한다.
#
#   ./scripts/install-souls.sh              설치
#   ./scripts/install-souls.sh --dry-run    미리보기 (파일을 쓰지 않음)
#   ./scripts/install-souls.sh --only grace 한 명만
#
# 하는 일:
#   1. YAML 프론트매터 제거 (시스템 프롬프트에는 불필요한 잡음)
#   2. 마크다운 링크 평탄화 — [Brian](./brian-backend.md) → Brian
#      (프로필 디렉터리에서는 상대 링크가 깨진다)
#   3. roles/_team.md 를 모두에게 덧붙임 — 동료 목록과 Kanban 사용법
#   4. roles/_orchestrator.md 를 lucas 에게만 덧붙임
#   5. 기존 SOUL.md 는 SOUL.md.bak 으로 백업
#
# macOS 기본 bash 3.2 에서 동작하도록 연상 배열을 쓰지 않는다.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROLES_DIR="$REPO_ROOT/roles"
PROFILES_DIR="${HERMES_PROFILES_DIR:-$HOME/.hermes/profiles}"

TEAM_BLOCK="$ROLES_DIR/_team.md"
ORCH_BLOCK="$ROLES_DIR/_orchestrator.md"

# 프로필ID:페르소나파일
PAIRS="
lucas:lucas-tech-lead.md
grace:grace-business-analyst.md
brian:brian-backend.md
emma:emma-frontend.md
mia:mia-qa.md
leo:leo-devops.md
david:david-data-analyst.md
aiden:aiden-ai-engineer.md
jack:jack-security.md
oscar:oscar-devils-advocate.md
"

DRY_RUN=0
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --only)    ONLY="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
done

for f in "$TEAM_BLOCK" "$ORCH_BLOCK"; do
  [ -f "$f" ] || { echo "없음: $f" >&2; exit 1; }
done
[ -d "$PROFILES_DIR" ] || { echo "프로필 디렉터리 없음: $PROFILES_DIR" >&2; exit 1; }

echo "저장소:   $REPO_ROOT"
echo "프로필:   $PROFILES_DIR"
[ "$DRY_RUN" -eq 1 ] && echo "모드:     dry-run (파일을 쓰지 않음)"
echo

installed=0
skipped=0

for pair in $PAIRS; do
  id="${pair%%:*}"
  file="${pair#*:}"

  [ -n "$ONLY" ] && [ "$ONLY" != "$id" ] && continue

  src="$ROLES_DIR/$file"
  dst_dir="$PROFILES_DIR/$id"
  dst="$dst_dir/SOUL.md"

  if [ ! -f "$src" ]; then
    echo "  ✗ $id — 페르소나 없음: $src"
    skipped=$((skipped + 1))
    continue
  fi

  if [ ! -d "$dst_dir" ]; then
    echo "  ✗ $id — 프로필 없음. 먼저: hermes profile create $id --clone-from bateam"
    skipped=$((skipped + 1))
    continue
  fi

  # 프론트매터 제거 + 링크 평탄화
  body="$(
    awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; next} !fm' "$src" \
      | sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g'
  )"

  extra=""
  [ "$id" = "lucas" ] && extra="$(cat "$ORCH_BLOCK")"

  if [ "$DRY_RUN" -eq 1 ]; then
    bytes=$(printf '%s\n%s\n%s\n' "$body" "$(cat "$TEAM_BLOCK")" "$extra" | wc -c | tr -d ' ')
    marker=""
    [ "$id" = "lucas" ] && marker=" (+ 오케스트레이터 지침)"
    echo "  · $id ← $file  →  ${bytes} bytes${marker}"
  else
    [ -f "$dst" ] && cp "$dst" "$dst.bak"
    {
      printf '%s\n' "$body"
      printf '%s\n' "$(cat "$TEAM_BLOCK")"
      [ -n "$extra" ] && printf '\n%s\n' "$extra"
    } > "$dst"
    size=$(wc -c < "$dst" | tr -d ' ')
    marker=""
    [ "$id" = "lucas" ] && marker=" (+ 오케스트레이터 지침)"
    echo "  ✓ $id  →  $dst  (${size} bytes)${marker}"
  fi

  installed=$((installed + 1))
done

echo
if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry-run 완료 — 대상 ${installed}개, 건너뜀 ${skipped}개"
  echo "실제 설치: ./scripts/install-souls.sh"
else
  echo "설치 완료 — ${installed}개, 건너뜀 ${skipped}개"
  echo
  echo "검증:"
  echo "  lucas chat -q \"너는 누구고 팀에서 무슨 일을 하지?\""
  echo "  jack  chat -q \"외부 API를 하나 붙이려 한다.\""
  echo "  mia   chat -q \"이 기능 배포해도 될까?\""
fi
