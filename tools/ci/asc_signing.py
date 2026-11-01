# App Store signing for CI without Xcode's account sign-in (which rejects the API key with
# "Cannot verify client's JWT headers"): makes a distribution certificate and an App Store profile
# through the App Store Connect API and puts them in a throwaway keychain.
#
#   python3 tools/ci/asc_signing.py setup     before exporting; writes PROFILE_UUID and SIGNING_KEYCHAIN to $GITHUB_ENV
#   python3 tools/ci/asc_signing.py cleanup   at the end (always); revokes this run's certificate unless UPLOADED=1
#
# The profile is named "Frog Quest CI cert <certificate id>". A run that uploaded keeps its certificate
# until the next run's setup revokes it, so Apple can finish processing the build first.
import base64, json, os, secrets, subprocess, sys, time, urllib.request

from asc_api import Api, ApiError

BUNDLE_ID = "com.muse.frogquest"
PROFILE_PREFIX = "Frog Quest CI cert "
WWDR_G3 = "https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer"

work = os.path.join(os.environ["RUNNER_TEMP"], "signing")
state_path = os.path.join(work, "state.json")
api = Api()


def fail(message):
    print("::error::" + message, flush=True)
    sys.exit(1)


def run(*cmd, quiet=False):
    # Only the tool name is ever printed: some arguments are (throwaway) passwords.
    result = subprocess.run(list(cmd), capture_output=True, text=True)
    if result.returncode != 0:
        fail("%s failed: %s" % (" ".join(cmd[:2]), (result.stderr or result.stdout).strip()[-800:]))
    return "" if quiet else result.stdout


def save(state):
    with open(state_path, "w") as f:
        json.dump(state, f)


def forget_ci_signing(certificate_id=None, profile_id=None):
    for kind, ident in (("profiles", profile_id), ("certificates", certificate_id)):
        if ident:
            try:
                api.call("DELETE", "/v1/%s/%s" % (kind, ident))
                print("Removed %s %s" % (kind[:-1], ident))
            except ApiError as e:
                if e.status != 404:
                    print("::warning::Couldn't remove %s %s: %s" % (kind[:-1], ident, e))


