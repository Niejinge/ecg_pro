# Figma Integration Rules

## Source Of Truth

Flutter code is the source of truth for the first ECG Pro design library.

- Tokens: `packages/ecg_ui/lib/src/theme`
- Components: `packages/ecg_ui/lib/src/widgets`
- App usage examples: `apps/user_app/lib/src/user_app.dart` and `apps/admin_app/lib/src/admin_app.dart`
- Product requirements: `docs/requirements.md`
- Design system scope: `docs/design-system.md`

## Figma Library V1 Scope

Create these foundations first:

- Color variables: `brand`, `brandPressed`, `brandSoft`, `accent`, `accentSoft`, `success`, `warning`, `danger`, backgrounds, borders, and text colors.
- Spacing variables: `xxs`, `xs`, `sm`, `md`, `lg`, `xl`, `xxl`, `xxxl`.
- Radius variables: `xs`, `sm`, `md`, `lg`, `xl`, `pill`.
- Text styles: `display`, `title`, `body`, `label`.

Create these components after variables are ready:

- `Badge`
- `Metric Card`
- `Action Card`
- `Empty State`
- `Section Card`
- `Page Shell`

## Naming

- Use slash-separated variable names, for example `color/brand/default`, `spacing/lg`, `radius/md`.
- Use title case component names, for example `Metric Card`.
- Use simple variant names, for example `Tone=Warning` or `State=Empty`.

## Build Rules

- Bind Figma component colors, radius, and spacing to variables wherever possible.
- Keep clinical learning screens calm and readable.
- Use badges for metadata only: category, risk, difficulty, status.
- Use metric cards for numeric progress and dashboard values.
- Use action cards for resumable learning actions and wrong-question review.
- Keep component examples close to real ECG content, not placeholder lorem ipsum.

## Current Figma Access Note

The connected Figma account is authenticated as `gehejinnie@gmail.com`, but the available team seat is `View`. Creating or modifying a Figma design library requires edit access. Once an editable team or file is available, use Figma MCP to create the library from this scope.
