# THLNTFS Security Policy

## Security Architecture
THLNTFS strictly adheres to Apple's security specifications:
- Zero sudo elevation in the user-facing GUI application.
- All hardware partition mounts and privileged operations are mediated through a signed system daemon.
- Network I/O is restricted to isolated virtual interfaces.
