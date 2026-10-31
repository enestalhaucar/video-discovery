# Video Discovery

A SwiftUI app to browse, search, favourite and play videos from a remote catalogue.

| Discover | Favourites | Video Details | Dark mode |
|---|---|---|---|
| <img src="docs/screenshots/discover.png" width="190" alt="Discover feed"> | <img src="docs/screenshots/favourites.png" width="190" alt="Favourites list"> | <img src="docs/screenshots/detail.png" width="190" alt="Video Details playing"> | <img src="docs/screenshots/discover-dark.png" width="190" alt="Discover in dark mode"> |

## What the brief asked for, and where it lives

| Brief | How it works |
|---|---|
| Catalogue in one HTTP request | `DiscoverModel.load()` runs once from `RootView`; retry only after a failure |
| Show 3, reveal up to 3 more while scrolling, from fetched data | `revealMore()` widens a window over the fetched array when the feed's footer scrolls into view: 3 → 6 → 8 |
| Search titles across the whole catalogue | `displayedVideos` filters every fetched title, including ones not revealed yet |
| Open details, add or remove favourites from Discover | Card → detail push; heart on the card (it never triggers navigation) and in the detail toolbar |
| Favourites: list, remove, same detail screen | Inset list, newest first; swipe to remove or tap the heart; rows push the same `VideoDetailView` |
| Favourites consistent across tabs and persisted | One `FavoritesStore` in the environment, saved as JSON in Application Support |
| Each tab keeps its navigation state | Each tab's `NavigationStack` path lives in `RootView` |
| Title, category, description; remote video with custom controls | `AVPlayerLayer` with SwiftUI controls: scrubber, times, ±10 s, play/pause |
| Loading and playback-failure feedback | Spinner, delayed buffering spinner, "Can’t play this video" with Try again |
| Pause on leaving the screen, switching tabs, backgrounding | `onDisappear`, an `isTabActive` environment value and `scenePhase` |
| Loading, empty and error states with retry | Skeleton cards, "No videos yet", "Couldn’t load videos" with Try again, "No results" |
| SwiftLint in the build, config in the repo | Run Script build phase + `.swiftlint.yml` (0 violations, `--strict`) |
| Two focused unit tests | `DiscoverModelTests`, `FavoritesStoreTests` (Swift Testing), plus player-state, cache, snapshot and UI tests |

Added after testing on a device: the video starts when its detail screen first opens, pinch to
zoom, a full-screen player that follows the phone into landscape, and a media cache that lasts for
the session.

## Setup

- Xcode 16 or later (the project uses the Xcode 16 format). Built and tested with Xcode 27 on the
  iOS 27 simulator and an iPhone 15 Pro; the deployment target is iOS 17.
- SwiftLint: `brew install swiftlint`. It runs as a build phase; without it the build prints a
  warning and carries on.
- Open `VideoDiscovery.xcodeproj`, pick the `VideoDiscovery` scheme and an iPhone simulator, and run.
  No third-party dependencies. On a device, choose your own team under Signing & Capabilities.
- Tests: ⌘U, or

  ```bash
  xcodebuild test -project VideoDiscovery.xcodeproj -scheme VideoDiscovery \
    -destination "platform=iOS Simulator,name=iPhone 17"
  ```

### Trying every state

Debug builds read two launch arguments (Edit Scheme › Run › Arguments):

| Argument | Values | Effect |
|---|---|---|
| `-catalog-stub` | `loaded`, `empty`, `error`, `slow` | Replaces the network with canned data |
| `-favorites` | `none`, `sample` | Starts with no favourites or three saved videos |

"Unavailable Preview" in the catalogue points at a URL that returns an error, so it shows the
playback failure state. Airplane mode shows the catalogue error.

## Architecture

1. One app target, organised by feature: `App`, `Core`, `Shared`, `Features/Discover`,
   `Features/Favorites`, `Features/VideoDetail`.
2. MVVM-lite: screen logic lives in `@Observable @MainActor` models (`DiscoverModel`, `PlayerModel`);
   views stay thin.
3. Networking and persistence sit behind small protocols (`CatalogServicing`, `FavoritesPersisting`)
   injected through initialisers, so tests use fakes.
