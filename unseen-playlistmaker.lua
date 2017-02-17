local settings = {
  --linux=true, windows=false, nil=auto
  linux_over_windows = nil,

  --toggle to load unseen playlistmaker on startup, use only if loading script manually
  unseen_load_on_start = false,
  --unseen-playlistmaker filetypes {'ext','ext2'}, use empty string {''} for all filetypes
  unseen_filetypes = {'mkv', 'mp4', 'jpg'},
  --absolute path to media directory where unseen-playlistmaker should look for files. Do not use aliases like $HOME.
  unseen_searchpath = "/home/anon/Videos/",
  --full path and name of file that contains seen files
  unseen_savedpath="/tmp/unseenlist",
}

local utils = require 'mp.utils'
local msg = require 'mp.msg'

local seenarray = {}
local loadingarray = {}
local active = false
local mark = false

function escapepath(dir, escapechar)
  return string.gsub(dir, escapechar, '\\'..escapechar)
end

--check os
if not settings.linux_over_windows then
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
    return 'cd "'..escapepath(path, '"')..'";ls -1vp'..query..'2>/dev/null'
  else
    return 'dir /b'..query
  end
end

--initialize unseen scan query once
local scan = create_searchquery(settings.unseen_searchpath, settings.unseen_filetypes, settings.linux_over_windows)

--creating/checking seen list file on startup
local test, err = io.open(settings.unseen_savedpath, "r")
if not test then
  msg.info(err.." => creating seen list file")
  local create, err = io.open(settings.unseen_savedpath, "w")
  if not create then
    msg.error("Failed to create seen list, check permissions or create manually. Error: "..err or "") 
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
  mark=false

  --only track files that are in our searchdirectory
  if directory == settings.unseen_searchpath then unseentimer:resume() else mark=true end
end

function on_close()
  --if playlist-mode is active, unwatched files are appended to end of playlist
  if not mark and active and path then
    for i=0, plen, 1 do
      if path == mp.get_property('playlist/'..i..'/filename') then
        mp.commandv("playlist-remove", i)
        break
      end
    end
    mp.commandv("loadfile", path, "append")
  end

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
  if mark or not filename then return end
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
    if args~='timer' then msg.warn("File already marked as watched: "..filename) end
    return
  end
  local file, err = io.open(settings.unseen_savedpath, "a+")
  if not file then
    msg.error("Error opening seen list in watched() : "..err or "")
  else
    local line = file:read("*l")
    local match = false
    while line ~= nil do
      if line == filename then 
        match = true
        break
      end
      line = file:read("*l")
    end
    if not match then
      msg.info("Marking as watched: " .. filename)
      file:write(filename, "\n")
    else
      if args ~= 'timer' then msg.warn("File already marked as watched: "..filename) end
    end
    file:close()
  end
end

--Toggles playlist mode to listen for new files and calls an initial search for files
function activate(force)
  if not active then
    if mp.get_property('idle-active', 'no') == 'yes' then idletimer:resume() end
      msg.info("Activating playlist mode, listening for unseen files.")
      active = true
      search()
  else
    if mp.get_property('idle-active', 'no') == 'yes' then idletimer:kill() end
    msg.info("Playlist mode disabled")
    active = false
  end
end

--appends unseen episodes into playlist
--if a new file is added to the folder, it will be appended on next search
function search(args)
  local seenlist, err = io.open(settings.unseen_savedpath, "r")
  if not seenlist then msg.error("Cannot read seen list: "..err or "") return end
  local seen = seenlist:read("*l")
  while seen ~= nil do
    if not seenarray[seen] then
      seenarray[seen]='true'
    end
    seen = seenlist:read("*l")
  end
  seenlist:close()
  local count = 0
  local popen = io.popen(scan)
  for line in popen:lines() do
    if not seenarray[line] and line:sub(-1)~="/" then
      --checking that file is readable
      local errcheck, err = io.open(utils.join_path(settings.unseen_searchpath, line), "r") 
      if errcheck then
        errcheck:close()
        seenarray[line]='true'
        count = count + 1
        mp.commandv("loadfile", settings.unseen_searchpath..line, "append-play")
        msg.info("Loaded: "..line)
      end
    end
  end
  if count ~= 0 and args ~= 'hide' then 
    mp.osd_message("Added total of "..count.." files to playlist")
  end
  popen:close()
  plen = mp.get_property_number('playlist-count', 1)
end

unseentimer = mp.add_periodic_timer(1, timecheck)
unseentimer:kill()

idletimer = mp.add_periodic_timer(5, idle_timer)
idletimer:kill()

if settings.unseen_load_on_start then
    activate()
end

--react to script messages
function unseenmsg(msg, value)
  --allows other scripts to set mark to avoid conflicts
  if msg == "mark" then mark = value=="true" end
end
mp.register_script_message("unseenplaylist", unseenmsg)

mp.register_event('file-loaded', on_load)
mp.register_event('end-file', on_close)

--change the lines below if you want to change keybindings
mp.add_key_binding('w', 'mark-seen', watched)
mp.add_key_binding('W', 'playlist-mode-toggle', activate)
