# FindFix

A small native macOS menu bar app (Swift, SwiftUI) that fixes five everyday
annoyances. macOS 14+, Apple silicon. No Electron, no WebView, no third-party
packages. With every feature on, it idles at 0% CPU: it listens through one
shared event tap and does work only on the clicks and keys it handles.

| Feature | What it does |
| --- | --- |
| Quit on close | The red close button quits the app once its last window is gone. Apps on the exclusion list (default: Finder) behave as usual. |
| Maximize on green button | The green button fills the screen's desktop area (below the menu bar, clear of the Dock) instead of entering a full-screen Space. Click again to restore. ⌥-click keeps the macOS behavior. |
| Delete key in Finder | ⌦ (fn+⌫ on Mac keyboards) moves selected items to the Trash. Text fields (rename, search) keep the key. Optional: delete immediately, after a confirmation. |
| Cut & paste in Finder | ⌘X then ⌘V moves files. Copying something else in between cancels the cut. |
| Rename shortcut in Finder | A shortcut you choose (default ⌃R) starts renaming the selected item. |

Every feature has its own switch, and there is a master switch. Switching one
off restores the stock behavior at once. When no running feature needs events,
the event tap is removed.

## Install

1. Download `FindFix-<version>-arm64.dmg` from
   [Releases](https://github.com/j0di3x/FindFix/releases).
2. Open it and drag **FindFix** into **Applications**.
3. FindFix is not notarized by Apple, so the first launch is blocked. Open
   System Settings › Privacy & Security, scroll down and click **Open Anyway**
   next to FindFix. Or run this once:

   ```bash
   xattr -dr com.apple.quarantine /Applications/FindFix.app
   ```

4. FindFix opens its Settings on first launch. It lives in the menu bar
   (folder icon). While Settings is open it also has a Dock icon. **Done**
   (⌘W) hides the window, and FindFix keeps running in the menu bar.

## Permissions

- **Accessibility**: needed by every feature. FindFix asks for it the first
  time you switch on a feature.
- **Automation → Finder**: needed for Cut & paste and permanent delete (to read
  the Finder selection and move items). FindFix asks for it on first use.
- Input Monitoring is not needed.

If a switch keeps saying "Waiting for Accessibility permission" although
FindFix is on in System Settings, click **Reset** next to Accessibility in
FindFix Settings, then allow it again.

## Build

```bash
xcodebuild -scheme FindFix -configuration Release build
xcodebuild -scheme FindFix test
Scripts/make-dmg.sh            # → dist/FindFix-<version>-arm64.dmg
```

Builds are ad-hoc signed, with the designated requirement pinned to the bundle
ID `io.github.j0di3x.FindFix` (`Config/FindFix.req`), so an Accessibility
grant survives rebuilds and updates. With an Apple Developer ID, sign and
notarize instead, and remove that requirement.

The app icon is a layered Icon Composer file (`FindFix/AppIcon.icon`), so it
renders correctly in the Default, Dark, Clear and Tinted icon styles. The DMG
artwork is drawn by `Scripts/make-dmg-background.swift`.

## Releasing

Push a version tag. The `Release` workflow tests, builds the DMG and attaches
it to a GitHub release:

```bash
git tag v1.0 && git push origin v1.0
```

Bump `MARKETING_VERSION` in the Xcode project before tagging.

## Adding a feature

Write one file in `FindFix/Features/` that conforms to `Feature`
(`FindFix/Core/Feature.swift`), then add it to `FeatureManager.live()`. The
manager takes care of the switch, permissions, start/stop and the shared tap.

## Credits and license

FindFix is a trimmed rewrite of [Vorssaint](https://vorssaint.com)
([source](https://github.com/vorssaint/vorssaint-utils)), © 2026 Vorssaint,
licensed under GPL-3.0. FindFix reuses and adapts code from:

- `WindowMaximizer.swift`, `WindowServerSupport.swift`: green-button hit test and window frame handling
- `AutoQuitService.swift`: close-button detection and quit-after-last-window checks
- `FinderCutPaste.swift`: Finder Apple Event bridge and text-focus check
- `FinderRenameService.swift`: rename shortcut

Files with adapted code say so in their header. Because of this reuse, FindFix
is licensed under the **GNU General Public License v3.0 or later**. See
[LICENSE](LICENSE).

FindFix is an **unofficial** project. It is not affiliated with, endorsed by
or sponsored by Vorssaint. In line with Vorssaint's
[trademark policy](https://github.com/vorssaint/vorssaint-utils/blob/main/TRADEMARKS.md),
it uses its own name, icon, bundle ID and signing, and none of Vorssaint's
branding.

## Legal

- **No warranty.** FindFix is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY, without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GPL for details.
  The permanent-delete option removes files for good; use it at your own risk.
- **Source.** Every release is built from the tagged source in this repository.
  The app shows its license and a link to this source under Settings › About.
- **Trademarks.** Apple, Mac, macOS and Finder are trademarks of Apple Inc.,
  registered in the U.S. and other countries. FindFix is not affiliated with
  Apple. Vorssaint is a name of its respective owner. Names are used only to
  describe compatibility and origin.
- The FindFix icon, mascot and DMG artwork are original works made for this
  project and are covered by the same license as the code.
