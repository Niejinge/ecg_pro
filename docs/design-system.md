# ECG Pro Design System

## Design Direction

ECG Pro uses a clean clinical learning style: quiet surfaces, clear information hierarchy, and restrained status color. The UI should feel close to Apple-style simplicity without becoming decorative or sparse. Screens should help learners scan ECG case information, compare risk, and continue study with minimal friction.

## Tokens

- Color tokens live in `packages/ecg_ui/lib/src/theme/app_colors.dart`.
- Spacing tokens live in `packages/ecg_ui/lib/src/theme/app_spacing.dart`.
- Radius tokens live in `packages/ecg_ui/lib/src/theme/app_radius.dart`.
- Text styles live in `packages/ecg_ui/lib/src/theme/app_text_styles.dart`.
- App-level Material theming lives in `packages/ecg_ui/lib/src/theme/ecg_app_theme.dart`.

## Component Primitives

- `EcgScaffold`: shared scrollable page shell.
- `EcgSectionCard`: section wrapper for grouped content.
- `EcgBadge`: compact risk, difficulty, category, and status label.
- `EcgMetricCard`: small dashboard metric tile.
- `EcgActionCard`: compact continuation or review action.
- `EcgEmptyState`: inline empty or unavailable state.

## Usage Rules

- Use status colors only for state: success, warning, danger, risk, correctness.
- Use `EcgBadge` for short metadata, not long descriptions.
- Use `EcgMetricCard` for numeric progress and dashboard summaries.
- Use `EcgActionCard` for recent learning, wrong-question review, and resumable tasks.
- Keep dense operational screens readable: prefer section grouping and short labels over decorative hero content.

## Figma Mapping

Create the first Figma library with these foundations:

- Variables: `color/*`, `spacing/*`, `radius/*`, `text/*`.
- Components: `Badge`, `Metric Card`, `Action Card`, `Empty State`, `Section Card`, `Page Shell`.
- Component variants: Badge status variants for brand, accent, success, warning, danger.
