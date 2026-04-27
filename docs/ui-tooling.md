# UI Tooling Guide

## Principle

ECG Pro uses the Flutter UI package as the source of truth for implementation.
External design tools are used to explore and communicate ideas, not to define
the final production contract.

Primary source of truth:

- Tokens: `packages/ecg_ui/lib/src/theme`
- Components: `packages/ecg_ui/lib/src/widgets`
- Product usage: `apps/user_app` and `apps/admin_app`

Design tools should stay lightweight at the current MVP stage. A design draft is
useful when it makes layout, flow, or visual direction easier to discuss. It is
not required for every screen.

## Recommended Free Tools

### Penpot

Use Penpot when we need a Figma-like UI design workspace without relying on a
paid Figma plan.

Best for:

- Shared UI screen drafts.
- Reusable visual component references.
- Clickable product flow prototypes.
- Future self-hosted design collaboration.

Current role:

- Optional primary free UI design tool.
- Good fit if we want one place to maintain visual references for web and
  Android screens.

### Lunacy

Use Lunacy when we want a local Windows desktop design tool that can work
offline.

Best for:

- Quick page mockups.
- Local visual exploration.
- Lightweight UI asset edits.
- Importing or viewing Figma-style files when needed.

Current role:

- Recommended local fallback.
- Good fit for fast solo iteration without setting up a server or team space.

### Excalidraw

Use Excalidraw for early thinking, not polished UI.

Best for:

- User flow sketches.
- Admin workflow diagrams.
- Learning path diagrams.
- Low-fidelity page structure.

Current role:

- Fastest tool for discussing screen flow before implementation.

### Figma Free

Figma can still be used for small drafts when convenient, but it should not block
development.

Best for:

- Small one-off visual references.
- Inspecting community UI inspiration.
- Future MCP-assisted library generation when edit access is available.

Current role:

- Optional only.
- Do not depend on Figma MCP for the MVP while account or plan limits are
  restrictive.

## Workflow

1. Sketch the flow only when the screen or interaction is unclear.
2. Convert approved direction into `ecg_ui` tokens or reusable components.
3. Use `ecg_ui` components in user and admin apps.
4. Add or update widget tests for any new shared behavior.
5. Keep screenshots or design files as references, but treat code as canonical.

## Design Acceptance Rules

- If a visual decision affects repeated UI, add it to `ecg_ui`.
- If a design draft conflicts with `ecg_ui`, update the component library first.
- If a screen uses one-off styling, confirm it is truly screen-specific.
- If a tool requires paid features for the next step, choose a simpler workflow.
- If a low-fidelity sketch is enough, prefer Excalidraw or a Markdown diagram.

## MVP Recommendation

For the current ECG Pro phase, use this stack:

- `ecg_ui` for production tokens and components.
- Penpot or Lunacy for optional UI drafts.
- Excalidraw for flows and rough wireframes.
- Figma only when free access is sufficient.

This keeps the project moving while preserving a clean path to a more formal
design library later.
