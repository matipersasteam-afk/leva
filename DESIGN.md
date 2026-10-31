---
name: LEVA
description: "Official LEVA padel tournament app: every match set as a fight poster, gold on deep navy-black."
colors:
  ink-0: "#06080D"
  ink-1: "#0A0D14"
  ink-2: "#0E1626"
  ink-3: "#132037"
  navy: "#1B2A4A"
  navy-hi: "#24375F"
  gold-700: "#8C6A2E"
  gold-500: "#D4AF5A"
  gold-200: "#F3DC9A"
  gold-line: "rgba(212,175,90,.28)"
  gold-wash: "rgba(212,175,90,.08)"
  tx-1: "#F6F4EF"
  tx-2: "#BAC1CF"
  tx-3: "#97A0B2"
  line: "rgba(255,255,255,.08)"
  line-2: "rgba(255,255,255,.14)"
  live: "#F0484F"
  live-text: "#FF8A8F"
  ok: "#43C08F"
  ok-text: "#7BDDB5"
  pending: "#F09A4A"
  pending-text: "#FFB877"
  danger: "#F0484F"
typography:
  display-mega:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "76px"
    fontWeight: 900
    lineHeight: 0.88
    letterSpacing: "-0.005em"
    fontVariation: "'wdth' 62"
    fontFeature: "italic; uppercase"
  display-xl:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "52px"
    fontWeight: 900
    lineHeight: 0.88
    letterSpacing: "-0.005em"
    fontVariation: "'wdth' 62"
    fontFeature: "italic; uppercase"
  display-l:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "34px"
    fontWeight: 900
    lineHeight: 0.88
    letterSpacing: "-0.005em"
    fontVariation: "'wdth' 62"
    fontFeature: "italic; uppercase"
  display-m:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "24px"
    fontWeight: 900
    lineHeight: 0.88
    letterSpacing: "-0.005em"
    fontVariation: "'wdth' 62"
    fontFeature: "italic; uppercase"
  duel-name:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "30px"
    fontWeight: 900
    lineHeight: 0.9
    fontVariation: "'wdth' 62"
    fontFeature: "italic; uppercase"
  button:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "21px"
    fontWeight: 900
    letterSpacing: "0.01em"
    fontVariation: "'wdth' 62"
    fontFeature: "italic; uppercase"
  button-small:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 900
    letterSpacing: "0.01em"
    fontVariation: "'wdth' 62"
    fontFeature: "italic; uppercase"
  support:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 400
    letterSpacing: "0.3em"
    fontVariation: "'wdth' 125"
    fontFeature: "uppercase"
  support-light:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 300
    letterSpacing: "0.3em"
    fontVariation: "'wdth' 125"
    fontFeature: "uppercase"
  body:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.45
    fontVariation: "'wdth' 100"
  body-small:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.45
    fontVariation: "'wdth' 100"
  label:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 600
    fontVariation: "'wdth' 100"
  tag:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 600
    letterSpacing: "0.06em"
    fontVariation: "'wdth' 100"
    fontFeature: "uppercase"
  tab:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 600
    letterSpacing: "0.08em"
    fontVariation: "'wdth' 100"
    fontFeature: "uppercase"
  score:
    fontFamily: "Archivo, Arial Narrow, system-ui, sans-serif"
    fontSize: "36px"
    fontWeight: 900
    fontVariation: "'wdth' 62"
    fontFeature: "italic; tnum"
rounded:
  xs: "4px"
  sm: "6px"
  md: "10px"
  lg: "16px"
  chamfer: "12px"
  chamfer-sm: "10px"
  full: "9999px"
spacing:
  sp-1: "4px"
  sp-2: "8px"
  sp-3: "12px"
  sp-4: "16px"
  sp-5: "20px"
  sp-6: "24px"
  sp-8: "32px"
  sp-10: "40px"
  sp-12: "48px"
