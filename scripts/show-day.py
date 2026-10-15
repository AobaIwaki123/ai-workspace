#!/usr/bin/env python3
"""
Render Google Calendar-style daily timeline to terminal.
Usage: ./scripts/show-day.py [mon|tue|wed|thu|fri]
"""

import sys
import datetime

SCHEDULES = {
    "mon": [
        ("07:00", "07:15", "Wake Up & Prep", "身支度・水・着替え", "green"),
        ("07:15", "07:45", "River & Roastery Cafe", "目黒川散歩 / 珈琲 / Kindle読書", "cyan"),
        ("07:45", "08:25", "Walk Commute (40m)", "秋風ウォーキング・徒歩出社", "green"),
        ("08:30", "18:30", "Work: Core Focus", "業務集中 (目標退勤 18:30)", "blue"),
        ("18:30", "19:00", "Leave & Return", "退勤・中目黒へ帰還", "gray"),
        ("19:00", "19:45", "Dinner: 中目黒ビストロ", "月曜の静寂ハック・空いてる名店開拓", "yellow"),
        ("20:00", "21:30", "Night Cafe & Stroll", "夜の静かなカフェ / 中目黒散歩", "cyan"),
        ("21:30", "23:00", "Bath & Reading / Rest", "入浴・読書・チル", "cyan"),
        ("23:00", "23:45", "AI Reflection & Log", "思考デトックス・lifestyle-logger同期", "magenta"),
        ("24:00", "07:00", "Sleep (7 Hours)", "消灯・リカバリー", "gray"),
    ],
    "tue": [
        ("07:00", "07:15", "Wake Up & Prep", "身支度・水・着替え", "green"),
        ("07:15", "07:45", "River & Roastery Cafe", "目黒川散歩 / 珈琲 / Kindle読書", "cyan"),
        ("07:45", "08:25", "Walk Commute (40m)", "秋風ウォーキング・徒歩出社", "green"),
        ("08:30", "18:30", "Work: Core Focus", "業務集中 (目標退勤 18:30)", "blue"),
        ("18:30", "19:00", "Leave & Return", "退勤・中目黒へ帰還", "gray"),
        ("19:00", "19:45", "Dinner: 大戸屋 中目黒", "定食・開発前のエネルギー補給", "yellow"),
        ("20:00", "22:30", "★ Dev Session w/ Friend", "友達と夜の開発・実装・ペアプロ", "blue"),
        ("22:30", "23:00", "Bath & Cool Down", "入浴・開発後のクールダウン", "cyan"),
        ("23:00", "23:45", "AI Reflection & Log", "思考デトックス・lifestyle-logger同期", "magenta"),
        ("24:00", "07:00", "Sleep (7 Hours)", "消灯・リカバリー", "gray"),
    ],
    "wed": [
        ("07:00", "07:15", "Wake Up & Prep", "身支度・水・着替え", "green"),
        ("07:15", "07:45", "River & Roastery Cafe", "目黒川散歩 / 珈琲 / Kindle読書", "cyan"),
        ("07:45", "08:25", "Walk Commute (40m)", "秋風ウォーキング・徒歩出社", "green"),
        ("08:30", "18:30", "Work: Core Focus", "業務集中 (目標退勤 18:30)", "blue"),
        ("18:30", "19:00", "Leave & Return", "退勤・中目黒へ帰還", "gray"),
        ("19:00", "19:45", "Dinner: 大戸屋 中目黒", "定食・筋トレ前エネルギー補給", "yellow"),
        ("20:00", "21:30", "Gym Workout (筋トレ)", "目黒区民センター等でマシントレ", "green"),
        ("21:30", "23:00", "Sauna: 光明泉 中目黒", "温冷交代浴・サウナで完全脱力", "cyan"),
        ("23:00", "23:45", "AI Reflection & Log", "思考デトックス・明日のライブ準備", "magenta"),
        ("24:00", "07:00", "Sleep (7 Hours)", "消灯・リカバリー", "gray"),
    ],
    "thu": [
        ("07:00", "07:15", "Wake Up & Prep", "身支度・水・着替え", "green"),
        ("07:15", "07:45", "River & Roastery Cafe", "目黒川散歩 / 珈琲 / Kindle読書", "cyan"),
        ("07:45", "08:25", "Walk Commute (40m)", "秋風ウォーキング・徒歩出社", "green"),
        ("08:30", "18:00", "Work: Fast Finish", "定時・早め退勤", "blue"),
        ("18:30", "19:00", "Transit to Venue", "ライブ会場へ移動 & 軽食", "magenta"),
        ("19:00", "21:30", "★ IDOL LIVE (現場)", "ルキルキ指名入場 / 援軍の1票 / 物販", "magenta"),
        ("21:30", "22:30", "Return to Nakameguro", "中目黒帰還・余韻", "gray"),
        ("23:00", "23:45", "AI Reflection & Log", "ライブ受け取り報告・思考整理", "magenta"),
        ("24:00", "07:00", "Sleep (7 Hours)", "消灯・リカバリー", "gray"),
    ],
    "fri": [
        ("07:00", "07:15", "Wake Up & Prep", "身支度・水・着替え", "green"),
        ("07:15", "07:45", "River & Roastery Cafe", "目黒川散歩 / 珈琲 / Kindle読書", "cyan"),
        ("07:45", "08:25", "Walk Commute (40m)", "秋風ウォーキング・徒歩出社", "green"),
        ("08:30", "18:30", "Work: Week Closing", "業務締め (目標退勤 18:30)", "blue"),
        ("18:30", "19:00", "Leave & Return", "混雑を避けて即帰還", "gray"),
        ("19:00", "19:45", "Dinner: 大戸屋 / テイクアウト", "家でリラックス夕食", "yellow"),
        ("20:00", "21:30", "Home Movie / Chill", "名作映画鑑賞 (PERFECT DAYS等)", "yellow"),
        ("21:30", "23:00", "Bath & Reading / Rest", "長風呂・読書・ウィークエンド突入", "cyan"),
        ("23:00", "23:45", "AI Reflection & Log", "1週間の振り返り・週末プラン", "magenta"),
        ("24:00", "07:00", "Sleep (7 Hours)", "消灯・ぐっすり睡眠", "gray"),
    ],
}

