# Farcast identity

The official app name is **Farcast**. Window/sidebar titles, alerts, permission text,
macOS app menus, Xcode project/target/source folder and the built `Farcast.app` use
that spelling. The Swift module is `Farcast`, the core package/product is
`farcast-core` (Swift target `FarcastCore`), and the embedded executable is
`FarcastWireGuard`. Package identifiers use lowercase:
`com.peterpo.farcast`, `com.peterpo.farcast.credentials`,
`com.peterpo.farcast.wireguard` and Go module `com.peterpo.farcast/wireguard`.
Scripts resolve the outer repository root from their own paths, so its folder
and Git repository can be renamed independently.

The new identity uses a separate macOS sandbox and credential namespace. Previous
data stays untouched. **File → Import Existing Library…** explicitly imports a
user-selected prior library into an empty Farcast library, preserving profile,
folder and WireGuard IDs and metadata. Copying local credentials requires opt-in;
Keychain items are never exported/copied. Existing Keychain credentials must be
entered again, and app-specific folder grants need reselection. Historical identity
strings exist only in migration input recognition and regression fixtures.
See [the migration workflow](user-guide.md#move-an-existing-library-to-farcast).

After renaming the outer checkout, follow the cache relocation instructions in [development](development.md), then run `scripts/build.sh` to rebuild. Compiler caches and native install prefixes retain absolute checkout paths. Keep `.local-testing` intact. The already packaged app is self-contained and keeps working after a folder move.

## Icon direction

An original connected-node emblem represents several remote endpoints gathered in one workspace. It uses a restrained blue background, a clear central silhouette and independently layered foreground shapes. No Apple logo, hardware illustration or copied artwork is used.

The editable app icon is a native Icon Composer document. macOS supplies the icon's outline, depth, lighting and appearance variants instead of baking a fake system mask or reflection into a single bitmap. Design references: [Apple app icon guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons/) and [Icon Composer workflow](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).

Run scripts/update-icon-artwork.sh to regenerate the original layers and sidebar glyph using scripts/generate-icon.swift; run scripts/export-icon.sh for previews. Icon Composer remains the editable source of truth for materials and layering. Generated preview images are stored under .build and are not app runtime assets.

README retains the supplied screenshots in `docs/images`. Their contents show the
previous name until updated; README explains that history. Filenames and references
use Farcast. Its 512×512 icon PNG is rendered from the Default macOS appearance of
`Farcast/AppIcon.icon`. Regenerate
`docs/images/Farcast-Icon.png` with `scripts/export-icon.sh --readme` after
editing the icon. The README displays it at 128×128; the Icon Composer document
remains the source of truth.
