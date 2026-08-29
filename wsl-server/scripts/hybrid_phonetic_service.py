#!/usr/bin/env python3
import time
import json
import re
import sys
import urllib.request

sys.stdout.reconfigure(line_buffering=True)

# ==============================================================================
# Hybrid Phonetic Conversion Pipeline (Deterministic Rule-Engine + LLM Fallback)
# ==============================================================================

# 1. Alphabet Pronunciation Mapping (A-Z)
ALPHABET_TABLE = {
    "A": "エー", "B": "ビー", "C": "シー", "D": "ディー", "E": "イー",
    "F": "エフ", "G": "ジー", "H": "エイチ", "I": "アイ", "J": "ジェー",
    "K": "ケー", "L": "エル", "M": "エム", "N": "エヌ", "O": "オー",
    "P": "ピー", "Q": "キュー", "R": "アール", "S": "エス", "T": "ティー",
    "U": "ユー", "V": "ブイ", "W": "ダブリュー", "X": "エックス", "Y": "ワイ",
    "Z": "ゼット"
}

# 2. Well-Known Acronyms with Non-letter Pronunciation (Dictionary Override)
KNOWN_ACRONYMS = {
    "NASA": "ナサ",
    "LASER": "レーザー",
    "OPEC": "オペック",
    "UNESCO": "ユネスコ",
    "BASIC": "ベーシック",
    "RAM": "ラム",
    "LAN": "ラン",
    "WAN": "ワン",
    "SaaS": "サース",
    "PaaS": "パース",
    "IaaS": "イアース",
    "JSON": "ジェイソン",
    "YAML": "ヤムル",
    "SQL": "エスキューエル",
    "VIP": "ブイアイピー",
    "SOS": "エスオーエス",
    "DJ": "ディージェイ",
    "JR": "ジェイアール",
    "NHK": "エヌエイチケー",
    "WHO": "ダブリューエイチオー",
    "CIA": "シーアイエー",
    "FBI": "エフビーアイ",
    "GDP": "ジーディーピー",
    "DX": "ディーエックス",
    "KPI": "ケーピーアイ",
    "CEO": "シーイーオー",
    "CTO": "シーティーオー",
    "CFO": "シーエフオー",
    "NPO": "エヌピーオー",
    "NGO": "エヌジーオー",
    "PTA": "ピーティーエー",
    "PR": "ピーアール",
    "HR": "エイチアール",
    "API": "エーピーアイ",
    "SDK": "エスディーケー",
    "CLI": "シーエルアイ",
    "SSH": "エスエスエイチ",
    "DNS": "ディーエヌエス",
    "TCP": "ティーシーピー",
    "UDP": "ユーディーピー",
    "CPU": "シーピーユー",
    "GPU": "ジーピーユー",
    "SSD": "エスエスディー",
    "HTML": "エイチティーエムエル",
    "CSS": "シーエスエス",
    "HTTP": "エイチティーティーピー",
    "HTTPS": "エイチティーティーピーエス",
    "VPN": "ブイピーエヌ",
    "IoT": "アイオーティー",
    "URL": "ユーアールエル",
    "GCP": "ジーシーピー",
    "AWS": "エーダブリューエス",
    "AKB": "エーケービー",
    "USB": "ユーエスビー",
    "Web3": "ウェブスリー",
    "IPv6": "アイピーブイシックス",
    "3D": "スリーディー",
    "4K": "フォーケー",
    "5G": "ファイブジー",
    "B2B": "ビートゥービー",
}

# System Prompt for general English words / Technical Brands
SYSTEM_PROMPT = """あなたは英単語や技術固有名詞を自然な日本語カタカナ読みに変換するAIです。
出力は余計な解説を一切含めず、最も自然なカタカナ表記のみを出力してください。"""

def convert_acronym(text: str) -> str:
    """Convert acronym letter-by-letter using deterministic lookup."""
    upper = text.upper()
    if upper in KNOWN_ACRONYMS:
        return KNOWN_ACRONYMS[upper]
    
    # If all uppercase letters (e.g. CI/CD, XYZ)
    cleaned = re.sub(r'[^A-Z0-9]', '', upper)
    if cleaned and all(c in ALPHABET_TABLE or c.isdigit() for c in cleaned):
        res = []
        for ch in cleaned:
            if ch in ALPHABET_TABLE:
                res.append(ALPHABET_TABLE[ch])
            else:
                res.append(ch)
        return "".join(res)
    return ""

