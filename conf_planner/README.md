# Conference Planner starter

`conf_planner/` hosts a directory of independent, mobile-friendly conference planners.

## Structure

- `index.html` loads and displays `conferences.json`, sorted newest conference first.
- `conferences.json` is the directory manifest. Add one entry for each published planner.
- Each conference has its own slug folder and `index.html`, plus any venue images it needs.
- `mtms-2026/` is the canonical feature-complete reference implementation.
- `supabase-setup.sql` installs the common multi-conference PIN-sync backend.

## Creating another conference

1. Copy `mtms-2026/` to a new lowercase slug folder.
2. Replace conference metadata, talks, events, timezone, day buttons, maps, and room mappings.
3. Set a unique `CONFERENCE_ID` matching the slug.
4. Use relative asset URLs so each planner remains portable.
5. Add the conference to `conferences.json`; chronological ordering is automatic.
6. Validate talk/event times against the official program and verify every room maps to the venue schematic.

## Required retained behavior

- Browse by time (default) or by session
- Add individual talks or complete sessions
- 4–6 digit PIN sync, isolated by conference ID
- Coffee, meal, special-event, gap, and parallel-talk timeline blocks
- Full talk and session information
- Explicit first, last, and sole author labels
- Sticky mobile navigation
- Conference-timezone jump-to-now
- Quick and booklet maps with context-aware room highlighting

Run `supabase-setup.sql` once in the shared Supabase project's SQL Editor before using PIN sync.
