# Damage toggle artwork

`damage-axes-reference.png` is the high-resolution transparent design reference
created with the built-in image-generation tool from the user's selected crossed
double-headed axe reference. The live UI uses native paths in
`src/dpsmeter/MeterModeButton.hx`: broad crescent blades described by cubic curves,
mirrored around the center, with only the handles crossing. It uses the existing
4x `h2d.filter.Nothing` smoothing technique from Item Utilities and BMS.
The PNG is a design reference, not an additional runtime asset/dependency.

Generation prompt: Restyle the supplied crossed double-headed battle axes in
warm cream with dark brown outlines and tan handles. Preserve the large curved
crescent blades, convex cutting edges, deep concave inner curves, and clear gap
between the heads; only the handles cross. Make a smooth, anti-aliased, flat game
UI icon legible at 28 pixels, isolated on transparency, without text or a button
background. Use the current button screenshot only as a palette reference.

Native paths omit the generated image's fine highlights to retain legibility at
the button's actual size. Curve geometry is rebuilt only when the mode changes.
