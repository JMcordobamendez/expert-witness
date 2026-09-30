from datetime import date, timedelta


def last_n_days(entries, n, today):
    """Return the entries dated within the last n days, today included.

    An entry dated exactly n days before today is included.
    """
    start = today - timedelta(days=n)
    return [e for e in entries if start < e["date"] <= today]
