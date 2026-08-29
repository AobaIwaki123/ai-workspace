#!/usr/bin/env python3
import time
import json
import sys
import urllib.request
import urllib.error

sys.stdout.reconfigure(line_buffering=True)

# ==============================================================================
# Comprehensive Benchmark Dataset for English -> Japanese Katakana Conversion
# (Completely separated from the prompt to avoid data leakage)
# ==============================================================================

SYSTEM_PROMPT = """あなたは英単語やアルファベット略語を正確な日本語カタカナ読みに変換するAIです。

【変換ルール】
1. アルファベットの頭字語（略語）は、1文字ずつアルファベット読みをつなげます。
   - A: エー, B: ビー, C: シー, D: ディー, E: イー, F: エフ, G: ジー, H: エイチ, I: アイ
   - J: ジェー, K: ケー, L: エル, M: エム, N: エヌ, O: オー, P: ピー, Q: キュー, R: アール
   - S: エス, T: ティー, U: ユー, V: ブイ, W: ダブリュー, X: エックス, Y: ワイ, Z: ゼット
2. 一般的な英単語・技術固有名詞は、日本語で最も慣用的に使われるカタカナ読みにします。

出力は余計な解説を一切含めず、カタカナ読みのみを出力してください。"""

TEST_DATASET = [
    # --------------------------------------------------------------------------
    # Category 1: IT / Tech Acronyms (Letter-by-letter alphabet pronunciation)
    # --------------------------------------------------------------------------
    {"input": "GCP", "expected": ["ジーシーピー"], "category": "IT_Acronym"},
    {"input": "SDK", "expected": ["エスディーケー"], "category": "IT_Acronym"},
    {"input": "CLI", "expected": ["シーエルアイ"], "category": "IT_Acronym"},
    {"input": "SSH", "expected": ["エスエスエイチ"], "category": "IT_Acronym"},
    {"input": "DNS", "expected": ["ディーエヌエス"], "category": "IT_Acronym"},
    {"input": "TCP", "expected": ["ティーシーピー"], "category": "IT_Acronym"},
    {"input": "UDP", "expected": ["ユーディーピー"], "category": "IT_Acronym"},
    {"input": "SQL", "expected": ["エスキューエル", "エスケイエル"], "category": "IT_Acronym"},
    {"input": "HTML", "expected": ["エイチティーエムエル"], "category": "IT_Acronym"},
    {"input": "CSS", "expected": ["シーエスエス"], "category": "IT_Acronym"},
    {"input": "CPU", "expected": ["シーピーユー"], "category": "IT_Acronym"},
    {"input": "GPU", "expected": ["ジーピーユー"], "category": "IT_Acronym"},
    {"input": "VPN", "expected": ["ブイピーエヌ"], "category": "IT_Acronym"},
    {"input": "IoT", "expected": ["アイオーティー"], "category": "IT_Acronym"},
    {"input": "URL", "expected": ["ユーアールエル"], "category": "IT_Acronym"},
    {"input": "HTTP", "expected": ["エイチティーティーピー"], "category": "IT_Acronym"},
    {"input": "HTTPS", "expected": ["エイチティーティーピーエス"], "category": "IT_Acronym"},
    {"input": "API", "expected": ["エーピーアイ"], "category": "IT_Acronym"},
    {"input": "SSD", "expected": ["エスエスディー"], "category": "IT_Acronym"},

    # --------------------------------------------------------------------------
    # Category 2: General / Business / Culture Acronyms
    # --------------------------------------------------------------------------
    {"input": "CEO", "expected": ["シーイーオー"], "category": "General_Acronym"},
    {"input": "CTO", "expected": ["シーティーオー"], "category": "General_Acronym"},
    {"input": "CFO", "expected": ["シーエフオー"], "category": "General_Acronym"},
    {"input": "DX", "expected": ["ディーエックス"], "category": "General_Acronym"},
    {"input": "KPI", "expected": ["ケーピーアイ"], "category": "General_Acronym"},
    {"input": "GDP", "expected": ["ジーディーピー"], "category": "General_Acronym"},
    {"input": "FBI", "expected": ["エフビーアイ"], "category": "General_Acronym"},
    {"input": "CIA", "expected": ["シーアイエー"], "category": "General_Acronym"},
    {"input": "NPO", "expected": ["エヌピーオー"], "category": "General_Acronym"},
    {"input": "NGO", "expected": ["エヌジーオー"], "category": "General_Acronym"},
    {"input": "NHK", "expected": ["エヌエイチケー"], "category": "General_Acronym"},
    {"input": "JR", "expected": ["ジェイアール"], "category": "General_Acronym"},
    {"input": "PTA", "expected": ["ピーティーエー"], "category": "General_Acronym"},
    {"input": "SOS", "expected": ["エスオーエス"], "category": "General_Acronym"},
    {"input": "DJ", "expected": ["ディージェイ"], "category": "General_Acronym"},
    {"input": "VIP", "expected": ["ブイアイピー", "ビップ"], "category": "General_Acronym"},
    {"input": "PR", "expected": ["ピーアール"], "category": "General_Acronym"},
    {"input": "HR", "expected": ["エイチアール"], "category": "General_Acronym"},

    # --------------------------------------------------------------------------
    # Category 3: Tech Names, OSS & Brands (Phonics / Common Japanese Katakana)
    # --------------------------------------------------------------------------
    {"input": "Docker", "expected": ["ドッカー"], "category": "Tech_Brand"},
    {"input": "Ansible", "expected": ["アンシブル"], "category": "Tech_Brand"},
    {"input": "Terraform", "expected": ["テラフォーム"], "category": "Tech_Brand"},
    {"input": "Prometheus", "expected": ["プロメテウス"], "category": "Tech_Brand"},
    {"input": "Grafana", "expected": ["グラファナ"], "category": "Tech_Brand"},
    {"input": "Kafka", "expected": ["カフカ"], "category": "Tech_Brand"},
    {"input": "Oracle", "expected": ["オラクル"], "category": "Tech_Brand"},
    {"input": "Ubuntu", "expected": ["ウブントゥ", "ウブントゥー"], "category": "Tech_Brand"},
    {"input": "Debian", "expected": ["デビアン"], "category": "Tech_Brand"},
    {"input": "Python", "expected": ["パイソン"], "category": "Tech_Brand"},
    {"input": "Golang", "expected": ["ゴーラング", "ゴー"], "category": "Tech_Brand"},
    {"input": "Rust", "expected": ["ラスト"], "category": "Tech_Brand"},
    {"input": "TypeScript", "expected": ["タイプスクリプト"], "category": "Tech_Brand"},
    {"input": "JavaScript", "expected": ["ジャバスクリプト", "ジャヴァスクリプト"], "category": "Tech_Brand"},
    {"input": "Ruby", "expected": ["ルビー"], "category": "Tech_Brand"},
    {"input": "Swift", "expected": ["スウィフト", "スイフト"], "category": "Tech_Brand"},
    {"input": "Kotlin", "expected": ["コトリン"], "category": "Tech_Brand"},
    {"input": "React", "expected": ["リアクト"], "category": "Tech_Brand"},
    {"input": "Vue", "expected": ["ビュー"], "category": "Tech_Brand"},
    {"input": "Tailwind", "expected": ["テイルウィンド", "テールウィンド"], "category": "Tech_Brand"},
    {"input": "Slack", "expected": ["スラック"], "category": "Tech_Brand"},
    {"input": "Discord", "expected": ["ディスコード"], "category": "Tech_Brand"},
    {"input": "Notion", "expected": ["ノーション"], "category": "Tech_Brand"},
    {"input": "Figma", "expected": ["フィグマ"], "category": "Tech_Brand"},

    # --------------------------------------------------------------------------
    # Category 4: Mixed Alphanumeric / Symbols
    # --------------------------------------------------------------------------
    {"input": "Web3", "expected": ["ウェブスリー", "ウェブサン"], "category": "Mixed"},
    {"input": "IPv6", "expected": ["アイピーブイシックス", "アイピーブイロク"], "category": "Mixed"},
    {"input": "3D", "expected": ["スリーディー", "サンディー"], "category": "Mixed"},
    {"input": "4K", "expected": ["フォーケー", "ヨンケー"], "category": "Mixed"},
    {"input": "5G", "expected": ["ファイブジー", "ゴージー"], "category": "Mixed"},
    {"input": "B2B", "expected": ["ビートゥービー", "ビーツービー"], "category": "Mixed"},
]

