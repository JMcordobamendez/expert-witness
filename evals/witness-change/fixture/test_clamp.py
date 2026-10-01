import pytest

from clamp import clamp


@pytest.mark.parametrize(
    "value, low, high, expected",
    [(5, 0, 10, 5), (-1, 0, 10, 0), (11, 0, 10, 10), (0, 0, 10, 0), (10, 0, 10, 10), (3, 3, 3, 3)],
)
def test_clamp(value, low, high, expected):
    assert clamp(value, low, high) == expected


def test_rejects_inverted_range():
    with pytest.raises(ValueError):
        clamp(1, 5, 0)
