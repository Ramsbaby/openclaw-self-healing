# Channel Persona Architecture

**컨텍스트별 AI 역할 분리 패턴**

## 개요

하나의 AI 시스템이 컨텍스트(채널, 사용자, 작업 유형)에 따라 다른 페르소나로 동작하는 아키텍처 패턴입니다.

## 핵심 원리

```
User Message
    ↓
Detect Context (channel, topic, user)
    ↓
Load Persona (systemPrompt)
    ↓
Apply Persona-Specific Rules
    ↓
Generate Response
```

## 구현 예시: Discord 채널별 Persona

### 1. Persona 정의

```typescript
interface Persona {
  name: string;
  responsibilities: string[];
  forbidden: string[];
  tone: string;
  output_format: OutputFormat;
  auto_routing: RoutingRule[];
  emoji_reactions: EmojiRule[];
  validation_checklist: string[];
}

const personas: Record<string, Persona> = {
  "general": {
    name: "일반 대화",
    responsibilities: ["범용 작업", "일상 대화", "프로젝트 관리"],
    forbidden: ["시장 분석", "시스템 알림", "코드 디버깅"],
    tone: "자비스 페르소나 (영국식 위트, 건방짐)",
    output_format: {
      max_chars: 2000,
      markdown: true,
      split_strategy: "auto"
    },
    auto_routing: [
      { trigger: "TQQQ|주가|시세", target: "market" },
      { trigger: "크론|에러|로그", target: "system" },
      { trigger: "코드|디버그|버그", target: "dev" }
    ],
    emoji_reactions: ["👀", "⏳", "✅", "❌"],
    validation_checklist: [
      "2000자 이하?",
      "도구 3회+ 시 중간 보고?",
      "링크 3개+ 시 <> 감쌈?"
    ]
  },
  
  "market": {
    name: "시장 분석",
    responsibilities: ["시세", "지표", "투자 분석", "리스크 평가"],
    forbidden: ["일반 대화", "시스템 상태", "코드 작업"],
    tone: "객관적, 데이터 중심, 리스크 명시",
    output_format: {
      required_fields: ["현재가 USD", "현재가 KRW", "변동률", "Stop-Loss 거리", "출처", "타임스탬프"],
      forbidden: ["테이블"],
      disclaimer: "투자 조언 아님, 손실 책임 없음"
    },
    auto_routing: [
      { trigger: "파일|프로젝트", target: "general" },
      { trigger: "시스템|크론", target: "system" }
    ],
    emoji_reactions: ["📈", "📉", "🚨", "💰"],
    validation_checklist: [
      "USD + KRW 포함?",
      "데이터 출처 명시?",
      "리스크 섹션?",
      "타임스탬프?"
    ]
  },
  
  "system": {
    name: "시스템 알림",
    responsibilities: ["크론 결과", "장애 알림", "리소스 상태"],
    forbidden: ["대화", "시장 정보", "코드 작업"],
    tone: "간결, 핵심만, 긴급도 명확",
    output_format: {
      template: "[긴급도] 제목\n- 핵심 데이터\n- 액션 아이템",
      max_log_lines: 10,
      mask_sensitive: true
    },
    auto_routing: [
      { trigger: "TQQQ|주가", target: "market" },
      { trigger: "코드|스택트레이스", target: "dev" }
    ],
    emoji_reactions: [],  // 이미 긴급도 이모지 포함
    validation_checklist: [
      "긴급도 이모지?",
      "로그 10줄 이하?",
      "민감 정보 마스킹?"
    ]
  },
  
  "dev": {
    name: "개발/디버깅",
    responsibilities: ["코드 분석", "디버깅", "시스템 설계"],
    forbidden: ["일반 대화", "시장 정보", "시스템 알림"],
    tone: "엔지니어 투 엔지니어, ChatGPT 톤 금지",
    output_format: {
      code_blocks_with_lang: true,
      error_analysis_steps: 5,
      performance_metrics: true
    },
    auto_routing: [
      { trigger: "TQQQ|시세", target: "market" },
      { trigger: "크론 실패", target: "system" }
    ],
    emoji_reactions: ["🐛", "🔧", "✅", "⚡"],
    validation_checklist: [
      "코드블록 언어 명시?",
      "5단계 에러 분석?",
      "성능 지표?",
      "ChatGPT 톤 없음?"
    ]
  }
}
```

