# Changelog

All notable changes to this project are documented here.

## 0.1.0 (unreleased)

Initial development. M1 (foundation): `SpreeDoordash::Credential` (encrypted per-store DoorDash
Drive access key), `SpreeDoordash::Client` (JWT signing against the Drive v2 API), and a plain
credential-entry admin form.

⚠️ DoorDash Drive API production access is currently restricted by DoorDash (no committed
timeline) — this extension targets and is verified against **Sandbox** only until that changes.
