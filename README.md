# depview

**Why is this library in my app?** depview prints the Swift package dependency tree of a package or an Xcode app project in your terminal, and tells you what pulls each package in and where to remove it.

![depview tree and depview why on Ice Cubes, an open-source Mastodon app](Assets/demo.gif)

Xcode shows your packages as a flat list. depview shows who depends on whom, and answers the question directly:

```
$ depview why SwiftSoup
SwiftSoup 2.13.9  MIT
Pulled in by 214 paths, and every one goes through Models.
Only Models uses it directly, so that's where to remove SwiftSoup.

  IceCubesApp → Models → SwiftSoup
  IceCubesApp → AppAccount → Models → SwiftSoup
  IceCubesApp → Account → Models → SwiftSoup
  IceCubesApp → Conversations → Models → SwiftSoup
  IceCubesApp → DesignSystem → Models → SwiftSoup
  …and 209 more. Pass --all to list them.
```

## Install

```bash
brew install ninikurshavishvili/tap/depview
```

Homebrew builds depview on your Mac, so it needs Xcode 16 or later. depview runs on macOS 13 or later.

To build it yourself:

```bash
git clone https://github.com/ninikurshavishvili/depview.git
cd depview
swift build -c release
.build/release/depview --help
```

## Usage

Every command takes the project as its last argument: a folder with `Package.swift`, an `.xcodeproj` or an `.xcworkspace`. Without one, depview uses the current folder.

### tree

Prints the dependency tree, with a summary next to the project's name.

```
$ depview tree ~/Developer/IceCubesApp
IceCubesApp  31 packages · 16 direct · 9 levels · 1 on a branch
├── KeychainSwift 24.0.0
├── SFSafeSymbols 7.0.0
├── wishkit-ios 5.2.1                   +1
│   └── wishkit-ios-shared 1.5.0
├── RevenueCat 5.89.0
├── AppAccount
│   ├── NetworkClient
│   │   └── Models                      +1
│   │       └── SwiftSoup 2.13.9
│   ├── Env                             +1
│   │   ├── TelemetryDeck 2.14.2
│   │   └── ↑ Models, NetworkClient, KeychainSwift
│   ├── DesignSystem                    +5
│   │   ├── Nuke 13.2.0
│   │   ├── EmojiText branch fix-ios26  +2
│   │   │   └── swift-markdown 0.8.0    +1
│   │   │       └── cmark-gfm 0.8.0
│   │   ├── Gifu 4.0.1
│   │   └── ↑ Models, Env
│   └── ↑ Models
…
```

- **Each package is shown once.** When it comes up again, it joins the `↑` line under that parent instead of being printed again.
- **`+N`** counts the packages that are there only because of that one: remove it, and they go too. DesignSystem's `+5` are Nuke, EmojiText and what it uses, and Gifu.
- **Colors:** your own local packages are magenta, releases cyan, and a package that follows a branch or a single commit is yellow, because it can change without a new version.

`--depth <n>` stops after n levels, `--no-versions` hides versions, and `--no-color` turns colors off. Colors are also off when the output goes to a file or a pipe, or when `NO_COLOR` is set.

### why

Answers why a package is in your project: how many paths pull it in, which packages every one of them goes through, and who uses it directly. Then it lists the shortest paths.

```
$ depview why ButtonKit
ButtonKit 0.8.1  MIT
Pulled in by 3 paths, and every one goes through Account.
Only Account uses it directly, so that's where to remove ButtonKit.

  IceCubesApp → Account → ButtonKit
  IceCubesApp → Explore → Account → ButtonKit
  IceCubesApp → Lists → Account → ButtonKit
```

It takes a package's name or identity, ignoring case, and suggests close matches when there's no such package. It lists the 5 shortest paths; `--all` lists every one.

### stats

```
$ depview stats
IceCubesApp
Packages      31: 16 direct, 15 through other packages
From          13 local, 18 downloaded
Max depth     9
Most shared   Models, used by 13 packages
Licenses      MIT 14, Apache-2.0 2, BSD-2-Clause 1, unknown 1

Heaviest direct dependencies, by packages only they bring in
  DesignSystem  ████████████████████ 5
  Timeline      ████████████ 3
  Account       ████████ 2
  StatusKit     ████████ 2
  Env           ████ 1

Watch out
  EmojiText follows branch fix-ios26, not a release.
```

Licenses come from each downloaded package's license file, so depview needs no network for them. A file it doesn't recognize, or no file at all, counts as unknown; depview never guesses. It's a starting point for a license review, not legal advice.

`--json` prints the same numbers as JSON.

### export

Writes the graph as [Mermaid](https://mermaid.js.org) (the default), [DOT](https://graphviz.org) or JSON, to the terminal or to a file with `-o`.

```bash
depview export --format mermaid -o dependencies.mmd
depview export --format dot | dot -Tsvg -o dependencies.svg
depview export --format json
```

The JSON lists every package once with its version, how that version was chosen (`release`, `branch` or `commit`), its URL, license and dependencies.

GitHub draws Mermaid diagrams in Markdown files, so you can paste the output into a README between ` ```mermaid ` fences.

## Xcode projects

For Swift packages, depview asks SwiftPM (`swift package show-dependencies`), which first downloads any packages it hasn't resolved yet. Xcode projects have no such command, so depview puts the graph together from:

- **project.pbxproj:** the packages your project adds, and the package folders in its navigator that a target links.
- **Package.resolved:** the version of each package.
- **DerivedData:** the packages Xcode downloaded. depview reads each one's `Package.swift` with `swift package dump-package` to find which packages it uses. Like SwiftPM, it leaves out dependencies that only tests or turned-off traits need.

So Xcode has to download the packages first. Open the project in Xcode once, or run:

```bash
xcodebuild -resolvePackageDependencies -project MyApp.xcodeproj
```

Until then, depview shows only your direct dependencies, with a warning. If you built with `xcodebuild -derivedDataPath <folder>`, pass the same folder with `--derived-data <folder>`.

For Xcode projects, depview doesn't download anything or change the project, so it works offline.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Something to fix on your side, like a wrong path or an unknown package name |
| 2 | A tool depview runs failed, like `swift` |
| 64 | The command itself is wrong, like a missing argument |

Every error comes with a hint for fixing it.

## Coming next

- CocoaPods: reading `Podfile.lock`, so projects moving from CocoaPods to SwiftPM can see both.
- `depview browse`: an interactive screen to move through the tree, with details for the selected package.

## License

MIT. See [LICENSE](LICENSE).
