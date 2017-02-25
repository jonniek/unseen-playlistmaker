local settings = {
  --linux=true, windows=false, nil=auto
  linux_over_windows = nil,

  --when playlist-mode is active append skipped files to end of playlist
  append_skipped = true,
  --unseen-playlistmaker filetypes {'ext','ext2'}, use empty string {''} for all filetypes
  allowed_extensions = {'mkv', 'avi', 'mp4', 'ogv', 'webm', 'rmvb', 'flv', 'wmv', 'mpeg', 'mpg', 'm4v', '3gp',
'mp3', 'wav', 'ogv', 'flac', 'm4a', 'wma' },
  --absolute path to media directory where unseen-playlistmaker should look for files. Do not use aliases like $HOME.
  --notice trailing slashes, escape backslashes on windows like c:\\dir\\
  unseen_directory = "/home/anon/Videos/",
  --full path and name of file that contains seen files, don't keep as tmp if you want to save them
  seenlist_file = "/tmp/unseenlist",
}

local utils = require 'mp.utils'
local msg = require 'mp.msg'

local seenarray = {}
local active = false
local mark = false

--check os
if settings.linux_over_windows==nil then
  local o = {}
  if mp.get_property_native('options/vo-mmcss-profile', o) ~= o then
    settings.linux_over_windows = false
  else
    settings.linux_over_windows = true
  end
end

--create file search query with path to search files, extensions in a table, unix as true(windows false)
function create_searchquery(path, extensions, unix)
  local query = ' '
  for i in pairs(extensions) do
    if unix then
      if extensions[i] ~= "" then extensions[i] = "*"..extensions[i] end
      query = query..extensions[i]..' '
    else
      query = query..'"'..path..'*'..extensions[i]..'" '
    end
  end
  if unix then
    return 'cd "'..path:gsub('"', '\\"')..'";ls -1vp'..query..'2>/dev/null'
  else
    return 'dir /b'..(query:gsub("/","\\")) --Windows doesn't like dir/*
  end
end

--initialize unseen scan query once
local scan = create_searchquery(settings.unseen_directory, settings.allowed_extensions, settings.linux_over_windows)

--creating/checking seen list file on startup
local test, err = io.open(settings.seenlist_file, "r")
if not test then
  msg.info(err.." => creating seen list file")
  local create, err = io.open(settings.seenlist_file, "w")
  if not create then
    msg.error("Failed to create seen list, check permissions or create manually. Error: "..(err or "")) 
  else 
    msg.info("File created without problems! The script is ready now.")
    create:close() 
  end
else
  test:close()
end

function on_load()
  filename = mp.get_property('filename')
  path = utils.join_path(mp.get_property('working-directory'), mp.get_property('path'))
  pos = mp.get_property_number('playlist-pos', 0)
  plen = mp.get_property_number('playlist-count', 0)
  directory = utils.split_path(path)
  mark = false

  --only track files that are in our searchdirectory
  if directory == settings.unseen_directory then
    local ismarked = seenarray[filename] == 'true'
    if not ismarked then unseentimer:resume() end
  end
end

function on_close()
  --if playlist-mode is active, unwatched files are appended to end of playlist
  if not mark and active and path and settings.append_skipped then
    for i=0, plen, 1 do
      if path == mp.get_property('playlist/'..i..'/filename') then
        mp.commandv("playlist-remove", i)
        break
      end
    end
    mp.commandv("loadfile", path, "append")
  end

  --make sure watched cannot be called when no file is playing
  filename = nil
  --make sure unseentimer is killed so on_load can resume it if needed
  unseentimer:kill()

  --activate idle timer if player enters idle
  if mp.get_property('idle-active', 'no') == 'yes' and active then 
    msg.info("Entering idle mode and listening for new files.")
    idletimer:resume()
  end
end

--this checks for new files while player is in idle and playlist mode is active
function idle_timer()
  if mp.get_property('idle-active', 'no') ~= 'yes' and active then
    idletimer:kill()
    return
  end
  search()
end

--checks position of video and marks as watched
function timecheck()
  if mark then unseentimer:kill() end
  local percentpos = mp.get_property_number('percent-pos', 0)
  --position in % when to mark file
  if percentpos >= 80 then
    watched('timer')
    --searching for new files if playlist mode is activated
    --if you want this search to display osd message if files are found, remove the 'hide' argument below
    if active then search('hide') end
    unseentimer:kill()
  end
end