components:
  button-gold:
    textColor: "{colors.ink-1}"
    typography: "{typography.button}"
    rounded: "{rounded.chamfer}"
    height: "56px"
    padding: "0 24px"
    width: "100%"
  button-gold-disabled:
    backgroundColor: "{colors.ink-3}"
    textColor: "{colors.tx-3}"
    rounded: "{rounded.chamfer}"
    height: "56px"
  button-gold-small:
    textColor: "{colors.ink-1}"
    typography: "{typography.button-small}"
    rounded: "{rounded.chamfer}"
    height: "40px"
    padding: "0 16px"
  button-line:
    backgroundColor: "rgba(212,175,90,.04)"
    textColor: "{colors.gold-200}"
    typography: "{typography.button}"
    rounded: "{rounded.sm}"
    height: "56px"
    padding: "0 24px"
  button-line-small-chamfered:
    backgroundColor: "rgba(212,175,90,.04)"
    textColor: "{colors.gold-200}"
    typography: "{typography.button-small}"
    rounded: "{rounded.chamfer-sm}"
    height: "40px"
    padding: "0 16px"
  button-dark:
    backgroundColor: "{colors.ink-3}"
    textColor: "{colors.tx-1}"
    typography: "{typography.button}"
    rounded: "{rounded.sm}"
    height: "56px"
    padding: "0 24px"
  icon-button:
    textColor: "{colors.tx-1}"
    rounded: "{rounded.full}"
    size: "44px"
  chip:
    textColor: "{colors.tx-2}"
    typography: "{typography.label}"
    rounded: "{rounded.sm}"
    height: "36px"
    padding: "0 14px"
  chip-selected:
    backgroundColor: "{colors.gold-500}"
    textColor: "{colors.ink-1}"
    rounded: "{rounded.sm}"
    height: "36px"
    padding: "0 14px"
  tag-live:
    backgroundColor: "rgba(240,72,79,.14)"
    textColor: "{colors.live-text}"
    typography: "{typography.tag}"
    rounded: "{rounded.xs}"
    height: "24px"
    padding: "0 8px"
  tag-ok:
    backgroundColor: "rgba(67,192,143,.13)"
    textColor: "{colors.ok-text}"
    typography: "{typography.tag}"
    rounded: "{rounded.xs}"
    height: "24px"
    padding: "0 8px"
  tag-pending:
    backgroundColor: "rgba(240,154,74,.13)"
    textColor: "{colors.pending-text}"
    typography: "{typography.tag}"
    rounded: "{rounded.xs}"
    height: "24px"
    padding: "0 8px"
  tag-gold:
    backgroundColor: "{colors.gold-wash}"
    textColor: "{colors.gold-200}"
    typography: "{typography.tag}"
    rounded: "{rounded.xs}"
    height: "24px"
    padding: "0 8px"
  tag-mute:
    backgroundColor: "rgba(255,255,255,.06)"
    textColor: "{colors.tx-2}"
    typography: "{typography.tag}"
    rounded: "{rounded.xs}"
    height: "24px"
    padding: "0 8px"
  seg-control:
    backgroundColor: "{colors.ink-2}"
    textColor: "{colors.tx-3}"
    typography: "{typography.label}"
    rounded: "{rounded.sm}"
    padding: "4px"
    height: "48px"
  seg-control-selected:
    textColor: "{colors.ink-1}"
    rounded: "{rounded.xs}"
    height: "40px"
  field:
    backgroundColor: "{colors.ink-2}"
    textColor: "{colors.tx-1}"
    rounded: "{rounded.sm}"
    height: "52px"
    padding: "0 14px"
  panel:
    backgroundColor: "{colors.ink-3}"
    textColor: "{colors.tx-1}"
    rounded: "{rounded.md}"
  tab-bar:
    backgroundColor: "rgba(19,32,55,.92)"
    textColor: "{colors.tx-3}"
    typography: "{typography.tab}"
    rounded: "{rounded.lg}"
    height: "56px"
  tab-bar-active:
    textColor: "{colors.gold-200}"
  point-box:
    backgroundColor: "{colors.ink-1}"
    textColor: "{colors.tx-1}"
    typography: "{typography.score}"
    rounded: "{rounded.sm}"
    height: "56px"
    width: "64px"
  bracket-match:
    backgroundColor: "{colors.ink-2}"
    textColor: "{colors.tx-1}"
    typography: "{typography.body-small}"
    rounded: "{rounded.sm}"
    width: "200px"
  bracket-match-row:
    height: "36px"
    padding: "0 10px"
  gold-slash:
    width: "22px"
    height: "64px"
