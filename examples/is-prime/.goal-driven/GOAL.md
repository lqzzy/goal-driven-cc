# GOAL

## Intent
Implement a correct primality predicate `is_prime(n)` in `src/is_prime.py` so that
the provided test suite passes for all cases.

## Success looks like (acceptance requirements)
1. `is_prime(n)` returns the correct boolean for every integer, matching a trial-division reference.
2. Non-positive and small edge cases are correct: n < 2 (including negatives, 0, 1) are not prime; 2 and 3 are prime.
3. Correct across a wide deterministic range (0..499) and a seeded random sample up to 100000.

## Non-goals
- No performance requirement beyond finishing the tests within the time budget.
- No CLI, packaging, or API beyond the `is_prime(n)` function.

## Constraints
- Python 3, standard library only (tests use `unittest`).
- The public surface is exactly `is_prime(n)` in `src/is_prime.py`.

## Assumptions
- "Prime" uses the standard definition (integers ≥ 2 with no divisor other than 1 and itself).
