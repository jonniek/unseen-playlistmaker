local settings = {
	linux_over_windows = true,                                 --linux=true, windows=false

	--playlist management settings
	playlist_savepath = "/custom/playlists/",                      --notice trailing \ or /
	playlist_osd_dur = 5,                                       --seconds playlist is shown when navigating                                   
	loadfiles_filetypes = {'*mkv','*mp4','*jpg','*gif','*png','*avi','*mp3','*flac'}, --shortcut P filetypes that will be loaded, true if all filetypes, else array like {'*mkv','*mp4'}
	sortplaylist_on_start = false,

	--amount of entries to show before slicing. Optimal value depends on font/video size etc.
	showamount = 13,

	--replaces matches on filenames, put as false to not replace anything
	--replaces executed in index order, if order doesn't matter many can be placed inside one index of rules
	--uses :gsub('pattern', 'replace'), read more http://lua-users.org/wiki/StringLibraryTutorial
	filename_replace = {
		[1] = {
			['ext'] = { ['all']=true }, --apply rule to all files
			['rules'] = {
				[1] = { ['^.*/'] = '' },	--strip paths from file, all before and last / removed
				[2] = { ['_'] = ' ' },   	--change underscore to space
			},
		},
		[2] = {
			['ext'] = { ['mkv']=true, ['mp4']=true }, --apply rule to mkv and mp4 only
			['rules'] = {
				[1] = { ['^(.+)%..+$']='%1' },					--remove extension
				[2] = { ['%s*[%[%(].-[%]%)]%s*']='' },  --remove brackets, their content and surrounding white space
				[3] = { ['(%w)%.(%w)']='%1 %2' },  			--change dots between alphanumeric chars to spaces
			},
		},
	},

	--set title of window with stripped name and suffix
	set_title_stripped = true,
  title_prefix = "",
  title_suffix = " - mpv",

	--slice long filenames, and how many chars to show
	slice_longfilenames = {true, 70},

	--show playlist every time a new file is loaded
	--will try to override any osd-playing-msg conf, may cause flickering if a osd-playing-msg exists.
	--2 shows playlist, 1 shows current file(filename strip above applied), 0 shows nothing
	show_playlist_on_fileload = 1,

	--show playlist when selecting file within manager (ENTER)
	show_playlist_on_select = false,

	--sync cursor when file is loaded from outside reasons(file-ending, playlist-next shortcut etc.)
	--has the sideeffect of moving cursor if file happens to change when navigating
	--good side is cursor always following current file when going back and forth files
	--2 is true, always follow on load 
	--1 is sticky, follow if cursor is close
	--0 is false, never follow
	sync_cursor_on_load = 2,

	--playlist display signs, {"prefix", "suffix"}
	playing_str = {"->", ""},
	cursor_str = {">", "<"},
	cursor_str_selected = {">>", "<<"},
	--top and bottom if playlist entries are sliced off from display
	sliced_str = {"...", "..."},

	--keybindings force override only while playlist is visible
	--allowing you to use common overlapping keybinds
	dynamic_binds = false,

	--### UNSEEN PLAYLISTMAKER SETTINGS ###

	--toggle to load unseen playlistmaker on startup, use only if loading script manually
	unseen_load_on_start = false,
	--unseen-playlistmaker filetypes, {'*'} for all filetypes
	unseen_filetypes = {'*mkv','*mp4'},
	--path to media files where unseen-playlistmaker should look for files 
	unseen_searchpath = "/media/HDD/users/anon/Downloads/temp/",
	--file and path to where to save seen files
	unseen_savedpath="/custom/list",
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
	local stripped = strippath(mp.get_property('media-title'))
	if settings.show_playlist_on_fileload == 2 then
		showplaylist(true)
	elseif settings.show_playlist_on_fileload == 1 then
		mp.commandv('show-text', stripped, 2000)
	end
	if settings.set_title_stripped then
    mp.set_property("title", settings.title_prefix..stripped..settings.title_suffix)
	end
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
		mp.add_timeout(2, timecheck)
	end
end

--marks episode as watched, invoked at timecheck() and shortcut (w)
--this file is loaded in search()
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

function strippath(pathfile)
	local ext = pathfile:match("^.+%.(.+)$")
  if not ext then ext = "" end
	local tmp = pathfile
	if settings.filename_replace then
		for k,v in ipairs(settings.filename_replace) do
			if v['ext'][ext] or v['ext']['all'] then
				for ruleindex, indexrules in ipairs(v['rules']) do
					for rule, override in pairs(indexrules) do
						tmp = tmp:gsub(rule, override)
					end
				end
			end
		end
	end
  if settings.slice_longfilenames[1] and tmp:len()>settings.slice_longfilenames[2]+5 then
    tmp = tmp:sub(1, settings.slice_longfilenames[2]).." ..."
  end
	return tmp
end

cursor = 0
function showplaylist(delay)
	if delay then
		mp.add_timeout(0.2,showplaylist)
		return
	end
	add_keybinds()
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
		output = "Playing: "..strippath(mp.get_property('media-title')).."\n\n"
		output = output.."Playlist - "..(cursor+1).." / "..plen.."\n"
		local b = cursor - math.floor(settings.showamount/2)
		local showall = false
		local showrest = false
		if b<0 then b=0 end
		if plen <= settings.showamount then
			b=0
			showall=true
		end
		if b > math.max(plen-settings.showamount-1, 0) then 
			b=plen-settings.showamount
			showrest=true
		end
		if b > 0 and not showall then output=output.."...\n" end
		for a=b,b+settings.showamount-1,1 do
	    if a == plen then break end
	    if a == pos then output = output..settings.playing_str[1] end
	    if a == cursor then
        if tag then
          output = output..settings.cursor_str_selected[1]..playlist[a]..settings.cursor_str_selected[2].."\n"
        else
          output = output..settings.cursor_str[1]..playlist[a]..settings.cursor_str[2].."\n"
        end
	    else
        output = output..playlist[a].."\n"
	    end
	    if a == pos then output = output..settings.playing_str[2] end
	    if a == b+settings.showamount-1 and not showall and not showrest then
	      output=output..settings.sliced_str[2]
	    end
		end
	else
		output = file
	end
	mp.osd_message(output, settings.playlist_osd_dur)
  timer:kill()
  timer:resume()
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
	if settings.show_playlist_on_select then
		showplaylist(true)
  else
    remove_keybinds()
	end
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

function add_keybinds()
	mp.add_forced_key_binding('UP', 'moveup', moveup, "repeatable")
	mp.add_forced_key_binding('DOWN', 'movedown', movedown, "repeatable")
	mp.add_forced_key_binding('CTRL+UP', 'tagcurrent', tagcurrent)
	mp.add_forced_key_binding('ENTER', 'jumptofile', jumptofile)
	mp.add_forced_key_binding('BS', 'removefile', removefile)
end

function remove_keybinds()
  if settings.dynamic_binds then
    mp.remove_key_binding('moveup')
    mp.remove_key_binding('movedown')
    mp.remove_key_binding('tagcurrent')
    mp.remove_key_binding('jumptofile')
    mp.remove_key_binding('removefile')
  end
end
timer = mp.add_periodic_timer(settings.playlist_osd_dur, remove_keybinds)
timer:kill()
if not settings.dynamic_binds then
  add_keybinds()
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


