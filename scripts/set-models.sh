#!/usr/bin/env bash
#
# config/models.conf 에 적힌 대로 각 프로필의 모델을 설정한다.
#
#   ./scripts/set-models.sh --dry-run          실행할 명령만 출력
#   ./scripts/set-models.sh                    모델만 적용 (model.default)
#   ./scripts/set-models.sh --with-provider    공급사·base_url 까지 적용 (복구용)
#   ./scripts/set-models.sh --only mia         한 명만
#
# ⚠ `config set model <값>` 을 쓰면 안 된다.
#   model 은 {default, provider, base_url} 딕셔너리라, 스칼라를 넣으면
#   provider·base_url 이 사라져 "no API keys or providers found" 가 뜬다.
#   이 스크립트는 model.default 만 설정한다.
#
# 이미 깨진 프로필은 --with-provider 로 복구한다.
# 공급사 값은 config/models.conf 의 @provider / @base_url 에 있다.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$REPO_ROOT/config/models.conf"

DRY_RUN=0
WITH_PROVIDER=0
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)       DRY_RUN=1; shift ;;
    --with-provider) WITH_PROVIDER=1; shift ;;
    --only)          ONLY="${2:-}"; shift 2 ;;
    -h|--help)       sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
done

[ -f "$CONF" ] || { echo "설정 파일 없음: $CONF" >&2; exit 1; }
command -v hermes >/dev/null 2>&1 || { echo "hermes 를 찾을 수 없다" >&2; exit 1; }

# @directive 읽기
PROVIDER="$(awk '$1=="@provider" {print $2; exit}' "$CONF" || true)"
BASE_URL="$(awk '$1=="@base_url" {print $2; exit}' "$CONF" || true)"

if [ "$WITH_PROVIDER" -eq 1 ]; then
  [ -n "$PROVIDER" ] || { echo "@provider 가 $CONF 에 없다" >&2; exit 1; }
  [ -n "$BASE_URL" ]  || { echo "@base_url 이 $CONF 에 없다" >&2; exit 1; }
fi

echo "설정 파일: $CONF"
[ "$DRY_RUN" -eq 1 ]       && echo "모드:      dry-run (적용하지 않음)"
[ "$WITH_PROVIDER" -eq 1 ] && echo "공급사:    $PROVIDER  ($BASE_URL)"
echo

applied=0
failed=0

set_key() {  # set_key <profile> <key> <value>
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "      hermes -p $1 config set $2 $3"
    return 0
  fi
  hermes -p "$1" config set "$2" "$3" >/dev/null 2>&1
}

while read -r id model _rest; do
  case "$id" in ''|\#*|@*) continue ;; esac
  [ -z "${model:-}" ] && { echo "  ✗ $id — 모델이 비어 있다"; failed=$((failed + 1)); continue; }

  [ -n "$ONLY" ] && [ "$ONLY" != "$id" ] && continue

  if [ ! -d "$HOME/.hermes/profiles/$id" ]; then
    echo "  ✗ $id — 프로필 없음"
    failed=$((failed + 1))
    continue
  fi

  [ "$DRY_RUN" -eq 1 ] && echo "  · $id"

  ok=1
  set_key "$id" model.default "$model" || ok=0
  if [ "$WITH_PROVIDER" -eq 1 ]; then
    set_key "$id" model.provider "$PROVIDER" || ok=0
    set_key "$id" model.base_url "$BASE_URL" || ok=0
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
    if [ "$ok" -eq 1 ]; then
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
  echo "  for id in \$(awk '!/^#/ && \$1!~/^@/ && NF {print \$1}' config/models.conf); do"
  echo "    printf '%-8s ' \"\$id\"; hermes -p \"\$id\" chat -q '1+1은?' 2>&1 | tail -1"
  echo "  done"
fi