--marks episode as watched, invoked at timecheck() and shortcut (w)
--this file is loaded in search()
function watched(args)
  if not filename then return end
  if not mark then
    mark = true
  else
    if args == 'timer' then return end
    if args == 'true' or not args then
      msg.warn("File already marked as watched: "..filename)
      return
    end
  end
  local file, err = io.open(settings.seenlist_file, "a+")
  if not file then
    msg.error("Error opening seen list in watched() : "..(err or ""))
  else
    local content = {}

    local match = false
    for line in file:lines() do
      if line == filename then
        match = true
        --stop iterating if we will not rewrite the file
        if args == 'timer' or args == 'true' then 
          break
        end
      else
        --create list of seen files without the current file incase of removal
        content[#content+1] = line
      end
    end
    if not match then
      msg.info("Marking as watched: " .. filename)
      file:write(string.format( "%s\n", filename))
      --set file as watched
      seenarray[filename] = 'true'
      unseentimer:kill()
    else
      --if file is marked but we want to remove it
      if args == 'toggle' or args == 'false' then
        file:close()
        local file, err = io.open(settings.seenlist_file, "w+" )
        if not file then
          msg.error("Error trying to rewrite seen list: "..(err or ""))
        else
          for i = 1, #content do
            file:write( string.format( "%s\n", content[i] ) )
          end
          file:close()
          msg.info("Removing from watched: " .. filename)
          mark = false
          --set file into queue status
          seenarray[filename] = 'queue'
          return
        end
      elseif args ~= 'timer' then
        msg.warn("File already marked as watched: "..filename)
        unseentimer:kill()
      end
    end
    file:close()
  end
end

--Toggles playlist mode to listen for new files and calls an initial search for files
function activate(force)
  if ( not active or force == true ) and force ~= false then
    if mp.get_property('idle-active', 'no') == 'yes' then idletimer:resume() end
      msg.info("Activating playlist mode, listening for unseen files.")
      active = true
      search()
  elseif active or force == false then
    if mp.get_property('idle-active', 'no') == 'yes' then idletimer:kill() end
    msg.info("Playlist mode disabled")
    active = false
  end
end

--appends unseen episodes into playlist
--if a new file is added to the folder, it will be appended on next search
function search(args)
  local seenlist, err = io.open(settings.seenlist_file, "r")
  if not seenlist then msg.error("Cannot read seen list: "..(err or "")) ; return end
  for seen in seenlist:lines() do
    if not seenarray[seen] then
      --mark files from seen list as true into seenarray
      seenarray[seen]='true'
    end
  end
  seenlist:close()
  local count = 0
  local popen = io.popen(scan)
  for line in popen:lines() do
    if not seenarray[line] and line:sub(-1)~="/" then
      --checking that file is readable
      local errcheck, err = io.open(utils.join_path(settings.unseen_directory, line), "r") 
      if errcheck then
        errcheck:close()
        --mark loaded files as queue
        seenarray[line]='queue'
        count = count + 1
        mp.commandv("loadfile", utils.join_path(settings.unseen_directory, line), "append-play")
        msg.info("Loaded: "..line)
      end
    end
  end
  if count ~= 0 and args ~= 'hide' then 
    mp.osd_message("Added total of "..count.." files to playlist")
  end
  popen:close()
  plen = mp.get_property_number('playlist-count', 0)
end

--clear all files not in directory from seen file
function clean_seen_file(message)
  --save unseen dir into array
  local in_dir = {}
  local popen, err = io.popen(scan)
  if not popen then msg.error("Couldn't read directory: "..(err or "")) ; return end
  for line in popen:lines() do
    in_dir[line] = "true"
  end
  popen:close()

  --examine what entries in seenfile exist in unseen dir array
  --add matches into new seen array
  local new_seen_array = {}
  local seenlist, err = io.open(settings.seenlist_file, "r")
  if not seenlist then msg.error("Cannot read seen list: "..(err or "")) ; return end
  for seen in seenlist:lines() do
    if in_dir[seen] then
      table.insert(new_seen_array, seen)
    end
  end
  seenlist:close()

  --write the new seen array
  local file, err = io.open(settings.seenlist_file, "w+" )
  if not file then msg.error("Error trying to rewrite seen list: "..(err or "")) ; return end
  for i = 1, #new_seen_array do
    file:write( string.format( "%s\n", new_seen_array[i] ) )
  end
  file:close()
  
  if message then mp.osd_message("Cleaned "..(oldlength - #new_seen_array).." files from seen file") end
end

unseentimer = mp.add_periodic_timer(1, timecheck)
unseentimer:kill()

idletimer = mp.add_periodic_timer(5, idle_timer)
idletimer:kill()

if mp.get_opt("unseenplayliststart") then
    activate()
end

--react to script messages
function unseenmsg(msg, value, reason)
  --print for debugging messages
  --print(msg, value, "reason: "..(reason or ""))

  --allows other scripts to mark file to avoid conflicts
  if msg == "mark" then mark = value=="true" ; if value=="true" then unseentimer:kill() else unseentimer:resume() end; return end
  if msg == "search" then search(value) ; return end
  if msg == "activate" and value=="true" then activate(true) ; return end
  if msg == "activate" and value=="false" then activate(false) ; return end
  if msg == "activate" and value==nil then activate() ; return end
  if msg == "mark-seen" then watched(value) ; return end
  if msg == "clean" then clean_seen_file(value) ; return end
end
mp.register_script_message("unseenplaylist", unseenmsg)
mp.register_event('file-loaded', on_load)
mp.register_event('end-file', on_close)
