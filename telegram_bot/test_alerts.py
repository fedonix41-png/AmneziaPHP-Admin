#!/usr/bin/env python3
"""
Quick test for alerting logic with mock data.
Run inside bot container: docker exec amnezia-panel-telegram-bot python /app/test_alerts.py
"""

import asyncio
import types
from datetime import datetime, timezone, timedelta
from services.alerts import AlertScheduler
from services.panel_api import PanelAPIError

# ============ MOCKS ============

class TestBot:
    """Mock Bot that logs messages instead of sending them."""
    def __init__(self, name="TestBot"):
        self.name = name
        self.messages = []

    async def send_message(self, chat_id, text, parse_mode=None):
        ts = datetime.now(timezone.utc).strftime("%H:%M:%S")
        self.messages.append(f"[{ts}] -> Chat {chat_id}: {text[:60]}...")
        print(f"✉ [{ts}] -> Chat {chat_id}: {text[:80]}{'...' if len(text) > 80 else ''}")

    def reset(self):
        self.messages.clear()

class MockPanelAPI:
    """Mock PanelAPI that returns controlled test data."""
    def __init__(self):
        self.mode = "normal"  # normal, high_cpu, overlimit, expiring, mixed

    async def list_servers(self):
        if self.mode == "error":
            raise PanelAPIError("Simulated API error")
        return [
            {"id": 1, "name": "Production"},
            {"id": 2, "name": "Backup"},
            {"id": 3, "name": "Test"},
        ]

    async def server_metrics(self, server_id, hours=1):
        base = datetime(2026, 6, 28, 16, 0, 0, tzinfo=timezone.utc)
        ts = (base + timedelta(minutes=30)).isoformat()

        if self.mode == "error":
            raise PanelAPIError("Metrics API error")
        if self.mode == "empty":
            return []

        # Server 1: high load in 'high_cpu' mode, normal otherwise
        if server_id == 1:
            if self.mode in ("high_cpu", "mixed"):
                return [{
                    "cpu_percent": 95.0,
                    "ram_used_mb": 1800,
                    "ram_total_mb": 2000,
                    "ram_pct": 90.0,
                    "collected_at": ts,
                }]
            return [{
                "cpu_percent": 20.0,
                "ram_used_mb": 800,
                "ram_total_mb": 2000,
                "collected_at": ts,
            }]

        # Server 2: high RAM in 'high_cpu' mode, normal otherwise
        if server_id == 2:
            if self.mode in ("high_cpu", "mixed"):
                return [{
                    "cpu_percent": 40.0,
                    "ram_used_mb": 1900,
                    "ram_total_mb": 2000,
                    "ram_pct": 95.0,
                    "collected_at": ts,
                }]
            return [{
                "cpu_percent": 15.0,
                "ram_used_mb": 600,
                "ram_total_mb": 2000,
                "collected_at": ts,
            }]

        # Server 3: always normal
        if server_id == 3:
            return [{
                "cpu_percent": 20.0,
                "ram_used_mb": 800,
                "ram_total_mb": 2000,
                "collected_at": ts,
            }]

        return []

    async def get_overlimit_clients(self):
        if self.mode == "error":
            raise PanelAPIError("Overlimit API error")

        if self.mode == "overlimit" or self.mode == "mixed":
            return {"clients": [
                {"id": 101, "name": "user1", "traffic_limit": 1000},
                {"id": 102, "name": "user2", "traffic_limit": 2000},
                {"id": 103, "name": "user3", "traffic_limit": 3000},
            ]}
        return {"clients": []}

    async def get_expiring_clients(self, days=1):
        if self.mode == "error":
            raise PanelAPIError("Expiring API error")

        if self.mode == "expiring" or self.mode == "mixed":
            return {"clients": [
                {"id": 201, "name": "alice", "expires_at": (datetime.now(timezone.utc) + timedelta(hours=23)).isoformat()},
                {"id": 202, "name": "bob", "expires_at": (datetime.now(timezone.utc) + timedelta(hours=5)).isoformat()},
                {"id": 203, "name": "carol", "expires_at": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()},
            ]}
        return {"clients": []}

