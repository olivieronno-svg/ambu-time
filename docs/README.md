# Pages légales Ambu Time

Ce dossier contient les pages HTML requises par Google Play :
- [privacy.html](privacy.html) — Politique de confidentialité (obligatoire)
- [delete-account.html](delete-account.html) — Procédure de suppression de compte (obligatoire depuis 2024)

## Avant publication

**Remplace dans les 2 fichiers HTML :**
- `[TON_NOM_OU_SOCIÉTÉ]` → ton nom complet ou raison sociale
- `[TON_EMAIL]` → ton email de contact (4 occurrences au total)

## Hébergement sur GitHub Pages

1. Va sur le repo GitHub de ton choix (ex: `olivieronno-svg/ambu-time`)
2. **Settings → Pages**
3. **Source** : Deploy from a branch
4. **Branch** : `main` / `/docs`
5. **Save**

GitHub Pages publiera alors les 2 fichiers à l'URL :
- `https://olivieronno-svg.github.io/ambu-time/privacy.html`
- `https://olivieronno-svg.github.io/ambu-time/delete-account.html`

(Délai 1-2 minutes après le premier push.)

## Vérifier les URLs dans l'app

Les 2 URLs sont référencées dans [lib/screens/info_screen.dart](../lib/screens/info_screen.dart).
Si tu changes d'hébergement, modifie-les là-bas.

## Soumission Play Console

Une fois publié :
1. Play Console → Ton app → **App content**
2. **Privacy policy** → Saisir l'URL `privacy.html` → Save
3. **Account deletion** → "Users can request account deletion from within the app" + URL `delete-account.html`
