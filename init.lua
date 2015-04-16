local range = 100
local v = 1
local a = 100
local speed = 0.1 --0 or less for default maximum speed

local particle_texture = "extinguisher_shot.png"
local sound = "extinguisher"
local lastp = vector.zero

local function spray_foam(pos)
	local smp
	for z = -1,1 do
		for y = -1,1 do
			for x = -1,1 do
				local p = {x=pos.x+x, y=pos.y+y, z=pos.z+z}
				smp = vector.round(vector.divide(p, 3))
				if vector.equals(smp, lastp) then
					return
				end
				local nn = minetest.get_node(p).name
				if nn == "fire:basic_flame" then
					minetest.set_node(p, {name="extinguisher:foam"})
					fire.on_flame_remove_at(p)
					nodeupdate(p)
				elseif math.random(0,3) >= 1 then
					if nn == "air" then
						minetest.set_node(p, {name="extinguisher:foam"})
						nodeupdate(p)
					elseif nn == "default:lava_source" then
						minetest.set_node(p, {name="default:obsidian"})
					elseif nn == "default:lava_flowing" then
						minetest.set_node(p, {name="default:cobble"})
					end
				end
			end
		end
	end
	lastp = vector.new(smp)
end

local function extinguish_node(pos, player, sound)
	minetest.sound_stop(sound)
	spray_foam(pos)
end

local function extinguish(player)
	--local t1 = os.clock()

	local playerpos = player:getpos()
	local dir = player:get_look_dir()

	local startpos = {x=playerpos.x, y=playerpos.y+1.625, z=playerpos.z}
	local bl, pos = minetest.line_of_sight(startpos, vector.add(vector.multiply(dir, range), startpos), 1)
	local snd = minetest.sound_play(sound, {pos = playerpos, gain = 0.5, max_hear_distance = range})
	local delay = 1
	if pos then
		delay = vector.straightdelay(math.max(vector.distance(startpos, pos)-0.5, 0), v, a)
	end
	if not bl then
		minetest.after(delay, function(pos)
			extinguish_node(vector.round(pos), player, snd)
		end, pos, player, snd)
	end
	minetest.add_particle({
		pos = startpos,
		vel = vector.multiply(dir, v),
		acc = vector.multiply(dir, a),
		expirationtime = delay,
		size = 1,
		texture = particle_texture.."^[transform"..math.random(0,7)
	})

	--print("[extinguisher] my shot was calculated after "..tostring(os.clock()-t1).."s")
end


--[[
local function table_empty(t)
	for _,_ in pairs(t) do
		return false
	end
	return true
end

local function get_tab(pos)
	local tab_tmp = {pos}
	local tab_avoid = {[pos.x.." "..pos.y.." "..pos.z] = true}
	local tab_done,num = {pos},2
	while not table_empty(tab_tmp) do
		for n,p in pairs(tab_tmp) do
			tab_tmp[n] = nil
			for z = -2,2 do
				for y = -2,2 do
					for x = -2,2 do
						local p2 = {x=pos.x+x, y=pos.y+y, z=pos.z+z}
						local pstr = p2.x.." "..p2.y.." "..p2.z
						if not tab_avoid[pstr]
						and minetest.get_node(p2).name == "fire:basic_flame" then
							tab_avoid[pstr] = true
							tab_done[num] = p2
							num = num+1
							table.insert(tab_tmp, p2)
						end
					end
				end
			end
		end
	end
	return tab_done
end]]

local function stop_all_fire_sounds()
	for _,sound in pairs(fire.sounds) do
		minetest.sound_stop(sound.handle)
	end
end

local c_fire, c_foam, c_lava, c_lavaf, c_obsidian, c_cobble
local function extinguish_fire(pos)
	local t1 = os.clock()
	c_fire = c_fire or minetest.get_content_id("fire:basic_flame")
	c_foam = c_foam or minetest.get_content_id("extinguisher:foam")
	c_lava = c_lava or minetest.get_content_id("default:lava_source")
	c_lavaf = c_lavaf or minetest.get_content_id("default:lava_flowing")
	c_cobble = c_cobble or minetest.get_content_id("default:cobble")
	c_obsidian = c_obsidian or minetest.get_content_id("default:obsidian")
	local tab = vector.explosion_table(40)

	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(vector.add(pos, -40), vector.add(pos, 40))
	local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	local nodes = manip:get_data()

	for _,i in pairs(tab) do
		local ran = i[2]
		if not ran
		or math.random(2) == 1 then
			local p = area:indexp(vector.add(pos, i[1]))
			local d_p = nodes[p]
			if d_p == c_fire then
				nodes[p] = c_foam
			elseif d_p == c_lava then
				nodes[p] = c_obsidian
			elseif d_p == c_lavaf then
				nodes[p] = c_cobble
			end
		end
	end

	manip:set_data(nodes)
	manip:write_to_map()
	stop_all_fire_sounds()
	print(string.format("[extinguisher] exploded at ("..pos.x.."|"..pos.y.."|"..pos.z..") after ca. %.2fs", os.clock() - t1))
	--[[t1 = os.clock()
	manip:update_map()
	print(string.format("[extinguisher] map updated after ca. %.2fs", os.clock() - t1))]]
