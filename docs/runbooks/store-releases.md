# Store releases (Android)

How an app release reaches testers: tagging `app-v<x.y.z>`, the signed AAB that `app-release.yml` builds, Play App Signing, the closed-track upload you do by hand, and the testers list. It touches Google Play, not the servers. The iOS builds (Codemagic, TestFlight, the App Store) and the production track arrive with D12–D20 and are not covered here. Background: system-design §9, FR-049 (spec 002), [ci-workflows.md](ci-workflows.md) for the workflow's checks, [secrets.md](secrets.md#rotate-the-android-upload-key) for the key.

**The upload to Play is manual on purpose.** `app-release.yml` stops at the artifact `app-prod-release.aab`. An automated upload needs a Play service account, which arrives on D27 ([secrets.md](secrets.md)). Until then you give Play the AAB yourself.

## Before you start

- A Google Play Console developer account, with the app created for the package `com.madarsat.app` (the `prod` flavor; `.dev` and `.staging` are never uploaded).
- The upload keystore and its four secrets on the repository: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`) and `ANDROID_KEY_PASSWORD` ([secrets.md](secrets.md#rotate-the-android-upload-key) has how they were made).
- `gh` logged in with access to `AhmedSaied94/madar-sat`.
- `master` is green for `app` and `pwa`, and it contains the app code you mean to release. Tags are built from the commit they point at, not from `master`'s tip.

## 1. Back up the upload keystore

Do this once, before the first release. GitHub cannot return a secret, so the only other copy is on your machine.

1. Copy `~/.config/madar-sat/upload-keystore.jks` and `~/.config/madar-sat/keystore-password` into your password manager (as attachments or secure notes).
2. Check the copy opens and note the key's fingerprint:

   ```bash
   keytool -list -v -keystore ~/.config/madar-sat/upload-keystore.jks -alias upload \
     -storepass "$(cat ~/.config/madar-sat/keystore-password)" | grep 'SHA256:'
   ```

   You should see one `SHA256:` line. The workflow prints the same fingerprint on every release ("Upload key SHA256…"), so you can compare them.

## 2. Tag the release

The tag must be exactly `app-v<major>.<minor>.<patch>`; the workflow fails on anything else (`tag must look like app-v1.2.3`).

```bash
git switch master && git pull --ff-only
git tag app-v0.2.0
git push origin app-v0.2.0
```

`app-release.yml` runs on the push. `versionName` is the tag without `app-v`, and `versionCode` is the run number, so it only ever goes up.

**Never re-run a finished run to get a new build.** A re-run keeps the same run number, so it produces the same `versionCode`, and Play refuses an upload whose `versionCode` it already has. Push a new tag (`app-v0.2.1`) instead.

## 3. Get the AAB

1. Find the run and watch it until the `aab` job is green:

   ```bash
   gh run list -R AhmedSaied94/madar-sat --workflow app-release.yml --limit 3
   gh run watch <run-id> -R AhmedSaied94/madar-sat
   ```
2. In the run summary, read the line "Upload key SHA256: …". It must equal the fingerprint from step 1. A mismatch means the secrets hold a different key than the one Play knows ([If it fails](#if-it-fails)).
3. Download the artifact:

   ```bash
   gh run download <run-id> -R AhmedSaied94/madar-sat -n app-prod-release.aab -D ~/madar-aab
   ls -l ~/madar-aab/app-prod-release.aab
   ```

   The artifact is kept for GitHub's default retention (90 days). Keep the file you upload next to its tag.

## 4. Enrol in Play App Signing (first release only)

Play App Signing makes Google hold the key that signs what users install, and your upload key only proves the upload is yours. A lost or leaked upload key is then replaced through Play ([secrets.md](secrets.md#rotate-the-android-upload-key)), and users are unaffected. Without it, losing the upload key would mean no more updates.

1. In Play Console, open the app, then **Test and release → App integrity → App signing** (the labels move around; look for "App signing").
2. Choose **Use Google-generated key** (the default for a new app) and accept the terms.
3. When Play asks for the first AAB, give it the one from step 3. It reads the upload certificate from that file. Check that the certificate shown under **App signing → Upload key certificate** has the same SHA-256 as in step 1.

## 5. Upload to the closed track by hand

1. In Play Console, **Test and release → Testing → Closed testing**, create a track (or open the existing one), then **Create new release**.
2. Upload `app-prod-release.aab`. Play shows the version code (the run number) and the version name (the tag).
3. Name the release after the tag (`0.2.0`) and write the release notes in Arabic: what a fan can now do, in one or two lines.
4. **Save, review the release, then start the rollout to the closed track.** Play may take from minutes to a few days to review a release; the first one is the slowest.

## 6. The testers list

1. In the same track, open **Testers** and add the people (an email list, or a Google Group of testers so you can add people without editing the track).
2. Copy the **opt-in link** and send it to them. A tester opens it on the Android phone that has the Google account you listed, accepts, and installs the app from Play.
3. Keep the testers opted in. Google's rule for a new personal account is a closed test with at least 12 testers for 14 continuous days before it will review a production release ([owner-actions.md](../owner-actions.md#calendar-gates) tracks this as a calendar gate), so start the clock with the first release.

## Check

- The track shows your version name and code with the status "Available to testers".
- A tester can install from the opt-in link, and the app opens and shows today's matches from VPS-1 (SC-009).
- `adb shell dumpsys package com.madarsat.app | grep versionCode` on a tester's phone shows the run number of the build you uploaded.

## If it fails

| Symptom | Do |
| --- | --- |
| `tag must look like app-v1.2.3` | Delete the bad tag (`git push --delete origin <tag>`, `git tag -d <tag>`) and push a correct one. |
| `secret for KEYSTORE_BASE64 is empty or missing` (or another name) | One of the four secrets is not set. Set it from the keystore files ([secrets.md](secrets.md#rotate-the-android-upload-key), step 3), then push a **new** tag. |
| `the AAB is not signed with the Madar Sat upload key` | The secrets hold a different keystore (or the debug key was used). Fix the secrets, then push a new tag. |
| Play: "You uploaded an APK or Android App Bundle signed with a different key" | The upload key in the secrets is not the one Play has registered. Compare the SHA-256 with **App signing → Upload key certificate**. If you lost the right keystore, request an upload key reset in Play and rotate the secrets ([secrets.md](secrets.md#rotate-the-android-upload-key)). |
| Play: "Version code 12 has already been used" | You uploaded the same build twice, or re-ran a run. Push a new tag so the run number moves. |
| The run is green but no artifact | `if-no-files-found: error` makes the job fail instead, so look at the `aab` job's log for the `flutter build appbundle` error. |
| A tester sees "App not available" | The tester is not on the list for this track, is on a different Google account than the one listed, or has not accepted the opt-in link yet. Re-send the link and check the account. |
| The app opens but shows no matches | VPS-1 is not serving `/v1`, or the phone is offline: open `https://api.130.110.117.215.sslip.io/healthz` in the phone's browser (it should answer with `"db": "ok"` and `"redis": "ok"`). The PWA preview has its own CORS step ([firebase-hosting.md §4](firebase-hosting.md#4-the-preview-channel)); the Android app does not need it. |
