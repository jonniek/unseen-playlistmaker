
#MPV unseen-playlistmaker
-----------
This script keeps track of your watched files locally, and on keybind enters playlist-mode to watch unseen files from a specified directory.
  
####Default features:
* Marks file as seen into a file when surpassing 80% duration.
* Keybind(w) manually marks file as watched.  
  
####Playlist-mode features:
* Immidiately append all your unwatched files into the current playlist.
* Periodically continue to load new unwatched files into playlist(persists in idle).
* On file skip, appends it to the end of the playlist, allowing you to see files in the order you want. You can stop this behaviour by toggling the playlist-mode off.  

####Keybinds:
* playlist-mode-toggle(W) - Toggles playlist mode
* mark-seen(w)            - Marks file as seen
  
  
#####Setup:
1. Save lua in mpv/scripts folder.
2. Edit settings variable in lua to represent your system and paths.
3. Run `mpv --idle` to create the seen list file in the path you chose. 
4. If the file is created the script is ready, try it with (W). If it isn't created, there is problems with permissions. Try creating the file manually and granting read and write permissions.
  
####Files
- unseen-playlistmaker.lua as described above
- unseen+playlistmanager.lua as described above with playlistmanager integrated(see link below)

#### My other mpv scripts
- [collection of scripts](https://github.com/donmaiq/mpv-scripts)
