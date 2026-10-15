#!/usr/bin/env python3
"""
Render weekly routine schedule table to terminal.
Usage: ./scripts/show-routine.py
"""

def render_table():
    # ANSI Color codes
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    MAGENTA = "\033[95m"
    BLUE = "\033[94m"
    BOLD = "\033[1m"
    RESET = "\033[0m"

    days = [
        f"{BLUE}MON (月){RESET}",
        f"{BLUE}TUE (火){RESET}",
        f"{BLUE}WED (水){RESET}",
        f"{MAGENTA}THU (木){RESET}",
        f"{BLUE}FRI (金){RESET}"
    ]
    
    col_w = 23
    sep = "+" + ("-" * 13) + ("+" + "-" * col_w) * 5 + "+"
    
    title = f"{BOLD}{CYAN} WEEKLY ROUTINE: NAKAMEGURO HACK PROTOCOL {RESET}"
    total_w = 14 + (col_w + 1) * 5
    print("=" * total_w)
    print(f"{title:^{total_w + 8}}")
    print("=" * total_w)
    
    header = f"| {BOLD}TIME        {RESET} "
    for d in days:
        header += f"| {d:<{col_w + 8}} "
    header += "|"
    print(header)
    print(sep)
    
    # Rows: (Time, [Activities for Mon, Tue, Wed, Thu, Fri])
    rows = [
        ("07:00-07:15", [f"{GREEN}Wake Up & Prep{RESET}"] * 5),
        ("07:15-07:45", [f"{CYAN}River / Roastery{RESET}"] * 5),
        ("07:45-08:25", [f"{GREEN}Walk Commute 40m{RESET}"] * 5),
        ("08:30-18:30", ["Work (Focus)"] * 5),
        ("18:30-19:00", ["Leave & Return"] * 5),
        ("19:00-19:45", [
            f"{YELLOW}Bistro / Quiet{RESET}",
            "Ootoya (大戸屋)",
            "Ootoya (大戸屋)",
            f"{MAGENTA}Live Fast Dinner{RESET}",
            "Ootoya / Takeout"
        ]),
        ("20:00-21:30", [
            f"{CYAN}Night Cafe/Walk{RESET}",
            f"{BLUE}Study / Code{RESET}",
            f"{GREEN}Gym (Workout){RESET}",
            f"{MAGENTA}★ IDOL LIVE (現場){RESET}",
            f"{YELLOW}Home Movie Chill{RESET}"
        ]),
        ("21:30-23:00", [
            "Bath / Read",
            "Bath / Read",
            f"{CYAN}Sauna (光明泉){RESET}",
            f"{MAGENTA}Return & Echo{RESET}",
            "Home Chill/Read"
        ]),
        ("23:00-23:45", [f"{BOLD}{CYAN}AI Reflection & Log{RESET}"] * 5),
        ("24:00-07:00", ["Sleep (7 Hours)"] * 5)
    ]
    
    for time_slot, activities in rows:
        line = f"| {time_slot:<11} "
        for act in activities:
            # Calculate visible length without ANSI codes for proper alignment
            clean_act = act
            for code in [CYAN, GREEN, YELLOW, MAGENTA, BLUE, BOLD, RESET]:
                clean_act = clean_act.replace(code, "")
            
            pad = col_w - 2 - len(clean_act)
            # handle double-width zenkaku characters if any
            extra_zenkaku = sum(1 for c in clean_act if ord(c) > 127)
            pad -= extra_zenkaku
            line += f"| {act}{' ' * max(0, pad)} "
        line += "|"
        print(line)
        print(sep)

if __name__ == "__main__":
    render_table()