---

# Design System: LEVA

<!-- Source of truth: prototipo/leva-app.html (:root tokens + component classes). Brand values are APPROXIMATE, pending official values from LEVA; replace in the tokens, not per component. Shield, portrait plates and sponsor slots are labeled placeholders, not brand art. UI copy is Spanish (Mexico). This prototype is the visual reference for the Flutter design system (tokens -> ThemeData / ThemeExtension). -->

## Overview

**Creative North Star: "The Fight Poster"**

Every match is a LEVA fight poster. Pairings are set as poster duels: two condensed black-italic names split by a skewed gold slash, on deep navy-black. The world borrows from LEVA's Instagram flyers (high contrast, gold as protagonist, epic sports tone) and refuses the sports-SaaS default of white cards, green court accents and flat fixture lists.

The same world runs at two densities. Player screens are poster-scaled: huge italic names, generous dark ground, one gold primary action. Admin and judge screens keep the type, palette and gold vocabulary but tighten to working density (36px bracket rows, 13px body, 6px-radius list surfaces). The club TV (1920x1080 stage) is the poster at full scale, with the two signature motions: the "llamado a cancha" slam-in and the gold sweep on match end.

Legibility outranks drama: a court number, a time or a score is never sacrificed to the poster. Numerals are tabular wherever they change; the gold gradient is reserved so that when it appears it means "this is yours, this wins, or press this".

**Key Characteristics:**
- Deep navy-black ground in four ink steps; shield navy for raised surfaces.
- Metallic gold always as a gradient, reserved for names, primary actions, winners and the slash.
- One family (Archivo variable) in three widths: 62% black italic display, 100% body, 125% wide-tracked support caps.
- Chamfered (cut) corners on primary controls; small radii (4-16px) everywhere else.
- Gold hairlines and faint court-line drawings instead of heavy shadow.
- Fast, decisive motion on strong ease-out curves; everything reduces to fades or nothing under reduced motion.

## Colors

A near-black navy ground, one metallic gold carried as a gradient, warm off-white text and three saturated state hues kept to small tags.

### Primary
- **Metallic Gold** (gold-700 / gold-500 / gold-200): always rendered as a gradient. Horizontal gold (`linear-gradient(100deg, #8C6A2E 0%, #B88F42 22%, #D4AF5A 40%, #F3DC9A 52%, #D4AF5A 64%, #A07B36 84%, #8C6A2E 100%)`) fills primary buttons, gold display text (background-clip text, 200% width so it can sweep), the segmented indicator, progress meters and the tab indicator. Vertical gold (`linear-gradient(180deg, #F3DC9A 0%, #D4AF5A 45%, #8C6A2E 100%)`) fills the duel slash, the ticker separators and the active side-link bar.
- **Gold Mid** (gold-500): the only flat gold, used for strokes and small marks: focus/selected borders, radio dot, serve dot, caret, icon tint, qualified-position numerals, bracket "hot" path.
- **Champagne** (gold-200): gold as text where a gradient would be too small: winner names in brackets and scoreboards, active tab, link text, line-button text, gold tag text, focus ring.
- **Gold Hairline** (gold-line) and **Gold Wash** (gold-wash): the border and tint of "mine" and selected states (my match, selected day, selected slot, gold tag).

