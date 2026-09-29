"""Expose only the signed Razorpay webhook route to a local testing tunnel."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import httpx


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        if self.path != '/api/webhooks/razorpay':
            self.send_error(404)
            return
        if not self.headers.get('X-Razorpay-Signature'):
            self.send_error(401)
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            self.send_error(400)
            return
        if not 0 < length <= 1048576:
            self.send_error(413)
            return
        self.connection.settimeout(15)
        try:
            body = self.rfile.read(length)
            if len(body) != length:
                self.send_error(400)
                return
            response = httpx.post(
                'http://127.0.0.1:8000/api/webhooks/razorpay',
                content=body,
                headers={
                    'Content-Type': 'application/json',
                    'X-Razorpay-Signature': self.headers['X-Razorpay-Signature'],
                },
                timeout=20,
                trust_env=False,
            )
            self.send_response(response.status_code)
            self.end_headers()
        except (httpx.HTTPError, OSError):
            self.send_error(502)

    def do_GET(self):
        self.send_error(404)


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 8001), Handler).serve_forever()
