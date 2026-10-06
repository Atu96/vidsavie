# Developer guide

VidSavie is a native macOS menu bar app with a Chrome companion and independent offline media tools.

- [Architecture](ARCHITECTURE.md): ownership, dependency direction, and compatibility invariants.
- [System map](SYSTEM-MAP.md): route a feature or failure to its owning module.
- [Platform troubleshooting](PLATFORM-DOWNLOAD-TROUBLESHOOTING.md): measured extraction failures and privacy-preserving diagnostics.
- [Licensing audit](../../LICENSING-AUDIT.md): original-code scope, bundled dependencies, and outstanding review items.
- [Media release notes](../releases/MEDIA-RELEASE-NOTES.md): the reviewed media profile and matching source package.

## Before changing code

Keep platform DOM logic inside its adapter. Keep deterministic command/policy logic separate from SwiftUI. Preserve bundle identifiers, URL schemes, preference keys, and storage paths unless a migration is explicitly designed.

Run `./Scripts/test.sh` from the repository root. For runtime changes also run `./Scripts/build-app.sh` and verify the signed bundle. Routine app builds package verified prebuilt tools; rebuilding FFmpeg is a separate maintainer task, not a normal build requirement.

Automated tests use synthetic fixtures: do not download real platform media, read browser cookies, or modify a user's media folder. Report real-world verification separately. Never include cookies, signed media URLs, credentials, or personal paths in issues or commits.

## Contributions and reports

For a bug report, include the app version, platform, expected behavior, actual behavior, and a sanitized error log. Share a sample URL only if it is safe and public. For a code change, explain the affected layer and tests run; avoid unrelated rewrites. Discussion and pull requests are welcome, but acceptance is not guaranteed.

Owner-specific agent handoff notes are kept locally, not required to build a fresh clone. Release installers belong in GitHub Releases, not source commits. See the root README for installation and support; third-party tools retain their own licenses.
