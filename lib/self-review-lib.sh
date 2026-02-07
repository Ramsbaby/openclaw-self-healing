#!/bin/bash
# self-review-lib.sh
# Version: 5.0.1
# Common library for cron self-review (AOP pattern)

# 환경 검증
if [[ -z "$HOME" ]]; then
  echo "ERROR: HOME environment variable not set" >&2
  return 1
fi

# 메인 자기평가 함수 (네임스페이스: sr_)
sr_log_review() {
  local cron_name="$1"
  local duration="$2"
  local input_tokens="$3"
  local output_tokens="$4"
  local review_status="$5"
  local what_went_wrong="$6"
  local why="$7"
  local next_action="$8"
  
  # self-review-logger.sh 호출 (실패해도 크론은 계속)
  "$HOME/openclaw/scripts/self-review-logger.sh" \
    "$cron_name" "$duration" "$input_tokens" "$output_tokens" "$review_status" \
    "$what_went_wrong" "$why" "$next_action" 2>&1 || {
    echo "WARN: Self-review logging failed (continuing cron execution)" >&2
    return 0
  }
}

# 버전 정보 출력 함수
sr_version() {
  echo "self-review-lib.sh v5.0.1"
}

# 초기화 메시지 (source 시 실행)
echo "[self-review-lib] Loaded v5.0.1" >&2
