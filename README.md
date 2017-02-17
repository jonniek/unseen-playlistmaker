
#MPV unseen-playlistmaker
-----------
This script keeps track of your watched files from a directory locally, and on keybind enters playlist-mode to watch unseen files from that specified directory. This script operates based on filenames.
  
####Default features:
* Marks file as seen into a specified file when surpassing 80% duration. Only applies for files in the unseen directory.  
* Keybind(w) manually marks file as seen. Can mark any files.  
  
####Playlist-mode features:
* Immidiately append all your unseen files from unseen directory into the current playlist.  
* Periodically continue to load new unseen files into playlist(persists in idle).  
* On file skip, appends it to the end of the playlist, allowing you to see files in the order you want. You can stop this behaviour by toggling the playlist-mode off or sending a script message `script-message unseenplaylist mark true` before changing file(this will treat the file as watched even if it isn't).  
  
###Keybinds
#####All the controlling of this script is done through script messages:  
`script-message unseenplaylist command value`  
  
Command | Value | Effect
--- | --- | ---
activate | - / true / false | toggles(no value) / activates(true) / ends(false) - playlist-mode
mark-seen | - | Manually marks file as seen
search | hide / - | searches for new files once. Hide value will make no osd message on found.
mark | true / false | Sets the value of mark without marking file. Helper to avoid conflict with other scripts.
  
examples:  
`W script-message unseenplaylist activate` Toggles playlist-mode  
`w script-message unseenplaylist mark-seen`  Marks file as seen manually  
`alt+w script-message unseenplaylist search hide` Searches for files once  
  
  
#####Setup:
1. Save lua in mpv/scripts folder.
2. Edit settings variable in lua to represent your system and paths.
3. Edit your input.conf to include binds that you want
4. Run `mpv --idle` to create the seen list file in the path you chose. 
5. If the file is created the script is ready, try it with (W). If it isn't created, there is problems with permissions. Try creating the file manually and granting read and write permissions.

#### My other mpv scripts
- [collection of scripts](https://github.com/donmaiq/mpv-scripts)
