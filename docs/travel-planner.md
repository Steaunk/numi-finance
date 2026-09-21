# Travel planner

The Travel tab now includes Overview, Itinerary, Places, Bookings, Preparation and Expenses. All planner records save locally before network work. Existing trip expense records remain separate: adding a reservation does not create a payment.

## Using the planner

1. Create a trip and open **Places** to save restaurants, shops, sights or practical stops. Use category, priority and scheduled filters.
2. Expand a place and select **Add to itinerary**. Pick a day and optional local start/end time; leave the day empty for an unassigned activity. Activities reference their place, so updating the place updates its displayed address and links. An optional activity name overrides the place name. Deleting the place keeps the activity and its last display name.
3. In **Itinerary**, select a day and drag activity handles to choose the order. Edit an activity to move it to another date. Bookings appear alongside activities from the original record, without duplication.
4. Add accommodation, transport and reservations in **Bookings**. Check-in and checkout use local calendar dates; checkout is not counted as an overnight stay. For overnight flights or trains, use **No accommodation needed** for the relevant night. Transport can arrive on an earlier local date across time zones; times retain the entered zone labels, without automatic conversion.
5. Track preparation, packing and shopping in **Preparation**. Due dates, responsible names and cancellation deadlines are displayed in the app, without notifications or messages to other people.
6. Continue recording payments in **Expenses**. No budgeting, expense splitting or automatic booking-to-expense conversion is included in this release.

## External links

Places, activities and bookings support multiple links with a purpose, optional display name and URL. Paste a URL or share text into **Add links** and review the detected URLs before saving. Short URLs are preserved; the app does not expand or scrape them. Known services get platform names, and other links show their host.

Google Maps and Baidu Maps have generated map entries for the saved name and address, including arrival addresses. Baidu searches use the trip destination as the region. Pasted links for other maps, booking sites, restaurant websites and guides open through the system. A compatible installed app may handle a link; otherwise the browser does. The fallback dialog offers a copy action if opening fails. Only HTTP/HTTPS links without embedded credentials are accepted.

Names, addresses, confirmation codes and notes are available offline. External maps and websites are not downloaded and may need connectivity.

## Local storage and synchronization

Drift schema 3 adds `trip_plans`, keyed by local trip ID. Documents use stable random item IDs, item references, ordered arrays and link lists. Writes are transactional and carry a new mutation ID. The pending document is retained across restarts and failures.

The backend stores one revisioned document per trip. Uploads use revision checks and a stable mutation ID, so retrying a request after a lost response does not apply it twice. A newer local edit is never acknowledged by an older response. Conflicts remain visible until the user confirms keeping the complete local version or using the complete server version; there is no automatic merge.

Trips must sync before their documents. Trip creation uses an optional stable `client_id`; parent creation and deletion are serialized. Deletions remain queued until acknowledged and hide the trip from pulls. Deleting a trip clears local planning, travel expenses and their queue entries; deleting its server record cascades to its plan. If a remote deletion encounters a dirty local plan, the local plan is preserved with a warning instead of silently discarded.

## Deployment

1. Back up the database, deploy the backend, and run `python manage.py migrate` (migration `expenses.0006_trip_client_id_tripplan`). Existing trips remain valid; new fields and endpoints are additive.
2. Build the client using the existing CI workflow. Drift-generated code is included; regenerate after schema changes with `dart run build_runner build --delete-conflicting-outputs`.
3. Release the client after the backend is ready. Against an older backend the client keeps local planner edits and shows a sync warning until the endpoint becomes available. New retry guarantees for parent creation require the new backend.

## Validation

The Django web page at `/expenses/travel/` shares the same six sections and planning API. It supports browser-local pending documents, retry and explicit conflict resolution. Planning edits remain in browser storage across reloads; opening the web page itself and managing trips or expenses requires a connection. Flutter remains the fully offline client.

Backend tests: `python manage.py test expenses`; migration check: `python manage.py makemigrations --check --dry-run`.

Client: `flutter analyze --no-fatal-infos` and `flutter test`. Planner tests cover local persistence, schema upgrades, in-flight edits, retries, conflicts, parent synchronization/deletion, links, date coverage, and mobile/desktop navigation and forms.

Web browser regression: start Django on `127.0.0.1:8765` using an isolated test database, then run `node backend/expenses/browser_tests/travel_planner.cjs` from the repository root with Playwright available. `CHROME_PATH` optionally selects an installed Chrome executable. This test creates trips on the local preview and covers mobile/desktop layout, planning, links, offline retry, conflicts and reload recovery; it refuses non-local hosts.

To save a visual QA artifact outside the repository, set `NUMI_PLANNER_SCREENSHOT=/tmp/planner.png` when running `flutter test test/trip_planner_widget_test.dart`.
For readable text in that artifact, also set `NUMI_PLANNER_FONT_DIR` to the Flutter SDK's `bin/cache/artifacts/material_fonts` directory.

Baidu links follow the [official web map URL documentation](https://lbsyun.baidu.com/docs/webapi?title=mapadjustment%2Furi%2Fweb); no API key or location permission is required for generated search links.
