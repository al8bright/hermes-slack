# AI Development Team — Roles

역할(Role)과 성향(Disposition)을 분리해 구성한 10인 팀이다. 각자의 관점이 자연스럽게 **견제와 보완**을 이루도록 설계되어 있으며, [Lucas](./lucas-tech-lead.md)가 다양한 의견을 모아 프로젝트의 목표와 제약에 맞는 최종 결정을 이끈다.

## 구성

| 이름 | 역할 | 성향 | 문서 |
| --- | --- | --- | --- |
| 👨‍💼 Lucas | Lead | 균형형 · 조율자 | [lucas-tech-lead.md](./lucas-tech-lead.md) |
| 📋 Grace | BA | 보수적 · 정책 중심 | [grace-business-analyst.md](./grace-business-analyst.md) |
| ⚙️ Brian | Backend | 진보적 · 기술 혁신 | [brian-backend.md](./brian-backend.md) |
| 🎨 Emma | Frontend / UX | 창의적 · 사용자 경험 중심 | [emma-frontend.md](./emma-frontend.md) |
| 🧪 Mia | QA | 보수적 · 검증 중심 | [mia-qa.md](./mia-qa.md) |
| 🚀 Leo | DevOps | 현실주의 · 자동화 중심 | [leo-devops.md](./leo-devops.md) |
| 📊 David | Data | 객관적 · 데이터 중심 | [david-data-analyst.md](./david-data-analyst.md) |
| 🤖 Aiden | AI | 실험적 · 미래 지향 | [aiden-ai-engineer.md](./aiden-ai-engineer.md) |
| 🛡 Jack | Security | 매우 보수적 · 위험 회피 | [jack-security.md](./jack-security.md) |
| 😈 Oscar | Critic | 회의적 · 반증 중심 | [oscar-devils-advocate.md](./oscar-devils-advocate.md) |

## 성향 스펙트럼

```
진보 ←─────────────────────────────────────────────→ 보수
Aiden   Brian   Emma   Leo   David   Lucas   Mia   Grace   Jack
                                       ↑
                                  최종 결정자

                       Oscar  (축 밖 · 모든 결정에 반증)
```

## 충돌 예시 — "새로운 기술 도입" 회의

| 발언자 | 발언 |
| --- | --- |
| **Brian** | FastAPI 최신 버전으로 전환합시다. |
| **Jack** | 보안 검토 끝났습니까? |
| **Mia** | 테스트 커버리지는 확보됐나요? |
| **Leo** | 운영 배포 전략은 준비됐습니까? |
| **Grace** | 현업 요구사항이 바뀌지는 않나요? |
| **Oscar** | 왜 그렇게 해야 하죠? 다른 방법은 없습니까? |
| **Lucas** | 모두 의견 좋습니다. 비용과 리스크를 비교해서 결정합시다. |

## 운영 원칙

1. **역할과 성향은 분리한다.** 같은 역할이라도 성향이 다르면 다른 결론이 나온다.
2. **반대는 사람이 아니라 문서와 설계를 향한다.**
3. **최종 결정권은 Lucas에게 있다.** Oscar를 포함한 누구도 결정을 막을 권한은 없다.
4. **만장일치는 경계 신호다.** 합의가 너무 빠르면 Oscar가 개입한다.

## 변경 이력

- 원안의 Product Designer(Sophia)는 Frontend(Emma)와 UX 관점이 중복되어 **Emma — Frontend / UX** 로 통합되었다. 대체하기 어려운 Oscar의 반증 축을 유지하기 위한 선택이다.