# ============ TEST SCENARIOS ============

async def scenario_normal(bot, scheduler, mock):
    """Scenario 1: Normal state - no alerts expected."""
    print("\n" + "="*60)
    print("SCENARIO 1: Normal state (no alerts expected)")
    print("="*60)
    mock.mode = "normal"
    bot.reset()

    await scheduler._check_cpu_ram(bot)
    await scheduler._check_overlimit(bot)
    await scheduler._maybe_check_expiring(bot)

    alerts = len([m for m in bot.messages if "🚨" in m or "Превышение" in m])
    print(f"  Messages sent: {len(bot.messages)}")
    print(f"  Alerts: {alerts}")
    print(f"  ✓ PASS" if alerts == 0 else f"  ✗ FAIL (expected 0, got {alerts})")
    return alerts == 0

async def scenario_cpu_alert(bot, scheduler, mock):
    """Scenario 2: CPU/RAM high - expect alerts, then recovery."""
    print("\n" + "="*60)
    print("SCENARIO 2: CPU/RAM high -> recovery")
    print("="*60)

    # Step 1: High load -> expect 2 alerts (Server 1 CPU, Server 2 RAM)
    mock.mode = "high_cpu"
    bot.reset()
    await scheduler._check_cpu_ram(bot)

    cpu_alerts = len([m for m in bot.messages if "CPU" in m or "RAM" in m])
    print(f"  Step 1: High load")
    print(f"    Alerts sent: {cpu_alerts}")
    print(f"    ✓ PASS" if cpu_alerts == 2 else f"    ✗ FAIL (expected 2, got {cpu_alerts})")

    # Step 2: Still high -> dedup, no new alerts
    bot.reset()
    await scheduler._check_cpu_ram(bot)

    dup_alerts = len([m for m in bot.messages if "CPU" in m or "RAM" in m])
    print(f"  Step 2: Still high (dedup)")
    print(f"    Alerts sent: {dup_alerts}")
    print(f"    ✓ PASS" if dup_alerts == 0 else f"    ✗ FAIL (expected 0, got {dup_alerts})")

    # Step 3: Normal -> expect 2 recoveries
    mock.mode = "normal"
    bot.reset()
    await scheduler._check_cpu_ram(bot)

    recoveries = len([m for m in bot.messages if "Нагрузка в норме" in m or "в норме" in m])
    print(f"  Step 3: Recovery")
    print(f"    Recoveries sent: {recoveries}")
    print(f"    ✓ PASS" if recoveries == 2 else f"    ✗ FAIL (expected 2, got {recoveries})")

    return cpu_alerts == 2 and dup_alerts == 0 and recoveries == 2