def query_llm(word: str, endpoint="http://127.0.0.1:8080/v1/chat/completions") -> str:
    """Fallback to LLM for brand names, English words, complex phrases with smart normalization."""
    # If the word is entirely uppercase and contains spaces or is longer than 5 letters (e.g. DRAMATIC RECORD, FRUIT ZIPPER),
    # normalize to Title Case to prevent BPE tokenizer from confusing common words with tech acronyms (like DRAM -> DRAMティック)
    cleaned_word = word.strip()
    if cleaned_word.isupper() and (" " in cleaned_word or len(cleaned_word) > 4):
        input_word = cleaned_word.title()
    else:
        input_word = cleaned_word

    payload = {
        "model": "default-llm",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"次の英単語の日本語カタカナ読みを出力してください: {input_word}"}
        ],
        "temperature": 0.0,
        "max_tokens": 32
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(endpoint, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as response:
        res_body = json.loads(response.read().decode("utf-8"))
    
    raw_res = res_body["choices"][0]["message"]["content"].strip().split("\n")[0].strip()
    # Strip any accidental markdown formatting or quotes
    clean_res = re.sub(r'[\*\"\'`]', '', raw_res)
    return clean_res

def hybrid_convert(word: str) -> tuple[str, str, float]:
    """
    Hybrid Pipeline:
    1. Dictionary Override (0.001ms)
    2. Acronym Letter-by-Letter Rule (0.001ms)
    3. LLM Inference Fallback (~200-500ms)
    """
    t0 = time.perf_counter()
    
    # 1. Exact Dictionary Match (case-insensitive)
    upper_word = word.strip().upper()
    if upper_word in KNOWN_ACRONYMS:
        lat = (time.perf_counter() - t0) * 1000
        return KNOWN_ACRONYMS[upper_word], "DICT", lat
    if word in KNOWN_ACRONYMS:
        lat = (time.perf_counter() - t0) * 1000
        return KNOWN_ACRONYMS[word], "DICT", lat
    
    # 2. All-Uppercase Acronym Pattern (e.g. 2+ uppercase letters)
    if re.match(r'^[A-Z0-9/_-]{2,}$', word) and not word.isdigit():
        acronym_res = convert_acronym(word)
        if acronym_res:
            lat = (time.perf_counter() - t0) * 1000
            return acronym_res, "RULE", lat

    # 3. LLM Fallback (Brands, Product Names, English Words)
    try:
        llm_res = query_llm(word)
        lat = (time.perf_counter() - t0) * 1000
        return llm_res, "LLM", lat
    except Exception as e:
        lat = (time.perf_counter() - t0) * 1000
        return str(e), "ERROR", lat

def interactive_mode():
    print("=" * 70)
    print("  🔤 Hybrid Phonetic Converter (Rule + Dict + Llama-3.2-3B LLM)")
    print("  Type any English word / acronym (e.g. 'AKB48', 'Docker', 'GCP').")
    print("  Type 'exit' or 'quit' to exit.")
    print("=" * 70)

    while True:
        try:
            word = input("\n\033[1;36mInput Word:\033[0m ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nGoodbye!")
            break

        if not word:
            continue
        if word.lower() in ["exit", "quit"]:
            print("Goodbye!")
            break

        result, engine, lat_ms = hybrid_convert(word)
        print(f"\033[1;32mKatakana:\033[0m   {result}")
        print(f"\033[1;34mEngine:\033[0m     {engine} ({lat_ms:.2f} ms)")

def run_benchmark():
    from evaluate_phonetic_conversion import TEST_DATASET, is_match

    print("=" * 75)
    print("  Hybrid Phonetic Conversion Pipeline Benchmark")
    print(f"  Total Test Cases: {len(TEST_DATASET)} (Rule + Dict + LLM Fallback)")
    print("=" * 75)

    category_stats = {}
    total_correct = 0
    engine_counts = {"DICT": 0, "RULE": 0, "LLM": 0, "ERROR": 0}
    latencies = []

    print(f"{'Input':<14} | {'Output':<22} | {'Engine':<6} | {'Status':<6} | {'Time (ms)':<8}")
    print("-" * 75)

    for item in TEST_DATASET:
        inp = item["input"]
        expected = item["expected"]
        cat = item["category"]

        if cat not in category_stats:
            category_stats[cat] = {"total": 0, "correct": 0}
        category_stats[cat]["total"] += 1

        actual, engine, lat_ms = hybrid_convert(inp)
        latencies.append(lat_ms)
        engine_counts[engine] = engine_counts.get(engine, 0) + 1

        matched = is_match(actual, expected)
        if matched:
            status = "PASS"
            total_correct += 1
            category_stats[cat]["correct"] += 1
        else:
            status = "FAIL"

        print(f"{inp:<14} | {actual:<22} | {engine:<6} | {status:<6} | {lat_ms:6.2f} ms")

    print("=" * 75)
    print("  Benchmark Summary & Hybrid Performance")
    print("=" * 75)
    print(f"  Total Test Cases: {len(TEST_DATASET)}")
    print(f"  Overall Accuracy: {total_correct} / {len(TEST_DATASET)} ({total_correct / len(TEST_DATASET) * 100:.1f}%)")
    print(f"  Average Latency:  {sum(latencies)/len(latencies):.2f} ms (Rule/Dict: <0.1ms, LLM: ~500ms)")
    print(f"  Engine Routing:   DICT: {engine_counts['DICT']}, RULE: {engine_counts['RULE']}, LLM: {engine_counts['LLM']}")
    print("-" * 75)
    print(f"  {'Category':<20} | {'Correct / Total':<18} | {'Accuracy':<10}")
    print("-" * 75)
    for cat, stats in category_stats.items():
        acc = (stats["correct"] / stats["total"]) * 100
        print(f"  {cat:<20} | {stats['correct']:2d} / {stats['total']:2d}             | {acc:5.1f}%")
    print("=" * 75)

def main():
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg in ["--bench", "-b", "--benchmark"]:
            run_benchmark()
            return
        # Single word or multiple words passed via arguments
        for word in sys.argv[1:]:
            result, engine, lat_ms = hybrid_convert(word)
            print(f"{word:<15} -> {result:<20} [{engine}] ({lat_ms:.2f} ms)")
        return

    interactive_mode()

if __name__ == "__main__":
    main()