end

local function eexpl(pos)
	if minetest.get_node(pos).name ~= "extinguisher:automatic" then
		return
	end
	minetest.sound_play("extinguisher_explosion", {pos=pos})
	minetest.set_node(pos, {name="extinguisher:destroyed"})
	local startpos = minetest.find_node_near(pos, 2, {"fire:basic_flame"})
	if not startpos then
		return
	end
	extinguish_fire(startpos)
end


minetest.register_node("extinguisher:foam", {
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		}
	},
	use_texture_alpha = true,
	tiles = {"extinguisher_foam.png"},
	drop = "",
	groups = {dig_immediate=3, puts_out_fire=1, not_in_creative_inventory=1, falling_node=1},
})

local adtime = 0
local time = tonumber(os.clock())
local count = 0
minetest.register_abm({
	nodenames = {"extinguisher:foam"},
	interval = 5,
	chance = 5,
	action = function(pos)
		count = count+1
		if count > 10
		and tonumber(os.clock())-time < 1 then
			return
		end
		time = tonumber(os.clock())
		count = 0
		minetest.remove_node(pos)
		if adtime < 0.1 then
			nodeupdate(pos)
		end
	end,
})

minetest.register_node("extinguisher:automatic", {
	description = "Extinguisher",
	tiles = {"extinguisher.png"},
	inventory_image = "extinguisher.png",
	wield_image = "extinguisher_pipe.png",
	drawtype = "plantlike",
	paramtype = "light",
	groups = {dig_immediate=2},
	sounds = {dig=""},
	on_punch = function(pos, _, player)
		minetest.sound_play("extinguisher_touch", {pos=pos, gain=0.25, max_hear_distance=8})
		if player:get_wielded_item():get_name() == "default:torch" then
			minetest.after(math.random()*5, eexpl, pos)
		end
	end
})

minetest.register_node("extinguisher:destroyed", {
	tiles = {"extinguisher_destroyed.png"},
	drawtype = "plantlike",
	paramtype = "light",
	groups = {dig_immediate=2},
	drop = {items = {{items =
		{"default:steel_ingot 4", "default:stick 2"}
	}}},
})

local timer = 0
minetest.register_globalstep(function(dtime)
	adtime = dtime
	timer = timer+dtime
	if timer < speed then
		return
	end
	timer = 0
	for _,player in pairs(minetest.get_connected_players()) do
		if player:get_wielded_item():get_name() == "extinguisher:automatic"
		and player:get_player_control().LMB then
			extinguish(player)
		end
	end
end)

minetest.register_craftitem("extinguisher:foam_ingredient_1", {
	description = "Foam Ingredient",
	inventory_image = "extinguisher_essence_1.png",
})

minetest.register_craftitem("extinguisher:foam_ingredient_2", {
	description = "Foam Ingredient",
	inventory_image = "extinguisher_essence_2.png",
})

minetest.register_craftitem("extinguisher:foam_bucket", {
	description = "Foam",
	inventory_image = "extinguisher_foam_bucket.png",
})

minetest.register_craft({
	output = "extinguisher:foam_ingredient_1 2",
	recipe = {
		{"default:stone"},
		{"poisonivy:climbing"},
		{"default:stone"},
	},
	replacements = {{"default:stone", "default:stone"}, {"default:stone", "default:stone"}},
})

minetest.register_craft({
	output = "extinguisher:foam_ingredient_2",
	recipe = {
		{"default:stone"},
		{"poisonivy:seedling"},
		{"default:stone"},
	},
	replacements = {{"default:stone", "default:stone"}, {"default:stone", "default:stone"}},
})

minetest.register_craft({
	output = "extinguisher:foam_ingredient_2 3",
	recipe = {
		{"default:stone"},
		{"poisonivy:sproutling"},
		{"default:stone"},
	},
	replacements = {{"default:stone", "default:stone"}, {"default:stone", "default:stone"}},
})

minetest.register_craft({
	output = "extinguisher:foam_bucket",
	recipe = {
		{"extinguisher:foam_ingredient_1"},
		{"extinguisher:foam_ingredient_2"},
		{"bucket:bucket_water"},
	},
})

minetest.register_craft({
	output = "extinguisher:foam_bucket",
	recipe = {
		{"extinguisher:foam_ingredient_2"},
		{"extinguisher:foam_ingredient_1"},
		{"bucket:bucket_water"},
	},
})

minetest.register_craft({
	output = "extinguisher:automatic",
	recipe = {
		{"group:stick", "", ""},
		{"default:steel_ingot", "group:stick", "group:stick"},
		{"extinguisher:foam_bucket", "", ""},
	},
})


