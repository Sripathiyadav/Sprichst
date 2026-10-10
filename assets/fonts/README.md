# Fonts

Sprichst ships its own fonts so that no visitor's IP address is sent to a font
CDN (Google Fonts, `fonts.gstatic.com`) just to render text.

| Family | Files | Licence | Source |
| --- | --- | --- | --- |
| Figtree | `figtree/Figtree-*.ttf` | SIL Open Font License 1.1 (`figtree/OFL.txt`) | https://github.com/erikdkennedy/figtree. The one family of the design system |
| Roboto | `roboto/Roboto-*.ttf` | Apache License 2.0 (`roboto/LICENSE.txt`) | Bundled with the Flutter SDK (`bin/cache/artifacts/material_fonts`); original by Christian Robertson, https://github.com/googlefonts/roboto |

Flutter's web engine downloads Roboto from `fonts.gstatic.com` when the app does
not provide a font called "Roboto". Declaring it in `pubspec.yaml` stops that.
The glyphs cover Latin (including ä ö ü ß), Greek and Cyrillic.
