# UI interaction guidelines

Use Apple's [button guidance](https://developer.apple.com/design/human-interface-guidelines/buttons)
and [accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility).
The app remains native macOS; custom controls use a 44×44-point minimum hit region
to make current pointer use easier and prepare for a possible touch interface.
This is a design baseline, not a claim of touchscreen or iPad support.

- Put sizing and `contentShape` inside a button's label/style so padding is clickable.
  Keep neighboring actions in separate, nonoverlapping hit regions.
  A 44-point target need not have a 44-point visible background: shared secondary
  actions use 34-point backgrounds, icon actions use 36-point backgrounds with
  20-point symbols, and transparent margins fill the target. Preserve semantic
  label text; avoid hidden measuring labels, forced shrinking or negative padding.
- Reuse ComfortableButtonStyle, IconActionButton and PrimaryActionButton for custom controls. Keep native
  menus, pickers, text inputs, alerts and primary glass buttons; use large control
  size and readable semantic fonts. Avoid tiny fixed-size text for protocol/status labels.
- Keep close buttons visible, independent of tab selection, with the session name
  in their accessibility label. Tab accessibility also announces protocol and state;
  status never relies on a colored dot alone. Keep tab capsules at 44 points high,
  without outer vertical padding, and keep their close targets full height.
- Disclosure headers activate across their full row and announce expanded/collapsed.
  The connection editor's grouped Form is its only scrolling owner; header/actions
  stay outside it. Keep server address/port as labelled fields with placeholders;
  do not add explanatory description rows below them.
- Preserve keyboard shortcuts, focus and contextual actions. A connection row exposes
  a Connect accessibility action as well as its normal desktop double-click/menu.
- Give file rows enough height for selection and file-action icons explicit labels.
  Keep transfer cancellation and destructive-action confirmations distinct.
  The Local Mac heading opens the folder picker with a plain 44-point target;
  match its header/navigation heights to Server so their dividers align. File-only
  SSH sessions select Files and disable the unavailable terminal modes/tools.
- Inspect text wrapping, disabled states, target bounds and edge clicks in an isolated
  synthetic preview. Test VoiceOver, full keyboard access and actual touch hardware
  separately before making accessibility/platform support claims.
