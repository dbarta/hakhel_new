# Step 11 – host app integration for HKE

## Files modified
- `app/models/user.rb` – add HKE roles (jsonb), community association, role helpers/scopes, and admin fallback.
- `app/controllers/application_controller.rb` – role-based post-login redirect to HKE (admin → `/hke/admin`, community users → `/hke`).
- `app/controllers/users_controller.rb` – HKE-aware user management (roles/community selection, search_results partial).
- `app/views/application/_navbar.html.erb` – add HKE links and community switcher for HKE roles.

## Behaviors added
- Users now support HKE role flags and optional `Hke::Community` association.
- After login, HKE users land on `/hke` (or `/hke/admin` for system admins).
- Navbar shows HKE admin/community links and a community switcher for system admins (uses HKE routes).

## TODO / notes
- Authorization/policy alignment remains as-is from controllers; revisit once full UI flow is exercised.
- Verify navbar styling against JP defaults; kept HKE-specific UI to preserve functionality.
- Start app with `bin/dev` and check `/hke` and `/hke/future_messages` pages once credentials are configured.
