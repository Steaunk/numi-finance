# Travel planner

The Flutter Travel workspace has three main views: **Itinerary**, **Saved places**, and **Spending**. One destination filter applies across the views and the booking/spending summaries. **Bookings** and **Trip checklist** are explicitly labeled shortcuts; the checklist always covers the whole trip. All planner records save locally before network work.

## Using the planner

1. In **Itinerary**, select a day and tap **Add to this day**. Choose an activity/visit, transport, stay or reservation, or search saved places in the same picker. Tapping a saved place adds it directly to the selected day and returns to the itinerary with confirmation. Its time is flexible until edited.
2. Use **Saved places** for restaurants, shops, sights and practical stops you may want to visit. Notes and links are immediately available in the place form. The place detail action names the selected day. Activities reference their place, so updating its address or links updates the activity; deleting a place preserves the activity's display name and destination.
3. Timed activities and bookings share one chronological timeline. Untimed items appear under **Flexible time**. **Reorder flexible activities** changes only untimed activity order; setting or editing a time puts an arrangement in chronological order. An activity's menu offers moving to another day, leaving it unassigned, completion and deletion.
4. Add accommodation, transport and reservations from the daily picker or **Bookings**. Selecting a booking in that panel opens its editor directly. **Stay duration** selects check-in and check-out together and shows nights. Ongoing stays appear below the timeline; checkout is not an overnight stay. **No accommodation needed** covers overnight travel. Transport can arrive on an earlier local date across time zones; entered zone labels are retained without automatic conversion.
5. Track preparation, packing and shopping in **Trip checklist**. Due dates, responsible names and cancellation deadlines are displayed without notifications or messages to other people.
6. Activities have an editable **Activity type**: Sightseeing, Restaurant, Cafe, Shopping, Park, Practical, Accommodation or Other. Choosing a saved place initially uses its category; it can be changed for that visit.
7. In **Spending**, create or edit an expense and expand **Linked itinerary** to select any number of existing activities or bookings. On Web, use **Link itinerary / Edit links** beside the expense. Multiple expenses can reference the same arrangement. Removing every selection unlinks the expense.

Money is stored only in expenses. Itinerary forms and cards contain no prices or payment state, and saving an arrangement never creates an expense. Editing or deleting expenses leaves arrangements intact. Deleting an arrangement removes only its links; all recorded amounts remain. A linked expense is counted once, regardless of the number of arrangements. Refunds, allocation of one amount across arrangements, and automatic order import are not included.

Forms show essential fields first. Place notes, links, booking references and activity type stay visible; **More details** holds status and secondary fields. Import review suggests updating an existing activity for a matching name, date and time (including long English names inside bilingual titles). The user can review the combined details, cancel, or explicitly add a separate visit.

## Multiple destinations in one trip

Give the whole trip a name (for example “Japan autumn trip”), then open **Destinations** to add Tokyo, Kyoto and Osaka as separate visits. Cities, regions and countries all use the same destination record. Each visit has arrival and departure dates within the trip dates; same-day visits and overlapping transfer days are valid. Use the arrows to reorder the route. The App retains its three primary tabs.

Choose **Show destination** to filter the itinerary, saved places, booking panel, spending and header summaries. **Unassigned** and **Between destinations** are also available. The checklist is labeled as applying to the whole trip. Place-linked activities inherit the place’s destination. Free activities and accommodation can select a destination directly. Flights, trains, buses and car rentals can select **From destination** and **To destination**. A transfer appears in both relevant destination views while remaining one record.

**Spending by destination** uses an expense’s explicit destination first. Otherwise it derives the destination from linked arrangements. Links spanning multiple destinations, and transport between destinations, use **Between destinations**. Purchases without a destination remain **Unassigned**. No amount is counted twice. Existing standalone expenses can select a destination directly in their expense editor. Transfers remain a separate spending group, excluded from individual destination spending totals; they appear in both relevant itinerary views. Removing a destination clears its references while preserving places, activities, bookings and payments; removing a saved place preserves its destination on the surviving activities.

Destinations are `kind: destination` items in the existing revisioned plan, with `id`, `title`, `date` and `endDate`. Other items reference them using `destinationId`; transport can also use `endDestinationId`. References must resolve within the same trip. The array preserves route order, and existing offline persistence, retries and conflict handling apply. The existing trip API’s `destination` field serves as the trip name. Standalone expenses store `destination_id` separately in Django migration 0008 and Drift schema 5; planner references retain their existing format.

