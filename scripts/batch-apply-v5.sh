#!/bin/bash
# V5.0.1 전면 적용 스크립트
# 남은 크론들에 V5.0.1 footer 일괄 추가

set -euo pipefail

# V5.0.1 footer
read -r -d '' FOOTER << 'EOF' || true

---

**V5.0.1 자기평가 (Discord 출력 금지!)**

작업 완료 후 다음을 실행하세요:

1. 작업 품질을 1-10점으로 자체 평가
2. 사용한 토큰 추정 (입력/출력)
3. 문제점, 원인, 다음 액션 파악
4. 다음 명령 실행:

\`\`\`bash
bash ~/openclaw/scripts/self-review-logger.sh \\
  "CRON_NAME" \\
  "점수(1-10)" \\
  "입력토큰추정" \\
  "출력토큰추정" \\
  "ok 또는 error" \\
  "문제점(없으면 '없음')" \\
  "원인(없으면 'N/A')" \\
  "다음액션(없으면 '없음')"
\`\`\`

**중요:**
- 실제 값으로 치환할 것 (플레이스홀더 금지)
- 파일은 \`memory/self-review/YYYY-MM-DD/CRON_NAME_HHMMSS.yaml\`에 저장
- 사용자에게는 출력하지 말 것
EOF

echo "✅ V5.0.1 일괄 적용 스크립트 준비 완료"
echo ""
echo "사용법:"
echo "  이 스크립트는 수동 실행용입니다."
echo "  각 크론의 message 필드에 FOOTER를 추가하려면"
echo "  openclaw cron update 명령을 사용하세요."
echo ""
echo "Footer 길이: ${#FOOTER} 바이트"