### Neutral
- **Ink 0** (ink-0): outermost canvas and the TV overlays (court call, match end).
- **Ink 1** (ink-1): screen ground, point-box fill, text on gold.
- **Ink 2** (ink-2): list-item and field surfaces, bottom stop of panels.
- **Ink 3** (ink-3): top stop of panels, dark button, toast, disabled gold button.
- **Shield Navy** (navy) and **Navy High** (navy-hi): avatars, date blocks, schedule blocks, hero washes (next-match card starts at navy), scrollbar thumb.
- **Bone White** (tx-1): primary text. **Steel** (tx-2): secondary text and support lines. **Slate** (tx-3): tertiary text, captions, inactive tabs.
- **Line** (line) and **Line Strong** (line-2): white hairlines at 8% and 14%; dividers, panel and field borders.

### State
- **Live Red** (live; text live-text): live tags with pulsing dot, live bracket and court borders. **Danger** shares the value (schedule conflicts, error alerts).
- **Paid Green** (ok; text ok-text): paid, checked in, accepted.
- **Pending Amber** (pending; text pending-text): pending payment, invite waiting, delay banner.
- State hues appear as 13-14% tinted tag fills with a lighter text tone, or as 1px borders; never as large fills.

### Named Rules
**The Gold Is Earned Rule.** Gold gradient marks only four things: player/pair names given the spotlight, the primary action, winners, and the slash. Everything else is white, steel or slate on ink.

**The Never Flat Yellow Rule.** Any gold area larger than a stroke, dot or text glyph is a gradient. Flat gold-500 is for lines and marks only.

## Typography

**Display Font:** Archivo variable, width 62, weight 900, italic, uppercase (fallback Arial Narrow, system-ui)
**Body Font:** Archivo variable, width 100, weights 400-700
**Support Font:** Archivo variable, width 125, weight 300-400, uppercase, tracking 0.3em

**Character:** one family stretched to its extremes. The compressed black italic is the poster shout; the expanded thin caps are the quiet tracked line beneath or beside it ("BIENVENIDA", "GENTE · PÁDEL · EXPERIENCIAS"); width 100 carries everything that must simply be read.

### Hierarchy
- **Display** (900 italic, width 62, line-height 0.88, tracking -0.005em, uppercase): scale 76 (mega: greeting name, login hero) / 52 (xl: screen titles) / 34 (l: price) / 24 (m: section heads). Poster sizes go beyond the scale per use: 80-84px profile name and event hero, 64px event poster. Display numerals (court, time, countdown, totals) use this face with tabular figures.
- **Duel name** (900 italic, width 62, 30px, line-height 0.9): pair names in the poster duel; the sub-line under it is 12px/500 slate, upright, not uppercase.
- **Button** (900 italic, width 62, 21px, tracking 0.01em; small 16px): all text buttons except auth.
- **Body** (400, 15px, line-height 1.45): default reading text; 13-14px for list meta and secondary lines.
- **Label** (600, 13px): form labels, chips, links, segmented options.
- **Support** (400, width 125, 11px, tracking 0.3em, uppercase, steel): data labels (CANCHA / HORA / FALTAN), section groups, the greeting line; light variant 300 at 13px for brand taglines.
- **Tag / Tab** (600, 11px, tracking 0.06em / 0.08em, uppercase).
- **Score** (900 italic, width 62, 36px in the point box; 52px on TV): tabular figures always.

TV scale (1920x1080): call names 220px, opposing pair 120px, court 200px, winner names 230px, set scores 88px, court-card names 40px, support lines 14-24px at 0.24-0.6em tracking.

### Named Rules
**The Two Extremes Rule.** Display is always width 62 / 900 / italic / uppercase; support is always width 125 / light-regular / wide-tracked caps. Do not use mid widths or upright display.

**The Tabular Numbers Rule.** Every number that changes (scores, times, counts, money, seeds) uses tabular figures.

