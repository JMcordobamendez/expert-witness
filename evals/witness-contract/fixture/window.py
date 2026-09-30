from datetime import date, timedelta


def last_n_days(entries, n, today):
    """Return the entries dated from n days before today through today, both ends included.

    An entry dated exactly n days before today is included, so the window
    spans n + 1 calendar days.
    """
    start = today - timedelta(days=n)
    return [e for e in entries if start < e["date"] <= today]
