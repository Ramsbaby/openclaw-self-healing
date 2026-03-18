#!/usr/bin/env bash
# scripts/lib/llm-gateway.sh — LLM-agnostic AI call wrapper (v3.3)
#
# Level 3 Emergency Recovery can now use any major LLM — not just Claude.
# Source this file, then call ask_llm() with your diagnostic prompt.
#
# Supported providers:
#   claude  — Claude Code CLI (default, no extra API key with Max sub)
#   openai  — OpenAI GPT-4o / GPT-4-turbo / GPT-4o-mini
#   gemini  — Google Gemini 2.0 Flash / 1.5 Pro
#   ollama  — Any local Ollama model (fully offline, no API key)
#
# Configuration (set in ~/.openclaw/.env):
#   OPENCLAW_LLM_PROVIDER  — claude | openai | gemini | ollama  (default: claude)
#   OPENCLAW_LLM_MODEL     — override model name (optional)
#   OPENCLAW_CLAUDE_BIN    — claude binary path (default: /opt/homebrew/bin/claude)
#   OPENAI_API_KEY         — required if provider=openai
#   GOOGLE_API_KEY         — required if provider=gemini
#   OLLAMA_BASE_URL        — Ollama endpoint (default: http://localhost:11434)

LLM_PROVIDER="${OPENCLAW_LLM_PROVIDER:-claude}"

# ask_llm <prompt> [timeout_seconds]
# Sends a prompt to the configured LLM, prints response to stdout.
# Returns 0 on success, 1 on failure.
ask_llm() {
  local prompt="$1"
  local timeout_sec="${2:-90}"

  case "$LLM_PROVIDER" in
    claude|"")
      local bin="${OPENCLAW_CLAUDE_BIN:-/opt/homebrew/bin/claude}"
      if [[ ! -x "$bin" ]]; then
        echo "ERROR: claude binary not found at $bin" >&2
        return 1
      fi
      timeout "$timeout_sec" "$bin" -p "$prompt" 2>/dev/null
      ;;

    openai|gpt-4|gpt-4o|gpt-4o-mini|gpt-4-turbo)
      local model="${OPENCLAW_LLM_MODEL:-gpt-4o}"
      if [[ -z "${OPENAI_API_KEY:-}" ]]; then
        echo "ERROR: OPENAI_API_KEY not set (required for provider=openai)" >&2
        return 1
      fi
      python3 - <<PYEOF
import openai, os, sys
try:
    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    r = client.chat.completions.create(
        model="${model}",
        messages=[{"role": "user", "content": """${prompt}"""}],
        max_tokens=4096
    )
    print(r.choices[0].message.content)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
      ;;

    gemini|gemini-2.0-flash|gemini-1.5-pro)
      local model="${OPENCLAW_LLM_MODEL:-gemini-2.0-flash}"
      if [[ -z "${GOOGLE_API_KEY:-}" ]]; then
        echo "ERROR: GOOGLE_API_KEY not set (required for provider=gemini)" >&2
        return 1
      fi
      python3 - <<PYEOF
import google.generativeai as genai, os, sys
try:
    genai.configure(api_key=os.environ["GOOGLE_API_KEY"])
    model = genai.GenerativeModel("${model}")
    r = model.generate_content("""${prompt}""")
    print(r.text)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
      ;;

    ollama)
      local model="${OPENCLAW_LLM_MODEL:-llama3.2}"
      local base_url="${OLLAMA_BASE_URL:-http://localhost:11434}"
      local prompt_json
      prompt_json=$(python3 -c "import json, sys; print(json.dumps(sys.stdin.read()))" <<< "$prompt")
      curl -s --max-time "$timeout_sec" \
        "${base_url}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model}\",\"prompt\":${prompt_json},\"stream\":false}" \
        | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('response',''))
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
"
      ;;

    *)
      echo "ERROR: Unknown LLM provider: '$LLM_PROVIDER'" >&2
      echo "  Valid options: claude, openai, gemini, ollama" >&2
      return 1
      ;;
  esac
}

# llm_provider_info — prints a human-readable description of the active provider
llm_provider_info() {
  case "$LLM_PROVIDER" in
    claude|"")  echo "Claude Code CLI (${OPENCLAW_CLAUDE_BIN:-/opt/homebrew/bin/claude})" ;;
    openai)     echo "OpenAI ${OPENCLAW_LLM_MODEL:-gpt-4o}" ;;
    gemini)     echo "Google Gemini ${OPENCLAW_LLM_MODEL:-gemini-2.0-flash}" ;;
    ollama)     echo "Ollama ${OPENCLAW_LLM_MODEL:-llama3.2} @ ${OLLAMA_BASE_URL:-http://localhost:11434}" ;;
    *)          echo "Unknown provider: $LLM_PROVIDER" ;;
  esac
}