**The Support Line Labels Data Rule.** The tracked support line names a datum (CANCHA, HORA), groups a list, or carries a brand phrase. It does not get stacked as a decorative eyebrow above section titles.

## Layout

Mobile screens are designed at 390x844 (iPhone frame) with 20px side padding (sp-5) and a 4px spacing base (sp-1..sp-12). Sections open with a 32px top gap (sp-8) and 12px under the head. Full-bleed bands (event hero, profile hero, stats strip, bracket scroller, chip rail) break out with negative margins equal to the side padding. Bottom tab bar is fixed (92px zone with a 56px floating bar); scroll content reserves 120-130px at the bottom; sticky CTA zones fade from transparent to ink-1 over 14px.

Data grids: next-match meta in three equal columns; facts in a 2-column grid with 1px line gutters; scoreboard columns `1fr / 3 x 34px sets / 64px point`; bracket rounds 200px wide with 36px column gap; schedule grid 44px time rail + 4 courts at 66px rows.

TV: fixed 1920x1080 stage scaled to fit; 72px side margins, 132px top bar, 64px tab row, 72px ticker; slides rotate with a gold progress bar per tab.

Breakpoint: the prototype canvas (sidebar + phone) collapses its sidebar into a top rail below 900px; the app screens themselves are single-width mobile.

## Elevation & Depth

Mostly tonal. Depth comes from the ink ladder (ink-1 ground, ink-2/ink-3 panel gradient, navy for raised heroes), 1px white or gold hairlines, and radial navy/gold washes in hero backgrounds, with faint court-line drawings as texture. Shadows are soft, dark and downward, with an inset 1px top highlight; they read as weight, never as glow, except the QR scanline.

### Shadow Vocabulary
- **Resting** (`box-shadow: 0 1px 0 rgba(255,255,255,.04) inset, 0 10px 28px -14px rgba(0,0,0,.7)`): panels.
- **Raised** (`box-shadow: 0 1px 0 rgba(255,255,255,.06) inset, 0 22px 48px -20px rgba(0,0,0,.85)`): next-match card, toast.
- **Slash** (`box-shadow: 6px 10px 18px -8px rgba(0,0,0,.7)`): under the gold slash only.
- **Dragging** (`box-shadow: 0 18px 40px -10px rgba(0,0,0,.9), 0 0 0 1px #D4AF5A`): a schedule block in hand.
- A gold glow token (`0 12px 30px -12px rgba(212,175,90,.55)`) exists in the tokens but is unused; do not reach for it by default.

### Named Rules
**The Hairline Over Shadow Rule.** Separate with a 1px line (8%/14% white, or gold-line for "mine") before adding shadow. Only panels and floating elements carry shadow.

## Shapes

Angular, poster-cut. Primary gold buttons are chamfered: top-right and bottom-left corners cut at 45 degrees by 12px (`polygon(0 0, calc(100% - 12px) 0, 100% 12px, 100% 100%, 12px 100%, 0 calc(100% - 12px))`); paired small secondary buttons use the same cut at 10px. Everything else uses small radii: 4px tags and mini buttons, 6px list items, fields, chips, segmented control and bracket boxes, 10px panels and cards, 16px only for the floating tab bar. Circles are reserved for avatars, icon buttons, radio, switch knob and status dots.

Skew is the second shape motif: the slash is skewed -18 degrees, the tab indicator -30 degrees, TV ticker separators -18 degrees, the court-call band -6 degrees. Icons are 20px stroked line icons (1.75 stroke, round caps).

**The Cut Corner Rule.** The chamfer belongs to the primary action (and its paired small buttons). Containers keep soft radii; do not chamfer panels or list items.

## Components