def setup():
    os.makedirs(work, exist_ok=True)

    # Leftovers from earlier runs (kept so Apple could process their builds).
    profiles = api.get("/v1/profiles", **{"filter[profileType]": "IOS_APP_STORE", "fields[profiles]": "name", "limit": 200})
    for p in profiles["data"]:
        name = p["attributes"]["name"]
        if name.startswith(PROFILE_PREFIX):
            forget_ci_signing(name[len(PROFILE_PREFIX):].strip(), p["id"])

    key = os.path.join(work, "dist.key")
    csr = os.path.join(work, "dist.csr")
    run("openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", csr,
        "-subj", "/CN=Frog Quest CI/C=US", quiet=True)
    try:
        cert = api.call("POST", "/v1/certificates", body={"data": {"type": "certificates", "attributes": {
            "certificateType": "DISTRIBUTION", "csrContent": open(csr).read()}}})["data"]
    except ApiError as e:
        listed = api.get("/v1/certificates", **{"filter[certificateType]": "DISTRIBUTION,IOS_DISTRIBUTION",
                                                 "fields[certificates]": "name,certificateType,expirationDate", "limit": 50})
        for c in listed["data"]:
            a = c["attributes"]
            print("  existing: %s (%s), expires %s" % (a.get("name"), a.get("certificateType"), (a.get("expirationDate") or "")[:10]))
        fail("Apple wouldn't make a distribution certificate (%s). If the team is at its limit, revoke an unused one "
             "in developer.apple.com > Certificates." % e)
    state = {"certificate": cert["id"]}
    save(state)
    print("Made distribution certificate %s (%s)" % (cert["id"], cert["attributes"].get("name")))

    cer = os.path.join(work, "dist.cer")
    pem = os.path.join(work, "dist.pem")
    p12 = os.path.join(work, "dist.p12")
    with open(cer, "wb") as f:
        f.write(base64.b64decode(cert["attributes"]["certificateContent"]))
    run("openssl", "x509", "-inform", "DER", "-in", cer, "-out", pem, quiet=True)
    p12_pass = secrets.token_hex(16)
    run("openssl", "pkcs12", "-export", "-inkey", key, "-in", pem, "-out", p12, "-passout", "pass:" + p12_pass,
        "-keypbe", "PBE-SHA1-3DES", "-certpbe", "PBE-SHA1-3DES", "-macalg", "sha1", quiet=True)

    bundles = api.get("/v1/bundleIds", **{"filter[identifier]": BUNDLE_ID, "fields[bundleIds]": "identifier", "limit": 200})
    bundle = next((b for b in bundles["data"] if b["attributes"]["identifier"] == BUNDLE_ID), None)
    if not bundle:
        fail("No App ID for %s in this team." % BUNDLE_ID)
    profile = api.call("POST", "/v1/profiles", body={"data": {
        "type": "profiles",
        "attributes": {"name": PROFILE_PREFIX + cert["id"], "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
            "certificates": {"data": [{"type": "certificates", "id": cert["id"]}]}}}})["data"]
    state["profile"] = profile["id"]
    save(state)
    uuid = profile["attributes"]["uuid"]
    content = base64.b64decode(profile["attributes"]["profileContent"])
    for folder in ("~/Library/MobileDevice/Provisioning Profiles", "~/Library/Developer/Xcode/UserData/Provisioning Profiles"):
        folder = os.path.expanduser(folder)
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, uuid + ".mobileprovision"), "wb") as f:
            f.write(content)
    print("Made App Store profile %s (%s)" % (profile["attributes"]["name"], uuid))

    keychain = os.path.join(work, "ci.keychain-db")
    keychain_pass = secrets.token_hex(16)
    state["keychain"] = keychain
    save(state)
    run("security", "create-keychain", "-p", keychain_pass, keychain, quiet=True)
    run("security", "set-keychain-settings", "-lut", "21600", keychain, quiet=True)
    run("security", "unlock-keychain", "-p", keychain_pass, keychain, quiet=True)
    run("security", "import", p12, "-k", keychain, "-P", p12_pass, "-T", "/usr/bin/codesign", "-T", "/usr/bin/security", quiet=True)
    wwdr = os.path.join(work, "AppleWWDRCAG3.cer")
    try:
        urllib.request.urlretrieve(WWDR_G3, wwdr)
        subprocess.run(["security", "import", wwdr, "-k", keychain], capture_output=True)
    except OSError as e:
        print("::warning::Couldn't fetch Apple's WWDR G3 intermediate (%s); relying on the system keychain." % e)
    run("security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", keychain_pass, keychain, quiet=True)
    others = [line.strip().strip('"') for line in run("security", "list-keychains", "-d", "user").splitlines() if line.strip()]
    run("security", "list-keychains", "-d", "user", "-s", keychain, *[k for k in others if k != keychain], quiet=True)
    os.remove(key)
    os.remove(p12)
    print(run("security", "find-identity", "-v", "-p", "codesigning", keychain).strip())

    with open(os.environ["GITHUB_ENV"], "a") as f:
        f.write("PROFILE_UUID=%s\nSIGNING_KEYCHAIN=%s\n" % (uuid, keychain))


def cleanup():
    if not os.path.exists(state_path):
        return
    with open(state_path) as f:
        state = json.load(f)
    if os.environ.get("UPLOADED") == "1":
        print("Uploaded: keeping certificate %s until the next run, so Apple can finish processing." % state.get("certificate"))
    else:
        forget_ci_signing(state.get("certificate"), state.get("profile"))
    if state.get("keychain"):
        subprocess.run(["security", "delete-keychain", state["keychain"]], capture_output=True)


if __name__ == "__main__":
    {"setup": setup, "cleanup": cleanup}[sys.argv[1]]()