def query_llama_server(input_text: str, endpoint="http://127.0.0.1:8080/v1/chat/completions"):
    payload = {
        "model": "default-llm",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"次の英語をカタカナ読みに変換してください:\n{input_text}"}
        ],
        "temperature": 0.0,
        "max_tokens": 32
    }
    
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(endpoint, data=data, headers={"Content-Type": "application/json"})
    
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=10) as response:
        res_body = json.loads(response.read().decode("utf-8"))
    latency = time.perf_counter() - start
    
    output_text = res_body["choices"][0]["message"]["content"].strip()
    return output_text, latency

def normalize_text(text: str) -> str:
    return text.replace("・", "").replace(" ", "").replace("　", "").replace("ー", "").replace("ッ", "").lower()

def is_match(actual: str, expected_list: list) -> bool:
    cleaned_actual = actual.strip().split("\n")[0].split("->")[-1].strip()
    norm_actual = normalize_text(cleaned_actual)
    for exp in expected_list:
        norm_exp = normalize_text(exp)
        if norm_exp in norm_actual or norm_actual in norm_exp:
            return True
    return False

def main():
    print("=" * 70, flush=True)
    print("  Expanded Benchmark: English -> Japanese Katakana Conversion", flush=True)
    print(f"  Total Test Cases: {len(TEST_DATASET)} (Zero-Shot Rule Generalization / Leak-Free)", flush=True)
    print("=" * 70, flush=True)

    category_stats = {}
    total_correct = 0
    latencies = []

    print(f"{'Input':<14} | {'Actual Output':<24} | {'Status':<6} | {'Time (ms)':<8}", flush=True)
    print("-" * 70, flush=True)

    for item in TEST_DATASET:
        inp = item["input"]
        expected = item["expected"]
        cat = item["category"]

        if cat not in category_stats:
            category_stats[cat] = {"total": 0, "correct": 0}
        category_stats[cat]["total"] += 1

        try:
            actual, lat = query_llama_server(inp)
            lat_ms = lat * 1000
            latencies.append(lat_ms)

            first_line = actual.split("\n")[0].strip()
            matched = is_match(first_line, expected)
            if matched:
                status = "PASS"
                total_correct += 1
                category_stats[cat]["correct"] += 1
            else:
                status = "FAIL"

            print(f"{inp:<14} | {first_line:<24} | {status:<6} | {lat_ms:6.1f} ms", flush=True)
        except Exception as e:
            print(f"{inp:<14} | ERROR: {str(e)[:20]:<17} | FAIL   |   --- ms", flush=True)

    print("=" * 70, flush=True)
    print("  Benchmark Summary & Category-wise Accuracy", flush=True)
    print("=" * 70, flush=True)
    print(f"  Total Test Cases: {len(TEST_DATASET)}", flush=True)
    print(f"  Overall Accuracy: {total_correct} / {len(TEST_DATASET)} ({total_correct / len(TEST_DATASET) * 100:.1f}%)", flush=True)
    if latencies:
        print(f"  Average Latency:  {sum(latencies)/len(latencies):.1f} ms (p95: {sorted(latencies)[int(len(latencies)*0.95)]:.1f} ms)", flush=True)
    print("-" * 70, flush=True)
    print(f"  {'Category':<20} | {'Correct / Total':<18} | {'Accuracy':<10}", flush=True)
    print("-" * 70, flush=True)
    for cat, stats in category_stats.items():
        acc = (stats["correct"] / stats["total"]) * 100
        print(f"  {cat:<20} | {stats['correct']:2d} / {stats['total']:2d}             | {acc:5.1f}%", flush=True)
    print("=" * 70, flush=True)

if __name__ == "__main__":
    main()
