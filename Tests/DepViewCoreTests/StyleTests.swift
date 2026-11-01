import Testing
@testable import DepViewCore

struct StyleTests {
    @Test func onInTerminal() {
        #expect(Style.automatic(noColor: false, isTerminal: true, environment: [:]).isEnabled)
    }

    @Test func offWhenPiped() {
        #expect(!Style.automatic(noColor: false, isTerminal: false, environment: [:]).isEnabled)
    }

    @Test func offWithNoColorFlag() {
        #expect(!Style.automatic(noColor: true, isTerminal: true, environment: [:]).isEnabled)
    }

    @Test(arguments: [["NO_COLOR": "1"], ["TERM": "dumb"]])
    func offFromEnvironment(_ environment: [String: String]) {
        #expect(!Style.automatic(noColor: false, isTerminal: true, environment: environment).isEnabled)
    }

    // no-color.org: an empty NO_COLOR doesn't count.
    @Test func emptyNoColorIsIgnored() {
        #expect(Style.automatic(noColor: false, isTerminal: true, environment: ["NO_COLOR": ""]).isEnabled)
    }

    @Test func wrapsTextOnlyWhenEnabled() {
        #expect(Style.ansi.cyan("1.0") == "\u{1B}[36m1.0\u{1B}[0m")
        #expect(Style.plain.cyan("1.0") == "1.0")
        #expect(Style.ansi.bold("") == "")
    }
}
