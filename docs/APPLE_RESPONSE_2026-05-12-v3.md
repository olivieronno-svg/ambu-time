# Réponse Resolution Center — Build 1.0.27 (61)

> Texte à coller dans le Resolution Center d'App Store Connect

```
Hello Apple Review Team,

Thank you for your feedback on the previous build. For build 1.0.27 (61) we have made the following changes to fully resolve all outstanding issues:

============================================================
Guideline 2.1(a) — Sign in with Apple
============================================================

We have completely REMOVED the "Sign in with Apple" button from the iOS app. The app no longer offers Sign in with Apple as an authentication option.

The previous "invalid credentials" error was caused by a server-side Firebase Authentication configuration issue that we were unable to fully diagnose without a macOS development environment. Rather than risk another rejection, we have removed the feature entirely.

Per Apple Guideline 4.8, Sign in with Apple is only required when an app offers third-party social sign-in (Google, Facebook, etc.). Since the app does NOT offer any third-party social sign-in (Google Sign-In was removed in build 1.0.24), Sign in with Apple is not required.

Users can sign in using:
- Email and password (primary authentication method)
- Account creation directly within the app

============================================================
Guideline 1.5 — Safety (Support URL)
============================================================

The dedicated support page is now live at:

  https://olivieronno-svg.github.io/ambu-time/

Contains: contact email (onnoff1975@gmail.com), FAQ section, privacy policy link, account deletion procedure.

============================================================
Guideline 2.1(b) — Information Needed (In-App Purchases)
============================================================

This version of the iOS app has NO in-app purchases. The "Ambu Time Pro" subscription has been permanently deleted from App Store Connect. The app is 100% free with advertising as the only monetization.

All previously gated features (PDF export, labor law reference section, advanced charts) are available to ALL users with no paywall.

============================================================
Summary of changes
============================================================

- Sign in with Apple button removed from iOS (eliminates motif 2.1a)
- Support page deployed at olivieronno-svg.github.io/ambu-time/
- "Ambu Time Pro" subscription deleted from App Store Connect
- Version: 1.0.27 (61)

No test credentials are required — all features are accessible without authentication. Email/password sign-in is available for optional cloud sync.

Thank you for your continued review.

Best regards,
The Ambu Time team
```
