# Keeps a build's own game pack (the .pck in its Xcode project, the one that goes in the app) as base.pck on a
# GitHub release named build-<BUILD>, so updates over the air can be made for that build: an update is just
# what's changed since this exact pack (tools/ota/publish_update.ps1, scripts/Updater.gd). A release already
# there for the build number (a run tried again) is replaced, tag and all.
# Needs GITHUB_TOKEN (contents: write), GITHUB_REPOSITORY, GITHUB_SHA, BUILD; VERSION if it's known.
#   python3 tools/ci/save_base_pack.py <the .pck>
import json, os, sys, urllib.error, urllib.request


def call(method, url, data=None, raw=None, kind="application/json"):
    headers = {
        "Authorization": "Bearer " + os.environ["GITHUB_TOKEN"],
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "frogquest-testflight-workflow",
    }
    body = raw if raw is not None else (json.dumps(data).encode() if data is not None else None)
    if body is not None:
        headers["Content-Type"] = kind
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=600) as r:
            text = r.read()
            return r.status, (json.loads(text) if text else None)
    except urllib.error.HTTPError as e:
        return e.code, None


def main():
    pck = sys.argv[1]
    repo = os.environ["GITHUB_REPOSITORY"]
    build = os.environ["BUILD"]
    version = os.environ.get("VERSION", "")
    tag = "build-" + build
    api = "https://api.github.com/repos/" + repo
    status, was = call("GET", api + "/releases/tags/" + tag)
    if status == 200:
        call("DELETE", "%s/releases/%d" % (api, was["id"]))
        print("Replacing the release %s from a run before" % tag)
    call("DELETE", api + "/git/refs/tags/" + tag)  # (none there is fine)
    status, release = call("POST", api + "/releases", {
        "tag_name": tag,
        "target_commitish": os.environ["GITHUB_SHA"],
        "name": ("Frog Quest %s (%s)" % (version, build)).replace("  ", " "),
        "body": "Build %s's own game pack (base.pck), kept so updates over the air can be made for it: "
                "an update is just what's changed since this pack. Made by the TestFlight workflow." % build,
        "prerelease": True,
    })
    if status != 201:
        print("::error::Couldn't make the release %s (GitHub said %s)" % (tag, status))
        sys.exit(1)
    with open(pck, "rb") as f:
        data = f.read()
    status, asset = call("POST", "https://uploads.github.com/repos/%s/releases/%d/assets?name=base.pck" % (repo, release["id"]),
                         raw=data, kind="application/octet-stream")
    if status != 201:
        print("::error::Couldn't put the pack on the release %s (GitHub said %s)" % (tag, status))
        sys.exit(1)
    print("Kept %s (%d bytes) as %s" % (os.path.basename(pck), len(data), asset["browser_download_url"]))


if __name__ == "__main__":
    main()
