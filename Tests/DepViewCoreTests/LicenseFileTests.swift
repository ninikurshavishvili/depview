import Foundation
import Testing
@testable import DepViewCore

struct LicenseFileTests {
    // The opening words of each license, wrapped the way license files wrap them.
    @Test(arguments: [
        ("MIT License\n\nCopyright (c) 2024 Someone", "MIT"),
        ("Copyright (c) 2024 Someone\n\nPermission is hereby granted, free of\ncharge, to any person", "MIT"),
        ("                                 Apache License\n                           Version 2.0, January 2004", "Apache-2.0"),
        ("Redistribution and use in source and binary forms, with or without modification,\n"
         + "are permitted provided that the following conditions are met:\n* Redistributions of source code", "BSD-2-Clause"),
        ("Redistribution and use in source and binary forms, with or without modification, are permitted. "
         + "* Neither the name of the copyright holder nor the names of its contributors", "BSD-3-Clause"),
        ("GNU GENERAL PUBLIC LICENSE\n Version 3, 29 June 2007", "GPL-3.0"),
        ("GNU LESSER GENERAL PUBLIC LICENSE\n Version 2.1, February 1999", "LGPL-2.1"),
        ("Mozilla Public License Version 2.0\n==================================", "MPL-2.0"),
        ("ISC License\n\nPermission to use, copy, modify, and/or distribute this software for any purpose", "ISC"),
        ("This is free and unencumbered software released into the public domain.", "Unlicense"),
        ("Boost Software License - Version 1.0 - August 17th, 2003", "BSL-1.0"),
    ])
    func recognizesLicense(_ text: String, _ license: String) {
        #expect(LicenseFile.identify(text) == license)
    }

    @Test func unknownTextIsNil() {
        #expect(LicenseFile.identify("Copyright 2024 Someone. All rights reserved.") == nil)
    }

    // Like swift-cmark's COPYING: its own BSD license, then MIT ones for code it bundles.
    @Test func firstLicenseInTheFileWins() {
        let text = """
            Copyright (c) 2014, John MacFarlane
            Redistribution and use in source and binary forms, with or without modification, are permitted.

            houdini.h is under this license:
            Permission is hereby granted, free of charge, to any person obtaining a copy
            """
        #expect(LicenseFile.identify(text) == "BSD-2-Clause")
    }

    @Test(arguments: ["LICENSE", "LICENSE.md", "License.txt", "LICENCE", "COPYING"])
    func readsTheLicenseFile(_ name: String) throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("MIT License\n".utf8).write(to: folder.appendingPathComponent(name))
        #expect(LicenseFile.license(inPackageAt: folder) == "MIT")
    }

    @Test func folderWithoutALicenseFile() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("# Readme".utf8).write(to: folder.appendingPathComponent("README.md"))
        #expect(LicenseFile.license(inPackageAt: folder) == nil)
        #expect(LicenseFile.license(inPackageAt: folder.appendingPathComponent("missing")) == nil)
    }
}
