#!/usr/bin/env python3
"""Turn Project Cake's opt-in JSONL playtest log into shareable reports."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


EVENT_COLUMNS = [
    "sequence",
    "elapsed_seconds",
    "kind",
    "chapter_id",
    "day",
    "coins",
    "global_reputation",
    "owned_growth_count",
    "success",
    "order_id",
    "recipe_id",
    "grade",
    "overall_score",
    "payment_coins",
    "reputation_delta",
    "growth_id",
    "reason",
]

CHAPTER_LABELS = {
    "chapter.breakfast_stall": "早餐摊",
    "chapter.noodle_shop": "面馆",
    "chapter.night_market": "夜市",
}

MINIMUM_ORDER_SAMPLES = {
    "chapter.breakfast_stall": 20,
    "chapter.noodle_shop": 20,
    "chapter.night_market": 15,
}


def load_events(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line:
            continue
        value = json.loads(line)
        if not isinstance(value, dict):
            raise ValueError(f"line {line_number} is not a JSON object")
        events.append(value)
    return events


def flatten_event(event: dict[str, Any]) -> dict[str, Any]:
    payload = event.get("payload") if isinstance(event.get("payload"), dict) else {}
    return {
        "sequence": event.get("sequence", ""),
        "elapsed_seconds": round(float(event.get("elapsed_seconds", 0.0)), 3),
        "kind": event.get("kind", ""),
        **{column: payload.get(column, "") for column in EVENT_COLUMNS[3:]},
    }


def write_csv(path: Path, rows: Iterable[dict[str, Any]], columns: list[str]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def chapter_metrics(events: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    metrics: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "orders": 0,
            "successes": 0,
            "score_total": 0.0,
            "scored": 0,
            "payment_coins": 0,
            "reputation_delta": 0,
            "days": set(),
            "growths": [],
            "refusals": 0,
            "abandonments": 0,
            "last_coins": 0,
            "last_reputation": 0,
        }
    )
    for event in events:
        payload = event.get("payload") if isinstance(event.get("payload"), dict) else {}
        chapter_id = str(payload.get("chapter_id", ""))
        if not chapter_id:
            continue
        row = metrics[chapter_id]
        row["last_coins"] = int(payload.get("coins", row["last_coins"]) or 0)
        row["last_reputation"] = int(payload.get("global_reputation", row["last_reputation"]) or 0)
        kind = str(event.get("kind", ""))
        if kind == "order_settled":
            row["orders"] += 1
            row["successes"] += int(bool(payload.get("success", False)))
            if payload.get("overall_score", "") != "":
                row["score_total"] += float(payload.get("overall_score", 0.0))
                row["scored"] += 1
            row["payment_coins"] += int(payload.get("payment_coins", 0) or 0)
            row["reputation_delta"] += int(payload.get("reputation_delta", 0) or 0)
        elif kind == "day_ended":
            row["days"].add(int(payload.get("day", 0) or 0))
        elif kind == "growth_purchased" and bool(payload.get("success", False)):
            row["growths"].append(str(payload.get("growth_id", "")))
        elif kind == "order_refused":
            row["refusals"] += 1
        elif kind == "order_abandoned":
            row["abandonments"] += 1
    return dict(metrics)


def markdown_report(events: list[dict[str, Any]], raw_summary: dict[str, Any]) -> str:
    metrics = chapter_metrics(events)
    counts = Counter(str(event.get("kind", "")) for event in events)
    session_id = str(raw_summary.get("session_id", "unknown"))
    duration = float(raw_summary.get("duration_seconds", 0.0))
    lines = [
        "# 《煎饼开张》试玩遥测摘要",
        "",
        f"> 会话：`{session_id}`  ",
        f"> 自动记录时长：{duration / 60.0:.1f} 分钟  ",
        "> 仅包含本地玩法事件和数值，不包含账号、设备信息或玩家输入文本。",
        "",
        "## 结论先行",
        "",
    ]
    order_total = counts.get("order_settled", 0)
    day_total = counts.get("day_ended", 0)
    growth_total = sum(
        1
        for event in events
        if event.get("kind") == "growth_purchased"
        and bool((event.get("payload") or {}).get("success", False))
    )
    lines.append(f"- 本次记录 {order_total} 个结算订单、{day_total} 次日结、{growth_total} 次成功成长购买。")
    insufficient: list[str] = []
    for chapter_id, minimum in MINIMUM_ORDER_SAMPLES.items():
        actual = int(metrics.get(chapter_id, {}).get("orders", 0))
        if actual < minimum:
            insufficient.append(f"{CHAPTER_LABELS[chapter_id]} {actual}/{minimum}")
    if insufficient:
        lines.append("- 尚不足以调整正式平衡：" + "；".join(insufficient) + "。")
    else:
        lines.append("- 三章订单样本达到当前最低验收数量，可结合人工记录开始调整成长节奏。")
    lines.append("- 疲劳、误触原因、教学理解和主观听感仍须填写人工验收表，遥测不能替代真人判断。")
    lines.extend(
        [
            "",
            "## 分章节数据",
            "",
            "| 章节 | 订单 | 成功率 | 平均分 | 订单标价 | 日结 | 成长购买 | 谢绝/流失 | 末次金币 | 末次全局口碑 |",
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for chapter_id in CHAPTER_LABELS:
        row = metrics.get(chapter_id, {})
        orders = int(row.get("orders", 0))
        successes = int(row.get("successes", 0))
        scored = int(row.get("scored", 0))
        average = float(row.get("score_total", 0.0)) / scored if scored else 0.0
        success_rate = successes / orders * 100.0 if orders else 0.0
        lines.append(
            f"| {CHAPTER_LABELS[chapter_id]} | {orders} | {success_rate:.0f}% | {average:.1f} | "
            f"{int(row.get('payment_coins', 0))} | {len(row.get('days', set()))} | "
            f"{len(row.get('growths', []))} | {int(row.get('refusals', 0))}/{int(row.get('abandonments', 0))} | "
            f"{int(row.get('last_coins', 0))} | {int(row.get('last_reputation', 0))} |"
        )
    lines.extend(["", "## 成长购买顺序", ""])
    any_growth = False
    for chapter_id in CHAPTER_LABELS:
        growths = metrics.get(chapter_id, {}).get("growths", [])
        if growths:
            any_growth = True
            lines.append(f"- {CHAPTER_LABELS[chapter_id]}：" + " → ".join(f"`{growth}`" for growth in growths))
    if not any_growth:
        lines.append("- 本次会话没有成功购买成长。")
    lines.extend(
        [
            "",
            "## 配套文件",
            "",
            "- `events.jsonl`：逐事件原始记录，可用于复核。",
            "- `events.csv`：全部事件扁平表。",
            "- `orders.csv`：订单结算样本。",
            "- `days.csv`：日结样本。",
            "- `growth.csv`：成长购买尝试与结果。",
            "- `summary.json`：游戏运行时持续维护的崩溃安全汇总。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("result_directory", type=Path)
    args = parser.parse_args()
    result_directory = args.result_directory.resolve()
    events_path = result_directory / "events.jsonl"
    summary_path = result_directory / "summary.json"
    if not events_path.is_file():
        raise SystemExit(f"missing telemetry log: {events_path}")
    events = load_events(events_path)
    raw_summary = json.loads(summary_path.read_text(encoding="utf-8")) if summary_path.is_file() else {}
    flat = [flatten_event(event) for event in events]
    write_csv(result_directory / "events.csv", flat, EVENT_COLUMNS)
    write_csv(result_directory / "orders.csv", (row for row in flat if row["kind"] == "order_settled"), EVENT_COLUMNS)
    write_csv(result_directory / "days.csv", (row for row in flat if row["kind"] == "day_ended"), EVENT_COLUMNS)
    write_csv(result_directory / "growth.csv", (row for row in flat if row["kind"] == "growth_purchased"), EVENT_COLUMNS)
    (result_directory / "report.md").write_text(markdown_report(events, raw_summary), encoding="utf-8")
    print(f"PLAYTEST_REPORT={result_directory / 'report.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
