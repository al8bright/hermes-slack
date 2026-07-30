# 폐기된 설계 문서

이 폴더의 문서들은 **Hermes를 직접 만든다는 잘못된 전제**로 작성되었다. 실제로는 [Hermes Agent (Nous Research)](https://hermes-agent.nousresearch.com/docs/) 라는 기존 제품이 이미 설치되어 있었다.

| 문서 | 무엇을 잘못 가정했나 |
| --- | --- |
| `launchpad-design.md` | Provider 어댑터·Slack Bolt 게이트웨이·launchd plist를 직접 구현한다고 가정. Hermes가 전부 기본 제공한다 |
| `cli-spec.md` | `hermes` CLI 명령 체계를 새로 설계. 실제 CLI가 이미 존재하며 명령 체계가 다르다 |
| `session-topology.md` | "10 프로세스 vs 1 프로세스"를 선택 가능한 설계로 취급. Hermes는 **프로필 = 에이전트 1개 = 모델 1개**로 제품 차원에서 확정되어 있어 선택지가 아니다 |

## 폐기 사유 상세

**결정적 오류**: "프로필 `bateam` 안에 10개 페르소나" 구조는 존재하지 않는다. Hermes 프로필은 `SOUL.md` 하나와 모델 하나를 가진다. 역할별로 다른 모델을 쓰려면 프로필을 10개 만들어야 한다.

## 살아남은 것

- [`roles/`](../../roles/) 의 페르소나 문서 10개 — 그대로 각 프로필의 `SOUL.md` 원본이 된다
- 역할별 성향 구분과 모델 배정 의도

## 현행 문서

현행 문서는 [`docs/`](../) 를 볼 것. 운영 방식은 [`06-team-workflow.md`](../06-team-workflow.md).