COLORS = {
    "cyan": "\033[96m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "magenta": "\033[95m",
    "blue": "\033[94m",
    "gray": "\033[90m",
    "bold": "\033[1m",
    "reset": "\033[0m"
}

def render_day(day_key):
    schedule = SCHEDULES.get(day_key.lower(), SCHEDULES["tue"])
    day_name = day_key.upper()
    
    print("┌──────┬────────────────────────────────────────────────────────┐")
    print(f"│ TIME │  GOOGLE CALENDAR STYLE: {day_name} DAILY TIMELINE      │")
    print("├──────┼────────────────────────────────────────────────────────┤")
    
    for start, end, title, desc, color_key in schedule:
        col = COLORS.get(color_key, COLORS["cyan"])
        rst = COLORS["reset"]
        
        # Calculate visual length for Japanese characters
        def get_width(s):
            return sum(2 if ord(c) > 127 else 1 for c in s)
            
        header_text = f"■ {title} ({start} - {end})"
        h_pad = 52 - get_width(header_text)
        header_line = f"{header_text}{' ' * max(0, h_pad)}"
        
        desc_text = f"  {desc}"
        d_pad = 52 - get_width(desc_text)
        desc_line = f"{desc_text}{' ' * max(0, d_pad)}"
        
        print(f"│{start} │ {col}┌──────────────────────────────────────────────────────┐{rst}│")
        print(f"│      │ {col}│ {header_line} │{rst}│")
        print(f"│      │ {col}│ {desc_line} │{rst}│")
        print(f"│{end} │ {col}└──────────────────────────────────────────────────────┘{rst}│")
        
    print("└──────┴────────────────────────────────────────────────────────┘")

if __name__ == "__main__":
    day = sys.argv[1] if len(sys.argv) > 1 else "tue"
    render_day(day)
