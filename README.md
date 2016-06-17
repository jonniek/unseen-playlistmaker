
#MPV unseen-playlistmaker
-----------
This script keeps track of your watched files locally, and on keybind enters playlist-mode to watch unseen files.
  
####Default features:
* Marks file as seen into a text document when surpassing 80% duration.
* Keybind(w) manually marks file as watched.  
  
####Playlist-mode features:
* Immidiately load all your unwatched files into a playlist.
* Periodically continue to load new unwatched files into playlist(persists in idle).
* On file skip, appends it to the end of the playlist, allowing you to see files in the order you want.  

####Keybinds:
* playlist-mode-toggle(W) - Toggles playlist mode
* mark-seen(w)            - Marks file as seen
  
  
#####Setup:
1. Save lua in mpv/scripts folder.
2. Edit the scriptloc, fileloc and scan variables inside the lua.
3. Run `mpv --idle` to create the list.txt file in the scriptloc path you chose.
4. If the txt file is created the script is ready, try it with (W). If it isn't created, there is problems with permissions.
5. Read the comments on the lua if you want to change keybinds, timers etc.

#### My other mpv scripts
- https://github.com/donmaiq/Mpv-Playlistmanager
  - Does not work properly in combination with unseen-playlistmaker, use this combined script instead http://puu.sh/pwjZT/953f9a1e1a.lua
