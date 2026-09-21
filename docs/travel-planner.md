# Travel planner

The Flutter Travel workspace has two main views: **Itinerary** and **Saved places**. Compact booking, preparation and spending summaries open panels without losing the selected day. Past trips are collapsed in the trip list. All planner records save locally before network work. Bookings and activities can now own a payment: enter the details once and mark it paid to include it in Trip spending.

## Using the planner

1. Create a trip and open **Saved places** to save restaurants, shops, sights or practical stops. Open the filter button for category, priority and scheduled filters.
2. Tap a place and select **Add to itinerary**. Pick a day and optional local start/end time; leave the day empty for an unassigned activity. Activities reference their place, so updating the place updates its displayed address and links. An optional activity name overrides the place name. Deleting the place keeps the activity and its last display name.
3. In **Itinerary**, select a day, tap **Reorder activities**, and drag handles to choose the order. Tap an activity for details; its menu offers **Move to another day**, **Leave unassigned**, completion and deletion. Bookings appear alongside activities from the original record, without duplication.
4. Add accommodation, transport and reservations from the booking summary at the top. **Stay duration** selects check-in and check-out together and displays the number of nights. The day view labels check-in, ongoing stays and check-out; checkout is not counted as an overnight stay. Accommodation payment is the total for the entire stay, recorded once. For overnight flights or trains, use **No accommodation needed** for the relevant night. Transport can arrive on an earlier local date across time zones; times retain the entered zone labels, without automatic conversion.
5. Track preparation, packing and shopping from the preparation summary. Due dates, responsible names and cancellation deadlines are displayed in the app, without notifications or messages to other people.
6. Enter an optional amount and currency on any booking or activity. Turn on **Paid** and choose the payment date to include it in spending. Unpaid amounts stay in the plan and do not count as expenses. Accommodation suggests Accommodation; flights, trains, buses and car rentals suggest Transportation; sights suggest Sightseeing; restaurants and cafés suggest Food & Drinks; shops suggest Shopping. The category can be changed in **More details**.
7. Open a linked expense to edit the same booking or activity. For an existing standalone expense, choose **Add booking details** or **Add to itinerary** to reuse its name, amount, currency and payment date. The date of travel and date of payment are separate. Standalone spending remains available for other purchases.

Each booking or activity supports one payment in this release. Cancelling an item keeps its recorded payment. Deleting the item keeps its expense as a standalone record. Removing its payment (or marking it unpaid) keeps the itinerary item and removes the expense after confirmation. Refunds, instalments, expense splitting and automatic order import are not included.

Forms show the essential fields first; expand **More details** for status, notes, links and booking references. Map actions and edit controls are in item details, keeping the daily itinerary compact.

## External links

Places, activities and bookings support multiple links with a purpose, optional display name and URL. Paste a URL or share text into **Add links** and review the detected URLs before saving. Short URLs are preserved; the app does not expand or scrape them. Known services get platform names, and other links show their host.

Google Maps and Baidu Maps have generated map entries for the saved name and address, including arrival addresses. Baidu searches use the trip destination as the region. Pasted links for other maps, booking sites, restaurant websites and guides open through the system. A compatible installed app may handle a link; otherwise the browser does. The fallback dialog offers a copy action if opening fails. Only HTTP/HTTPS links without embedded credentials are accepted.

Names, addresses, confirmation codes and notes are available offline. External maps and websites are not downloaded and may need connectivity.

## Local storage and synchronization

Drift schema 3 added `trip_plans`, keyed by local trip ID. Schema 4 adds stable expense identities and itinerary item references. Documents use stable random item IDs, item references, ordered arrays and link lists. The planning document is authoritative for linked payment details; the expense row is updated in the same local/server transaction. Writes carry a new mutation ID. Pending documents and their payments survive restarts and failures.

The backend stores one revisioned document per trip. Uploads use revision checks and a stable mutation ID, so retrying a request after a lost response does not apply it twice. A newer local edit is never acknowledged by an older response. Conflicts remain visible until the user confirms keeping the complete local version or using the complete server version; there is no automatic merge.

Trips must sync before their documents. Trip creation uses an optional stable `client_id`; parent creation and deletion are serialized. Deletions remain queued until acknowledged and hide the trip from pulls. Deleting a trip clears local planning, travel expenses and their queue entries; deleting its server record cascades to its plan. If a remote deletion encounters a dirty local plan, the local plan is preserved with a warning instead of silently discarded.

## Deployment

1. Back up the database, deploy the backend, and run `python manage.py migrate` through `expenses.0007_booking_payments`. Existing trips and expenses remain valid; expense identities are backfilled without changing amounts.
2. Build the client using the existing CI workflow. Drift-generated code is included; regenerate after schema changes with `dart run build_runner build --delete-conflicting-outputs`.
3. Release the client after the backend is ready. Against an older backend the client keeps local planner edits and shows a sync warning until the endpoint/fields become available. Older clients can still manage standalone expenses; direct modification of a linked expense returns HTTP 409 and requires the shared itinerary editor.

`GET/PUT /expenses/api/travel/trips/{id}/plan/` includes `payment_ids` (expense client identity to server ID). Booking/activity payment fields are `amount`, `currency`, `paymentStatus`, `paidDate`, `expenseClientId` and `expenseCategory`. Existing travel expense endpoints include `client_id` and nullable `plan_item_id`. Creating with the same `client_id` returns the existing record without duplicating it. The plan revision protects linked expense edits as well as itinerary edits.

## Validation

The Django web page at `/expenses/travel/` retains its six sections and shares the planning API. It supports browser-local pending documents, retry and explicit conflict resolution. Planning edits remain in browser storage across reloads; opening the web page itself and managing trips or expenses requires a connection. Flutter remains the fully offline client.

Backend tests: `python manage.py test expenses`; migration check: `python manage.py makemigrations --check --dry-run`.

Client: `flutter analyze --no-fatal-infos` and `flutter test`. Planner tests cover local persistence, schema upgrades, in-flight edits, retries, conflicts, parent synchronization/deletion, links, date coverage, and mobile/desktop navigation and forms.

Web browser regression: start Django on `127.0.0.1:8765` using an isolated test database, then run `node backend/expenses/browser_tests/travel_planner.cjs` from the repository root with Playwright available. `CHROME_PATH` optionally selects an installed Chrome executable. This test creates trips on the local preview and covers mobile/desktop layout, planning, links, offline retry, conflicts and reload recovery; it refuses non-local hosts.

Run `node backend/expenses/browser_tests/travel_payments.cjs` against the same isolated preview for paid flights, editing through the expense list, converting an existing ticket into an activity, and offline payment retry without duplicates. Flutter and Django tests also cover linked payment identity, category selection, cancellation, deletion, migration, conflict resolution and edits during upload.

To save named phone, desktop, form and dark-mode PNG artifacts outside the repository, set `NUMI_PLANNER_SCREENSHOT=/tmp/planner` when running `flutter test test/trip_planner_widget_test.dart`.
For readable text in that artifact, also set `NUMI_PLANNER_FONT_DIR` to the Flutter SDK's `bin/cache/artifacts/material_fonts` directory.

Baidu links follow the [official web map URL documentation](https://lbsyun.baidu.com/docs/webapi?title=mapadjustment%2Furi%2Fweb); no API key or location permission is required for generated search links.
