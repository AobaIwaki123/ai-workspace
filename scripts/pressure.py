#!/usr/bin/env python3
"""
Barometric Pressure CLI for Nakameguro (or custom lat/lon).
Uses Open-Meteo free API (no API key needed).
Usage: ./scripts/pressure.py [--hours 24]
"""

import argparse
import datetime
import json
import urllib.request

# Default: Nakameguro (Tokyo)
DEFAULT_LAT = 35.6443
DEFAULT_LON = 139.6990


def get_pressure_data(lat, lon):
    url = (
        f"https://api.open-meteo.com/v1/forecast?"
        f"latitude={lat}&longitude={lon}&hourly=surface_pressure,temperature_2m,weathercode&timezone=Asia%2FTokyo"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "PressureCLI/1.0"})
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode("utf-8"))


def analyze_pressure(data, hours_window=12):
    hourly = data["hourly"]
    times = hourly["time"]
    pressures = hourly["surface_pressure"]
    temps = hourly["temperature_2m"]

    # Current JST time
    now_jst = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9)))
    now_str = now_jst.strftime("%Y-%m-%dT%H:00")

    # Find current index
    current_idx = 0
    for idx, t in enumerate(times):
        if t <= now_str:
            current_idx = idx

    # ANSI Colors
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    BOLD = "\033[1m"
    RESET = "\033[0m"

    print("=" * 65)
    print(f"{BOLD}{CYAN} BAROMETRIC PRESSURE MONITOR: NAKAMEGURO (JST) {RESET}")
    print("=" * 65)

    current_p = pressures[current_idx]
    prev_3h_p = pressures[max(0, current_idx - 3)]
    diff_3h = current_p - prev_3h_p

    # Alert level evaluation
    # >= 3 hPa change in 3h is generally considered high-risk for headaches/autonomic nerve
    alert = f"{GREEN}STABLE (安全・安定){RESET}"
    if abs(diff_3h) >= 3.0:
        alert = f"{RED}{BOLD}⚠️ CAUTION: 急変警告 (3hで {diff_3h:+.1f} hPa){RESET}"
    elif abs(diff_3h) >= 1.5:
        alert = f"{YELLOW}NOTICE: 注意 (3hで {diff_3h:+.1f} hPa){RESET}"

    print(f"現在時刻: {times[current_idx]} | 気圧: {BOLD}{current_p:.1f} hPa{RESET} | 気温: {temps[current_idx]}°C")
    print(f"気圧変動ステータス: {alert}")
    print("-" * 65)
    print(f"{'TIME':<17} | {'PRESSURE':<10} | {'3h TREND':<10} | {'VISUAL GRAPH'}")
    print("-" * 65)

    start_idx = max(0, current_idx - 6)
    end_idx = min(len(times), current_idx + hours_window)

    min_p = min(pressures[start_idx:end_idx])
    max_p = max(pressures[start_idx:end_idx])
    p_range = max(1.0, max_p - min_p)

    for i in range(start_idx, end_idx):
        t_str = times[i]
        p = pressures[i]
        diff_str = "--"
        if i >= 3:
            d = p - pressures[i - 3]
            diff_str = f"{d:+.1f} hPa"

        # Graph bar (15 chars width)
        norm = int(((p - min_p) / p_range) * 15)
        bar = "■" * max(1, norm)

        # Highlight current hour
        if i == current_idx:
            line_time = f"{BOLD}{YELLOW}▶ {t_str[-5:]} (現在){RESET}"
            p_val = f"{BOLD}{YELLOW}{p:.1f} hPa{RESET}"
        elif i > current_idx:
            line_time = f"  {t_str[-5:]} (予報)"
            p_val = f"{p:.1f} hPa"
        else:
            line_time = f"  {t_str[-5:]}"
            p_val = f"{p:.1f} hPa"

        # Trend color
        trend_col = RESET
        if diff_str != "--":
            d_val = float(diff_str.split()[0])
            if abs(d_val) >= 3.0:
                trend_col = RED
            elif abs(d_val) >= 1.5:
                trend_col = YELLOW

        print(f"{line_time:<26} | {p_val:<19} | {trend_col}{diff_str:<10}{RESET} | {bar}")

    print("=" * 65)


def main():
    parser = argparse.ArgumentParser(description="Check barometric pressure trends.")
    parser.add_argument("--lat", type=float, default=DEFAULT_LAT, help="Latitude")
    parser.add_argument("--lon", type=float, default=DEFAULT_LON, help="Longitude")
    parser.add_argument("--hours", type=int, default=8, help="Forecast hours to display")
    args = parser.parse_args()

    data = get_pressure_data(args.lat, args.lon)
    analyze_pressure(data, hours_window=args.hours)


if __name__ == "__main__":
    main()
