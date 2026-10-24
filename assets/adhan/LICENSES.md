# Adhan audio — sources and licenses

Every file below is bundled inside the app. Playback is entirely offline; the
app never downloads audio at runtime.

All files were re-encoded to mono MP3 (40 kbps, 44.1 kHz) and loudness-normalised
with ffmpeg. That is the only modification. No audio was generated, synthesised
or invented.

| App sound | File | Title | Reciter / uploader | Source | License | Attribution |
| --- | --- | --- | --- | --- | --- | --- |
| `adhan_aishatu` | `adhan_aishatu.mp3` | Adhan | Aishatu98 | https://commons.wikimedia.org/wiki/File:Adhan.ogg | CC0 1.0 | "Adhan" by Aishatu98, Wikimedia Commons, CC0 1.0 |
| `adhan_beautiful` | `adhan_beautiful.mp3` | Beautiful adhan | Adam-synagda | https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg | CC0 1.0 | "Beautiful adhan" by Adam-synagda, Wikimedia Commons, CC0 1.0 |
| `adhan_madeenah` | `adhan_madeenah.mp3` | Oración Al-Azzan | B9. | https://commons.wikimedia.org/wiki/File:Oraci%C3%B3n_Al-Azzan.ogg | Public domain | "Oración Al-Azzan" by B9., Wikimedia Commons, public domain |
| `adhan_ejaz215` | `adhan_ejaz215.mp3` | Call to prayer from the Prophet's Mosque | ejaz215 | https://commons.wikimedia.org/wiki/File:33937_ejaz215_call-to-prayer-from-the-prophet-s-mo.ogg (original: https://freesound.org/people/ejaz215/sounds/33937/) | CC BY 3.0 | "Call to prayer from the prophet mosque" by ejaz215, Freesound, via Wikimedia Commons, CC BY 3.0 — compressed and loudness-normalised |
| `adhan_fouad_fajr` | `adhan_fouad_fajr.mp3` | Adhan Fouad Adan (Fajr) | Fouad Adan | https://archive.org/details/AdanAlfajrFouadAdan | Public Domain Mark 1.0 | "Adhan Fouad Adan" by Fouad Adan, Internet Archive, Public Domain Mark 1.0 — compressed and loudness-normalised |
| `adhan_egyptian_cairo` | `adhan_egyptian_cairo.mp3` | Morning Call to Prayer in Cairo | musesdelight (uploader) | https://www.masmaa.org/en/audio/morning-call-to-prayer-in-cairo | CC0 1.0 | "Morning Call to Prayer in Cairo" — Masmaa sound archive (masmaa.org), CC0 1.0 — compressed and loudness-normalised |

The CC0 and public-domain recordings need no visible attribution.  Only the
CC BY recording is repeated on the in-app **About / Licenses** screen, which is
linked from the bottom of the adhan settings.

## User-added Egyptian recordings

The app looks for `assets/adhan/egyptian_*.mp3` at start and adds every match
to the voice picker as «أذان مصري».  A user-added file is played from the app
assets by the full-screen player; its notification is silent.  To use it as a
notification sound too, place a copy with the same name in
`android/app/src/main/res/raw`.

## License texts

- **CC0 1.0** — https://creativecommons.org/publicdomain/zero/1.0/
- **CC BY 3.0** — https://creativecommons.org/licenses/by/3.0/
- **Public Domain Mark 1.0** — https://creativecommons.org/publicdomain/mark/1.0/

## Files considered but not included

- `Call to prayer by Sabah Fakhry.mp3` (Wikimedia Commons) — marked public
  domain on Commons, but the uploader's credit points to a 1985 YouTube
  recording of a named artist, so the underlying rights are unclear. Skipped.
- CC BY-SA recordings on Commons and Internet Archive items without an explicit
  license — the project only accepts public domain, CC0 or CC BY.
