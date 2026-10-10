# Universal Remote identity

The official displayed app name is **Universal Remote**. Window/sidebar titles, alerts, permission text, macOS app menus and the built `Universal Remote.app` use that spelling. Internal project/target and module names remain `UniversalRemote`; the module name is explicit so adding a space to the product name does not change SwiftData's model identity. Bundle identifiers, Keychain services and storage paths also remain stable, preserving existing profiles and credentials. The outer repository checkout can be renamed independently; scripts resolve the repository root from their own paths.

The bundle identifier is `com.peterpo.UniversalRemote` and the Keychain service is `com.peterpo.UniversalRemote.credentials`. The rebrand uses a new macOS app container and credential namespace. Pre-rebrand data is left untouched; saved connections can be reimported from the protected local file, and credentials must be saved in the new namespace. There is no automatic Keychain export or hidden migration of secrets.

After renaming the outer checkout, follow the cache relocation instructions in [development](development.md), then run `scripts/build.sh` to rebuild. Compiler caches and native install prefixes retain absolute checkout paths. Keep `.local-testing` intact. The already packaged app is self-contained and keeps working after a folder move.

## Icon direction

An original connected-node emblem represents several remote endpoints gathered in one workspace. It uses a restrained blue background, a clear central silhouette and independently layered foreground shapes. No Apple logo, hardware illustration or copied artwork is used.

The editable app icon is a native Icon Composer document. macOS supplies the icon's outline, depth, lighting and appearance variants instead of baking a fake system mask or reflection into a single bitmap. Design references: [Apple app icon guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons/) and [Icon Composer workflow](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).

Run scripts/update-icon-artwork.sh to regenerate the original layers and sidebar glyph using scripts/generate-icon.swift; run scripts/export-icon.sh for previews. Icon Composer remains the editable source of truth for materials and layering. Generated preview images are stored under .build and are not app runtime assets.

README uses the screenshots supplied in `docs/images` and a 512×512 PNG rendered
from the Default macOS appearance of `UniversalRemote/AppIcon.icon`. Regenerate
`docs/images/UniversalRemote-Icon.png` with `scripts/export-icon.sh --readme` after
editing the icon. The README displays it at 128×128; the Icon Composer document
remains the source of truth.
