#!/usr/bin/env python3
"""
Interactive & Command-line Chat CLI for Meta Llama-3.2-3B-Instruct.
Supports streaming responses, colorized output, interactive mode, and single-shot arguments.
"""
import sys
import json
import urllib.request
import urllib.error

ENDPOINT = "http://127.0.0.1:8080/v1/chat/completions"

def stream_chat(messages):
    payload = {
        "model": "default-llm",
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": 1024,
        "stream": True
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(ENDPOINT, data=data, headers={"Content-Type": "application/json"})

    assistant_reply = []
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            for line in response:
                line = line.decode("utf-8").strip()
                if not line or not line.startswith("data: "):
                    continue
                data_str = line[6:]
                if data_str == "[DONE]":
                    break
                try:
                    chunk = json.loads(data_str)
                    delta = chunk["choices"][0].get("delta", {})
                    content = delta.get("content", "")
                    if content:
                        print(content, end="", flush=True)
                        assistant_reply.append(content)
                except Exception:
                    continue
    except urllib.error.URLError as e:
        print(f"\n[ERROR] Failed to connect to llama-server at {ENDPOINT}: {e}")
        return ""
    
    print()
    return "".join(assistant_reply)

def main():
    # If arguments are passed (e.g. ./chat_cli.py "質問内容")
    if len(sys.argv) > 1:
        prompt = " ".join(sys.argv[1:])
        messages = [
            {"role": "system", "content": "あなたは親切で有能なAIアシスタントです。日本語で自然に会話してください。"},
            {"role": "user", "content": prompt}
        ]
        print("\033[1;32mLlama-3.2-3B:\033[0m ", end="", flush=True)
        stream_chat(messages)
        return

    # Interactive REPL mode
    print("=" * 70)
    print("  🦙 Meta Llama-3.2-3B-Instruct Local Interactive Chat")
    print(f"  Connected to: {ENDPOINT}")
    print("  Type 'exit', 'quit', or 'clear' to reset history. Press Ctrl+C to exit.")
    print("=" * 70)

    messages = [
        {"role": "system", "content": "あなたは親切で有能なAIアシスタントです。日本語で自然に会話してください。"}
    ]

    while True:
        try:
            user_input = input("\n\033[1;36mYou:\033[0m ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nGoodbye!")
            break

        if not user_input:
            continue
        if user_input.lower() in ["exit", "quit"]:
            print("Goodbye!")
            break
        if user_input.lower() == "clear":
            messages = [messages[0]]
            print("[INFO] Conversation history cleared.")
            continue

        messages.append({"role": "user", "content": user_input})
        print("\033[1;32mLlama-3.2-3B:\033[0m ", end="", flush=True)
        reply = stream_chat(messages)
        if reply:
            messages.append({"role": "assistant", "content": reply})

if __name__ == "__main__":
    main()
