---
name: svelte-frontend
description: Implement or refactor Svelte and SvelteKit frontend code so changes follow clean architecture. Use when building UI features, pages, components, forms, dialogs, boards, or client workflows and the agent must separate visual elements from visual logic, keep business rules out of .svelte files, use .svelte.ts for component model logic, and preserve inward dependencies from UI toward application and domain code.
---

Implement the requested frontend change using clean architecture for Svelte/SvelteKit.

Task:
$ARGUMENTS

Primary objective:
Deliver the requested UI behavior with the smallest correct change set while preserving or improving architectural boundaries. For generation workflows (charts, forms, PDFs, visualizations), visual browser validation is mandatory to confirm user-visible outcomes.

Repository monorepo context:
1. This repository is a Bun workspace monorepo with:
   - `apps/desktop-app`
   - `packages/ui`
   - `packages/domain`
2. Shared reusable UI belongs in `packages/ui`.
3. `apps/desktop-app` should consume shared UI from the workspace package instead of duplicating components locally.
4. Frontend code must import browser-safe shared domain code from `domain/shared`, not server entrypoints.
5. Prefer workspace package imports over relative cross-package filesystem imports.

Frontend dependency rule:
1. Visual files may depend on view-model, application, and domain code.
2. View-model files may depend on application and domain code.
3. Application code may depend on domain code and abstract ports.
4. Adapters and infrastructure may depend on inner layers.
5. Domain code must not depend on Svelte, SvelteKit, browser APIs, fetch clients, component files, route files, or UI libraries.

Non-negotiable rules:
1. Separate visual elements from visual logic.
2. `.svelte` files are for visual structure and binding only.
3. `.svelte.ts` files are for component model logic and reusable reactive UI behavior.
4. Business rules, domain invariants, and cross-screen workflow rules do not belong in `.svelte` files or `.svelte.ts` files unless they are purely presentation-specific.
5. Keep network calls, persistence calls, SDK calls, and transport details out of `.svelte` files.
6. Keep direct backend call code out of most components. Route it through application functions or adapter modules.
7. Do not leak HTTP payloads, database shapes, SDK responses, or route event objects into domain code.
8. Translate external data at the boundary using mappers, DTOs, or view-model transformers.
9. Prefer incremental refactoring over sweeping rewrites.
10. If the existing codebase already mixes layers, contain the leakage behind a boundary instead of spreading it further.
11. **Environment variable validation**: When SvelteKit server-side features depend on env vars (API keys, provider URLs, auth tokens), the implementation must verify these vars actually reach `process.env` at runtime with clear error messages if missing. This is critical in Vite 7 Module Runner where `.env` file values may not reach `process.env`.
12. **Error classification**: Transport layers must classify 502/503 errors from AI providers and external services as "service unavailable" rather than generic errors. Handle unexpected error shapes gracefully without crashing.

Environment variable validation examples:
```typescript
// In server-side adapter
if (!process.env.OPENAI_API_KEY) {
  throw new Error('OPENAI_API_KEY not found in process.env - check .env configuration and Vite setup');
}
```

Error classification examples:
```typescript
// In transport adapter
catch (error) {
  if (error.status === 502 || error.status === 503 || error.message?.includes('timeout')) {
    throw new ServiceUnavailableError('AI provider temporarily unavailable');
  }
  // Handle other cases...
}
```

Svelte separation rule:
- A stateful or reusable interactive component should normally have a paired file:
  - `Component.svelte`
  - `Component.svelte.ts`
- Example:
  - `Modal.svelte`
  - `Modal.svelte.ts`
- Pure presentational leaf components may remain `.svelte` only if they contain no meaningful logic beyond trivial markup wiring.

What belongs in `.svelte`:
- markup
- layout structure
- classes and styling hooks
- transitions and animations
- DOM-only bindings
- snippet/render composition (use snippets by default; slots only for legacy interop)
- accessibility attributes
- binding UI events to model methods
- rendering derived values that were already prepared by the model

What belongs in `.svelte.ts`:
- reactive component state
- derived UI state
- interaction logic
- local validation for user interaction
- command methods like open, close, toggle, submit, cancel, reorder, select
- async orchestration that is specific to the component or screen
- mapping application results into display-ready state
- UI state transitions
- reusable reactive logic shared across related components

