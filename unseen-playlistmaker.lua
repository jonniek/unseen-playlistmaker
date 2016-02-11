-- Created by Jonni-e 9.2.2016
-- This lua file needs to be located in your mpv scripts folder, or called with --script=<path>
-- Windows: C:\Users\anon\AppData\Roaming\mpv\scripts
-- Linux: ~/.config/mpv/scripts/
--
-- This script is created for the purpose of saving someone from navigating in their 
-- download folder for unwatched episodes of shows.
--
-- Keybind 1: Playlist-mode-toggle(W), when activating playlist-mode all unwatched shows from 
-- media directory will be appended to the playlist, and new files be searched for on load and 80%playthrough.
-- When toggling off playlist-mode, automatic searches for files will no longer be done.
-- Skipped files in playlist-mode will append to the end of the playlist. 
-- Allowing you to skip over files if you want to see your unwatched shows in a certain order.
--
-- Keybind 2: mark-seen(w), will mark an unwatched episode as watched. 
-- Note that this will also happen automatically when video reaches 80%.
--
-- Without activating playlist-mode (W) this script will keep track of watched files.
-- If mpv is ran without a terminal then search() will cause momentary popup windows. 
-- Remember you can toggle it off after loading the playlist with another (W).
-- If you use --idle the script will continue to wait for files in idle mode if playlist-mode is active.
-- So for example to load all your unseen videos run "mpv --idle" and press keybind for Playlist-mode-toggle(W). 
-- Make sure your torrent client stores incompleted files somewhere else, or they won't be loaded again once complete
-- I have tried minimizing errors with incomplete files but better safe than sorry
-- Files that are being copied over will not be loaded incomplete.
-----------------------------------------------------------------------------------------

--EDIT this path below to where you want your text file of watched shows placed
--note the escape strings on windows paths and traling / or \ because path will be chained with filenames.
--Make sure you have read and write permissions in the scriptloc folder
--you might need to disable UAC with regedit if you want to save to system folders on windows.
--To test write permission just open mpv --idle, if the list.txt file is created then permissions should be fine.
--I suggest using an absolute path.
local scriptloc="D:\\users\\anon\\Downloads(hdd)\\shortcuts\\scripts\\" 

--Below is path to media files, note that this script is designed with only one media path in mind. 
local fileloc="D:\\users\\anon\\Downloads(hdd)\\animu-temp\\"

local filetypes = {'*mkv','*mp4'} -- add whatever you want in the same format
local search =' '
for w in pairs(filetypes) do
    search = search..fileloc..filetypes[w]..' '
    --search = search..'"'..fileloc..filetypes[w]..'" ' --alternative that quotes searches if path has spaces, windows only
end

--change the scan below to suit your needs, note that all unwatched files this search finds, will try to be opened in mpv. 
--on default it searches all mkv files in fileloc folder, and lists them one per line. 
--replace '*mkv' with whatever filetype you want to search.
--scanning files from subdirectories will break the for loop in search().

--local scan = 'find'..search..'-type f -printf "%f\n"' --linux version
local scan = 'dir /b'..search --windows version


-----------------------------------------------------------------------------------------
local txtfile=scriptloc.."list.txt"
local mp=require 'mp'
local filename=nil
local mark=false
local seenarray={}
local loadingarray={}
local active = false
local idle = nil

--creating a list.txt file if one doesn't exist
local test, err= io.open(txtfile, "r")
if not test then
    mp.msg.info("creating list.txt file")
    local create = io.open(txtfile, "w")
    if not create then mp.msg.info("Failed to create list.txt file, check permissions to path") else create:close() end
else 
    test:close() 
end

--file is loaded
function on_load(event)
    filename = mp.get_property('filename')
    path = mp.get_property('path')
    mark=false
    --check if file has duration. If it has one, start listening for progress. Streams are skipped this way.
    local dur = mp.get_property('duration')
    if dur then timecheck() else mark=true end
end


