#!/usr/bin/env python3
"""Turns a link to a file in a git web UI into the source description bootstrap.sh needs.

  parse-link.py '<link>'   prints {"url": ..., "branch": ..., "entry": ...}

Understands Azure DevOps (`.../_git/<repo>?path=/a/b.md&version=GB<branch>`), GitHub and
GitLab (`.../<repo>/blob/<branch>/a/b.md`), and a plain clone URL (entry README.md).
"""
import json
import re
import sys
from urllib.parse import parse_qs, urlparse

link = sys.argv[1].strip()
u = urlparse(link)
q = parse_qs(u.query)
out = {}
if "/_git/" in u.path:
    out["url"] = f"{u.scheme}://{u.netloc}{u.path}"
    if "path" in q:
        out["entry"] = q["path"][0].lstrip("/")
    version = q.get("version", [""])[0]
    if version.startswith("GB"):
        out["branch"] = version[2:]
else:
    m = re.match(r"(/[^/]+/[^/]+?)(?:\.git)?/(?:-/)?blob/([^/]+)/(.+)", u.path)
    if m:
        out = {"url": f"{u.scheme}://{u.netloc}{m.group(1)}.git", "branch": m.group(2), "entry": m.group(3)}
    else:
        out["url"] = link
json.dump(out, sys.stdout)
print()