4. `FavoritesStore` is created once and shared with both tabs through the environment.
5. Each tab's `NavigationStack` path lives in `RootView`, so switching tabs never resets a stack.

```
VideoDiscovery/
  App/                  entry point, tabs, orientation lock, debug launch options
  Core/                 Video, catalogue service, favourites store and persistence, media cache
  Shared/               design tokens (Theme, Motion) and reusable views
  Features/Discover/    DiscoverModel, feed, cards
  Features/Favorites/   saved videos
  Features/VideoDetail/ PlayerModel, player surface, stage overlays, controls, zoom, full screen
VideoDiscoveryTests/    unit, player-state, cache and snapshot tests
VideoDiscoveryUITests/  UI tests driven by the debug launch arguments
```

## Main decisions

- **One request, local paging.** The feed is a window over the fetched array. The next batch is
  revealed when a footer below the last card actually comes into view, so the first screen never
  reveals more before the user scrolls. Search ignores the window and shows every match.
- **Favourites keep a copy of each video**, so the Favourites tab works even when the catalogue
  request fails. Everything is keyed by `id`: two catalogue entries share one clip URL.
- **A custom player on `AVPlayerLayer`.** `VideoPlayer` ships system controls, so the controls are
  SwiftUI. `PlayerModel` is a small state machine (loading, ready, playing, paused, ended, failed)
  fed by Combine publishers on the main queue; pausing never hides an ended or failed state.
- **Pausing is explicit**: on disappear, when the tab stops being selected, and when the scene
  leaves the foreground. The video starts by itself only when its detail screen first opens; after
  a pause it waits for the user. The feed never autoplays.
- **Zoom and full screen.** Pinch the video to zoom (1×–3×, drag to pan, double-tap to reset). Full
  screen shares the same `PlayerModel`, opens in the current orientation and follows the phone into
  landscape with the system rotation animation; the rest of the app is portrait.
- **A session-scoped media cache.** Thumbnails stay in memory. A video is downloaded once: a resource
  loader feeds the player from that single download and keeps the bytes, which land in a temporary
  folder when the transfer completes, so opening it again (or retrying offline) plays the local file.
  The folder is emptied at every launch (iOS gives no callback on a force-quit), so nothing outlives
  the session. Error responses are never saved.
- **A small design system, applied as tokens.** The look ("Quiet Cinema") was designed as a design
  system first: light and dark colours, type, spacing, radii and a motion spec. Tokens live in
  `Shared/Theme.swift`, timings in `Shared/Motion.swift`, and views use no literal colours. The
  structure stays native (`NavigationStack`, `TabView`, `List`, SF Symbols). Every animation turns
  into a plain fade with Reduce Motion.
- **SwiftLint as a Run Script phase** rather than the SPM plugin: nothing to trust or download, and
  the project stays dependency-free.
- **Swift 6 language mode** with strict concurrency; iOS 17 APIs only, iOS 18 extras (the card →
  detail zoom transition) behind availability checks.
- **Folder-synchronised groups:** adding a file to a folder adds it to the target.

## Assumptions

- Search is case- and diacritic-insensitive, trims whitespace and isn't paged.
- The search field sits under the large title, as designed. On iOS 26 and later an always-visible
  system search drawer collapses the large title, so the field is a small view at the top of the
  feed. Navigation and tab bars are the system ones (Liquid Glass on iOS 26+).
- Favourites are listed newest first.
- Pull-to-refresh is left out: the brief asks for a single catalogue request, and retry covers
  failures.
- The catalogue decodes as a whole: a malformed entry shows the error state rather than a partial
  feed.
- An unreadable favourites file is moved aside (`favorites.corrupt.json`) instead of being
  overwritten by the next save.
- English (British spelling) and Turkish UI from `Localizable.xcstrings`; catalogue titles and
  descriptions come from the API and aren't translated. iPhone only.

## Tests

The brief asks for two focused tests; these two come first. Everything runs with ⌘U, without
network access.

- **The two focused tests** (Swift Testing):
  - `DiscoverModelTests`: the catalogue is requested once; the feed shows 3 → 6 → 8 videos from
    that data; search finds a video that hasn't been revealed yet.
  - `FavoritesStoreTests`: favourites toggled in one store are read back by a fresh store from the
    same file, starting from a missing folder whose name has a space (as Application Support does on
    a fresh install).
