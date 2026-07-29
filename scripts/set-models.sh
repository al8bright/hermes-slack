#!/usr/bin/env bash
#
# config/models.conf 에 적힌 대로 각 프로필의 모델을 설정한다.
#
#   ./scripts/set-models.sh --dry-run     실행할 명령만 출력
#   ./scripts/set-models.sh               적용
#   ./scripts/set-models.sh --only mia    한 명만
#
# 모델을 바꾸려면 그 공급사가 먼저 인증되어 있어야 한다.
# 인증 없이 설정하면 설정 자체는 되지만 실제 호출에서 실패한다.
# 적용 후 반드시 검증 단계를 거칠 것 (스크립트 끝에서 안내).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$REPO_ROOT/config/models.conf"

DRY_RUN=0
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --only)    ONLY="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
done

[ -f "$CONF" ] || { echo "설정 파일 없음: $CONF" >&2; exit 1; }
command -v hermes >/dev/null 2>&1 || { echo "hermes 를 찾을 수 없다" >&2; exit 1; }

echo "설정 파일: $CONF"
[ "$DRY_RUN" -eq 1 ] && echo "모드:      dry-run (적용하지 않음)"
echo

applied=0
failed=0

# 주석과 빈 줄을 걸러 id/model 쌍만 읽는다
while read -r id model _rest; do
  case "$id" in ''|\#*) continue ;; esac
  [ -z "${model:-}" ] && { echo "  ✗ $id — 모델이 비어 있다"; failed=$((failed + 1)); continue; }

  [ -n "$ONLY" ] && [ "$ONLY" != "$id" ] && continue

  if [ ! -d "$HOME/.hermes/profiles/$id" ]; then
    echo "  ✗ $id — 프로필 없음"
    failed=$((failed + 1))
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  · hermes -p $id config set model $model"
  else
    if hermes -p "$id" config set model "$model" >/dev/null 2>&1; then
      echo "  ✓ $id  →  $model"
    else
      echo "  ✗ $id  →  $model  (설정 실패)"
      failed=$((failed + 1))
      continue
    fi
  fi
  applied=$((applied + 1))
done < "$CONF"

echo
if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry-run 완료 — 대상 ${applied}개"
  echo "실제 적용: ./scripts/set-models.sh"
else
  echo "적용 완료 — ${applied}개, 실패 ${failed}개"
  echo
  echo "확인:"
  echo "  hermes profile list"
  echo
  echo "실제 호출 검증 — 설정만 되고 인증이 없으면 여기서 드러난다:"
  echo "  for id in \$(awk '!/^#/ && NF {print \$1}' config/models.conf); do"
  echo "    printf '%-8s ' \"\$id\"; hermes -p \"\$id\" chat -q '1+1은?' 2>&1 | tail -1"
  echo "  done"
fi
