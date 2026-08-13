---
title: Recipe index
status: stub
---

# Recipes

Symptom-first debugging recipes. Titles name the failure mode, not the API.

| Recipe | Primary concept | Difficulty | Status |
| --- | --- | --- | --- |
| [`caching/user-a-sees-user-b-data`](caching/user-a-sees-user-b-data.md) | `caching/use-cache-directive` | intermediate | `draft` — fix + `'use cache: private'` probe + detection probe landed 2026-08-13; demo `billing-leak-{a,b,c}` + `billing-private` + `leak-{a,b,c,fixed,private}` |
