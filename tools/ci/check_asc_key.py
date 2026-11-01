# Checks the App Store Connect API key secrets before the long build, and picks the build number.
# - Accepts the .p8 with or without its BEGIN/END lines (and squashed onto one line), and writes it to
#   $RUNNER_TEMP/private_keys/AuthKey_<KEY_ID>.p8 (the name Apple's tools look for), path in $ASC_KEY_PATH.
# - Says what a wrong value looks like (a Key ID, an Issuer ID, a file name...) without ever printing it.
# - Signs in to the App Store Connect API with it, so a bad key fails in seconds, not after a 20 minute build.
# - Writes BUILD (one above anything already uploaded, and at least 2 + the run number) to $GITHUB_ENV.
import base64, json, os, re, subprocess, sys, time, urllib.error, urllib.parse, urllib.request

BUNDLE_ID = "com.muse.frogquest"
UUID = r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"


def fail(message):
    print("::error::" + message, flush=True)
    sys.exit(1)


def looks_like(value):
    v = value.strip()
    if re.fullmatch(UUID, v):
        return "an Issuer ID"
    if re.fullmatch(r"[A-Z0-9]{10}", v):
        return "a Key ID"
    if v.lower().endswith(".p8") or re.match(r"^[A-Za-z]:[\\/]", v):
        return "a file name or path, not the file's contents"
    return "%d characters on %d line(s)" % (len(v), v.count("\n") + 1)


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


key_id = os.environ.get("ASC_KEY_ID", "").strip()
issuer = os.environ.get("ASC_ISSUER_ID", "").strip()
raw = os.environ.get("ASC_PRIVATE_KEY", "").replace("\r", "")
for name in ("ASC_KEY_ID", "ASC_ISSUER_ID"):
    if os.environ.get(name, "") != os.environ.get(name, "").strip():
        print("%s has spaces or line breaks around it; the workflow trims them." % name)

if not re.fullmatch(r"[A-Z0-9]{10}", key_id):
    fail("ASC_KEY_ID should be the key's 10-character Key ID, but it looks like %s." % looks_like(key_id))
if not re.fullmatch(UUID, issuer):
    fail("ASC_ISSUER_ID should be the Issuer ID (shown above the keys list), but it looks like %s." % looks_like(issuer))

body = raw
match = re.search(r"-----BEGIN PRIVATE KEY-----(.*?)-----END PRIVATE KEY-----", raw, re.S)
if match:
    body = match.group(1)
elif "BEGIN" in raw:
    fail("ASC_PRIVATE_KEY has a BEGIN line but no END PRIVATE KEY line: paste the whole AuthKey_XXXX.p8 file.")
b64 = re.sub(r"\s+", "", body)
der = b""
if re.fullmatch(r"[A-Za-z0-9+/]+={0,2}", b64 or "-"):
    try:
        der = base64.b64decode(b64, validate=True)
    except ValueError:
        der = b""
if len(der) < 100 or der[0] != 0x30:
    fail("ASC_PRIVATE_KEY should be the contents of AuthKey_XXXX.p8 (open it in Notepad, Ctrl+A, Ctrl+C), "
         "but it looks like %s." % looks_like(raw))

key_dir = os.path.join(os.environ["RUNNER_TEMP"], "private_keys")
os.makedirs(key_dir, exist_ok=True)
key_path = os.path.join(key_dir, "AuthKey_%s.p8" % key_id)
lines = [b64[i:i + 64] for i in range(0, len(b64), 64)]
with open(key_path, "w") as f:
    f.write("-----BEGIN PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END PRIVATE KEY-----\n")
os.chmod(key_path, 0o600)
if subprocess.run(["openssl", "pkey", "-in", key_path, "-noout"], capture_output=True).returncode != 0:
    fail("ASC_PRIVATE_KEY isn't a readable private key: paste the whole AuthKey_XXXX.p8 file again.")
if not match:
    print("ASC_PRIVATE_KEY had no BEGIN/END lines; added them.")

# Sign a token for the App Store Connect API (ES256: openssl gives a DER signature, JWT wants raw r||s).
now = int(time.time())
header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
claims = b64url(json.dumps({"iss": issuer, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}).encode())
signing_input = (header + "." + claims).encode()
sig = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=signing_input,
                     capture_output=True, check=True).stdout
i = 2 if sig[1] < 0x80 else 2 + (sig[1] & 0x7F)
parts = []
for _ in range(2):
    n = sig[i + 1]
    parts.append(int.from_bytes(sig[i + 2:i + 2 + n], "big").to_bytes(32, "big"))
    i += 2 + n
token = header + "." + claims + "." + b64url(b"".join(parts))


def api(path, query):
    url = "https://api.appstoreconnect.apple.com" + path + "?" + urllib.parse.urlencode(query)
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


try:
    apps = api("/v1/apps", {"filter[bundleId]": BUNDLE_ID, "fields[apps]": "name,bundleId"})["data"]
except urllib.error.HTTPError as e:
    if e.code == 401:
        fail("Apple rejected the key (401): ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY must all come from "
             "the same key, and the key must not be revoked.")
    if e.code == 403:
        fail("Apple accepted the key but it can't see apps (403): give the key Admin access.")
    fail("App Store Connect API error %d." % e.code)
if not apps:
    fail("The key works, but no app with bundle ID %s is visible to it." % BUNDLE_ID)
app = apps[0]

builds = api("/v1/builds", {"filter[app]": app["id"], "fields[builds]": "version", "limit": 200})["data"]
uploaded = [int(b["attributes"]["version"]) for b in builds if str(b["attributes"].get("version", "")).isdigit()]
highest = max(uploaded, default=0)
build = max(2 + int(os.environ.get("GITHUB_RUN_NUMBER", "1")), highest + 1)
with open(os.environ["GITHUB_ENV"], "a") as f:
    f.write("BUILD=%d\nASC_KEY_PATH=%s\n" % (build, key_path))
print("Key works: %s (%s). Highest build already uploaded: %d. This run uploads build %d."
      % (app["attributes"]["name"], BUNDLE_ID, highest, build))
