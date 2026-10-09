# Release process

1. Update `CHANGELOG.md` and the app version in `Resources/Info.plist`.
2. Run `swift build`, `swift run QuickTabChecks`, `swift test`, and `./package-dmg.sh`.
3. Verify the DMG, app signature, bundle ID, deployment target, and SHA-256.
4. Commit to `main` and create a tag such as `v1.0.0`.
5. The release workflow builds the DMG and publishes it with a checksum.

The default workflow uses ad-hoc signing when Developer ID secrets are absent. Such releases are for testing and internal use only. Public distribution should provide a Developer ID identity, hardened runtime, notarize with `xcrun notarytool`, staple the ticket, and verify again.

Future signing secrets are `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`, `KEYCHAIN_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_PASSWORD`. Never commit certificates, passwords, notarization profiles, or TCC databases.
