local settings = {
    linux_over_windows = true,                                 --linux=true, windows=false

    --playlist management settings
    playlist_savepath = "/custom/playlists/",                      --notice trailing \ or /
    playlist_osd_dur = 5,                                       --seconds playlist is shown when navigating                                   
    loadfiles_filetypes = {'*mkv','*mp4','*jpg','*gif','*png','*avi','*mp3'}, --shortcut P filetypes that will be loaded, true if all filetypes, else array like {'*mkv','*mp4'}
    sortplaylist_on_start = false,

    --amount of entries to show before concatenating list
    showamount = 13,

    --attempt to strip path from the playlist filename, usually only nececcary if opened with playlist file
    --having it on true might have unwanted effects with files containing /
    strip_paths = true,

    --show playlist every time a new file is loaded
    show_playlist_on_fileload = true,

    --sync cursor when file is loaded from outside reasons(file-ending, playlist-next shortcut etc.)
    --has the sideeffect of moving cursor if file happens to change when navigating
    --good side is cursor always following current file when going back and forth files
    --2 is true, always follow on load 
    --1 is sticky, follow if cursor is close
    --0 is false, never follow
    sync_cursor_on_load = 2,


    --unseen playlistmaker settings
    unseen_load_on_start = false,                                       --toggle to load unseen playlistmaker on startup, use only if loading script manually
    unseen_filetypes = {'*mkv','*mp4'},                                 --unseen-playlistmaker filetypes, {'*'} for all filetypes
    unseen_searchpath = "/media/HDD/users/anon/Downloads/temp/",                            --path to media files where unseen-playlistmaker should look for files 
    unseen_savedpath="/custom/list"                         --file and path to where to save seen files 

}

local seenarray={}
local loadingarray={}
local active = false
local idle = nil
local search =' '
for w in pairs(settings.unseen_filetypes) do
    if settings.linux_over_windows then
        search = search..settings.unseen_searchpath..settings.unseen_filetypes[w]..' '
    else
        search = search..'"'..settings.unseen_searchpath..settings.unseen_filetypes[w]..'" '
    end
end
if settings.linux_over_windows then
    scan = 'find'..search..'-type f -printf "%f\\n" 2>/dev/null'
else
    scan = 'dir /b'..search 
end

--creating a list.txt file if one doesn't exist
local test, err= io.open(settings.unseen_savedpath, "r")
if not test then
    mp.msg.info("creating list.txt file")
    local create = io.open(settings.unseen_savedpath, "w")
    if not create then mp.msg.info("Failed to create list.txt file, check permissions to path") else create:close() end
else 
    test:close() 
end

function on_load(event)
    filename = mp.get_property('filename')
    path = mp.get_property('path')
    pos = tonumber(mp.get_property('playlist-pos'))
    plen = tonumber(mp.get_property('playlist-count'))
    fullpath = string.sub(mp.get_property("path"), 1, string.len(mp.get_property("path"))-string.len(mp.get_property("filename")))
    mark=false
    --check if file has duration. If it has one, start listening for progress. Streams are skipped this way.
    local dur = mp.get_property('duration')
    if dur then timecheck() else mark=true end

    if settings.loadfiles_filetypes == true then
        search_playlist = string.gsub(fullpath, "%s+", "\\ ")..'*'
    else
        search_playlist = ' '
        for w in pairs(settings.loadfiles_filetypes) do
            if settings.linux_over_windows then
                search_playlist = search_playlist..fullpath:gsub("%s+", "\\ "):gsub("%[","\\["):gsub("%]","\\]")..settings.loadfiles_filetypes[w]..' '
            else
                search_playlist = search_playlist..'"'..fullpath..settings.loadfiles_filetypes[w]..'" '
            end
        end
    end
    if settings.sync_cursor_on_load==2 then
        cursor=pos
    elseif settings.sync_cursor_on_load==1 then
        if cursor == pos -1 then 
            cursor = cursor + 1 
        elseif cursor==pos+1 then
            cursor=cursor-1
        end
    end
    if settings.show_playlist_on_fileload then showplaylist(true) end
end


