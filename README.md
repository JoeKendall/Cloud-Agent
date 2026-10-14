# Cloud agent launcher

A generic starting point for Claude Code cloud sessions whose instructions live in another
git repository, which may be private and on any host.

At the start of a session it reads a link to a start document and an access token from the
environment variables `AGENT_START_LINK` and `AGENT_SOURCE_TOKEN`, or asks the user for
them, clones that repository, runs its `setup-session.sh` if it has one, and follows the
start document. It also provides a headless browser whose request headers the start
document can set at runtime. It contains no project knowledge and no secrets.

Cloud environment: set `AGENT_START_LINK` and `AGENT_SOURCE_TOKEN`, and network access to
the hosts the start document needs. Pick this repository when starting the session. Anyone
who can use an environment can read its variables, so keep it personal.
