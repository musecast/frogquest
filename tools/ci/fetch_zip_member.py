# Pulls one file out of a remote zip with HTTP Range requests instead of downloading the whole archive
# (the CI only needs templates/ios.zip, ~200 MB, out of Godot's 1.28 GB export templates .tpz).
# usage: python3 fetch_zip_member.py <url> <member> <out_file>
import io, sys, urllib.request, zipfile

url, member, out = sys.argv[1], sys.argv[2], sys.argv[3]


def resolve(u):
    req = urllib.request.Request(u, method="HEAD")
    with urllib.request.urlopen(req) as r:
        return r.geturl(), int(r.headers["Content-Length"])


class RemoteFile(io.RawIOBase):
    def __init__(self, url, size):
        self.url, self.size, self.pos = url, size, 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else self.pos + off if whence == 1 else self.size + off
        return self.pos

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b""
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(self.url, headers={"Range": "bytes=%d-%d" % (self.pos, end)})
        with urllib.request.urlopen(req) as r:
            data = r.read()
        self.pos += len(data)
        return data

    def readinto(self, b):
        data = self.read(len(b))
        b[:len(data)] = data
        return len(data)


real, size = resolve(url)
zf = zipfile.ZipFile(io.BufferedReader(RemoteFile(real, size), buffer_size=8 << 20))
info = zf.getinfo(member)
print("%s: %d bytes from a %d byte archive" % (member, info.file_size, size), flush=True)
done = shown = 0
with zf.open(info) as src, open(out, "wb") as dst:
    while True:
        chunk = src.read(8 << 20)
        if not chunk:
            break
        dst.write(chunk)
        done += len(chunk)
        if done * 10 // info.file_size > shown:
            shown = done * 10 // info.file_size
            print("  %d%%" % (shown * 10), flush=True)
print("wrote", out, done)
