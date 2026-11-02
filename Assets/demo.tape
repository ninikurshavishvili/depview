# Records Assets/demo.gif for the README with vhs (brew install vhs).
# Before running it:
#   - put depview on your PATH, e.g. brew install ninikurshavishvili/tap/depview
#   - clone https://github.com/Dimillian/IceCubesApp to ~/Developer/IceCubesApp
#     and resolve its packages: xcodebuild -resolvePackageDependencies -project ~/Developer/IceCubesApp/IceCubesApp.xcodeproj
#   - run depview tree there once, so SwiftPM's manifest cache is warm
# Then, from the depview folder: vhs Assets/demo.tape

Output Assets/demo.gif

Set Shell "zsh"
Set FontSize 18
Set Width 1200
Set Height 760
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 60ms

Hide
Type "cd ~/Developer/IceCubesApp && clear"
Enter
Show

Type "depview tree --depth 2"
Sleep 500ms
Enter
Wait
Sleep 3s

Type "clear"
Enter
Type "depview why SQLite.swift"
Sleep 500ms
Enter
Wait
Sleep 2s

Type "depview why ButtonKit"
Sleep 500ms
Enter
Wait
Sleep 2s

Type "depview stats"
Sleep 500ms
Enter
Wait
Sleep 4s
