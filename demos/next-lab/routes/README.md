# Route segment convention for article extraction
#
# Each concept article / recipe that needs runnable samples owns a route
# segment under `app/` (or later `app/(lab)/`) named for its slug.
#
# Examples (not created yet — scaffolding only):
#   docs/concepts/caching/use-cache-directive.md
#     → app/caching/use-cache-directive/page.tsx
#   docs/recipes/caching/stale-dashboard-after-mutation.md
#     → app/recipes/caching/stale-dashboard-after-mutation/page.tsx
#
# Code blocks in articles are extracted verbatim from these routes.
# Do not hand-type sample code into markdown.
#
# TODO: add the first real article route when Wave 1 content lands.
