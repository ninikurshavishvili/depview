# Records Assets/tree.png for the README, at 2x so it stays sharp on Retina screens.
# Setup is in demo.tape. Then, from the depview folder: vhs Assets/tapes/tree.tape

Output .build/vhs/tree.gif

Set Shell "zsh"
Set FontFamily "Menlo"
Set FontSize 40
Set LineHeight 1.2
Set Width 2080
Set Height 2780
Set Padding 56
Set Theme "Catppuccin Mocha"
Set WindowBar Colorful
Set WindowBarSize 60
Set BorderRadius 24
Set TypingSpeed 40ms
Set WaitPattern /❯\s*$/

# A clean shell with a short prompt, so no user or host name shows up.
Hide
Type `exec env -i HOME="$HOME" PATH="$PATH" TERM="$TERM" LANG=en_US.UTF-8 zsh -f`
Enter
Type `PROMPT='%F{blue}IceCubesApp%f %F{magenta}❯%f ' && cd ~/Developer/IceCubesApp && clear`
Enter
Show

Type "depview tree"
Enter
Wait@60s
Sleep 500ms
Screenshot Assets/tree.png
