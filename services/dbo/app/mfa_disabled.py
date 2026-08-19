"""START extension: MFA is intentionally not implemented or enforced."""


def begin(username: str) -> None:
    return None


def verify(username: str, code: str) -> bool:
    return True


def required(username: str) -> bool:
    return False
