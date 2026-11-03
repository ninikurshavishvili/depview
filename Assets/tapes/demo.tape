# Records Assets/demo.gif for the README with vhs (brew install vhs).
# Before running it:
#   - put depview on your PATH, e.g. brew install ninikurshavishvili/tap/depview
#   - clone https://github.com/Dimillian/IceCubesApp to ~/Developer/IceCubesApp
#     and resolve its packages: xcodebuild -resolvePackageDependencies -project ~/Developer/IceCubesApp/IceCubesApp.xcodeproj
#   - run depview tree there once, so SwiftPM's manifest cache is warm
# Then, from the depview folder: vhs Assets/tapes/demo.tape
# The other tapes here record the README's screenshots the same way.
# Reading an Xcode project takes depview a few seconds; the GIF skips that wait
# (Hide ... Show) so the output isn't a blank screen. The output itself is unedited.

Output Assets/demo.gif

Set Shell "zsh"
Set FontFamily "Menlo"
Set FontSize 15
Set LineHeight 1.2
Set Width 1000
Set Height 1100
Set Padding 24
Set Theme "Catppuccin Mocha"
Set WindowBar Colorful
Set BorderRadius 10
Set TypingSpeed 60ms
Set WaitPattern /❯\s*$/

# A clean shell with a short prompt, so no user or host name shows up.
Hide
Type `exec env -i HOME="$HOME" PATH="$PATH" TERM="$TERM" LANG=en_US.UTF-8 zsh -f`
Enter
Type `PROMPT='%F{blue}IceCubesApp%f %F{magenta}❯%f ' && cd ~/Developer/IceCubesApp && clear`
Enter
Show

Type "depview tree"
Sleep 500ms
Enter
Hide
Wait@30s
Show
Sleep 5s

Type "clear"
Enter
Type "depview why SwiftSoup"
Sleep 500ms
Enter
Hide
Wait@30s
Show
Sleep 4s

Type "clear"
Enter
Type "depview stats"
Sleep 500ms
Enter
Hide
Wait@30s
Show
Sleep 5s