Run `node backend/expenses/browser_tests/travel_destinations.cjs` against the isolated preview (`NUMI_TEST_URL`, default `http://127.0.0.1:8767`) for route editing, overlapping dates, place inheritance, transfer spending, offline removal and reload recovery.

## External links

Places, activities and bookings support multiple links with a purpose, optional display name and URL. Paste a URL or share text into **Add links** and review the detected URLs before saving. Short URLs are preserved; the app does not expand or scrape them. Known services get platform names, and other links show their host.

Google Maps and Baidu Maps have generated map entries for the saved name and address, including arrival addresses. Baidu searches use the trip destination as the region. Pasted links for other maps, booking sites, restaurant websites and guides open through the system. A compatible installed app may handle a link; otherwise the browser does. The fallback dialog offers a copy action if opening fails. Only HTTP/HTTPS links without embedded credentials are accepted.

Names, addresses, confirmation codes and notes are available offline. External maps and websites are not downloaded and may need connectivity.

## Local storage and synchronization

Drift schema 3 added `trip_plans`, keyed by local trip ID. Schema 4 adds stable expense identities and itinerary item references. Schema 5 adds the optional standalone expense destination. Plan synchronization runs before expense queue upload so newly created destinations exist before their purchases are sent. Documents use stable random item IDs, item references, ordered arrays and link lists. The expense ledger is authoritative for money; planning edits only prune links to removed arrangements. Writes carry a new mutation ID. Pending documents and independently queued expenses survive restarts and failures.

The backend stores one revisioned document per trip. Uploads use revision checks and a stable mutation ID, so retrying a request after a lost response does not apply it twice. A newer local edit is never acknowledged by an older response. Revision snapshots allow field-level three-way merging: independent edits merge, while overlapping fields require a choice. Resolution preserves unrelated changes. Mutation receipts prevent retries from reapplying an older edit. In-flight app edits are rebased onto the merged server response.

Trips must sync before their documents. Trip creation uses an optional stable `client_id`; parent creation and deletion are serialized. Deletions remain queued until acknowledged and hide the trip from pulls. Deleting a trip clears local planning, travel expenses and their queue entries; deleting its server record cascades to its plan. If a remote deletion encounters a dirty local plan, the local plan is preserved with a warning instead of silently discarded.

## Deployment

1. Back up the database, deploy the backend, and run `python manage.py migrate` through `expenses.0012_expense_itinerary_links`. Migration 0009 gives pre-planner trips one whole-trip destination using their original destination name and assigns their standalone expenses to it. Existing plans are retained; linked expense destinations are backfilled from their actual plan references. Names, amounts and payment dates are unchanged.
2. Build the client using the existing CI workflow. Drift-generated code is included; regenerate after schema changes with `dart run build_runner build --delete-conflicting-outputs`.
3. Release the client after the backend is ready. Against an older backend the client keeps local planner edits and shows a sync warning until the endpoint/fields become available. Older clients can still manage standalone expenses; direct modification of a linked expense returns HTTP 409 and requires the shared itinerary editor.

`GET/PUT /expenses/api/travel/trips/{id}/plan/` stores itinerary content only. Expense endpoints accept `plan_item_ids`, a list of stable activity/booking IDs within the same trip, alongside `client_id` and `destination_id`. Omitting `plan_item_ids` on an expense update preserves links; `[]` clears them. `PUT /expenses/api/travel/trips/{trip_id}/expenses/{expense_id}/links/` accepts only `{ "plan_item_ids": [...] }`, so changing links cannot overwrite money from an older form. Invalid, duplicate, foreign-trip and non-arrangement IDs are rejected. Creating with the same `client_id` remains idempotent. Django migration 0012 and Drift schema 6 migrate existing single links, preserve expense amounts/identities and remove financial fields from plans; backend history is cleaned as well. Deploy the backend before the updated clients. Expense saves and sync operations are transactional locally; retry acknowledgements never mark newer edits synced.

## Validation

The Django web page at `/expenses/travel/` retains its six sections and shares the planning API. It supports browser-local pending documents, retry and explicit conflict resolution. Planning edits remain in browser storage across reloads; opening the web page itself and managing trips or expenses requires a connection. Flutter remains the fully offline client.

Backend tests: `python manage.py test expenses`; migration check: `python manage.py makemigrations --check --dry-run`.

Client: `flutter analyze --no-fatal-infos` and `flutter test`. Planner tests cover local persistence, schema upgrades, in-flight edits, retries, conflicts, parent synchronization/deletion, links, date coverage, and mobile/desktop navigation and forms.

