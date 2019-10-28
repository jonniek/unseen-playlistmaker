
# MPV unseen-playlistmaker
-----------
This script keeps track of your watched files from a directory locally, and on keybind enters playlist-mode to watch unseen files from that specified directory. This script operates based on filenames. Note that this script ignores files that are not readable(being written) but might not work properly with incomplete files such as in progress torrented files.
  
#### Passive features:
* Marks file as seen into a specified file when surpassing 80% duration. Only applies for files in the unseen directory.  
  
#### Playlist-mode features:
Playlist-mode is the active state of the script. It needs to be activated with a key, see keybinds section below.  
* Immidiately append all your unseen files from unseen directory into the current playlist.  
* Periodically continue to load new unseen files into playlist(when passing 80% duration). On idle searches every 5 sec.  
* On file skip, appends it to the end of the playlist, allowing you to see files in the order you want. You can stop this behaviour by toggling the playlist-mode off or sending a script message `script-message unseenplaylist mark true` before changing file(this will treat the file as watched even if it isn't). Settings variable also has a toggle that will disable this behaviour completely.  
  
#### Keybinds and active features
All the controlling of this script is done through script messages:  
`KEY script-message unseenplaylist command value message`  
  
List of commands, values and their effects:  
  
Command | Value | Effect
--- | --- | ---
activate | - / true / false | toggles(no value) / activates(true) / ends(false) - playlist-mode
mark-seen | - / toggle / false | Marks as seen(no value) / Toggles seen status(toggle) / marks as unseen(false). If seen status is removed the script will not continue to check for 80% for marking.
search |  - / hide | searches for new files once. Hide value will make osd message hidden.
mark | true / false | Sets the value of mark without actually changing seen file. This is mainly for other scripts to call to avoid conflicts if nececcary. Will continue 80% checking on false.
clean | - / true | Cleans the seen list file from entries that no longer are inside unseen directory, add any value parameter to show an osd message how many files was cleaned
  
The message argument is a optional string that is only used for debugging. It can be used as description of why the message was sent for example from another script to avoid conflict.  
  
examples:  
`W script-message unseenplaylist activate` Toggles playlist-mode  
`w script-message unseenplaylist mark-seen`  Marks file as seen manually  
`alt+w script-message unseenplaylist search hide` Searches for files once  
  
Playlistmanager.lua avoiding a conflict when deleting playing file:  
`mp.command('script-message unseenplaylist mark true "Fake mark file to allow safe deletion from playlist")`  
  
To activate unseenplaylistmanager on mpv startup use this as launch parameter:  
`--script-opts=unseenplayliststart=true --idle=once`  
requires --idle, or --idle=once(can be declared in mpv.conf as well) because the script will load files after mpv has started.
  
  
#### Setup:
1. Save lua in mpv/scripts folder.
2. Edit settings variable in lua to represent your system and paths.
3. Edit your input.conf to include activate bind and other binds that you want
4. Run `mpv --idle` to create the seen list file in the path you chose, check the output in terminal. 
5. If the file is created the script is ready, try it by activating(key you bound for activate in step 3). If it isn't created, there is problems with permissions. Try creating the file manually and granting read and write permissions.

#### My other mpv scripts
- [collection of scripts](https://github.com/donmaiq/mpv-scripts)