What does not belong in `.svelte.ts`:
- domain entities and domain invariants
- broad business policy
- raw HTTP client details
- direct database concerns
- route server logic
- secret handling
- user-specific server state stored at module scope

Layer model for frontend:
- Domain:
  - entities
  - value objects
  - business rules
  - invariants
  - domain services
  - pure policy
- Application:
  - use cases
  - commands and queries
  - workflow orchestration
  - UI-facing DTOs
  - ports for data, auth, analytics, files, and other side effects
- Presentation model:
  - `.svelte.ts` files
  - component models
  - page models
  - local interaction state
  - derived display state
  - event handling methods
- View:
  - `.svelte` files
  - pages, layouts, components, and visual composition
- Adapters/infrastructure:
  - HTTP clients
  - repository implementations
  - SDK wrappers
  - persistence implementations
  - browser API wrappers
  - route integrations
  - analytics adapters
  - framework wiring

Svelte 5 syntax contract (default for all new or touched code):
1. Props:
   - In runes-mode components, declare props with `$props()` destructuring.
   - Prefer typed props in TypeScript with a `Props` interface or inline type annotation.
   - Do not introduce new `export let` in runes-mode updates unless the user explicitly requests legacy syntax.
2. Reactivity:
   - Use `$state` for mutable reactive state.
   - Use `$derived` for derived values.
   - Use `$effect` (or `$effect.pre` when required) for side effects.
   - Avoid top-level `$:` in runes-mode updates.
3. DOM events:
   - Prefer event attributes such as `onclick`, `onchange`, `oninput`, `onkeydown`.
   - Avoid introducing new `on:` event directive syntax in modernized code.
4. Component events and communication:
   - Prefer callback props and typed function props for parent-child communication.
   - Do not introduce `createEventDispatcher` in newly touched runes-mode components.
5. Bindings:
   - In runes mode, opt in explicitly with `$bindable()` for bindable props.
   - Do not assume all props are bindable by default.
6. Composition:
   - Prefer snippet props (`{#snippet ...}` + `{@render ...}`) over new `<slot>` usage.
   - Use `children` snippet conventions when passing inline component content.
   - Avoid adding normal props named `children` when inline content is used.
   - Do not mix new snippets and legacy slots in the same API design unless migration constraints require it.

SvelteKit rules:
1. Do not store user-specific or request-specific data in shared module-level server state.
2. In `apps/desktop-app`, avoid per-route `+page.ts` for client-side composition unless the repository explicitly requires an exception.
3. For client-side route initialization in `apps/desktop-app`, prefer `.svelte.ts` page models plus route-local composition helpers and adapter factories.
4. If `load` is used, keep it pure. Do not write to global state or trigger side effects from `load`.
5. Keep server-only concerns in server files and browser-only concerns out of SSR-sensitive code paths.
6. Do not let page/server transport details leak into domain or application modules.

Implementation process:
1. **Inspect and map** - Identify:
   - the user-facing workflow and generation requirements
   - the affected screen or component boundary
   - current coupling between view, model, application, and infrastructure
   - existing seams that can be preserved

2. **Categorize changes** into five buckets:
   - domain changes
   - application changes
   - presentation-model changes
   - view changes
   - adapter/infrastructure changes

3. **Implement from inside out**:
   a. Add or update domain rules if behavior changed.
   b. Add or update application use cases and ports.
   c. Add or update adapters for APIs, persistence, analytics, browser wrappers, or backend calls.
   d. Add or update the `.svelte.ts` model for the screen/component.
   e. Keep the `.svelte` file focused on rendering and event binding.

4. **Wire the page or component** last.

5. **Add tests at the correct layer**:
   - Domain: unit tests for business rules
   - Application: workflow tests with mocked ports
   - Presentation model: state transitions and interaction behavior
   - View: rendering, accessibility, and wiring tests

6. **Visual validation checkpoint** (mandatory for generation workflows):
   - For chart/visualization tools: Verify actual chart rendering, axis labels visibility, data point placement, legend display, responsive layout
   - For form builders: Confirm drag visual feedback, drop zone highlighting, component placement in preview, form rendering accuracy
   - For PDF/download features: Validate button state changes, loading spinners, success notifications, download prompts
   - For any generation workflow: Tests must assert on rendered visual elements, not just data processing success

