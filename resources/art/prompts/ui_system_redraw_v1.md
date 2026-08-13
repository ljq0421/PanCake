# UI System Redraw v1 ImageGen Record

Generated with the built-in ImageGen tool on 2026-08-12. The formal 1920x1080 workstation capture was used only as a style and palette reference. Existing untracked teal UI drafts were not used as references and were not modified.

## Shared direction

- Warm hand-drawn Chinese breakfast-stall management-game UI.
- Subtle watercolor and rice-paper grain, restrained deep-brown linework, clean silhouettes and minimal ornament.
- Walnut `#59351F` / `#835332` and rice paper `#F1DDB0` / `#FFF0CC` carry most of the visual area.
- Terracotta `#C8792F` marks active, selected and filled states.
- Muted gray-blue `#59686A` / `#748180` is limited to secondary tracks, off and locked states.
- No teal, turquoise, green lacquer, neon saturation, glossy plastic, chrome, ornate corner hardware or heavy dark panel fill.
- Every source contains exactly one front-facing, textless UI asset on a flat `#FF00FF` chroma-key background.
- No text, letters, numbers, icons, logos, watermarks, perspective, floor plane or cast shadow.

## Asset prompts

### `panel_dialog_walnut_ricepaper.png`

Revised again on 2026-08-12 to use a slim continuous walnut frame at roughly 55-60% of the previous visible thickness and a more legible handmade rice-paper watercolor surface. The paper shows clearer fibers, softly pooled pale-ochre washes, gentle irregular tonal variation and faint dry-brush clouding while remaining light enough for dark text. No segmented bamboo-like frame, bindings, seams, glossy bevel, gray-blue or metal decoration. Continuous border suitable for nine-patch stretching.

### `panel_content_lightwood_ricepaper.png`

Revised on 2026-08-12 using the rice-paper card and walnut button as shared style references. Large clean pale rice-paper content surface surrounded by a thinner matte light honey-wood frame and restrained dark-brown hand-painted outline. Softer and lighter than the dialog panel, but using the same flat watercolor grain and line language. No shiny gold, plastic-like highlight, heavy bevel, gray-blue or metal decoration. Continuous border suitable for nine-patch stretching.

### `button_normal_walnut.png`

Wide low rounded walnut plaque with a clean medium-walnut label area, slightly darker slim border and restrained paper-brush texture. No inset black void, gray-blue or metal.

### `button_active_terracotta.png`

Wide low active-state plaque with a restrained terracotta center, slim walnut border and thin pale rice-paper inner highlight. Clearly selected without neon saturation.

### `button_disabled_graybrown.png`

Wide low disabled-state plaque with a desaturated warm gray-brown center and walnut-gray slim border. Low contrast and visibly inactive, without a cool blue cast.

### `card_normal_ricepaper.png`

Simple landscape choice card with a bright rice-paper center occupying at least 84%, thin light-walnut border, gently rounded corners and faint handmade paper grain.

### `card_selected_terracotta.png`

Simple landscape selected card with a bright rice-paper center occupying at least 82%, slim walnut frame, one restrained terracotta selected rim and one thin pale inner highlight. No protrusions or ornament.

### `card_locked_grayblue.png`

Simple landscape locked card with a plain warm desaturated rice-paper center occupying at least 84%, one thin walnut-gray outer border and one muted gray-blue inner border. Gray-blue wash remains close to the edge and below 15% of the area. No lock icon or motifs.

### `linear_track_grayblue.png`

One long thin rounded muted gray-blue control trough with a slim warm-walnut outline. Hollow center, no fill and no knob; suitable for slider and progress-bar use.

### `linear_fill_terracotta.png`

One solid long thin rounded terracotta fill bar with a subtle dark-walnut outline and minimal watercolor texture. No hollow center, knob or secondary part.

### `slider_grabber_lightwood.png`

Revised on 2026-08-12 as one strict geometric circle with equal visible width and height. Flat light honey-wood watercolor fill, subtle handmade paper grain and one clean slim walnut outline matching the content panel. No realistic plank grain, glossy highlight, bevel, icon, hole or metal.

### `switch_off_grayblue.png`