async def scenario_overlimit(bot, scheduler, mock):
    """Scenario 3: Overlimit clients - alert only new ones."""
    print("\n" + "="*60)
    print("SCENARIO 3: Overlimit (new clients only)")
    print("="*60)

    # Step 1: 3 clients overlimit
    mock.mode = "overlimit"
    bot.reset()
    await scheduler._check_overlimit(bot)

    alerts_1 = len([m for m in bot.messages if "Превышение лимита" in m])
    count_lines = sum(len(m.split('\n')) for m in bot.messages if "Превышение лимита" in m) if alerts_1 > 0 else 0
    print(f"  Step 1: 3 overlimit clients")
    print(f"    Alerts: {alerts_1}, total lines: {count_lines}")
    print(f"    ✓ PASS" if alerts_1 == 1 and count_lines >= 4 else f"    ✗ FAIL (expected 1 alert with 4+ lines, got {alerts_1} alert(s) with {count_lines} lines)")

    # Step 2: Same clients -> dedup, no new alerts
    bot.reset()
    await scheduler._check_overlimit(bot)

    dup_alerts = len([m for m in bot.messages if "Превышение лимита" in m])
    print(f"  Step 2: Same clients (dedup)")
    print(f"    Alerts: {dup_alerts}")
    print(f"    ✓ PASS" if dup_alerts == 0 else f"    ✗ FAIL (expected 0, got {dup_alerts})")

    # Step 3: Add 1 more client -> alert only new one
    async def mock_overlimit_with_new():
        return {"clients": [
            {"id": 101, "name": "user1", "traffic_limit": 1000},
            {"id": 102, "name": "user2", "traffic_limit": 2000},
            {"id": 103, "name": "user3", "traffic_limit": 3000},
            {"id": 104, "name": "user4", "traffic_limit": 4000},  # NEW
        ]}
    mock.get_overlimit_clients = mock_overlimit_with_new

    bot.reset()
    await scheduler._check_overlimit(bot)

    new_alerts = len([m for m in bot.messages if "Превышение лимита" in m])
    new_count = len([m for m in bot.messages if "user4" in m]) if new_alerts > 0 else 0
    print(f"  Step 3: Add new client")
    print(f"    Alerts: {new_alerts}, mentions new client: {new_count}")
    print(f"    ✓ PASS" if new_alerts == 1 and new_count > 0 else f"    ✗ FAIL")

    return alerts_1 == 1 and dup_alerts == 0 and new_alerts == 1

async def scenario_expiring(bot, scheduler, mock):
    """Scenario 4: Expiring subscriptions - daily gate."""
    print("\n" + "="*60)
    print("SCENARIO 4: Expiring (hour + daily gate)")
    print("="*60)

    # Mock datetime to be after ALERT_EXPIRING_HOUR (default 9)
    current_time = datetime(2026, 6, 28, 9, 0, 0, tzinfo=timezone.utc)
    original_datetime = datetime

    class MockDatetime:
        @staticmethod
        def now(tz=None):
            return current_time

    import services.alerts as alerts_module
    alerts_module.datetime = MockDatetime

    # Step 1: First run of day -> send report
    mock.mode = "expiring"
    bot.reset()
    scheduler._last_expiry_run = None
    await scheduler._maybe_check_expiring(bot)

    alerts_1 = len([m for m in bot.messages if "Истекают" in m or "подписки" in m])
    lines_count = sum(len(m.split('\n')) for m in bot.messages) if alerts_1 > 0 else 0
    print(f"  Step 1: First daily run (hour=9)")
    print(f"    Alerts: {alerts_1}, lines: {lines_count}")
    print(f"    ✓ PASS" if alerts_1 == 1 and lines_count >= 4 else f"    ✗ FAIL (expected 1 alert with 4+ lines, got {alerts_1} alert(s) with {lines_count} lines)")

    # Step 2: Same day -> dedup, no new alerts
    bot.reset()
    await scheduler._maybe_check_expiring(bot)

    dup_alerts = len([m for m in bot.messages if "Истекают" in m])
    print(f"  Step 2: Same day (dedup)")
    print(f"    Alerts: {dup_alerts}")
    print(f"    ✓ PASS" if dup_alerts == 0 else f"    ✗ FAIL (expected 0, got {dup_alerts})")

    # Step 3: Next day -> send report again
    current_time = datetime(2026, 6, 29, 9, 0, 0, tzinfo=timezone.utc)
    bot.reset()
    await scheduler._maybe_check_expiring(bot)

    alerts_2 = len([m for m in bot.messages if "Истекают" in m])
    print(f"  Step 3: Next day")
    print(f"    Alerts: {alerts_2}")
    print(f"    ✓ PASS" if alerts_2 == 1 else f"    ✗ FAIL (expected 1, got {alerts_2})")

    # Step 4: Before configured hour -> skip
    current_time = datetime(2026, 6, 29, 8, 0, 0, tzinfo=timezone.utc)
    bot.reset()
    await scheduler._maybe_check_expiring(bot)

    early_alerts = len([m for m in bot.messages if "Истекают" in m])
    print(f"  Step 4: Before hour (8:00)")
    print(f"    Alerts: {early_alerts}")
    print(f"    ✓ PASS" if early_alerts == 0 else f"    ✗ FAIL (expected 0, got {early_alerts})")

    alerts_module.datetime = original_datetime
    return alerts_1 == 1 and dup_alerts == 0 and alerts_2 == 1 and early_alerts == 0