function on_close(event)
    filename=nil
    --if playlist-mode is active, unwatched files are appended to end of playlist
    if mark == false and active and path then
        mp.commandv("loadfile", path, "append")
    end
    idle=mp.get_property('idle')
    if idle == 'yes' and active then 
       idle_timer('closed')
    end
end

--this checks for new files while player is in idle and playlist mode is active
function idle_timer(arg)
    if arg == 'closed' then
        mp.msg.info("Entering idle mode and listening for new files.")
    end
    if arg == 'deactive' then 
        idleact = false
    elseif arg == 'active' or arg == 'closed' then
        idleact = true
    end
    idle=mp.get_property('idle')
    if idle ~= 'yes' or idleact == false then return end
    search()
    --change below how often you want to listen for new files when idle
    mp.add_timeout(1, idle_timer)
    
end

--checks position of video every 5 seconds
function timecheck()
    if mark == true or filename==nil then return end
    local loc = tonumber(mp.get_property('percent-pos'))
    if not loc then return end
    --Change the equation below if you want to change at what point a file gets marked
    --0-100
    if loc >= 80 then
        watched('timer')
        --searching for new files if playlist mode is activated
        --if you want this search to display osd message if files are found, remove the 'hide' argument below
        if active then search('hide') end
    else
        --Change the number below if you want to change how often this function is ran
        mp.add_timeout(5, timecheck)
    end
end

--marks episode as watched, invoked at timecheck() and shortcut (w)
--writes the name of the file into a textfile named list.txt
--this text file is loaded in search()
function watched(args)
    if filename == nil then return end
    if mark == false then 
        mark = true 
    else 
        if args~='timer' then mp.msg.info("File already marked as watched: " .. filename) end
        return 
    end
    local file, err = io.open(txtfile, "a+")
    if file==nil then
        mp.msg.info("Error opening list.txt in watched()")
    else
        local x=file:read("*l")
        local match=false
        while x ~= nil do 
            if x==filename then match=true end
            x=file:read("*l")
        end
        if not match then 
            mp.msg.info("Marking as watched: " .. filename)
            file:write(filename, "\n")
        else
            if args~='timer' then mp.msg.info("File already marked as watched: " .. filename) end
        end
    file:close()
    end
end

--Toggles playlist mode to listen for new files and calls an initial search for files
function activate(args)
    if active==false then
        if mp.get_property('idle')=='yes' then idle_timer('active') end
        mp.msg.info("Activating playlist mode, listening for unseen files.")
        mp.register_event('file-loaded', search)
        active = true
        search()
    else
        if mp.get_property('idle')=='yes' then idle_timer('deactive') end
        mp.unregister_event('file-loaded', search)
        mp.msg.info("Disabling playlist mode.")
        active = false
    end
end

--appends unseen episodes into playlist
--if a new file is added to the folder, it will be appended on next search
function search(args)
    local seenlist= io.open(txtfile, "r")
    if seenlist == nil then mp.msg.info("Cannot write to list.txt file, check permissions or change path.") return end
    local seen=seenlist:read("*l")
    while seen ~= nil do
        if not seenarray[seen] then
            seenarray[seen]='true'
        end
        seen=seenlist:read("*l")
    end
    seenlist:close()
    local count=0
    local popen = io.popen(scan)
    for dirx in popen:lines() do
        if not seenarray[dirx] then
            --checking that file is not being copied
            local errcheck = io.open(fileloc..dirx, "r") 
            if errcheck then  
                errcheck:close()
                seenarray[dirx]='true'
                count = count +1
                mp.commandv("loadfile", fileloc..dirx, "append-play")
                mp.msg.info("Appended to playlist: " .. dirx)
            end
        end
    end
    if count ~= 0 and args~='hide' then 
        mp.osd_message("Added total of: "..count.." files to playlist")
    end
    popen:close()
end

--change the lines below if you want to change keybindings
mp.add_key_binding('w', 'mark-seen', watched)
mp.add_key_binding('W', 'playlist-mode-toggle', activate)
mp.register_event('file-loaded', on_load)
mp.register_event('end-file', on_close)
