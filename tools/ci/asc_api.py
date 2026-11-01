# Minimal App Store Connect API client for the CI scripts (standard library + the openssl command only).
import base64, json, os, subprocess, time, urllib.error, urllib.parse, urllib.request

BASE = "https://api.appstoreconnect.apple.com"


class ApiError(Exception):
    def __init__(self, status, detail):
        super().__init__("App Store Connect API %d: %s" % (status, detail))
        self.status, self.detail = status, detail


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def make_token(key_path, key_id, issuer, lifetime=1200):
    """ES256 JWT for the API. openssl signs in DER; a JWT wants the raw 32-byte r and s."""
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    claims = b64url(json.dumps({"iss": issuer, "iat": now, "exp": now + lifetime, "aud": "appstoreconnect-v1"}).encode())
    signing_input = (header + "." + claims).encode()
    sig = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=signing_input,
                         capture_output=True, check=True).stdout
    i = 2 if sig[1] < 0x80 else 2 + (sig[1] & 0x7F)
    parts = []
    for _ in range(2):
        n = sig[i + 1]
        parts.append(int.from_bytes(sig[i + 2:i + 2 + n], "big").to_bytes(32, "big"))
        i += 2 + n
    return header + "." + claims + "." + b64url(b"".join(parts))


class Api:
    def __init__(self, key_path=None, key_id=None, issuer=None):
        self.key_path = key_path or os.environ["ASC_KEY_PATH"]
        self.key_id = (key_id or os.environ["ASC_KEY_ID"]).strip()
        self.issuer = (issuer or os.environ["ASC_ISSUER_ID"]).strip()
        self._token, self._made = None, 0.0

    def token(self):
        if time.time() - self._made > 600:
            self._token, self._made = make_token(self.key_path, self.key_id, self.issuer), time.time()
        return self._token

    def call(self, method, path, query=None, body=None):
        url = BASE + path + ("?" + urllib.parse.urlencode(query) if query else "")
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(url, data=data, method=method, headers={
            "Authorization": "Bearer " + self.token(), "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                raw = response.read()
        except urllib.error.HTTPError as e:
            detail = e.reason
            try:
                errors = json.loads(e.read()).get("errors", [])
                detail = "; ".join("%s %s" % (x.get("title", ""), x.get("detail", "")) for x in errors) or detail
            except ValueError:
                pass
            raise ApiError(e.code, detail) from None
        return json.loads(raw) if raw else None

    def get(self, path, **query):
        return self.call("GET", path, query or None)