7. **Run validation in order**:
   - Unit tests first
   - Integration tests
   - Visual browser validation (required for generation features)
   - Broader system checks

Decision rules:
- If logic answers "what must be true for the business?", it belongs in domain.
- If logic answers "what happens and in what order for this user workflow?", it belongs in application.
- If logic answers "how should this screen/component behave and react?", it belongs in `.svelte.ts`.
- If logic answers "how is this rendered?", it belongs in `.svelte`.
- If logic answers "how do we talk to fetch, browser APIs, storage, analytics, or external SDKs?", it belongs in adapters/infrastructure.

Component model rules:
- Prefer a clear model factory, class, or exported reactive state object in `.svelte.ts`.
- Expose intent-based methods such as: `open()`, `close()`, `toggle()`, `startEdit()`, `save()`, `archive()`, `assignToAi()`
- Prefer derived properties for display state rather than scattering condition logic through markup.
- Keep DOM access out of the model unless it is truly UI-only and unavoidable.

AI SDK Svelte rules:
- Use `@ai-sdk/svelte` `Chat` class for streaming chat UIs, not React hooks.
- Never destructure `Chat` properties (`let { messages } = chat` breaks reactivity). Always access via `chat.messages`, `chat.status`, etc.
- Use reactive getters for `Chat` constructor arguments that may change: `new Chat({ get id() { return threadId; } })`.

Chat UI composition rules:
- Chat UI components live in `packages/ui/src/lib/chat/` and are imported from `ui/source`.
- `ChatComposer` requires `Tooltip.Provider` from `ui/source` as an ancestor. Pages that include `ChatComposer` must wrap content with `<Tooltip.Provider>`.
- The `packages/ui` chat types are structural mirrors of domain types. Do not import `domain/shared` from `packages/ui`.

Visual validation requirements for generation workflows:
1. **Chart/visualization generation**:
   - Tests must verify actual chart rendering in browser
   - Assert axis labels are visible and correctly positioned
   - Confirm data points appear at expected locations
   - Validate legend displays correctly
   - Check responsive layout behavior across screen sizes
   - Data processing tests alone are insufficient

2. **Form builder/drag-drop generation**:
   - Verify drag visual feedback appears during interaction
   - Confirm drop zone highlighting activates properly
   - Assert component placement in preview matches expectations
   - Validate form rendering accuracy in preview panel
   - Tests must check actual visible drag states, not just data model changes

3. **PDF/download generation**:
   - Validate button state changes (enabled/disabled/loading)
   - Confirm loading spinner appears during generation
   - Assert success notifications display correctly
   - Check download prompt appears for user
   - Verify each visual feedback state, not just file generation success

4. **Any generation workflow**:
   - Tests must assert on rendered visual elements
   - Visual browser validation is mandatory
   - Final reports must document verified visible behavior
   - User-facing generation features require confirmation of actual visual outcomes

Quality bar before finishing:
1. Interactive components are split correctly between `.svelte` and `.svelte.ts`.
2. `.svelte` files are primarily visual.
3. Domain/application code is free of Svelte and browser-specific leakage.
4. No side effects were introduced into `load`.
5. Backend/integration code is not scattered through component markup.
6. Touched runes-mode components use Svelte 5 syntax (props, events, reactivity).
7. **Environment variables validated** - Server-side features verify env vars reach `process.env` with clear error messages.
8. **Error classification implemented** - Transport layers properly classify 502/503 as service unavailable.
9. **Visual validation completed for generation workflows** - tests verify actual visible outcomes.
10. Changed behavior is covered by tests at the correct layer.
11. Any legacy syntax intentionally left in place is documented briefly.

Output behavior:
- Implement the change.
- Then briefly summarize:
  - what changed
  - which files are view files
  - which files are `.svelte.ts` presentation-model files
  - which files are application/domain/adapters
  - visual validation results for generation workflows
  - environment variable validation implemented
  - error classification patterns used
  - any assumptions made
  - any architectural debt intentionally left in place
