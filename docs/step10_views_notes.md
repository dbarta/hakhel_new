# Step 10 – HKE views and layouts

## Copied
- Views: all files from `hke/app/views/hke/**` → `app/views/hke/**` (including partials, dashboards, CRUD screens, jbuilder, etc.).
- Layouts: `hke/app/views/layouts/hke/**` → `app/views/layouts/hke/**`.
- Liquid templates: included as part of the `app/views/hke/liquid_templates/**` subtree.

## Fixes
- None required yet; route helpers already align with inlined `/hke` routes, and helpers were previously copied.

## Verification
- `bin/rails runner 'puts ActionController::Base.view_paths.map(&:to_s).grep(/views/).first'` outputs the app views path without error (app boots with views present).