Revised on 2026-08-12 as a compact 2:1 horizontal pill toggle: muted gray-blue watercolor track, thin walnut-gray outline and one strict geometric rice-paper circle on the left. The track geometry, outline width, knob diameter and edge clearance are shared exactly with the on state. No oval knob, perspective, gloss or bevel.

### `switch_on_terracotta.png`

Revised on 2026-08-12 as a compact 2:1 horizontal pill toggle: restrained terracotta watercolor track, thin walnut outline and one strict geometric rice-paper circle on the right. The track geometry, outline width, knob diameter and edge clearance are shared exactly with the off state. No oval knob, perspective, gloss or bevel.

## Interaction and navigation expansion

Added on 2026-08-12 after auditing the project scenes for actual control families. The expansion covers button interaction states, choice-card hover, keyboard focus, tooltip presentation and horizontal/vertical scrolling. Input-field, dropdown and tab assets were intentionally not generated because those controls were not found in the current `.tscn` node inventory.

### `button_hover_walnut.png`

Walnut button hover state matching the normal silhouette, slightly lighter and warmer with one thin rice-paper inner highlight. It remains clearly walnut and weaker than the terracotta active state.

### `button_pressed_walnut.png`

Walnut button pressed state matching the normal silhouette, with a slightly darker center and restrained inset edge. No perspective or cast shadow.

### `card_hover_ricepaper.png`

Plain rice-paper choice-card hover state with one slim warm-walnut outline and an extremely subtle pale-terracotta inner line. Weaker than the selected card and free of corner marks or other ornament.

### `focus_ring_terracotta.png`

Empty rounded rectangular keyboard-focus outline built from the selected-card terracotta watercolor texture. Fully transparent center, slim ring and no glow cloud.

### `tooltip_panel_ricepaper.png`

Compact warm rice-paper tooltip with a thin walnut outline and a small centered downward paper tail. Light enough for dark text and free of dark or gray-blue panel fill.

### Scrollbar family

- `scroll_track_horizontal_grayblue.png`: thin muted gray-blue horizontal track with a warm walnut-gray outline.
- `scroll_thumb_horizontal_lightwood.png`: compact matte lightwood horizontal thumb with a slim walnut outline.
- `scroll_track_vertical_grayblue.png`: exact 90-degree counterpart of the horizontal track.
- `scroll_thumb_vertical_lightwood.png`: exact 90-degree counterpart of the horizontal thumb.

### `divider_horizontal_lightwood.png`

Long quiet light-honey-wood watercolor divider with a restrained walnut center line, intended for separating settings rows without adding decorative clutter.

## Processing

Sources were generated through the built-in ImageGen path, copied into `tmp/imagegen/ui_system_redraw_v1/sources/`, and converted to RGBA with the installed `remove_chroma_key.py` helper using `--auto-key --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`. Final project assets were cropped to their alpha bounds, padded, resized to their delivery dimensions and validated independently from any runtime integration.

The five consistency revisions were generated through the same built-in ImageGen and chroma-key workflow. Their final preparation uses alpha-bound cropping plus aspect-preserving placement. The slider grabber and switch knobs receive deterministic circular masks; the two switch states share one 512x256 capsule geometry. Preview generation is read-only and no longer normalizes or rewrites project assets.

## Semantic control expansion

Added on 2026-08-12 after a second inventory pass over the current `.tscn` controls and workstation state code. The project currently contains four `HSlider` nodes, eight `ProgressBar` nodes, two `CheckButton` nodes and several in-scene status labels. The existing patience bars still use a dark teal system-style background with green fill, while their runtime code updates values without replacing fill styles. This expansion therefore adds only slider interaction states, warm semantic progress states and one reusable lightweight status background. A larger toast/notification family was intentionally omitted because no standalone notification component was found.

### `slider_grabber_hover_lightwood.png`

Strict circular light-honey-wood slider grabber matching `slider_grabber_lightwood.png`, with the same watercolor paper grain and slim walnut outline plus one restrained thin terracotta inner ring. No glow, glossy highlight, metal or icon. Final alpha geometry is masked to an exact circle.

### `slider_grabber_disabled_graybrown.png`