async def scenario_mixed(bot, scheduler, mock):
    """Scenario 5: Mixed alerts - all types at once."""
    print("\n" + "="*60)
    print("SCENARIO 5: Mixed alerts (all types)")
    print("="*60)

    mock.mode = "mixed"
    bot.reset()

    # Force expiring report (same day, after hour)
    current_time = datetime(2026, 6, 28, 9, 0, 0, tzinfo=timezone.utc)
    import services.alerts as alerts_module
    original_datetime = datetime
    class MockDatetime:
        @staticmethod
        def now(tz=None):
            return current_time
    alerts_module.datetime = MockDatetime
    scheduler._last_expiry_run = None

    await scheduler._check_cpu_ram(bot)
    await scheduler._check_overlimit(bot)
    await scheduler._maybe_check_expiring(bot)

    cpu = len([m for m in bot.messages if "CPU" in m or "RAM" in m])
    over = len([m for m in bot.messages if "Превышение" in m])
    exp = len([m for m in bot.messages if "Истекают" in m])
    total = len(bot.messages)

    print(f"  CPU alerts: {cpu}")
    print(f"  Overlimit alerts: {over}")
    print(f"  Expiring alerts: {exp}")
    print(f"  Total messages: {total}")
    print(f"  ✓ PASS" if total >= 3 else f"    ✗ FAIL")

    alerts_module.datetime = original_datetime
    return total >= 3

async def scenario_errors(bot, scheduler, mock):
    """Scenario 6: API errors - graceful handling."""
    print("\n" + "="*60)
    print("SCENARIO 6: API errors (graceful handling)")
    print("="*60)

    mock.mode = "error"
    bot.reset()

    try:
        await scheduler._check_cpu_ram(bot)
        await scheduler._check_overlimit(bot)
        await scheduler._maybe_check_expiring(bot)
        print(f"  No crash, messages: {len(bot.messages)}")
        print(f"  ✓ PASS (graceful error handling)")
        return True
    except Exception as e:
        print(f"  ✗ FAIL (crashed: {e})")
        return False

# ============ MAIN ============

async def main():
    print("\n" + "█"*60)
    print("  ALERTING INTEGRATION TEST (Mock Data)")
    print("  " + datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"))
    print("█"*60)

    # Setup
    import services.alerts as alerts_module
    original_panel_api = alerts_module.panel_api
    mock = MockPanelAPI()
    alerts_module.panel_api = mock

    bot = TestBot()
    scheduler = AlertScheduler()

    # Run scenarios
    results = {}
    results["normal"] = await scenario_normal(bot, scheduler, mock)
    results["cpu_alert"] = await scenario_cpu_alert(bot, scheduler, mock)
    results["overlimit"] = await scenario_overlimit(bot, scheduler, mock)
    results["expiring"] = await scenario_expiring(bot, scheduler, mock)
    results["mixed"] = await scenario_mixed(bot, scheduler, mock)
    results["errors"] = await scenario_errors(bot, scheduler, mock)

    # Restore
    alerts_module.panel_api = original_panel_api

    # Summary
    print("\n" + "="*60)
    print("  SUMMARY")
    print("="*60)
    for name, passed in results.items():
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"  {status}  {name}")

    total = len(results)
    passed = sum(results.values())
    print("\n" + "─"*60)
    print(f"  Total: {passed}/{total} scenarios passed")
    print("─"*60)

    if passed == total:
        print("\n  ✓✓✓ ALL TESTS PASSED ✓✓✓")
        print("  Ready for production!")
    else:
        print(f"\n  ✗ {total - passed} scenario(s) failed")

    print()

if __name__ == "__main__":
    asyncio.run(main())