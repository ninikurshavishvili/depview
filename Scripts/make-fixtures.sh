#!/usr/bin/env bash
# Rebuilds the JSON fixtures in Tests/DepViewCoreTests/Fixtures from real
# `swift package show-dependencies --format json` output.
#
# Run it when SwiftPM changes its JSON format, then review the diff and run
# swift test. If a snapshot changes on purpose, delete its file in Fixtures
# and run swift test again to write a new one.
#
# Usage: Scripts/make-fixtures.sh
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd -P)"
fixtures="$repo/Tests/DepViewCoreTests/Fixtures"
# pwd -P resolves /var to /private/var, the path SwiftPM prints.
work="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$work"' EXIT

# Every local path is rewritten to this made-up folder, so no real home
# folder ends up in the repo.
fake="/Users/dev/Projects"

# save <package folder> <path to hide> <replacement> <fixture name>
save() {
    (cd "$1" && swift package show-dependencies --format json) \
        | sed -n '/^{/,$p' \
        | sed "s|$2|$3|g" > "$fixtures/$4.json"
    echo "Wrote Fixtures/$4.json"
}

# library <folder> <name> [<dependency>...]: a package with one library
# target that uses each dependency's product of the same name.
library() {
    local folder="$1" name="$2"
    shift 2
    local deps="" uses=""
    for dep in "$@"; do
        deps+=".package(path: \"../$dep\"), "
        uses+=".product(name: \"$dep\", package: \"$(echo "$dep" | tr '[:upper:]' '[:lower:]')\"), "
    done
    mkdir -p "$folder/Sources/$name"
    cat > "$folder/Package.swift" <<EOF
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "$name",
    products: [.library(name: "$name", targets: ["$name"])],
    dependencies: [$deps],
    targets: [.target(name: "$name", dependencies: [$uses])]
)
EOF
    echo "public let \`$name\` = 1" > "$folder/Sources/$name/$name.swift"
}

swift --version 2>&1 | sed -n 1p

# spm-tiny: depview itself, with the versions pinned in Package.resolved.
save "$repo" "$repo" "$fake/depview" spm-tiny

# spm-shared: local packages where Logging is used by both Networking and Analytics.
#   App -> Networking -> Logging
#   App -> Analytics  -> Logging
library "$work/Logging" Logging
library "$work/Networking" Networking Logging
library "$work/Analytics" Analytics Logging
library "$work/App" App Networking Analytics
save "$work/App" "$work" "$fake" spm-shared

# spm-medium: a real open-source graph. Its packages share
# swift-issue-reporting (formerly xctest-dynamic-overlay) and
# swift-concurrency-extras. swift-dependencies is pinned, but the packages it
# uses resolve to the newest versions allowed, so rerunning this can change
# their versions.
mkdir -p "$work/Medium/Sources/Medium"
cat > "$work/Medium/Package.swift" <<'EOF'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Medium",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", exact: "1.17.2")
    ],
    targets: [
        .target(name: "Medium", dependencies: [
            .product(name: "Dependencies", package: "swift-dependencies")
        ])
    ]
)
EOF
echo "import Dependencies" > "$work/Medium/Sources/Medium/Medium.swift"
save "$work/Medium" "$work" "$fake" spm-medium