function on_close(event)
    --if playlist-mode is active, unwatched files are appended to end of playlist
    if mark == false and active and path then
        local oldfile = mp.get_property('playlist/'..(mp.get_property('playlist-pos')-1)..'/filename')
        local oldfile2 = mp.get_property('playlist/'..(mp.get_property('playlist-pos')+1)..'/filename')
        if path==oldfile then 
            mp.commandv("playlist-remove", mp.get_property('playlist-pos')-1) 
        elseif path==oldfile2 then 
            mp.commandv("playlist-remove", mp.get_property('playlist-pos')+1) 
        end
        mp.commandv("loadfile", path, "append")
    end

    filename=nil
    idle=mp.get_property('idle-active')
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
    idle=mp.get_property('idle-active')
    if idle ~= 'yes' or idleact == false then return end
    search()
    --change below how often you want to listen for new files when idle
    mp.add_timeout(5, idle_timer)
    
end

--checks position of video every 5 seconds
function timecheck()
    if mark == true or filename==nil then return end
    local tmppos = mp.get_property('percent-pos')
    if tmppos==nil then mp.add_timeout(5, timecheck) return end
    local loc = tonumber(tmppos)
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
    local file, err = io.open(settings.unseen_savedpath, "a+")
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
        if mp.get_property('idle-active')=='yes' then idle_timer('active') end
        mp.msg.info("Activating playlist mode, listening for unseen files.")
        mp.register_event('file-loaded', search)
        active = true
        search()
    else
        if mp.get_property('idle-active')=='yes' then idle_timer('deactive') end
        mp.unregister_event('file-loaded', search)
        mp.msg.info("Disabling playlist mode.")
        active = false
    end
end

--appends unseen episodes into playlist
--if a new file is added to the folder, it will be appended on next search
function search(args)
    local seenlist= io.open(settings.unseen_savedpath, "r")
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
            local errcheck = io.open(settings.unseen_searchpath..dirx, "r") 
            if errcheck then  
                errcheck:close()
                seenarray[dirx]='true'
                count = count +1
                mp.commandv("loadfile", settings.unseen_searchpath..dirx, "append-play")
                mp.msg.info("Appended to playlist: " .. dirx)
            end
        end
    end
    if count ~= 0 and args~='hide' then 
        mp.osd_message("Added total of "..count.." files to playlist")
    end
    popen:close()
    plen = tonumber(mp.get_property('playlist-count'))
end

------EMD OF UNSEEN
--START OF MANAGER


--if you need to strip filepaths from playlist names uncomment if statement below
function strippath(pathfile)
    if settings.strip_paths then
        local tmp = string.match(pathfile, '.*/(.*)')
        if tmp then return tmp end
    end
    return pathfile 
end


cursor = 0
function showplaylist(delay)
    if delay then
        mp.add_timeout(0.2,showplaylist)
        return
    end
    if not mp.get_property('playlist-pos') or not mp.get_property('playlist-count') then return end
    pos = tonumber(mp.get_property('playlist-pos'))
    plen = tonumber(mp.get_property('playlist-count'))
    if cursor>plen then cursor=0 end
    local playlist = {}
    for i=0,plen-1,1
    do
        playlist[i] = strippath(mp.get_property('playlist/'..i..'/filename'))
    end
    if plen>0 then
        output = "Playing: "..mp.get_property('media-title').."\n\n"
        output = output.."Playlist - "..(cursor+1).." / "..plen.."\n"
        local b = cursor - math.floor(settings.showamount/2)
        local showall = false
        if b<0 then b=0 end
        if plen <= settings.showamount then
        	b=0
        	showall=true
        end
        if b > 0 and not showall then output=output.."...\n" end
        for a=b,b+settings.showamount-1,1 do
            if a == plen then break end
            if a == pos then output = output.."->" end
            if a == cursor then
                if tag then
                    output = output..">> "..playlist[a].." <<\n"
                else
                    output = output.."> "..playlist[a].." <\n"
                end
            else
                output = output..playlist[a].."\n"
            end
            if a == b+settings.showamount-1 and not showall then
              output=output.."..."
            end
        end
    else
        output = file
    end
    mp.osd_message(output, settings.playlist_osd_dur)
end

tag=nil
function tagcurrent()
    if not tag then
        tag=cursor
    else
        tag=nil
    end
    showplaylist()
end

function removefile()
    tag = nil
    if cursor==pos then mark=true end
    mp.commandv("playlist-remove", cursor)
    if cursor==plen-1 then cursor = cursor - 1 end
    showplaylist()
