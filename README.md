
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
2. Edit the filepaths in settings array.
3. Run `mpv --idle` to create the list.txt file in the scriptloc path you chose.
4. If the txt file is created the script is ready, try it with (W). If it isn't created, there is problems with permissions.

####Files
- unseen-playlistmaker.lua as described above
- unseen+playlistmanager.lua as described above with playlistmanager integrated(see link below)

#### My other mpv scripts
- https://github.com/donmaiq/Mpv-Playlistmanager manager only, combined one unseen+playlistmanager.lua in this repo
- https://github.com/donmaiq/Mpv-Radio

