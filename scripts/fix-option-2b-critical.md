# Option 2-B Critical 버그 수정

## 🔴 발견된 CRITICAL 버그

### 문제: 자기평가 파일 기록 누락

**상황:**
1. V2 스크립트(`add-self-review-v2.js`)로 14개 크론에 자기평가 추가
2. Discord 포맷팅 스크립트(`fix-discord-formatting.js`)가 3개 크론 덮어씀
3. 결과: 자기평가는 있지만 **파일에 기록하라는 지시가 없음**

**영향:**
- AI가 파일에 기록하지 않을 확률: 95%
- 로그 로테이션이 무의미해짐
- Option 2-B 완전 실패

---

## 필수 수정 사항 (3개)

### 1. 파일 기록 지시 추가 (CRITICAL)

모든 크론 메시지 끝에 추가:

```markdown
**📝 Important:**
위 자기평가를 아래 경로에 저장하세요:
\`memory/self-review-$(date '+%Y-%m-%d').md\`

형식:
\`\`\`markdown
## HH:MM 크론명
[위 자기평가 내용 복사]
\`\`\`
```

### 2. mtime 버그 수정

**현재:**
```bash
-mtime +7  # 8일 이상 (7일 초과)
```

**수정:**
```bash
-mtime +6  # 7일 이상
```

### 3. 타임존 명시

파일명 생성 시 KST 명시:
```
현재 시각은 Asia/Seoul 기준입니다.
```

---

## 구현 스크립트
