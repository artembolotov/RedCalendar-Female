# App Store screenshots

Raw screenshots of the real app, built from mock data, for every language × light/dark. Laying
them out on marketing cards is a separate step.

```bash
Tools/AppStoreScreenshots/capture.sh          # Russian
Tools/AppStoreScreenshots/capture.sh ru en    # both languages
```

The result lands in `Tools/AppStoreScreenshots/Output/<device>/<lang>/<light|dark>/NN-scene.png`
(git-ignored): 1206×2622 on the iPhone 18 Pro simulator (the default). One run takes about two
minutes per language.

Another device is `DEVICE_NAME="…"` (see Options); its shots go under its own folder.

## What the script does

1. Applies `hooks.patch` and copies `ScreenshotMode.swift` into `RedCalendar-Female/App/`.
2. Builds `RedCalendar-Staging` / `Debug-Staging` for the simulator.
3. **Takes both out again** — right after the build, and also if the build fails or the run is
   interrupted. The working tree ends up exactly as it was; nothing needs reverting by hand.
4. Boots the simulator, sets the status bar to 9:41 / full signal / 100%, installs the app.
5. For each language and scene: launches the app with `-ScreenshotMode YES -ScreenshotScene …
   -AppleLanguages (…)`, waits, takes a light screenshot, switches the simulator to dark
   (`simctl ui appearance`), takes a dark one.

## How the mock works

`ScreenshotMode.swift` is used only while the app is launched with `-ScreenshotMode YES`:

- **Today is 8 April 2026** — `Daystamp.today` returns it, and every "today" in the app goes
  through that one function.
- **The database is recreated on every launch**: the file is deleted, `DatabaseService` creates
  and migrates it, and then the mock rows are written over a second connection — cycles, flow
  levels, tags, day tags, comments and the profile (Анна / Anna, anna@example.com, 28/5).
  Tag names and comments follow the launch language.
- **Sign-in is faked** with `.auth(.set(.authenticated(…)))`, and the store gets a reduced
  middleware list: no auth, sync, push, consent, migration or analytics. Nothing goes to the
  network, AppMetrica is not activated, and the notification permission alert never appears.
- **A scene** chooses which day is selected (dispatched 1.5s after launch, like a tap) and which
  sheet to open: the statistics/settings sheet in `HomeView`, the tags/comment sheet in
  `DayDetailsView`.

### The data

- 13 cycles, the last one started on 25 March. Intervals and periods vary by a day
  (`cycleIntervals`, `periodLengths`) so the statistics chart has something to show, and their
  medians are exactly 28 and 5. For perfectly identical cycles, set every value to 28 and 5.
- 8 April is cycle day 15 and the predicted ovulation day, inside the fertile window. The next
  period is forecast for 22–26 April. Four past cycles have a confirmed ovulation.
- 22 tags in four colour groups: symptoms (blue), mood (green), activity (teal),
  medications (purple). The two most recent cycles are tagged day by day; older ones follow a
  template.

### Scenes

| # | Scene        | What is on screen |
|---|--------------|-------------------|
| 1 | `calendar`   | Calendar, today (8 April) selected, the day card with tags and a comment |
| 2 | `period`     | 26 March: period day 2, flow, tags, comment |
| 3 | `tags`       | Tag picker over 26 March — every group, some selected |
| 4 | `comment`    | Comment editor over today (keyboard shown) |
| 5 | `statistics` | Averages, cycle chart, history |
| 6 | `settings`   | Settings: notifications, the three accents |
|   | `empty`      | Calendar with nothing selected (not in the default list) |

## Options

```bash
SCENES="calendar tags statistics" Tools/AppStoreScreenshots/capture.sh ru
ACCENT=berry Tools/AppStoreScreenshots/capture.sh     # coral (default) | rose | berry
DEVICE_NAME="iPhone 18 Pro Max" Tools/AppStoreScreenshots/capture.sh
OUTPUT=~/Desktop/shots Tools/AppStoreScreenshots/capture.sh
```

To change the data, edit `ScreenshotMode.swift` **in this folder** (never the copy in the target —
it only exists during the build) and run the script again. A new scene is a new `Scene` case plus
a line in `SCENES`; if it needs a sheet, hook it in the same way as the existing ones.

## Looking at a scene by hand

Run the script once, then:

```bash
xcrun simctl launch "iPhone 18 Pro" ru.artembolotov.RedCalendar-Woman -ScreenshotMode YES -ScreenshotScene period -AppleLanguages "(ru)" -AppleLocale ru_RU
```

From there you can tap around the app freely — for example to open the ovulation editor, which
has no scene of its own — and take a screenshot with
`xcrun simctl io "iPhone 18 Pro" screenshot shot.png`. Without `-ScreenshotMode` the installed
build behaves like an ordinary Staging build — the hooks do nothing unless the flag is passed.

## If the patch stops applying

The script stops before building with `hooks.patch no longer applies`. That means the code
around one of the hooks has changed. The hooks are small; apply them by hand, then regenerate the
patch:

| File | Hook |
|------|------|
| `Core/Models/Daystamp.swift` | first line of `today(calendar:)`: `if let today = ScreenshotMode.today { return today }` |
| `App/AppDelegate.swift` | before `Configurator.shared.setup()`: `if ScreenshotMode.isActive { ScreenshotMode.launch(); return true }` |
| `App/Configurator.swift` | before `analytics.registerApp()`: `guard !ScreenshotMode.isActive else { return }` |
| `Core/Redux/AppMiddleware.swift` | first line of `combineAppMiddlewares()`: `if ScreenshotMode.isActive { return ScreenshotMode.middlewares }` |
| `Features/Home/HomeView.swift` | after `.onAppear(perform: openSettingsIfEmailPending)`: `.task { if let sheet = await ScreenshotMode.menuSheet() { menuSheet = sheet } }` |
| `Features/Home/DayDetailsView.swift` | after `.onPreferenceChange(DayCardClippedKey.self)`: a `.task` that switches on `await ScreenshotMode.daySheet(isSelectedCard: isActive && store.state.calendarState.selectedDayStamp == dayStamp)` and sets `showTagsSheet` / `showCommentSheet` |

```bash
cp Tools/AppStoreScreenshots/ScreenshotMode.swift RedCalendar-Female/App/
# … apply the hooks by hand, build once to check …
git diff -- RedCalendar-Female/App/AppDelegate.swift RedCalendar-Female/App/Configurator.swift \
  RedCalendar-Female/Core/Models/Daystamp.swift RedCalendar-Female/Core/Redux/AppMiddleware.swift \
  RedCalendar-Female/Features/Home/HomeView.swift RedCalendar-Female/Features/Home/DayDetailsView.swift \
  > Tools/AppStoreScreenshots/hooks.patch
git checkout -- RedCalendar-Female && rm RedCalendar-Female/App/ScreenshotMode.swift
```

Careful: `git checkout -- RedCalendar-Female` throws away **every** uncommitted change in the
target. If you have edits of your own, revert only the six files listed above.
