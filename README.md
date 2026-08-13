# Rune

Mini SnowBoard-style icon themer for iOS.

**Package ID:** `com.krasei.rune`  
**Author:** krasei  (or krisbutiamanosdev/susiefromdeltarune/noelledev)
**iOS Support:** 15.0+

---

## Features

- Theme app icons by placing `<bundleid>.png` into the icons directory
- Works on the Home Screen and SpringBoard icon cache
- Lightweight — hooks `SBIconImageView` and `SBHIconImageCache` only
- Per-app toggle via Settings

---

## Installation

1. Install the `.deb` from [Releases](#) or build from source.
2. Place themed icon PNGs in:
   ```
   /var/jb/Library/rune/Icons/<bundleid>.png
   ```
   Example:
   ```
   /var/jb/Library/rune/Icons/com.apple.MobileSMS.png
   /var/jb/Library/rune/Icons/com.hammerandchisel.discord.png
   ```
3. Open **Settings → Rune** and enable **Enable Icon Theme**.
4. Respring.

---

## Building from Source

```bash
make package
```

The output `.deb` will be in the `packages/` folder.

---

## Credits

Inspired by [SnowBoard](https://github.com/SnowBoardTeam/).

---

## License

MIT
