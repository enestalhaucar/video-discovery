# Video Discovery

A small SwiftUI app to browse, search, favourite and play videos from a remote catalogue.

## Setup

- Xcode 16 or later. Built and tested with Xcode 27 on the iOS 27 simulator; the deployment target
  is iOS 17.
- SwiftLint: `brew install swiftlint`. It runs as a build phase using `.swiftlint.yml`; if it isn't
  installed the build prints a warning and carries on.
- Open `VideoDiscovery.xcodeproj`, pick the `VideoDiscovery` scheme and an iPhone simulator, and run.
  There are no third-party dependencies and the simulator needs no signing.
- Tests: ⌘U in Xcode, or

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

The video "Unavailable Preview" points at a URL that returns an error, which shows the playback
failure state.

## Architecture

1. One app target, organised by feature: `App`, `Core`, `Shared`, `Features/Discover`,
   `Features/Favorites`, `Features/VideoDetail`.
2. MVVM-lite: screen logic lives in `@Observable @MainActor` models (`DiscoverModel`, `PlayerModel`);
   views stay thin.
3. Networking and persistence sit behind small protocols (`CatalogServicing`, `FavoritesPersisting`),
   injected through initialisers, so tests use fakes.
4. `FavoritesStore` is created once and shared with both tabs through the environment, so a heart
   toggled anywhere is reflected everywhere.
5. Each tab has its own `NavigationStack` whose path lives in `RootView`, so switching tabs keeps
   each stack where it was.

```
VideoDiscovery/
  App/                 entry point, tabs, debug launch options
  Core/                Video, catalogue service, favourites store and persistence
  Shared/              design tokens and reusable views
  Features/Discover/   DiscoverModel, feed, search
  Features/Favorites/  saved videos
  Features/VideoDetail/ PlayerModel, player surface, custom controls
VideoDiscoveryTests/   the two unit tests and a mock service
```

## Main decisions

- **One request, local paging.** `DiscoverModel` fetches the catalogue once, shows three videos and
  reveals up to three more from memory when the bottom of the feed comes into view. Search filters
  titles across the whole catalogue, including videos not revealed yet, and shows every match.
- **Favourites keep a copy of each video** as JSON in Application Support. The Favourites tab works
  even when the catalogue request fails, and everything is keyed by `id` (two catalogue entries share
  the same clip URL).
- **Custom player on `AVPlayerLayer`.** `VideoPlayer` ships its own system controls, so the screen
  uses an `AVPlayerLayer` with SwiftUI controls. `PlayerModel` is a small state machine (loading,
  ready, playing, paused, ended, failed) fed by Combine publishers delivered on the main queue.
- **Pausing is explicit.** The detail screen pauses on disappear, when its tab stops being the
  selected one (an environment value set by `RootView`) and when the scene leaves the foreground.
  Nothing autoplays.
- **The catalogue load starts at the root**, so switching tabs during the first request can't cancel
  it.
- **A small design system, applied as tokens.** The look ("Quiet Cinema") was designed first as a
  design system: colours for light and dark, type styles, spacing, radii and a motion spec. Its
  tokens live in `Shared/Theme.swift` and its timings in `Shared/Motion.swift`; views never use
  literal colours. The structure stays native (`NavigationStack`, `TabView`, `List`, `.searchable`,
  SF Symbols). Discover uses large 16:9 cards: with small rows, three videos don't fill the screen
  and the next batch would appear without scrolling. Motion turns into plain fades with Reduce Motion.
- **SwiftLint as a Run Script phase** rather than the SPM build-tool plugin: no package to trust or
  download, and the project stays dependency-free.
- **Swift 6 language mode** with strict concurrency, iOS 17 APIs only.
- **Folder-synchronised groups** (Xcode 16 project format): adding a file to a folder adds it to the
  target, with no project file edits.

## Assumptions

- Search is case- and diacritic-insensitive, trims whitespace and isn't paged.
- Paging triggers when a footer below the last card actually scrolls into view, so the first screen
  doesn't reveal the next batch before the user scrolls.
- Search stays visible under the large title, as designed. On iOS 26 and later an always-visible
  system search drawer collapses the large title, so the field is a small `SearchField` view at the
  top of the feed. Navigation and tab bars are the system ones, so they take each iOS version's own
  look (Liquid Glass on iOS 26+) and keep swipe-back.
- Favourites are listed newest first.
- No autoplay on the detail screen, and no automatic resume after a pause.
- Pull-to-refresh is left out: the brief asks for a single catalogue request, and retry covers
  failures.
- English UI with British spelling ("Favourites"), iPhone only.
- The catalogue decodes as a whole: a malformed entry shows the error state with retry rather than a
  partial feed.
- An unreadable favourites file is moved aside (`favorites.corrupt.json`) instead of being
  overwritten by the next save.

## Tests

The brief asks for two focused tests; both use Swift Testing.

- `DiscoverModelTests`: the catalogue is requested once; the feed shows 3 → 6 → 8 videos from that
  data; search finds a video that hasn't been revealed yet.
- `FavoritesStoreTests`: favourites toggled in one store are read back by a fresh store from the
  same file, starting from a folder that doesn't exist yet (as on a fresh install).

## AI usage

The brief encourages AI tools, so I worked with Claude Code (Claude Opus 5.5) as a small team and
kept the decisions with me:

- **Brief and plan first.** The case was turned into a requirement list and a step plan before any
  code. I made the product and technical calls in one pass (architecture, persistence, SwiftLint
  setup, what to leave out).
- **Adversarial plan review.** A separate agent tried to break the plan before implementation. Its
  findings became rules for the code, for example: create Application Support before writing, deliver
  AVFoundation callbacks on the main queue, and don't let the feed reveal the next batch before the
  user scrolls.
- **Design.** I designed the screens and a small design system ("Quiet Cinema") in Claude Design,
  iterated once (a first native-only pass is visible in the history) and then implemented the
  system's tokens and motion spec exactly.
- **Parallel implementation.** The riskiest parts (the player model, the detail screen UI) were built
  by separate agents in their own git worktrees and merged once the tests passed; the rest was built
  step by step in the main checkout. Commits carry a `Co-Authored-By` line.
- **Review and testing.** I reviewed every change and tested on the simulator. Manual testing caught
  one bug the plan missed: favourites were saved but never loaded after a relaunch, because
  `URL.path()` percent-encodes the space in "Application Support". The favourites test now uses a
  folder name with a space and failed before the fix.

## Time spent

_Filled in at submission._

## Unfinished work and next steps

- **Image caching.** `AsyncImage` only uses the shared URL cache; a small image cache would make
  thumbnails instant when scrolling back.
- **UI and snapshot tests** for each screen state. The debug launch arguments are already there to
  drive them.
- **Larger layouts.** The app is iPhone and portrait only for now; landscape and iPad would need
  their own layouts (a grid, and a detail screen that fits the video beside the controls).
- **Player extras:** Picture in Picture, AirPlay and remembering the playback position.
- **Localisation.** Strings are English only and not yet in a String Catalog.
- Only verified on the iOS 27 simulator with Xcode 27; not run on an iOS 17 device.
