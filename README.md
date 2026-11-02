# depview

**Why is this library in my app?** depview prints the Swift package dependency tree of a package or an Xcode app project in your terminal, and shows every path that pulls a package in.

![depview tree and depview why on Ice Cubes, an open-source Mastodon app](Assets/demo.gif)

Xcode shows your packages as a flat list. depview shows who depends on whom:

```
$ depview why SQLite.swift
SQLite.swift 0.16.0 is pulled in by 1 path:
  IceCubesApp → Timeline → Bodega → SQLite.swift
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

Prints the dependency tree. A package that's already been shown is marked `(seen above)` instead of being printed again.

```
$ depview tree ~/Developer/IceCubesApp --depth 2
IceCubesApp
├── KeychainSwift 24.0.0
├── SFSafeSymbols 7.0.0
├── wishkit-ios 5.2.1
│   └── wishkit-ios-shared 1.5.0
├── RevenueCat 5.89.0
├── AppAccount
│   ├── NetworkClient
│   ├── Models
│   ├── Env
│   └── DesignSystem
…
```

`--depth <n>` stops after n levels, `--no-versions` hides versions, and `--no-color` turns colors off. Colors are also off when the output goes to a file or a pipe, or when `NO_COLOR` is set.

### why

Shows every path from your project to a package, shortest first. It takes a package's name or identity, ignoring case, and suggests close matches when there's no such package.

```
$ depview why ButtonKit
ButtonKit 0.8.1 is pulled in by 3 paths:
  IceCubesApp → Account → ButtonKit
  IceCubesApp → Explore → Account → ButtonKit
  IceCubesApp → Lists → Account → ButtonKit
```

It lists the first 20 paths; `--all` lists every one.

### stats

```
$ depview stats
Packages:     31  (16 direct, 15 transitive)
Max depth:    9
Most shared:  Models (used by 13 packages)
```

`--json` prints the same numbers as JSON.

### export

Writes the graph as [Mermaid](https://mermaid.js.org) (the default), [DOT](https://graphviz.org) or JSON, to the terminal or to a file with `-o`.

```bash
depview export --format mermaid -o dependencies.mmd
depview export --format dot | dot -Tsvg -o dependencies.svg
depview export --format json
```

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

- CocoaPods: reading `Podfile.lock`, so projects moving from CocoaPods to SwiftPM can see both. depview 1.1 is planned for January 2027.

## License

MIT. See [LICENSE](LICENSE).
