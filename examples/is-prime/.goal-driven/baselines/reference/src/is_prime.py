def is_prime(n):
    # Known-good baseline. The criteria MUST judge this PASS
    # (proves discrimination ceiling — the criteria are satisfiable).
    if n < 2:
        return False
    i = 2
    while i * i <= n:
        if n % i == 0:
            return False
        i += 1
    return True
