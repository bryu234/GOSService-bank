from django.http import HttpResponseForbidden

from . import mfa


class BankLabMfaMiddleware:
    """Stable extension point; the START module always reports MFA as disabled."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path == "/sign-in" and request.method == "POST":
            username = request.POST.get("username", "")
            if mfa.required(username) and not mfa.verify(username, request.POST.get("otp", "")):
                return HttpResponseForbidden("A valid second factor is required")
        return self.get_response(request)
