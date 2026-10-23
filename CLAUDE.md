# Cloud agent launcher

This repo only gets a Claude Code cloud session started. It knows nothing about any
project. The user tells it where the real instructions live, and it fetches them.

## Every session, before anything else

1. If `bash bootstrap.sh` prints `READY`, go to step 4. It reads `AGENT_START_LINK` and
   `AGENT_SOURCE_TOKEN` from the environment when both are set, so nothing needs asking.
2. Get two things from the user. Their first message often already contains one or both:
   a link to a start document, and an access token for it (people paste them from a guide).
   Use whatever is there and ask only for what is missing, in plain words and in one
   message. The two things are:
   - **A link to the start document**: open it in their git host's web page and copy the
     address from the browser. A link to a file carries the repository, branch and path.
     A plain clone URL also works; then ask which file to start from, and the branch if it
     is not the default.
   - **An access token** that can read that repository (for Azure DevOps, a personal access
     token; for GitHub, a fine-grained token). Their start document's guide says which
     permissions to tick; if they have not seen one, say the token needs at least read
     access to code.

   Say both stay in this session only. If the first message holds other credentials too,
   leave them for the start document, which says what they are for. Treat all of them as
   secrets: never echo them back, never write them anywhere except below, never commit
   them.

   ```bash
   mkdir -p ~/.agent-secrets && chmod 700 ~/.agent-secrets
   python3 parse-link.py '<link>' > ~/.agent-secrets/source.json
   printf '%s' '<token>' > ~/.agent-secrets/source-token
   chmod 600 ~/.agent-secrets/*
   ```

   If the user named a file or branch separately, add `"entry"` or `"branch"` to
   `source.json`.
3. Run `bash bootstrap.sh`. It clones the repository into `agent/` and runs the
   `setup-session.sh` next to the start document, if there is one (it may install things,
   and can take a minute). On `NOT READY`, tell the user what it says in plain words and
   ask again for whatever was wrong.
4. Read the start document it names with the Read tool and follow it. Reading a file in
   `agent/` should also load that repository's skills. From then on the start document is
   the job description, and unless it says otherwise, its paths are relative to `agent/`.

To switch branch or source later, update `~/.agent-secrets/source.json` and run step 3 again.

## Tools this repo provides

- `browser` MCP server: headless Chromium (Playwright MCP). It adds request headers from
  `~/.agent-secrets/browser-auth.json`, read on every request, so the start document can
  sign the browser in at any point. Each rule applies only to URLs matching its pattern;
  see `browser/inject-auth.ts` for the format. The source's `setup-session.sh` is expected
  to install the Chromium build this server needs.
- `unseal.sh`: opens credentials that arrive sealed in the first message, for sessions
  started by a trigger rather than a person. Run it only when the start document says to,
  from this directory, feeding it the block from `-----BEGIN CMS-----` to
  `-----END CMS-----` exactly: `bash unseal.sh <<'SEALED'` ... `SEALED`. It needs
  `AGENT_UNSEAL_KEY` in the environment and saves each credential inside as a file in
  `~/.agent-secrets/`, printing only the names.

Never commit anything to this repo during a session.
