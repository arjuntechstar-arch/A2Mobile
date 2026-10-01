"""Local POC server: built customer app and explicitly allowed customer API routes."""
import argparse
import re
from pathlib import Path
from urllib.parse import urlsplit
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import httpx

WEB_ROOT = Path(__file__).resolve().parents[1] / 'mobile' / 'build' / 'web'
RULES = {
    'GET': [r'/api/app-config', r'/api/auth/me', r'/api/me', r'/api/dashboard',
            r'/api/banner', r'/uploads/banners/[0-9a-f-]+\.(?:png|jpg|webp)',
            r'/api/schemes(?:/[^/]+)?', r'/api/enrollments(?:/[^/]+(?:/installments)?)?',
            r'/api/payments(?:/[^/]+/receipt)?', r'/api/notifications',
            r'/api/content/[^/]+', r'/api/support/tickets', r'/api/kyc/status',
            r'/api/kyc/identity/status'],
    'POST': [r'/api/auth/(?:registration/email|register|login|refresh|logout|send-email-verification|verify-email|verify-phone-firebase|forgot-password|reset-password)',
             r'/api/enrollments', r'/api/payments/orders', r'/api/payments/[^/]+/verify',
             r'/api/notifications/devices', r'/api/support/tickets'],
    'PATCH': [r'/api/me', r'/api/notifications/[^/]+/read'],
    'DELETE': [r'/api/notifications/devices'],
}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def log_message(self, *args):
        pass  # Avoid logging email verification tokens in query strings.

    def list_directory(self, path):
        self.send_error(404)
        return None

    def proxy(self):
        path = urlsplit(self.path).path
        if not any(re.fullmatch(rule, path) for rule in RULES.get(self.command, [])):
            self.send_error(404)
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            self.send_error(400)
            return
        if not 0 <= length <= 1048576 or self.headers.get('Transfer-Encoding'):
            self.send_error(413)
            return
        self.connection.settimeout(20)
        try:
            body = self.rfile.read(length)
            if len(body) != length:
                self.send_error(400)
                return
            headers = {key: self.headers[key] for key in
                       ['Content-Type', 'Authorization', 'Idempotency-Key'] if self.headers.get(key)}
            response = httpx.request(self.command, 'http://127.0.0.1:8000' + self.path,
                                    content=body, headers=headers, timeout=30, trust_env=False)
            self.send_response(response.status_code)
            self.send_header('Content-Type', response.headers.get('Content-Type', 'application/json'))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(response.content)))
            self.end_headers()
            self.wfile.write(response.content)
        except (httpx.HTTPError, OSError):
            self.send_error(502)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path.startswith(('/api/', '/uploads/')):
            self.proxy()
        elif path in ('/docs', '/redoc', '/openapi.json'):
            self.send_error(404)
        else:
            super().do_GET()

    do_POST = proxy
    do_PATCH = proxy
    do_DELETE = proxy


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Serve the locally built customer web app.')
    parser.add_argument('--host', default='127.0.0.1', choices=('127.0.0.1', '0.0.0.0'))
    parser.add_argument('--port', default=5174, type=int)
    args = parser.parse_args()
    if not (WEB_ROOT / 'index.html').is_file():
        raise SystemExit('Build the Flutter web app with API_BASE_URL=/api first.')
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()
