# Records Assets/demo.gif for the README with vhs (brew install vhs).
# Before running it:
#   - put depview on your PATH, e.g. brew install ninikurshavishvili/tap/depview
#   - clone https://github.com/Dimillian/IceCubesApp to ~/Developer/IceCubesApp
#     and resolve its packages: xcodebuild -resolvePackageDependencies -project ~/Developer/IceCubesApp/IceCubesApp.xcodeproj
#   - run depview tree there once, so SwiftPM's manifest cache is warm
# Then, from the depview folder: vhs Assets/demo.tape

Output Assets/demo.gif

Set Shell "zsh"
Set FontSize 15
Set Width 1100
Set Height 1000
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 60ms

Hide
Type "cd ~/Developer/IceCubesApp && clear"
Enter
Show

Type "depview tree"
Sleep 500ms
Enter
Wait
Sleep 5s

Type "clear"
Enter
Type "depview why SwiftSoup"
Sleep 500ms
Enter
Wait
Sleep 4s

Type "clear"
Enter
Type "depview stats"
Sleep 500ms
Enter
Wait
Sleep 5s
