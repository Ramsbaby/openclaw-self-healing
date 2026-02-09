# 한글 숙제 자동 교정 시스템 v6 아키텍처

## 목표
**어떤 손글씨 숙제 이미지가 오더라도 처리할 수 있는 범용 서비스**

## 핵심 문제
1. **인쇄 텍스트 vs 손글씨 구분** — 좌표 하드코딩 없이 자동 식별
2. **문법/철자 오류 자동 감지** — 패턴 하드코딩 없이
3. **오류 위치 자동 매칭** — Y 범위 하드코딩 없이

## 해결 전략

### 전략 A: 맞춤법 검사 기반 (간단)
```
[이미지]
   ↓
[Google Vision OCR] → 전체 텍스트 + 좌표
   ↓
[한국어 맞춤법 검사 API] → 오류 목록 (py-hanspell / 부산대)
   ↓
[매칭] → 오류 텍스트의 OCR 좌표 찾기
   ↓
[마킹]
```

**장점:** 간단, 인쇄 텍스트는 오류 없으니 자동 제외
**단점:** OCR이 손글씨를 자동 보정 (띄어쓰기 삽입, 불완전 글자 정상화)

### 전략 B: Vision LLM 기반 (정확)
```
[이미지]
   ↓
[Claude/GPT-4 Vision] → 손글씨 오류 목록 + 위치 설명
   ↓
[Google Vision OCR] → 전체 텍스트 + 좌표
   ↓
[매칭 엔진] → Vision 분석 + OCR 좌표 자동 매칭
   ↓
[마킹]
```

**장점:** 불완전 글자도 감지, 위치 정확
**단점:** API 비용, 복잡도

### 전략 C: 하이브리드 (권장)
1. **Claude Vision으로 이미지 분석** — JSON 형식 오류 목록
2. **Google Vision OCR** — 좌표 추출
3. **퍼지 매칭** — 오류 텍스트와 OCR 결과 매칭 (유사도 기반)
4. **마킹**

## 구현 단계

### Phase 1: 프로토타입 (현재 세션)
- Claude Vision으로 이미지 분석 (수동)
- Google Vision OCR 스크립트
- 매칭 + 마킹 스크립트

### Phase 2: API 자동화
- Claude API 또는 OpenAI GPT-4o Vision API 통합
- 단일 스크립트로 end-to-end 처리

### Phase 3: 서비스화
- Discord 봇이 #jarvis-preply-tutor에서 이미지 받으면 자동 처리
- 크론으로 채널 모니터링

## Claude Vision 프롬프트 (Phase 1)

```
이 한국어 숙제 이미지를 분석해주세요.

1. 손글씨 영역 식별 (인쇄 텍스트 제외)
2. 손글씨에서 문법/철자/띄어쓰기 오류 감지
3. 불완전한 글자 감지 (예: "아ㅍ요")

JSON 형식으로 응답:
{
  "errors": [
    {
      "original": "실제 손글씨",
      "corrected": "올바른 표현",
      "type": "spelling|spacing|incomplete|verb",
      "location": "위치 설명 (예: 상단 첫 번째 빈칸, 하단 세 번째 줄)"
    }
  ]
}
```

## 한국어 맞춤법 검사 API

### py-hanspell (네이버)
```python
from hanspell import spell_checker
result = spell_checker.check("이가아파요")
print(result.checked)  # "이가 아파요"
```

### 부산대 맞춤법 검사기
```python
import requests
url = "http://speller.cs.pusan.ac.kr/results"
data = {"text1": "이가아파요"}
response = requests.post(url, data=data)
# HTML 파싱 필요
```

## 다음 단계
1. [x] 아키텍처 문서화
2. [ ] py-hanspell 설치 및 테스트
3. [ ] Claude Vision 프롬프트 테스트
4. [ ] v6 스크립트 구현
5. [ ] Discord 자동화
