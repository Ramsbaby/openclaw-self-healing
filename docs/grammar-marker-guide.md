# Korean Grammar Marker - 한국어 문법 교정 이미지 마킹

## 개요

학생 숙제 이미지에서 문법 오류를 시각적으로 마킹하는 도구입니다.

## 기능

- 🔴 빨간 물결 밑줄: 오류 위치 표시
- 🟢 초록 박스: 교정 텍스트
- L# 라인 번호: 위치 참조

## 사용 방법

### #jarvis-preply-tutor 채널에서

1. **학생 숙제 이미지 업로드**
2. **"문법 교정해줘" 또는 "이거 마킹해줘" 요청**
3. **자비스가 분석 후 마킹된 이미지 반환**

### 예시 요청

```
[이미지 업로드]
"이 숙제 문법 오류 마킹해줘"
```

```
[이미지 업로드]
"2번이랑 4번 문장 틀린 것 같은데 교정해줘"
```

## 기술 스택

- **Vision API**: 이미지에서 텍스트 인식
- **Claude**: 문법 분석 및 교정
- **Python + Pillow**: 이미지 마킹

## 파일 위치

- 마킹 스크립트: `~/openclaw/scripts/korean-grammar-marker.py`
- 워크플로우: `~/openclaw/scripts/grammar-correction-workflow.sh`

## Corrections JSON 형식

```json
[
  {
    "line": 2,
    "original": "맛있는 먹었어요",
    "corrected": "맛있게 먹었어요",
    "error_type": "adverb",
    "position": {
      "x": 50,
      "y": 100,
      "width": 180,
      "height": 25
    }
  }
]
```

### 필드 설명

| 필드 | 설명 |
|------|------|
| line | 문장 번호 |
| original | 원본 (틀린 부분) |
| corrected | 교정된 텍스트 |
| error_type | 오류 유형 (grammar, spelling, adverb, politeness 등) |
| position.x | 오류 시작 X 좌표 (픽셀) |
| position.y | 오류 시작 Y 좌표 (픽셀) |
| position.width | 밑줄 길이 |
| position.height | 텍스트 높이 |

## 자비스 워크플로우

```
1. 와이프님이 이미지 업로드
2. 자비스 Vision으로 텍스트 인식
3. Claude가 문법 분석 + 오류 위치 추정
4. korean-grammar-marker.py 실행
5. 마킹된 이미지 Discord에 업로드
```

## 제한사항

- OCR 정확도에 따라 위치가 정확하지 않을 수 있음
- 손글씨는 인식률이 낮을 수 있음
- 복잡한 레이아웃은 수동 위치 지정 필요

## 향후 개선

- [ ] OCR 통합 (EasyOCR 또는 Tesseract)
- [ ] 자동 위치 감지 정확도 향상
- [ ] 다양한 마킹 스타일 지원
- [ ] 인쇄체/손글씨 구분

---

*Created: 2026-02-08*
*Author: Jarvis for 와이프님's Preply tutoring*