end

function moveup()
    if cursor~=0 then
        if tag then mp.commandv("playlist-move", cursor,cursor-1) end
        cursor = cursor-1
    else
        if tag then mp.commandv("playlist-move", cursor,plen) end
        cursor = plen-1
    end
    showplaylist()
end

function movedown()
    if cursor ~= plen-1 then
        if tag then mp.commandv("playlist-move", cursor,cursor+2) end
        cursor = cursor + 1
    else
        if tag then mp.commandv("playlist-move", cursor,0) end
        cursor = 0
    end
    showplaylist()
end

function jumptofile()
    tag = nil
    if cursor < pos then
        for x=1,math.abs(cursor-pos),1 do
            mp.commandv("playlist-prev", "weak")
        end
    elseif cursor>pos then
        for x=1,math.abs(cursor-pos),1 do
            mp.commandv("playlist-next", "weak")
        end
    else
        if cursor~=plen-1 then
            cursor = cursor + 1
        end
        mp.commandv("playlist-next", "weak")
    end
    showplaylist(true)
end


--Attempts to add all files following the currently playing one to the playlist
--For exaple, Folder has 12 files, you open the 5th file and run this, the remaining 7 are added behind the 5th file
function playlist()
    local popen=nil
    if settings.linux_over_windows then
        popen = io.popen('find '..search_playlist..' -type f -printf "%f\\n" 2>/dev/null') --linux version, not tested, if it doesn't work fix it to print filenames only 1 per row
        --print('find '..search_playlist..' -type f -printf "%f\\n"')
    else
        popen = io.popen('dir /b '..search_playlist) --windows version
    end
    if popen then 
        local cur = false
        local c= 0
        for dirx in popen:lines() do
            if cur == true then
                mp.commandv("loadfile", fullpath..dirx, "append")
                mp.msg.info("Appended to playlist: " .. dirx)
                c = c + 1
            end
            if dirx == filename then
                cur = true
            end
        end
        popen:close()
        if c > 0 then mp.osd_message("Added total of: "..c.." files to playlist") end
    else
        print("error: could not scan for files")
    end
    plen = tonumber(mp.get_property('playlist-count'))
end

--saves the current playlist into a m3u file
function save_playlist()
    local savename = os.time().."-size_"..plen.."-playlist.m3u"
    local file = io.open(settings.playlist_savepath..savename, "w")
    if file==nil then
        mp.msg.info("Error in creating playlist file, check permissions and paths")
    else
        local x=0
        while x < plen do
            local cursorfilename = mp.get_property('playlist/'..x..'/filename')
            file:write(cursorfilename, "\n")
            x=x+1
        end
        print("Playlist written to: "..settings.playlist_savepath..savename)
        file:close()
    end
end

function sortplaylist()
    local length = tonumber(mp.get_property('playlist/count'))
    if length > 1 then
        local playlist = {}
        for i=0,length,1
        do
            playlist[i+1] = mp.get_property('playlist/'..i..'/filename')
        end
        table.sort(playlist)
        local first = true
        for index,file in pairs(playlist) do
            print(file)
            if first then 
                mp.commandv("loadfile", file, "replace")
                first=false
            else
                mp.commandv("loadfile", file, "append") 
            end
        end
    end
end

if settings.sortplaylist_on_start then
    mp.add_timeout(0.03, sortplaylist)
end

if settings.unseen_load_on_start then
    activate()
end

mp.register_event('file-loaded', on_load)
mp.register_event('end-file', on_close)

--change the lines below if you want to change keybindings
mp.add_key_binding('w', 'mark-seen', watched)
mp.add_key_binding('W', 'playlist-mode-toggle', activate)

mp.add_key_binding('CTRL+p', 'sortplaylist', sortplaylist)
mp.add_key_binding('P', 'loadfiles', playlist)
mp.add_key_binding('p', 'saveplaylist', save_playlist)

mp.add_key_binding('Shift+ENTER', 'showplaylist', showplaylist)
mp.add_key_binding('UP', 'moveup', moveup)
mp.add_key_binding('DOWN', 'movedown', movedown)
mp.add_key_binding('CTRL+UP', 'tagcurrent', tagcurrent)
mp.add_key_binding('ENTER', 'jumptofile', jumptofile)
mp.add_key_binding('BS', 'removefile', removefile)
