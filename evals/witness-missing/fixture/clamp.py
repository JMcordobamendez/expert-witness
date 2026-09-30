def clamp(value, low, high):
    """Return value limited to the closed range [low, high].

    Raises ValueError if low > high.
    """
    if low > high:
        raise ValueError(f"low ({low}) is greater than high ({high})")
    return max(low, min(value, high))
