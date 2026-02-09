# 시스템 개선 계획
> 최종 업데이트: 2026-02-03 13:54

## ✅ 완료된 항목

### 보안
- [x] **exec.security 검토**: 광범위한 연구 후 "full" 유지 결정
  - 20+ cron, 수십 개 스크립트, 각 스크립트마다 여러 바이너리 호출
  - allowlist 관리 = 유지보수 지옥
  - 채널 제한 + elevated 제한으로 충분한 방어

### Cron 최적화
- [x] GitHub Watcher: 하루 2회 → 1회 (17:00만)
- [x] Market Volatility: 자정~새벽 6시만 (23:00 제거)
- [x] 시간당 체크: 09→10 (월간 비용 추적과 분리)
- [x] 모든 cron Haiku 모델 적용 (Trend Hunter만 Opus)
- [x] 3개 cron model 누락 수정 (Backup/Rotation/Update)

### 토큰 최적화
- [x] memoryFlush: 50k → 70k (35% of 200k)
- [x] contextPruning.ttl: 1h → 3h
- [x] Sub-agent 기본 모델: Haiku

### 모니터링 확장
- [x] 주간 요약 리포트 (일요일 20:00)
- [x] 월간 비용 추적 (매주 월요일 09:00)
- [x] 디스크 용량 경고 (매일 05:00)

### 기타
- [x] Memory cleanup automation (weekly/monthly)
- [x] Preply GCP 보안 강화 (internal ingress)
- [x] Cron 중복 제거 및 정리

## 🚫 보류/기각 항목

### Skills 마이그레이션
- **Status**: 보류
- **이유**: 20+ cron 메시지에 `~/clawd/skills/` 하드코딩
- **리스크**: 경로 변경 시 전체 재작성 필요, 실수 가능성 높음
- **대안**: 현재 상태 유지, 새 skill은 `~/openclaw/skills/`에 추가

### Config 버전 관리
- **Status**: 보류
- **이유**: Gateway config.patch가 자동 백업 제공
- **대안**: 수동 백업 필요 시 `~/openclaw/config-backup/` 사용

## 📊 최종 상태

**활성 Cron: 23개**
- Haiku 모델: 22개
- Opus 모델: 1개 (Trend Hunter)
- 모든 cron isolation 설정 완료
- Model 필드 누락 해결

**시간별 분포:**
- 야간 (00-05): 5개 (Market Volatility 포함)
- 오전 (06-11): 6개
- 오후 (12-17): 6개
- 저녁 (18-23): 6개

**예상 효과:**
- 토큰 비용: ~15% 절감 (cron 빈도 조정)
- Context 지속성: ~40% 개선 (70k flush, 3h TTL)
- 모니터링: 주간/월간 리포트로 장기 추세 파악