- **Player state**: `PlayerChromeTests` checks what the stage and control bar show for every
  phase × buffering combination, and the m:ss clock formatting.
- **Cache**: `CachingResourceLoaderTests` checks that one download serves playback and lands in the
  session folder, and that error responses are never saved (a stubbed `URLProtocol`).
- **Snapshots**: every screen state (feed, loading, error, empty, no results, favourites, empty
  favourites, player overlays, controls) in light and dark, rendered by a small in-repo helper and
  compared with references in `VideoDiscoveryTests/__Snapshots__`. They were recorded on an iPhone 17
  simulator with iOS 27.0 and are skipped, with a reason, on any other device, because rendering
  differs between models and OS versions.
- **UI tests** (`VideoDiscoveryUITests`): paging 3 → 6 → 8, search results and no results, error
  and retry, empty catalogue, loading skeleton, favourites (add from a card, remove by swipe or
  heart, empty state and Browse videos), opening a detail screen, and each tab keeping its stack.
  They drive the app through the debug launch arguments, so they don't depend on the network.

## AI usage

The brief encourages AI tools, so I worked with Claude Code as a small team and kept the decisions
with me:

- **Brief and plan first.** The case became a requirement list and a step plan before any code. I
  made the product and technical calls in one pass.
- **Adversarial reviews.** A separate agent tried to break the plan before implementation and each
  larger change after it. Its findings became rules or fixes, for example creating Application
  Support before writing, delivering AVFoundation callbacks on the main queue, and a scrubber that
  stuttered on short clips.
- **Design.** I designed the screens and the "Quiet Cinema" design system in Claude Design. A first
  native-only pass is visible in the history; the final screens follow the design system's tokens and
  motion spec.
- **Parallel implementation.** The riskiest parts (player model, detail screen, media cache, and
  later the single-download cache, localisation and the test suites) were built by separate agents in
  their own git worktrees and merged once tests passed. Commits carry a
  `Co-Authored-By` line.
- **Testing.** I tested on the simulator and on an iPhone. Manual testing caught a bug the plan
  missed: favourites were saved but never loaded after a relaunch, because `URL.path()`
  percent-encodes the space in "Application Support". The favourites test now covers it.

## How the work went

The commit history follows this path; each step ended with green tests before the next began.

1. **Brief → requirement list.** Every line of the case became a numbered requirement, with the
   assumptions written down next to it.
2. **Plan and plan review.** Architecture and a step plan; a reviewer agent attacked the plan
   before any code (it caught, for example, the missing Application Support folder on first save).
3. **Walking skeleton.** Xcode project with SwiftLint in the build, then the catalogue service,
   the favourites store and their two unit tests (`326b2e3` → `89934c2`).
4. **Player model.** The playback state machine, built and tested on its own before any UI
   (`9b92e6a`).
5. **Screens, twice.** A first native-only pass (`f2c4d0f` → `edad491`), then the final
   "Quiet Cinema" design system as tokens and the screens restyled to it (`8509372` → `9822dec`).
6. **Device testing.** On an iPhone: autoplay on open, pinch to zoom, full screen that follows
   rotation, and a session media cache (`2780a3d` → `3020cce`). Manual testing also found the
   favourites path bug (`25c85c3`).
7. **Review and README.** A final adversarial review of the diff, its fixes, then this README
   (`996a5dc`, `261e1ad`).
8. **Finishing the gaps.** Instead of listing unfinished work, it was done: a single-download
   cache, English and Turkish localisation, and the player-state, snapshot and UI tests
   (`8c958b8` → `b11672f`).

## Time spent

About **4 h 10 min** in total, within the 5-hour limit. Taken from a stopwatch for the first part
and from commit times for the rest:

| Part | When | Time |
|---|---|---|
| Brief, plan, core logic, player, both design passes, device changes, first README (steps 1–7) | 30 Oct 23:20 – 31 Oct 02:00 | 2 h 40 min |
| Single-download cache, localisation, player-state, snapshot and UI tests (step 8) | 31 Oct 12:55 – 14:10 | 1 h 15 min |
| Final checks and this README | 1 Nov | 15 min |

The design iteration was the costliest part: the first pass was built native-only before the final
design system arrived, and its screens were then redone.
