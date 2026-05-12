# Réponse Resolution Center — Rejet 2026-05-12

> Ce fichier contient le texte à copier-coller dans le **Resolution Center**
> d'App Store Connect après avoir effectué les 2 actions manuelles ci-dessous.

---

## ⚠️ AVANT de coller ce message, faire ces 2 actions

### 1. Supprimer l'abonnement "Ambu Time Pro" dans ASC
- App Store Connect → Ambu Time → Distribution → Subscriptions
- Cliquer sur Pro Features → Ambu Time Pro
- Scroller tout en bas → cliquer sur le **lien rouge "Supprimer cet abonnement"**
- Confirmer

### 2. Re-vérifier la configuration Firebase Apple Sign In
- **Apple Developer** : vérifier que la clé .p8 a bien `com.onnoff.ambutime` comme Primary App ID
- **Firebase Console → Authentication → Apple** : re-coller le contenu du .p8 (au cas où il aurait été corrompu)
- Vérifier Team ID + Key ID

---

## 📋 Texte à coller dans Resolution Center

```
Hello Apple Review Team,

Thank you for your detailed feedback on the May 12, 2026 review of build
1.0.24 (50). We have addressed all three issues in build 1.0.25 (51):

============================================================
Guideline 1.5 — Safety (Support URL)
============================================================

The previous Support URL was missing an index page at the root,
returning a 404. We have now published a dedicated support page at:

  https://olivieronno-svg.github.io/ambu-time/

This page contains:
- Direct contact email (onnoff1975@gmail.com)
- A complete FAQ section covering app usage, account management,
  data privacy, and pricing
- Links to the Privacy Policy and Account Deletion procedure
- Information on supported devices and offline behavior


============================================================
Guideline 2.1(a) — Performance (Sign in with Apple)
============================================================

We investigated the "invalid credentials" error you encountered.
The Sign in with Apple flow involves:
1. The native Apple AuthenticationServices presents the credential
2. Apple returns an identityToken
3. We validate this token against Firebase Authentication

We have:
- Re-verified the .p8 private key in Firebase Console
- Confirmed Team ID and Key ID match Apple Developer Portal
- Confirmed the .p8 key is properly configured with
  com.onnoff.ambutime as its Primary App ID
- Added detailed diagnostic logging to the authentication flow
- Improved the user-facing error message to suggest the
  email/password alternative if Apple Sign In fails

If the issue persists during your next review, please:
1. Ensure the test Apple ID is not in iCloud Family
2. Try a different test Apple ID
3. Use the email/password sign-in option which is fully functional

The "Continuer avec Apple" button is optional. The primary sign-in
method is email/password which has no third-party dependency.


============================================================
Guideline 2.1(b) — Information Needed (In-App Purchases)
============================================================

To clarify: this version of the iOS app has NO in-app purchases.

The previous "Ambu Time Pro" subscription has been:
- Removed from sale in all 175 countries
- Deleted entirely from App Store Connect

The iOS app is now 100% free with advertising as the only
monetization. All previously gated features (PDF export, labor
law reference section, advanced charts) are now available to
ALL users with no paywall and no upgrade path.

There is intentionally no IAP location to demonstrate because
no IAP exists in this build. The Settings tab does not contain
any "Upgrade to Pro" button, subscription information, or
purchase flow.

You will not find any in-app purchase in this version. Please
review the app as a free application monetized exclusively
through interstitial advertisements.


============================================================
Summary of changes since build 1.0.24 (50)
============================================================

- New support page at https://olivieronno-svg.github.io/ambu-time/
- Improved Sign in with Apple error handling and logging
- "Ambu Time Pro" subscription deleted from App Store Connect
- Version bumped to 1.0.25 (51)

No test credentials are required — all features are accessible
without authentication.

Thank you for your continued review.

Best regards,
The Ambu Time team
```

---

## Après avoir collé la réponse

1. Cliquer sur **"Soumettre"** dans le Resolution Center
2. Aller sur Codemagic et déclencher manuellement un nouveau build (workflow iOS)
3. Attendre 20 min que TestFlight reçoive 1.0.25 (51)
4. Dans la fiche de version ASC, remplacer le build 50 par le 51
5. Cliquer sur "Mettre à jour la vérification"
