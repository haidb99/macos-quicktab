# macOS permissions

Accessibility is needed to enumerate and activate individual windows and to use the active event tap. Screen Recording is optional and only supplies thumbnails. Input Monitoring may be required by the system depending on event-tap policy.

Permissions are granted per app identity and machine. Use the app copied to `/Applications`, keep the bundle identifier stable, and avoid running multiple copies from different paths. A rebuild or ad-hoc signature can cause macOS to request consent again.

QuickTab checks permission state when the app becomes active, when Settings is open, and when an event tap reports a failure. It does not bypass TCC or silently reset consent. If Accessibility is withdrawn, the active switcher session is cancelled.
