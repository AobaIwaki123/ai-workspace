import sqlite3
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key="local-unsloth",
)
response = client.chat.completions.create(
    model="default",
    messages=[{"role": "user", "content": "hello"}],
    max_tokens=10
)
print(response.choices[0].message.content)
