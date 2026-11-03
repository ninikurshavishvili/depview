import Foundation

/// Recognizes a package's license from the license file in its folder, without the network.
enum LicenseFile {
    /// The SPDX id of the license in `folder`'s LICENSE, LICENCE or COPYING file, e.g. "MIT".
    /// nil when there's no such file or depview doesn't recognize the text.
    static func license(inPackageAt folder: URL) -> String? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let files = names.filter { name in
            let lowercased = name.lowercased()
            return ["license", "licence", "copying"].contains { lowercased.hasPrefix($0) }
        }
        for name in files.sorted() {
            guard let data = FileManager.default.contents(atPath: folder.appendingPathComponent(name).path) else { continue }
            if let license = identify(String(decoding: data.prefix(16_384), as: UTF8.self)) { return license }
        }
        return nil
    }

    /// The SPDX id for a license text, found by a phrase from each license's own wording.
    /// A file can hold several licenses, its own first and then those of code it bundles,
    /// so the phrase that comes first wins.
    static func identify(_ text: String) -> String? {
        let text = text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        // Each phrase, and the license it means given the text that follows it.
        let rules: [(phrase: String, license: (Substring) -> String?)] = [
            ("apache license", { $0.prefix(200).contains("version 2.0") ? "Apache-2.0" : nil }),
            ("mozilla public license", { $0.prefix(100).contains("2.0") ? "MPL-2.0" : nil }),
            ("gnu lesser general public license", { $0.prefix(200).contains("version 3") ? "LGPL-3.0" : "LGPL-2.1" }),
            ("gnu general public license", { $0.prefix(200).contains("version 3") ? "GPL-3.0" : "GPL-2.0" }),
            ("boost software license", { _ in "BSL-1.0" }),
            ("free and unencumbered software released into the public domain", { _ in "Unlicense" }),
            ("mit license", { _ in "MIT" }),
            ("permission is hereby granted, free of charge", { _ in "MIT" }),
            ("permission to use, copy, modify, and/or distribute this software for any purpose", { _ in "ISC" }),
            // The third clause is the one that names the authors.
            ("redistribution and use in source and binary forms",
             { $0.prefix(1000).contains("neither the name") ? "BSD-3-Clause" : "BSD-2-Clause" }),
        ]
        var first: (position: String.Index, license: String)?
        for rule in rules {
            guard let range = text.range(of: rule.phrase), let license = rule.license(text[range.upperBound...]) else {
                continue
            }
            if first.map({ range.lowerBound < $0.position }) ?? true { first = (range.lowerBound, license) }
        }
        return first?.license
    }
}
