#!/usr/bin/env python3
"""
Lightweight & Clean Web Chat UI for local llama-server.
Uses pure Server-Sent Events (SSE) proxy to eliminate CORS & chunk size bugs.
"""
import http.server
import socketserver
import json
import urllib.request
import urllib.error
import sys

PORT = 8080
LLAMA_ENDPOINT = "http://127.0.0.1:8081/v1/chat/completions"

HTML_CONTENT = """<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Meta Llama 3.2 3B Local Chat</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #1e1e2e; color: #cdd6f4; display: flex; flex-direction: column; height: 100vh; }
        header { background: #181825; padding: 14px 20px; border-bottom: 1px solid #313244; display: flex; justify-content: space-between; align-items: center; }
        header h1 { font-size: 1.1rem; color: #89b4fa; font-weight: 600; }
        .badge { background: #a6e3a1; color: #11111b; font-size: 0.75rem; font-weight: bold; padding: 4px 10px; border-radius: 12px; }
        #chat-container { flex: 1; overflow-y: auto; padding: 20px; display: flex; flex-direction: column; gap: 16px; }
        .message { max-width: 80%; padding: 12px 16px; border-radius: 14px; line-height: 1.6; font-size: 0.95rem; white-space: pre-wrap; word-break: break-word; }
        .message.user { align-self: flex-end; background: #89b4fa; color: #11111b; border-bottom-right-radius: 2px; }
        .message.assistant { align-self: flex-start; background: #313244; color: #cdd6f4; border-bottom-left-radius: 2px; border: 1px solid #45475a; }
        .message.system { align-self: center; background: #45475a; color: #a6adc8; font-size: 0.8rem; border-radius: 6px; padding: 6px 12px; }
        #input-area { background: #181825; padding: 16px 20px; border-top: 1px solid #313244; display: flex; gap: 10px; }
        textarea { flex: 1; background: #313244; border: 1px solid #45475a; color: #cdd6f4; padding: 10px 14px; border-radius: 8px; font-size: 0.95rem; resize: none; height: 50px; outline: none; }
        textarea:focus { border-color: #89b4fa; }
        button { background: #89b4fa; color: #11111b; border: none; padding: 0 20px; border-radius: 8px; font-weight: bold; cursor: pointer; transition: background 0.2s; }
        button:hover { background: #b4befe; }
        button:disabled { background: #585b70; cursor: not-allowed; }
        .clear-btn { background: #45475a; color: #cdd6f4; padding: 6px 12px; border-radius: 6px; font-size: 0.8rem; border: none; cursor: pointer; }
        .clear-btn:hover { background: #f38ba8; color: #11111b; }
    </style>
</head>
<body>
    <header>
        <div>
            <h1>🦙 Meta Llama-3.2-3B Local Web Chat</h1>
        </div>
        <div style="display: flex; gap: 10px; align-items: center;">
            <span class="badge">GTX 1650 Ti (4GB) Online</span>
            <button class="clear-btn" onclick="clearHistory()">Clear Chat</button>
        </div>
    </header>
    <div id="chat-container">
        <div class="message system">モデル: Meta Llama-3.2-3B-Instruct (GPU 100% 全層オフロード稼働中)</div>
    </div>
    <div id="input-area">
        <textarea id="prompt-input" placeholder="メッセージを入力してください... (Enter で送信, Shift+Enter で改行)" onkeydown="handleKeyDown(event)"></textarea>
        <button id="send-btn" onclick="sendMessage()">送信</button>
    </div>

    <script>
        const chatContainer = document.getElementById('chat-container');
        const promptInput = document.getElementById('prompt-input');
        const sendBtn = document.getElementById('send-btn');

        let messages = [
            { role: "system", content: "あなたは親切で有能なAIアシスタントです。日本語で自然かつ簡潔に回答してください。" }
        ];

        function handleKeyDown(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        }

        function appendMessage(role, text) {
            const div = document.createElement('div');
            div.className = 'message ' + role;
            div.textContent = text;
            chatContainer.appendChild(div);
            chatContainer.scrollTop = chatContainer.scrollHeight;
            return div;
        }

        async function sendMessage() {
            const text = promptInput.value.trim();
            if (!text) return;

            promptInput.value = '';
            appendMessage('user', text);
            messages.push({ role: 'user', content: text });

            promptInput.disabled = true;
            sendBtn.disabled = true;

            const assistantMsgDiv = appendMessage('assistant', '');

            try {
                // Same-origin POST to avoid CORS issues
                const response = await fetch('/api/chat', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ messages: messages })
                });

                if (!response.ok) {
                    throw new Error('HTTP status ' + response.status);
                }

                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                let assistantText = '';
                let buffer = '';

                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;

                    buffer += decoder.decode(value, { stream: true });
                    const lines = buffer.split('\\n');
                    buffer = lines.pop(); // Keep incomplete trailing chunk

                    for (const line of lines) {
                        const trimmed = line.trim();
                        if (!trimmed || !trimmed.startsWith('data: ')) continue;
                        const dataStr = trimmed.slice(6);
                        if (dataStr === '[DONE]') break;

                        try {
                            const parsed = JSON.parse(dataStr);
                            const content = parsed.choices[0]?.delta?.content || '';
                            if (content) {
                                assistantText += content;
                                assistantMsgDiv.textContent = assistantText;
                                chatContainer.scrollTop = chatContainer.scrollHeight;
                            }
                        } catch (e) {
                            // ignore JSON parse on incomplete chunks
                        }
                    }
                }

                messages.push({ role: 'assistant', content: assistantText });
            } catch (err) {
                assistantMsgDiv.textContent = '[エラー: 接続に失敗しました] ' + err.message;
            } finally {
                promptInput.disabled = false;
                sendBtn.disabled = false;
                promptInput.focus();
            }
        }

        function clearHistory() {
            messages = [messages[0]];
            chatContainer.innerHTML = '<div class="message system">会話履歴をクリアしました。</div>';
            promptInput.focus();
        }
    </script>
</body>
</html>
"""

class RobustChatHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path.startswith("/?"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_CONTENT.encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/api/chat":
            content_length = int(self.headers.get("Content-Length", 0))
            post_data = self.rfile.read(content_length)
            req_json = json.loads(post_data.decode("utf-8"))

            payload = {
                "model": "default-llm",
                "messages": req_json.get("messages", []),
                "temperature": 0.7,
                "max_tokens": 1024,
                "stream": True
            }

            req = urllib.request.Request(
                LLAMA_ENDPOINT,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )

            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.end_headers()

            try:
                with urllib.request.urlopen(req, timeout=60) as response:
                    while True:
                        chunk = response.read(128)
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        self.wfile.flush()
            except Exception as e:
                err_payload = f"data: {{\"choices\": [{{\"delta\": {{\"content\": \"\\n[Error: {str(e)}]\"}}}}]}}\n\n"
                self.wfile.write(err_payload.encode("utf-8"))
                self.wfile.flush()
        else:
            self.send_response(404)
            self.end_headers()

def run_server():
    server = socketserver.TCPServer(("0.0.0.0", PORT), RobustChatHandler)
    server.allow_reuse_address = True
    print(f"[SUCCESS] Clean Web Chat UI serving on http://0.0.0.0:{PORT}")
    server.serve_forever()

if __name__ == "__main__":
    run_server()
