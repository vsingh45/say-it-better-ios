# Say It Better (iOS)

A native SwiftUI rebuild of the Say It Better vocabulary app: 40 words that help an engineer sound
like a lead in meetings, grouped as **Process, Problems, Decisions, Speaking**.

- **Learn**: one card at a time with everything visible at once: word, pronunciation, definition,
  six "goes with" phrases, the example sentence with the word highlighted, and the "instead of
  saying…" swap. Tap the speaker to hear the word. **Still learning** puts the card back about three
  cards later; **I know this** marks it known.
- **Quiz**: 10 questions per round, alternating *fill the blank* and *say it better*, with
  same-part-of-speech distractors, a score at the end, and a history of recent rounds.
- **My words**: every known word A–Z with its phrases and example shown in the row, plus
  **Relearn**.
- **All words**: search (word, meaning, or the "instead of" phrase) with a known/learning toggle on
  each row.
- **Deep dive** (from any card or row): meaning, origin, word family, collocations, near-synonyms,
  a common mistake, examples by meeting setting, a memory tip, reference links, and a
  "write your own sentence" feedback box.

## Run it

Requirements: Xcode 16+, iOS 17+ simulator or device.

1. Open `SayItBetter.xcodeproj`. The project uses Xcode 16 folder-synced groups, so any file you add
   under `SayItBetter/` is picked up automatically.
2. Pick an iPhone simulator and press **Run**.
3. **Signing.** On a device, set your team under *Signing & Capabilities* and change the bundle ID
   from `com.example.SayItBetter` to one of your own. iCloud Key-Value sync needs a paid developer
   team. With a free Personal Team, delete the `CODE_SIGN_ENTITLEMENTS` build setting (or the iCloud
   capability). The app then keeps progress on the device only, with no code changes.

## How it's put together

```
SayItBetter/
  App/            SayItBetterApp (SwiftData container, environment), RootView (tab bar)
  Models/         Word (+ loader, example-sentence parsing), DeepDive, QuizResult (@Model)
  Store/          WordStore (@Observable: words, known set, shared category filter), FeedSession
  Services/       DeepDiveService (bundled deep dives), OnDeviceLookup (Apple's on-device model),
                  FeedBuilder, QuizBuilder, Speaker, ReferenceLinks
  Views/          Feed/, LearnView, QuizView, MyWordsView, AllWordsView, HeardWordsView, DeepDiveSheet,
                  SettingsView, Components/
  Resources/      words.json (the 40 words), deepdive.json (pre-generated deep dives)
```

- **Content is data.** To add words, append entries to `Resources/words.json` using the same shape.
  Wrap the target word in the `example` in `[brackets]`. Add a matching entry to `deepdive.json`, or
  look the word up from search to have it written on the iPhone.
- **Known words, Feed progress, quiz history and heard words** are stored with SwiftData, on the device.
- **Deep dive** first shows the bundled content right away. When the iPhone can run Apple's on-device
  model, a fuller version replaces it. Sentence feedback is also written on the device. Without the
  model, the app only checks that you used the word.
- **Word lookup** (search) uses the on-device model. It needs iOS 26 or later and Apple Intelligence.

