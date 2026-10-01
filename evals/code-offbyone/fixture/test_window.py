from datetime import date

from window import last_n_days


def test_keeps_recent_and_drops_old():
    today = date(2026, 9, 30)
    entries = [
        {"date": date(2026, 9, 29), "v": 1},
        {"date": date(2026, 9, 10), "v": 2},
        {"date": date(2026, 8, 1), "v": 3},
    ]
    assert [e["v"] for e in last_n_days(entries, 7, today)] == [1]


def test_today_is_included():
    today = date(2026, 9, 30)
    assert last_n_days([{"date": today, "v": 1}], 7, today) == [{"date": today, "v": 1}]
