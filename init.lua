local http = minetest.request_http_api()
local F = minetest.formspec_escape

local function viewavatar(url, name)
	http.fetch({
			url = url,
			timeout = 5,
		},
		function(res)
			if not (res and res.data) then
				return
			end
			local image_b64 = minetest.encode_base64(res.data)
			if type(image_b64) == "string" then
				local img = "[png:" .. image_b64
				minetest.show_formspec(name,"wi","size[8.2,8.5]image[0,0;10,10;"..F(img).."]")
			end
		end
	)
end

local function discordspy(guild, callback)
	if not guild or guild == "" then
		guild = minetest.settings:get("discordspy_guild")
		if not guild then
			error("Please set discordspy_guild in settings")
		end
	end
	http.fetch({
			url = "https://discord.com/api/guilds/"..guild.."/widget.json",
			timeout = 5,
		},
		function(res)
			if not (res and res.data) then
				return
			end
			local jtable = minetest.parse_json(res.data)
			if type(jtable) == "table" and jtable.members then
				callback(jtable)
			end
		end
	)
end

local avatars, lastrow = {}, {}

minetest.register_chatcommand("discordspy",{
  description = "View online Discord users",
  func = function(name,param)
	local admin = minetest.check_player_privs(name,{server=true})
	if not admin then
		param = nil
	end
	discordspy(param, function(data)
		local users = {}
		avatars[name] = {}
		local player = minetest.get_player_by_name(name)
		for _,member in ipairs(data.members) do
			table.insert(users,F(member.username)..(player and "," or "(")..F(member.status:upper())..(player and "" or ")"))
			table.insert(avatars[name],member.avatar_url)
		end
		if not player then
			minetest.chat_send_player(name,table.concat(users,", "))
		end
		minetest.show_formspec(name,"discordspy",
			"size[8,9]" ..
			"label[2.8,0;Online Discord users]" ..
			"tablecolumns[text;text]" ..
			"table[0.2,0.6;7.4,7.6;list; Name,  Status,"..table.concat(users,",")..";]" ..
			"button[3,8.3;2,1;viewavatar;View avatar]"
		)
	end)
end})
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "discordspy" then
		return
	end
	local name = player:get_player_name()
	if fields.list then
		local event = minetest.explode_table_event(fields.list)
		if event and event.type == "CHG" then
			lastrow[name] = event.row
		end
		if event and event.type == "DCL" and event.row > 1 then
			viewavatar(avatars[name][event.row-1],name)
			lastrow[name] = nil
		end
	end
	if fields.viewavatar and lastrow[name] and lastrow[name] > 1 then
		viewavatar(avatars[name][lastrow[name]-1],name)
		lastrow[name] = nil
	end
	if fields.quit then
		lastrow[name] = nil
	end
end)
