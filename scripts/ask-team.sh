#!/usr/bin/env bash
#
# 여러 역할에게 같은 질문을 병렬로 던지고 답을 모은다.
#
#   ./scripts/ask-team.sh --roles jack,mia,leo "FastAPI 전환의 리스크를 짚어줘"
#   ./scripts/ask-team.sh --all "..."                    lucas 를 제외한 9명
#   ./scripts/ask-team.sh --roles jack,mia --synthesize "..."   답을 모아 lucas 가 종합
#   ./scripts/ask-team.sh --plan "FastAPI 전환 검토"      lucas 에게 분해안만 요청
#
# 결과는 reviews/<타임스탬프>-<슬러그>/ 에 역할별 파일로 남는다.
#
# 칸반을 열 정도가 아닌 가벼운 질의용. 이력이 필요한 검토는 /kanban 을 쓴다.
# 배경은 docs/06-team-workflow.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$REPO_ROOT/config/models.conf"
OUT_ROOT="$REPO_ROOT/reviews"

ROLES=""
SYNTHESIZE=0
PLAN_ONLY=0

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --roles)      ROLES="${2:-}"; shift 2 ;;
    --all)        ROLES="__all__"; shift ;;
    --synthesize) SYNTHESIZE=1; shift ;;
    --plan)       PLAN_ONLY=1; shift ;;
    -h|--help)    usage 0 ;;
    --) shift; break ;;
    -*) echo "알 수 없는 옵션: $1" >&2; usage 2 ;;
    *)  break ;;
  esac
done

QUESTION="${*:-}"
[ -n "$QUESTION" ] || { echo "질문이 없다." >&2; usage 2; }
command -v hermes >/dev/null 2>&1 || { echo "hermes 를 찾을 수 없다" >&2; exit 1; }

ask() {  # ask <profile> <prompt> — 최종 응답만 받는다
  hermes -p "$1" -z "$2" 2>/dev/null
}

# ── 분해안만 요청 ────────────────────────────────────────────────
if [ "$PLAN_ONLY" -eq 1 ]; then
  echo "▶ lucas 에게 분해안 요청"
  echo
  ask lucas "다음 안건을 검토하려 한다. 직접 답하지 말고, 누구에게 무엇을 물어야 하는지 분해안만 제시해라.

안건: $QUESTION"
  exit 0
fi

# ── 대상 역할 결정 ───────────────────────────────────────────────
if [ "$ROLES" = "__all__" ] || [ -z "$ROLES" ]; then
  [ -f "$CONF" ] || { echo "설정 파일 없음: $CONF" >&2; exit 1; }
  ROLE_LIST="$(awk '!/^#/ && $1!~/^@/ && NF && $1!="lucas" {print $1}' "$CONF")"
else
  ROLE_LIST="$(printf '%s' "$ROLES" | tr ',' '\n')"
fi

[ -n "$ROLE_LIST" ] || { echo "대상 역할이 없다." >&2; exit 1; }

# ── 출력 디렉터리 ────────────────────────────────────────────────
slug="$(printf '%s' "$QUESTION" | tr -cs '[:alnum:]가-힣' '-' | cut -c1-40 | sed 's/-*$//')"
OUT_DIR="$OUT_ROOT/$(date +%Y%m%d-%H%M%S)-${slug:-질의}"
mkdir -p "$OUT_DIR"

printf '# %s\n\n일시: %s\n\n' "$QUESTION" "$(date '+%Y-%m-%d %H:%M')" > "$OUT_DIR/00-질문.md"

echo "질문:  $QUESTION"
echo "대상:  $(printf '%s' "$ROLE_LIST" | tr '\n' ' ')"
echo "출력:  $OUT_DIR"
echo

# ── 병렬 질의 ────────────────────────────────────────────────────
pids=""
for id in $ROLE_LIST; do
  if [ ! -d "$HOME/.hermes/profiles/$id" ]; then
    echo "  ✗ $id — 프로필 없음"
    continue
  fi
  (
    if ask "$id" "$QUESTION" > "$OUT_DIR/$id.md" 2>&1; then
      echo "  ✓ $id  ($(wc -c < "$OUT_DIR/$id.md" | tr -d ' ') bytes)"
    else
      echo "  ✗ $id  (호출 실패)"
    fi
  ) &
  pids="$pids $!"
done

for p in $pids; do wait "$p" || true; done

# ── 취합 ─────────────────────────────────────────────────────────
COMBINED="$OUT_DIR/_모음.md"
{
  printf '# 안건: %s\n\n' "$QUESTION"
  for id in $ROLE_LIST; do
    [ -s "$OUT_DIR/$id.md" ] || continue
    printf '\n---\n\n## %s\n\n' "$id"
    cat "$OUT_DIR/$id.md"
    printf '\n'
  done
} > "$COMBINED"

echo
echo "취합: $COMBINED"

# ── lucas 종합 ───────────────────────────────────────────────────
if [ "$SYNTHESIZE" -eq 1 ]; then
  echo
  echo "▶ lucas 종합 중"
  echo
  ask lucas "팀원들의 검토 의견이 아래에 있다. 종합해서 결정을 내려라.
충돌하는 지점을 먼저 드러내고, 비용과 리스크를 비교하고, 결정과 함께
그 결정이 틀렸을 때 무엇을 보고 알 수 있는지 적어라.

$(cat "$COMBINED")" | tee "$OUT_DIR/_종합-lucas.md"
  echo
  echo "종합: $OUT_DIR/_종합-lucas.md"
fi
