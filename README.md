# Cloud agent launcher

A generic starting point for Claude Code cloud sessions whose instructions live in another
git repository, which may be private and on any host.

At the start of a session it asks the user for a link to a start document and an access
token, clones that repository, runs its `setup-session.sh` if it has one, and follows the
start document. It also provides a headless browser whose request headers the start
document can set at runtime. It contains no project knowledge and no secrets.

Cloud environment: point it at this repository. The only other setting is network access,
which depends on the project: the hosts its start document needs.