### 2. Context Detection

```typescript
function detectContext(message: Message): string {
  // 1. Channel-based
  const channelId = message.channelId;
  if (channelToPersona[channelId]) {
    return channelToPersona[channelId];
  }
  
  // 2. Keyword-based (fallback)
  const keywords = {
    market: ["TQQQ", "주가", "시세", "투자", "Stop-Loss"],
    system: ["크론", "에러", "로그", "Gateway", "헬스체크"],
    dev: ["코드", "버그", "디버그", "스택트레이스", "성능"]
  };
  
  for (const [persona, words] of Object.entries(keywords)) {
    if (words.some(word => message.content.includes(word))) {
      return persona;
    }
  }
  
  // 3. Default
  return "general";
}
```

### 3. Auto-Routing

```typescript
async function handleMessage(message: Message) {
  const currentPersona = detectContext(message);
  const persona = personas[currentPersona];
  
  // Check if should route to different channel
  for (const rule of persona.auto_routing) {
    if (new RegExp(rule.trigger).test(message.content)) {
      // Send to correct channel
      await sendToChannel(rule.target, message.content);
      
      // Notify user
      await reply(message, `→ #${rule.target}로 전달했습니다.`);
      return;
    }
  }
  
  // Process in current persona
  const response = await generateResponse(message, persona);
  await reply(message, response);
}
```

### 4. Response Validation

```typescript
function validateResponse(response: string, persona: Persona): boolean {
  for (const check of persona.validation_checklist) {
    if (!passesCheck(response, check)) {
      console.warn(`Validation failed: ${check}`);
      response = autoFix(response, check, persona);
    }
  }
  return true;
}

function autoFix(response: string, check: string, persona: Persona): string {
  switch (check) {
    case "USD + KRW 포함?":
      if (!response.includes("₩")) {
        // Add KRW conversion
        response += "\n\n**참고:** KRW 환산 정보 누락. 토스증권에서 확인하세요.";
      }
      break;
    
    case "데이터 출처 명시?":
      if (!response.includes("출처:")) {
        response += "\n\n**출처:** Yahoo Finance (15분 지연)";
      }
      break;
    
    case "긴급도 이모지?":
      if (!["🚨", "⚠️", "ℹ️", "✅"].some(e => response.includes(e))) {
        response = "ℹ️ " + response;
      }
      break;
  }
  return response;
}
```

## 적용 사례

### Discord Bot

```javascript
// discord.js example
client.on('messageCreate', async (message) => {
  const persona = personas[message.channelId] || personas.general;
  const systemPrompt = buildSystemPrompt(persona);
  
  const response = await openai.chat.completions.create({
    model: "gpt-4",
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: message.content }
    ]
  });
  
  const validated = validateResponse(response, persona);
  await message.reply(validated);
});

function buildSystemPrompt(persona: Persona): string {
  return `
${persona.tone}

**책임:** ${persona.responsibilities.join(", ")}
**금지:** ${persona.forbidden.join(", ")}

**출력 형식:**
${JSON.stringify(persona.output_format, null, 2)}

**응답 전 Self-Check:**
${persona.validation_checklist.map(c => `- [ ] ${c}`).join("\n")}

**Escape Hatch:** 사용자가 "무시하고 X" 명령 시 규칙 우회
  `.trim();
}
```

### Slack App

```python
from slack_sdk import WebClient

personas = {
    "#support": SupportPersona(),
    "#sales": SalesPersona(),
    "#engineering": EngineeringPersona()
}

@app.event("message")
def handle_message(event, say):
    channel = event["channel"]
    persona = personas.get(channel, DefaultPersona())
    
    system_prompt = persona.build_system_prompt()
    response = llm.chat(system_prompt, event["text"])
    
    validated = persona.validate(response)
    say(validated)