### Buttons
Heavy, italic and pressed with a quick squeeze.
- **Shape:** gold primary chamfered at 12px; line and dark buttons 6px radius, or 10px chamfer when paired as small buttons.
- **Gold (primary):** horizontal gold gradient at 220% width, background-position 30%; ink-1 text; 56px tall, full width; small 40px. Hover (fine pointers) slides the gradient to 70% over 600ms ease-out, so the metal catches light. Focus: 2px bone-white outline inset by -5px. Disabled: ink-3 fill, slate text, inset 1px line-2.
- **Line (secondary):** champagne text, gold-line 1px border, 4% gold tint.
- **Dark (tertiary):** ink-3 fill, line border, bone-white text.
- **Press:** scale 0.97 over 140ms ease-out on all buttons; icon buttons 0.92. Loading: 20px spinner in ink-1 on gold.
- **Auth buttons** (Apple/Google) follow platform conventions: 54px, 6px radius, 600/15px upright; Apple is bone-white fill with black text, Google is transparent with line-2 border.

### Chips
- **Style:** 36px, 6px radius, line-2 border, steel 13px/500 text; horizontal scroll rail bleeding to screen edges.
- **State:** selected fills gold-500 with ink-1 700 text (see not-canonized note on flat gold). Press scale 0.96.

### Tags / States
- 24px, 4px radius, 11px/600 uppercase at 0.06em. Live (red tint, pulsing 6px dot, 1.6s), Paid/OK (green tint), Pending (amber tint), Gold (gold wash + gold-line border, used for category/round on my match), Mute (6% white).

### Segmented Control
- ink-2 track, line border, 6px radius, 4px inset; options 40px, 13px/600 slate; the selected option sits on a sliding gold-gradient indicator (4px radius) with ink-1 text, moving over 220ms ease-in-out. 2, 3 and 4-option variants.

### Cards / Containers
- **Panel:** vertical gradient ink-3 to ink-2, 1px line border, 10px radius, resting shadow; padding 16-20px.
- **Next-match card:** 160-degree gradient navy to ink-2, gold-line border, raised shadow, court-line drawing at 12% opacity behind; the whole card is the tap target (press scale 0.985).
- **List items** (category, payment method, timeline match, format option): ink-2, line border, 6px radius, 14px 16px padding; selected or "mine" switches to a gold-500 border plus a left-to-right gold tint (12% to 2%) or gold wash.

### Inputs / Fields
- **Style:** 52px, ink-2 fill, line-2 border, 6px radius, 16px input text, gold-500 caret, slate placeholder.
- **Focus:** border shifts to gold-500 over 180ms. Global focus-visible ring is 2px gold-200 with 2px offset.
- **Radio:** 22px ring in line-2, gold-500 dot scales in. **Switch:** 50x30, off 12% white, on gold-500, knob slides 20px over 240ms ease-out.

### Navigation
- **Tab bar:** four tabs (Inicio, Cuadro, Horarios, Perfil) in a floating 56px bar, 16px radius, ink-3 at 92% with 12px backdrop blur, sitting over a fade to ink-1. Inactive slate, active champagne; a 22x3px gold-gradient indicator skewed -30 degrees slides under the active tab over 220ms ease-in-out.
- **App bar:** 44px icon buttons (ghost variant: 5% white + line border), centered support-line title.
- **Screen transitions:** push slides in from the right while the previous screen shifts -28% and dims to 55% brightness (400ms drawer curve); tab switches cross-fade 140ms; fades 200ms.

### Gold Slash Duel (signature)
Three-column grid (`1fr auto 1fr`, 8px gap): left pair name, skewed gold slash (22x64px, vertical gold, -18 degrees, 1px radius, slash shadow), right pair name right-aligned. Names in duel-name type; the winning side turns champagne. Under the duel, a three-column meta row (Cancha / Hora / Faltan) of support labels over 30px display numerals, the court number in gold. The same slash separates pairs in TV "Siguientes" rows (16px wide) and the ticker.

