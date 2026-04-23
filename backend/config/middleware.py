class ApiCsrfExemptMiddleware:
    """Skip CSRF checks for API endpoints.

    This is safe because the app has no session-based authentication,
    so CSRF protection provides no security benefit for API calls.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_view(self, request, callback, callback_args, callback_kwargs):
        if '/api/' in request.path:
            setattr(request, '_dont_enforce_csrf_checks', True)
        return None