Web browser regression: start Django on `127.0.0.1:8765` using an isolated test database, then run `node backend/expenses/browser_tests/travel_planner.cjs` from the repository root with Playwright available. `CHROME_PATH` optionally selects an installed Chrome executable. This test creates trips on the local preview and covers mobile/desktop layout, planning, links, offline retry, conflicts and reload recovery; it refuses non-local hosts.

Run `node backend/expenses/browser_tests/travel_payments.cjs` against the same isolated preview for multi-select expense linking, unlinking, independent expense editing and editable activity categories. Flutter and Django tests also cover many-to-many totals, migration, deleting linked records, and newer expense edits/deletions during an upload.

To save named phone, desktop, form and dark-mode PNG artifacts outside the repository, set `NUMI_PLANNER_SCREENSHOT=/tmp/planner` when running `flutter test test/trip_planner_widget_test.dart`.
For readable text in that artifact, also set `NUMI_PLANNER_FONT_DIR` to the Flutter SDK's `bin/cache/artifacts/material_fonts` directory.

Baidu links follow the [official web map URL documentation](https://lbsyun.baidu.com/docs/webapi?title=mapadjustment%2Furi%2Fweb); no API key or location permission is required for generated search links.


## People and collaborative planning

Use **People** in the app, or **Manage people** in the web workspace, to add named travellers. Activities and bookings have optional `participantIds`; missing or empty means everyone, including active people added later. Explicit IDs remain fixed. People are `kind: person` items with stable IDs; archive them (`status: cancelled`) to preserve references. Participation is unrelated to payment or cost splitting.

Use **Show people** to see one person's arrangements together with Everyone arrangements. Archived people remain available to inspect their explicitly assigned arrangements. The owner opens `/expenses/travel/trips/{id}/plan/`; the existing travel page links there, and the app offers **Invite & collaborate on web**. The shared workspace has Itinerary, Saved places and Checklist, plus people, invitation management and item history. Each editor can change participants, dates, places, notes and other itinerary fields.

The owner creates a named viewer/editor invitation, optionally linked to a traveller. A 256-bit bearer token is placed in the link fragment, exchanged through a CSRF-protected POST, and removed from the address bar. Only its SHA-256 hash is stored. Session grants are scoped to that trip; every request checks expiry and revocation. Links expire in 30 days, sessions in 14 days. Names identify invitation holders' edits, not verified real-world identities. Creating an invitation does not send it. The owner must copy the link when it is created; the token cannot be retrieved later. Viewers cannot edit. Only the owner can manage invitations or delete a trip.

Shared pages and APIs return no-store responses and no financial fields or expense identities. Shared notes are visible to invitees. Collaboration writes use public item fields even for the owner; restoring history also restores itinerary content only. Deleting an arrangement retains recorded expenses. Financial edits remain in the owner-only spending flow.

`/travel/shared/{id}/` is the public page shell; `session/`, `data/`, and `history/` under that prefix are the only shared endpoints. The shell contains no trip data. `data/` requires a trip grant and accepts `{revision, mutation_id, operations: [{id, changes} | {id, delete: true}]}`. `replace: true` restores one itinerary item; expenses remain independent. The owner endpoints live at `/expenses/api/travel/trips/{id}/collaboration/{data,history,invites}/` behind existing Basic Auth. Do not remove Basic Auth from other paths. The shared path must remain outside `ApiCsrfExemptMiddleware`'s `/api/` exemption.

Migration `0010_tripinvite_tripplanchange` adds invitation and revision history tables. Existing documents are snapshotted on their next write. History shows the 50 most recent revisions; older snapshots remain available to safely merge offline writes. Web clients poll every 12 seconds while visible, pausing refresh during editing. Unsent edits remain in an open editor after network failures; the new web workspace is online-first and does not persist form drafts across reloads. Flutter retains offline persistence. Runtime invite checks, financial field isolation, participant references, concurrent edits, history restoration and idempotent retries are covered by `expenses.test_collaboration`. Run `browser_tests/travel_collaboration.cjs` on a local isolated preview to verify two independent sessions, mobile layout, participant filters, conflicts, restore, viewer access and revocation.


## Import shared travel links and itineraries

On Android, use another app's **Share → Numi** action. Cold-start and already-open
shares are queued locally until their review screen is dismissed. In Travel,
**Import share link** also accepts pasted links or itinerary text on other app
platforms. Select a trip, choose a saved place, activity, or transport/stay draft,
then review the normal editor before saving. No import creates a payment or
marks a reservation confirmed. A missing participant list still means Everyone.

The owner-authenticated `POST /expenses/api/travel/import-preview/` accepts
`{text, url}` and only returns draft metadata. It reads public Airbnb, Trip.com,
and Google Maps pages, follows validated short-link redirects, and extracts
structured place/reservation metadata, available hotel name/address elements,
and explicit date parameters. Google Maps place/search URLs are also understood.
Dates in hotel URLs can be search dates and must be reviewed. Login-only pages,
CAPTCHAs, or unavailable metadata leave the original text/link available for
manual completion; private order details are not fetched using the user's account.

Flight/Train/Bus reservation metadata and labelled multi-leg text return separate
`items` for sequential review. Text such as `Flight: SQ638`, `From: SIN`, `To: NRT`,
`Departure: 2026-10-06 23:55`, `Arrival: 2026-10-07 07:30` is supported, as are
`Venue: ...` / `Date/time: 10 October 2026 11:00` event shares. Missing years,
booking numbers, prices, and timezone guesses are not inferred. This is bounded
metadata/text extraction, not an LLM or a guarantee that every Trip.com order or
travel-guide format can be parsed. Screenshot/PDF and iOS share extensions are not
included in this version.

Remote fetching is HTTPS-only, uses explicit provider domains, rejects private
DNS results, pins the validated address with TLS hostname verification, and
rechecks each redirect. It sends no Numi/nginx cookies or authorization headers.
Responses are size/time bounded and are never persisted until reviewed by the user.

### Trip map

Open the map button on an app trip, or the **Map** tab in its collaborative web
workspace. Filter by day, destination and traveller; empty participants still mean
Everyone. Stays remain visible through checkout. Saved places can be included for
planning, and a saved place already represented by an activity appears only once.
Transport can have separate departure and arrival pins.

Google Maps imports retain explicit place coordinates, including resolved short
links. Structured venue metadata can also supply coordinates. Viewport centres
(`@lat,lng`, `ll`) and ambiguous multi-place links are not venue locations. Existing
places without coordinates appear in **to locate**; paste a Google Maps place share
link under **Locate**. Editors can change pins collaboratively, with the same
revision conflict handling as other fields. Viewers can explore but cannot edit.

Numbered pins correspond to the list. Select a place to compare straight-line
kilometres; **Directions from selected** opens Google Maps for actual routes and
travel times. The basemap is OpenStreetMap with visible attribution, standard tile
caching, no prefetch and an identified native client. Shared web tile requests send
only the site origin as referrer, never invitation tokens or trip paths. No Google
Maps API key is needed. An unavailable basemap does not hide place details.

### PDF tickets

Use **Select PDF** in the app's travel import screen, Android's **Share → Numi**,
or **Import PDF** in the collaborative web workspace. Preview is read-only: inspect
the extracted text, choose the trip and review each proposed activity or transport
leg before saving. No payment is recorded. An existing activity or booking can
also receive an original PDF attachment without creating another arrangement.

Original bytes are stored once per trip and SHA-256 hash in `TravelDocument`;
plan items reference `documentId` / `documentName`. Files stay behind the owner's
normal login or an active invitation for the same trip. Editors can upload;
viewers can download. Invitations also grant access to the ticket's full contents.
Files are downloaded as attachments, never published under an unauthenticated
media URL. Removing a plan item retains its original for history restoration;
deleting the trip removes its documents. App tickets already opened are retained
in private application storage for offline use.

Maximum PDF size is 10 MiB, with 1–20 pages. Selectable text is extracted first;
up to five scanned pages use local Tesseract OCR (English, simplified Chinese,
Japanese) within a bounded worker timeout. No document is sent to an external AI
service. Ambiguous or missing dates remain empty; OCR and incomplete extraction
show a review warning. Password-protected or damaged files must be replaced with
readable PDFs. The preview displays at most 15,000 characters and saved notes at
most 10,000; the attached original is unchanged.

Deployment requires migration `0011_traveldocument`, the PDFium/Pillow requirements,
and the Tesseract packages in the Dockerfile. Set nginx `client_max_body_size 12M`
to allow a 10 MiB file plus multipart overhead, preserving existing login rules.
PDF bytes are included in the normal SQLite backup. Tests use generated tickets;
OCR regression runs in the Docker image where the OCR language packs are installed.
