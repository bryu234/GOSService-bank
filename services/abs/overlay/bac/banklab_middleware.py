from django.http import HttpResponseForbidden


class BankLabRoleMiddleware:
    PUBLIC_PREFIXES = ("/sign-in", "/sign-out", "/static/", "/admin/login")
    WRITE_PATHS = ("/transfer", "/api/transfer", "/api/beneficiaries", "/sign-up")

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.user.is_authenticated and not request.path.startswith(self.PUBLIC_PREFIXES):
            groups = set(request.user.groups.values_list("name", flat=True))
            if request.path.startswith("/admin"):
                if "abs_admin" not in groups:
                    return HttpResponseForbidden("abs_admin permission is required")
            elif "abs_read" not in groups:
                return HttpResponseForbidden("abs_read permission is required")
            if request.method not in {"GET", "HEAD", "OPTIONS"} and request.path.startswith(self.WRITE_PATHS):
                if "abs_write" not in groups:
                    return HttpResponseForbidden("abs_write permission is required")
        return self.get_response(request)
