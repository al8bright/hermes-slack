#!/usr/bin/env bash
#
# skills/ 의 커스텀 스킬을 프로필에 설치한다.
#
#   ./scripts/install-skills.sh --dry-run     설치될 목록만 출력
#   ./scripts/install-skills.sh               설치
#   ./scripts/install-skills.sh --only lucas  한 프로필만
#   ./scripts/install-skills.sh --list        설치된 커스텀 스킬 확인
#
# 스킬별 대상 프로필은 아래 TARGETS 로 정한다.
# 전원에게 필요한 스킬이 아니면 굳이 전부에 넣지 않는다 — 컨텍스트만 차지한다.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"
PROFILES_DIR="${HERMES_PROFILES_DIR:-$HOME/.hermes/profiles}"

# 스킬명:대상프로필(쉼표구분, all=전원)
TARGETS="
meeting-note:lucas
daily-log:lucas
"

DRY_RUN=0
LIST=0
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --list)    LIST=1; shift ;;
    --only)    ONLY="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
done

[ -d "$SKILLS_SRC" ]   || { echo "스킬 디렉터리 없음: $SKILLS_SRC" >&2; exit 1; }
[ -d "$PROFILES_DIR" ] || { echo "프로필 디렉터리 없음: $PROFILES_DIR" >&2; exit 1; }

# ── 설치 현황 ────────────────────────────────────────────────────
if [ "$LIST" -eq 1 ]; then
  for pair in $TARGETS; do
    skill="${pair%%:*}"
    for prof in $(printf '%s' "${pair#*:}" | tr ',' ' '); do
      dst="$PROFILES_DIR/$prof/skills/$skill/SKILL.md"
      if [ -f "$dst" ]; then
        printf '  ✓ %-14s %-8s %s bytes\n' "$skill" "$prof" "$(wc -c < "$dst" | tr -d ' ')"
      else
        printf '  ✗ %-14s %-8s 미설치\n' "$skill" "$prof"
      fi
    done
  done
  exit 0
fi

echo "스킬:    $SKILLS_SRC"
echo "프로필:  $PROFILES_DIR"
[ "$DRY_RUN" -eq 1 ] && echo "모드:    dry-run (파일을 쓰지 않음)"
echo

installed=0
skipped=0

for pair in $TARGETS; do
  skill="${pair%%:*}"
  targets="${pair#*:}"
  src="$SKILLS_SRC/$skill/SKILL.md"

  if [ ! -f "$src" ]; then
    echo "  ✗ $skill — 원본 없음: $src"
    skipped=$((skipped + 1))
    continue
  fi

  # all → 프로필 디렉터리 전체 (템플릿·default 제외)
  if [ "$targets" = "all" ]; then
    targets="$(ls "$PROFILES_DIR" | grep -vx -e default -e bateam | tr '\n' ',' | sed 's/,$//')"
  fi

  for prof in $(printf '%s' "$targets" | tr ',' ' '); do
    [ -n "$ONLY" ] && [ "$ONLY" != "$prof" ] && continue

    if [ ! -d "$PROFILES_DIR/$prof" ]; then
      echo "  ✗ $skill → $prof (프로필 없음)"
      skipped=$((skipped + 1))
      continue
    fi

    dst_dir="$PROFILES_DIR/$prof/skills/$skill"
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '  · %-14s → %s\n' "$skill" "$dst_dir/SKILL.md"
    else
      mkdir -p "$dst_dir"
      cp "$src" "$dst_dir/SKILL.md"
      # 참조 파일이 있으면 함께 복사
      for extra in "$SKILLS_SRC/$skill"/*; do
        [ "$(basename "$extra")" = "SKILL.md" ] && continue
        [ -e "$extra" ] && cp -R "$extra" "$dst_dir/"
      done
      printf '  ✓ %-14s → %-8s (%s bytes)\n' "$skill" "$prof" "$(wc -c < "$dst_dir/SKILL.md" | tr -d ' ')"
    fi
    installed=$((installed + 1))
  done
done

echo
if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry-run 완료 — 대상 ${installed}개"
  echo "실제 설치: ./scripts/install-skills.sh"
else
  echo "설치 완료 — ${installed}개, 건너뜀 ${skipped}개"
  echo
  echo "확인:"
  echo "  ./scripts/install-skills.sh --list"
  echo "  lucas skills list | grep -E 'meeting-note|daily-log'"
fi
