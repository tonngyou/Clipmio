# Clipmio visual identity

The reference supplied by the owner is ClipLite's logo. It informed the calm, minimal mood; the final Clipmio artwork uses layered sheets, a curled corner and a custom M-shaped ribbon clasp to establish a different form.

Created on 2026-10-22 with the built-in imagegen tool, in transparent-background mode. The generated PNG is preserved unchanged at `Sources/Clipmio/Resources/ClipmioLogo.png` and `Assets/Clipmio-logo.png`. `scripts/make-icon.sh` only resizes it to standard macOS icon sizes and packages `Assets/Clipmio.icns`; it does not recreate the reference design. Keep the two original PNG copies in sync when replacing the artwork. The menu-bar template is a simplified native drawing in `ClipmioBrand.swift` for small-size legibility.

## Generation prompt

```text
Use case: logo-brand.
Asset type: original Clipmio macOS clipboard utility logo, a single transparent isolated mark.
Reference image role: stylistic mood reference ONLY. This reference is the existing ClipLite logo; do not reproduce its silhouette, proportions, solid rectangular top tab or tilted blank gray board.
Primary request: create a new distinctive, extremely simple and memorable Clipmio mark with soft precision and a few broad geometric forms. A pair of slightly offset rounded paper sheets creates a compact layered clipboard. The rear sheet is pale periwinkle; the front sheet is warm white with a small elegant folded lower-right corner. The original signature is a thick indigo folded ribbon clasp at the top with a clear shallow M-shaped notch, subtly evoking the M of Clipmio. The clasp must read as a custom folded M ribbon, NOT a solid plain rectangular pill. One broad indigo accent, delicate lavender depth. Upright front-facing composition, near square overall proportion rather than a long tilted gray board. No lines of text on the sheet.
Style: refined minimal macOS productivity icon, vector-friendly geometry, softly rounded edges, restrained shallow dimensionality and gentle ambient shadow, no toy-like excessive 3D. Recognizable at 32px.
Composition: one mark centered, approximately 78% of square canvas with generous equal transparent padding. NO enclosing app icon square; NO background of any color. Real transparent background with preserved alpha.
Colors: indigo-purple, pale lavender, warm white. No typography, letters rendered as text, wordmark, watermark, extra decorations, badge, multiple options or presentation mockup. Distinguish confidently from reference while retaining its calm minimal feel.
```
