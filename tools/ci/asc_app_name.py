# Renames the app on the App Store (App Information > Name) through the App Store Connect API, with the
# CI's key, so nobody has to sign in. Apple shows the new name once a version carrying it is released;
# until then it waits with the version being prepared. If no version is being prepared, this makes one
# with the iOS export preset's version (application/short_version), the one the TestFlight builds have.
# If Apple won't take the name (another app has it), it says so and changes nothing.
#   python3 tools/ci/asc_app_name.py "Frog Quest"
import os, re, sys

from asc_api import Api, ApiError

BUNDLE_ID = "com.muse.frogquest"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}


def fail(message):
    print("::error::" + message, flush=True)
    sys.exit(1)


def preset_version():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "export_presets.cfg")
    match = re.search(r'application/short_version="([^"]+)"', open(path, encoding="utf-8").read())
    return match.group(1) if match else None


def state_of(info):
    return info["attributes"].get("state") or info["attributes"].get("appStoreState")


def editable_info(api, app_id):
    infos = api.get("/v1/apps/%s/appInfos" % app_id)["data"]
    for info in infos:
        print("App Information %s: %s" % (info["id"], state_of(info)))
    return next((info for info in infos if state_of(info) in EDITABLE), None)


name = " ".join(sys.argv[1:]).strip()
if not 0 < len(name) <= 30:
    fail("An App Store name is 1 to 30 characters.")
api = Api()
app = api.get("/v1/apps", **{"filter[bundleId]": BUNDLE_ID, "fields[apps]": "name,bundleId"})["data"][0]
print("App: %s (%s)" % (app["attributes"]["name"], app["id"]))

info = editable_info(api, app["id"])
if info is None:
    version = preset_version()
    print("No version is being prepared for the App Store; making version %s to carry the new name." % version)
    try:
        api.call("POST", "/v1/appStoreVersions", body={"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": version},
            "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})
    except ApiError as e:
        fail("Couldn't make version %s: %s" % (version, e))
    info = editable_info(api, app["id"])
    if info is None:
        fail("Made version %s, but its App Information isn't editable yet. Run this again in a minute." % version)

for loc in api.get("/v1/appInfos/%s/appInfoLocalizations" % info["id"])["data"]:
    locale, old = loc["attributes"].get("locale"), loc["attributes"].get("name")
    if old == name:
        print("%s: already '%s'." % (locale, name))
        continue
    try:
        api.call("PATCH", "/v1/appInfoLocalizations/%s" % loc["id"], body={"data": {
            "type": "appInfoLocalizations", "id": loc["id"], "attributes": {"name": name}}})
    except ApiError as e:
        if e.status == 409:
            fail("Apple won't take '%s' for %s (%s). It's probably another app's name: pick another." % (name, locale, e.detail))
        fail("Couldn't rename %s: %s" % (locale, e))
    print("%s: '%s' -> '%s'" % (locale, old, name))
print("Done: the App Store shows '%s' once the version being prepared is released." % name)