```

### Customer Support System

```typescript
// Route by ticket category
const categoryPersonas = {
  "billing": BillingAgentPersona,
  "technical": TechSupportPersona,
  "sales": SalesAgentPersona,
  "general": GeneralSupportPersona
};

async function handleTicket(ticket: Ticket) {
  const category = classifyTicket(ticket);
  const Persona = categoryPersonas[category];
  const agent = new Persona();
  
  const response = await agent.respond(ticket.message);
  const validated = agent.validate(response);
  
  await replyToTicket(ticket, validated);
}
```

## 설계 패턴

### 1. Separation of Concerns

각 페르소나는 독립적:
- 책임 범위 명확
- 다른 페르소나 영향 없음
- 개별 테스트 가능

### 2. Composition over Inheritance

```typescript
class Persona {
  constructor(
    public tone: Tone,
    public validator: Validator,
    public router: Router,
    public formatter: Formatter
  ) {}
}

// Reuse components
const marketPersona = new Persona(
  new ObjectiveTone(),
  new FinancialValidator(),
  new TopicRouter(),
  new ListFormatter()
);
```

### 3. Strategy Pattern

```typescript
interface ToneStrategy {
  apply(text: string): string;
}

class JarvisTone implements ToneStrategy {
  apply(text: string): string {
    // Add British wit
    return addWit(text);
  }
}

class EngineerTone implements ToneStrategy {
  apply(text: string): string {
    // Remove ChatGPT friendliness
    return removeFriendliness(text);
  }
}
```

## 메트릭 & 모니터링

### 주간 품질 리포트

```yaml
channel_quality_report:
  "#general":
    messages: 150
    avg_length: 850
    validation_pass_rate: 0.92
    auto_routing_triggers: 12
    
  "#market":
    messages: 45
    required_fields_compliance: 0.95
    disclaimer_inclusion: 1.00
    data_freshness_mentioned: 0.98
    
  "#system":
    messages: 380
    urgency_emoji_rate: 1.00
    log_truncation_rate: 0.15
    duplicate_suppression: 0.08
    
  "#dev":
    messages: 78
    code_block_lang_rate: 0.97
    chatgpt_tone_detected: 0.02
    performance_metrics_rate: 0.85
```

### KPI 대시보드

```markdown
## 📊 Channel Persona KPI

| Channel | Messages | Quality Score | Auto-Routes | Top Issue |
|---------|----------|---------------|-------------|-----------|
| #general | 150 | 92% | 12 | Link wrapping |
| #market | 45 | 95% | 3 | KRW missing |
| #system | 380 | 100% | 8 | None |
| #dev | 78 | 97% | 5 | Lang missing |

**Overall Quality:** 96% ✅
**Target:** 90%+
```

## 한계 및 해결

### 문제 1: 컨텍스트 애매함

**예:** "TQQQ 로그 분석해줘" → #market? #system? #dev?

**해결:**
1. 우선순위 규칙 (market > system > dev)
2. 사용자에게 물어보기
3. 여러 채널에 동시 전달

### 문제 2: Persona 충돌

**예:** #system에서 "무시하고 TQQQ 가격 보여줘"

**해결:** Escape Hatch (사용자 명령 > 채널 규칙)

### 문제 3: 과도한 복잡성

**해결:** 시작은 2-3개 페르소나, 점진적 확장

## 권장사항

1. **시작은 간단하게:** 페르소나 2-3개
2. **점진적 확장:** 필요할 때만 추가
3. **사용자 피드백:** "이 채널 응답 스타일 어때요?"
4. **A/B 테스트:** 새 페르소나 실험
5. **정기 감사:** 주간 품질 리포트

## 참고 구현

- OpenClaw Discord Channels: `~/openclaw/docs/self-healing-system.md`
- Config: `~/.openclaw/openclaw.json` (channels.discord.guilds.*.channels.*.systemPrompt)
- Quality Audit: `~/openclaw/scripts/discord-channel-quality-audit.sh`

---

**버전:** 1.0.0  
**작성일:** 2026-02-08  
**라이센스:** MIT
