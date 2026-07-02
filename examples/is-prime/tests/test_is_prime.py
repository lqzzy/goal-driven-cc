import os
import sys
import random
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from is_prime import is_prime  # noqa: E402


def ref(n):
    """Independent oracle: trial division."""
    if n < 2:
        return False
    i = 2
    while i * i <= n:
        if n % i == 0:
            return False
        i += 1
    return True


class TestIsPrime(unittest.TestCase):
    def test_small_known(self):
        expected = {0: False, 1: False, 2: True, 3: True, 4: False, 5: True,
                    6: False, 7: True, 8: False, 9: False, 10: False, 11: True,
                    12: False, 13: True}
        for n, e in expected.items():
            self.assertEqual(is_prime(n), e, f"is_prime({n}) should be {e}")

    def test_range_matches_reference(self):
        # Wide range defeats any hardcoded/lookup cheat.
        for n in range(0, 500):
            self.assertEqual(is_prime(n), ref(n), f"mismatch at n={n}")

    def test_random_large(self):
        random.seed(1234)  # fixed seed => deterministic
        for _ in range(200):
            n = random.randint(0, 100000)
            self.assertEqual(is_prime(n), ref(n), f"mismatch at n={n}")

    def test_negatives(self):
        for n in (-1, -5, -100):
            self.assertFalse(is_prime(n), f"is_prime({n}) should be False")


if __name__ == "__main__":
    unittest.main()
