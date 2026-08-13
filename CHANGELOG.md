# Changelog

All notable changes to this project are documented here.

## 0.1.0 (unreleased)

Initial development. M1 (foundation) — complete and verified against a real DoorDash Sandbox
endpoint (`bin/rails spree_doordash:verify_connection`, a real accepted quote):
`SpreeDoordash::Credential` (encrypted per-store DoorDash Drive access key),
`SpreeDoordash::Client` (JWT signing against the Drive v2 API), and a plain credential-entry
admin form.

Two real JWT-signing bugs only surfaced by that live verification, not by DoorDash's own docs or
sample code:
- The signing secret must be **base64url**-decoded, not standard base64.
- The JWT header needs an explicit `typ: 'JWT'` field — the `jwt` gem doesn't add it
  automatically the way Node's `jsonwebtoken` (what DoorDash's own sample code uses) does.

⚠️ DoorDash Drive API production access is currently restricted by DoorDash (no committed
timeline) — this extension targets and is verified against **Sandbox** only until that changes.