Strict circular disabled slider grabber in warm desaturated gray-brown, with low-contrast watercolor grain and one slim walnut-gray outline. No cool blue cast, gloss, bevel or icon. Final alpha geometry is masked to an exact circle.

### `linear_track_disabled_graybrown.png`

Long thin hollow disabled slider track in warm gray-brown, with a restrained walnut-gray edge and quiet watercolor grain. The generated texture is deterministically recolored to remove unintended red edging while retaining handmade variation.

### `progress_track_grayblue.png`

Solid low-contrast gray-blue capsule background for patience and progress bars. Gray-blue remains secondary and occupies only the narrow control area. The source watercolor texture is sampled from its neutral midsection and recolored into `#59686A` / `#748180` so the final capsule has no pale end blocks or teal cast.

### `progress_fill_warning_amber.png`

Solid toasted honey-amber watercolor fill for reminder / low-patience state. It is warmer and more legible than the gray-blue track, but less urgent than the brick-red danger state and avoids neon yellow.

### `progress_fill_danger_brickred.png`

Solid muted brick-clay red watercolor fill for nearly depleted / danger state. It remains low saturation and materially consistent with the terracotta normal fill rather than reading as glossy system red.

Normal progress continues to reuse `linear_fill_terracotta.png`; no duplicate normal-state asset was created.

### `status_panel_ricepaper.png`

Wide shallow nine-patch status-message background with a bright rice-paper center, visible but quiet watercolor fibers, one slim lightwood rim and restrained walnut outline. It is lighter than a dialog, has no tail, icon slot or decorative corners, and is intended for short workstation feedback rather than a new notification system.

## Semantic-control processing

Each source was generated independently on flat `#FF00FF`, converted to RGBA using the same chroma-key helper and then placed on fixed delivery canvases without non-proportional scaling of circular controls. Both new slider grabbers use deterministic antialiased circle masks. Progress assets use shared 1024×96 capsule geometry, the disabled track uses 1024×128 hollow-track geometry, and the status panel uses a 1024×256 rounded nine-patch canvas. The final contact and usage previews read only the finished assets.

## Destructive actions, disabled switches and small status badges

Added on 2026-08-12 after checking the remaining visible control roles. The current scenes contain destructive or high-cost actions such as discarding a pancake, refusing an order, skipping a tutorial, ending business and quitting, but the asset set previously had no destructive button family. A disabled checked `CheckButton` also exists, so the switch family needed disabled-off and disabled-on variants. Three small status badges were added for compact state labels without creating a new toast system.

### Destructive button family

- `button_danger_normal_brickred.png`: low-saturation brick-clay action surface with a slim walnut outline and restrained rice-paper inner edge.
- `button_danger_hover_brickred.png`: same geometry, slightly lighter and warmer, with a thin warm inner highlight.
- `button_danger_pressed_brickred.png`: same geometry, darker oxblood-brick watercolor and restrained inset edge.

The generated sources were deliberately recolored into a muted brick range during finishing because the initial normal source was too close to bright system-alert red. The family remains visually distinct from the terracotta confirmation button without using neon saturation.

### Disabled switch family

- `switch_disabled_off_graybrown.png`: warm gray-brown capsule with a gray-beige strict circular knob on the left.
- `switch_disabled_on_graybrown.png`: desaturated terracotta-gray capsule with the same strict circular knob on the right.

Both states reuse the exact 512×256 outer capsule, 190-pixel knob diameter, outline width and edge clearance of the previously revised switch family. Generated proportions are not used directly; only their watercolor materials are sampled.

### Small status badges

- `badge_tutorial_amber_ricepaper.png`: bright rice-paper center with a narrow toasted-amber rim for tutorial, new and unlimited-time states.
- `badge_locked_grayblue_ricepaper.png`: warm rice-paper center with a narrow muted gray-blue rim for locked or secondary states.
- `badge_caution_terracotta_ricepaper.png`: bright rice-paper center with a narrow terracotta rim for attention states that are not destructive actions.

All three badges share a 768×256 nine-patch geometry, identical border widths and a paper-dominant center. The tutorial source developed transparent sampling holes during chroma-key removal; finishing composites the generated watercolor over opaque rice paper before applying the final badge mask, preventing interior alpha gaps.