### Scoreboard and Point Box
Rows `1fr / 34px x3 / 64px`: name in 21px display with an 8px gold serve dot that fades in for the serving pair; set scores 20px/700 tabular in slate, current set bone-white, won sets champagne. The point box is a 56px ink-1 well with line border and 6px radius holding a 36px display numeral; new values slide up from 55% with a 2px blur over 220ms. A gold-gradient "PUNTO DE ORO" badge appears at the top of the board on golden point. TV court cards scale this to 76px boxes and 52px numerals.

### Bracket Match
200px box, ink-2, line border, 6px radius: a caption strip (11px uppercase slate on 18% black, live marker in red with pulsing dot) over two 36px rows (name 13px/500, tabular scores). Winner row champagne 700, loser slate, TBD italic slate. Borders: live red at 50%, mine gold-line. Connector paths 1.2px line-2, the advancing path gold-500. On TV rows grow to 64px with 34px display names. When a result lands, the winner name reveals left-to-right (900ms ease-out) and a champagne sweep crosses the box (1100ms ease-in-out).

### TV Court Call ("Llamado a cancha")
Full-bleed ink-0 overlay with a navy band skewed -6 degrees. Sequence: wide support label tightens from 1.2em to 0.6em tracking (700ms); called pair slams in from the left (clip reveal + 80px slide + -8 degree skew, 650ms ease-out) in 220px gold display, then a gold sweep (1600ms ease-in-out); "VS" fades; opposing pair slams in from the right at 120px steel; a gold arrow draws (600ms ease-in-out) toward "CANCHA N" at 200px, which scales in and sweeps. Holds 7s, fades out 260ms.

### TV Match End
ink-0 overlay with a gold radial wash: champagne support label, winner names at 230px gold that de-blur and scale in (700ms ease-out) then sheen across (2.4s ease-in-out), set scores at 88px rising in sequence (420ms, 80ms stagger), next-match line, gold confetti on canvas. Holds 6.5s, fades 280ms, then the bracket reveal plays.

### Motion
Curves: ease-out `cubic-bezier(.23,1,.32,1)` for entrances and presses; ease-in-out `cubic-bezier(.77,0,.175,1)` for indicators, sweeps and swaps; drawer `cubic-bezier(.32,.72,0,1)` for screen pushes and notifications. Durations: press 140ms, fast 180ms (colour/border), base 240ms (fades, switch), screen 400ms, hero 700ms; gold sweeps 1.4-2.4s. Reduced motion: all CSS animation and transition durations collapse to 1ms with one iteration; the ticker and live pulses stop; scripted entrances, sweeps, slam-ins and confetti are skipped; screen changes become plain fades; overlays still appear and dismiss.

## Do's and Don'ts

### Do:
- **Do** render every gold area as the gold gradient; keep flat gold-500 to strokes, dots and borders.
- **Do** set pair names, titles and key numerals in Archivo width 62 / 900 / italic / uppercase, and support lines in width 125 wide-tracked caps.
- **Do** separate pairs with the skewed gold slash wherever a match is presented as a pairing.
- **Do** chamfer the primary gold action (12px cut) and keep containers at 4-10px radii.
- **Do** use tabular figures for all scores, times, counts and money.
- **Do** mark "mine" and selected with gold-500 or gold-line borders plus gold wash, and live with the red tag and pulsing dot.
- **Do** keep every motion on the three named curves and provide the reduced-motion fallback.
- **Do** change brand values only in the tokens; they are approximate until LEVA supplies official values.

### Don't:
- **Don't** use flat yellow or a single flat gold fill for buttons, indicators or display text.
- **Don't** use white cards, green "court" accents or flat fixture lists.
- **Don't** spend the gold gradient on secondary actions, decoration or body text.
- **Don't** use upright or mid-width display type.
- **Don't** stack tracked support lines as eyebrows above section titles.
- **Don't** set text below 11px.
- **Don't** treat the placeholder shield, typographic portrait plates or "Logo sponsor" slots as brand art.
