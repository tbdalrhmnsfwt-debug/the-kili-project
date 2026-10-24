# Salat phrase audio — sources and licences

Search date: 2026-10-24.

## Result

No recording of any of the three requested Arabic phrases was found with a
verifiable public-domain, CC0, or CC-BY licence:

1. `صلِّ على محمد`
2. `صلِّ على سيدنا محمد`
3. `اللهم صلِّ وسلِّم وزد وبارك على سيدنا محمد`

The app therefore ships **no third-party phrase recording**. The three phrases
work as notification text, with the app-generated chime, or silently. A voice
becomes available only if the user adds their own file under
`assets/salat/<phrase_id>_*.mp3`.

## Candidates checked and rejected

| Source | Candidate | Why it was not used |
|---|---|---|
| Wikimedia Commons | `File:Muhammad Peace be Upon Him-ar.wav` | Public domain, but it is a short pronunciation of the Prophet's name with “peace be upon him”, not one of the three requested phrases. |
| Wikimedia Commons | `File:LL-Q36213 (mad)-Anis Ainun-salawat.wav` | CC0, but it is a 1.1-second Madurese pronunciation of the word “salawat”, not the Arabic phrase. |
| Wikimedia Commons | `File:BA-Салауат.ogg` | CC BY-SA 3.0, outside the allowed licences, and a Bashkir word rather than the requested Arabic phrase. |
| Internet Archive | `1.Salawat-Sh.Suhail` | CC0, but a roughly 20-minute recording rather than a short phrase. |
| Internet Archive | `SalawatGusDur` | CC0, but a roughly 11.6-minute recording rather than a short phrase. |
| Internet Archive | `dalailalkhayrat_montreal` | Public Domain Mark, but long recitation material rather than a short phrase. |
| Internet Archive | `salawat-menshawy` | No clear licence, and it appears to be a re-upload; not safe to bundle. |
| Freesound | search results | No matching Arabic phrase with a clearly usable licence and downloadable file was found. |

Rejected candidates were not copied into the app.

## Chime

`assets/salat/chime.mp3` (2.6 seconds, mono, 48 kbps, about 16 KB) was
generated for this app with FFmpeg from synthesised sine tones. It contains no
third-party recording and needs no attribution. The same file is included as
`android/app/src/main/res/raw/salat_chime.mp3` so Android notification
channels can use it as a notification sound.

## User-added phrase audio

The app auto-detects files named:

```text
assets/salat/asal_ala_muhammad_*.mp3
assets/salat/asal_ala_sayyidina_muhammad_*.mp3
assets/salat/allahumma_salli_*.mp3
```

The first matching file for each phrase is previewed in the app. Only a raw
Android resource can be used directly as a notification-channel sound; a file
that exists only in the Flutter asset bundle is silent in the notification and
can be played from the app. The app shows the phrase as text in that case.

The user is responsible for the rights to any file they add.
