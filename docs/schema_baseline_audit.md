# Schema baseline audit (HKE + custom additions)

## HKE tables included
- `hke_communities`, `hke_addresses`, `hke_cemeteries`, `hke_contact_people`, `hke_deceased_people`
- `hke_selections`, `hke_relations`, `hke_relations_selections`, `hke_preferences`
- `hke_future_messages`, `hke_sent_messages`, `hke_landing_pages`
- `hke_csv_imports`, `hke_csv_import_logs`, `hke_logs`, `hke_systems`

## Non-HKE tables modified (to match hakhel)
- `users`: add `roles` (jsonb, default `{}`, not null) + GIN index; add `community_id` (bigint) + index; FK to `hke_communities`.
- `account_users`: add indexes on `account_id` and `user_id` (complements existing composite unique index in `hakhel_new`).

## Extensions enabled
- `plpgsql` (guarded).

## Misses found in migrations
- None found beyond what `hakhel/db/schema.rb` reflects (no extra SQL/constraints detected in reviewed migrations).
