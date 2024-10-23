local range = 100
local v = 1
local a = 100
local speed = 0.1 --0 or less for default maximum speed

local function spray_foam(pos)
	if minetest.get_node(pos).name == "extinguisher:foam" then
		-- Do not spray foam onto foam
		return
	end
	for z = -1,1 do
		for y = -1,1 do
			for x = -1,1 do
				local p = {x=pos.x+x, y=pos.y+y, z=pos.z+z}
				local nn = minetest.get_node(p).name
				if nn == "fire:basic_flame" then
					minetest.set_node(p, {name="extinguisher:foam"})
					minetest.sound_play("fire_extinguish_flame",
						{pos = p, max_hear_distance = 16, gain = 0.15})
					minetest.check_for_falling(p)
				elseif math.random(0,3) >= 1 then
					if nn == "air" then
						minetest.set_node(p, {name="extinguisher:foam"})
						minetest.check_for_falling(p)
					elseif nn == "default:lava_source" then
						minetest.set_node(p, {name="default:obsidian"})
					elseif nn == "default:lava_flowing" then
						minetest.set_node(p, {name="default:cobble"})
					end
				end
			end
		end
	end
end

local function extinguish(player)
	local playerpos = player:get_pos()
	local dir = player:get_look_dir()

	local startpos = vector.new(playerpos)
	startpos.y = startpos.y+1.625
	local bl, pos = minetest.line_of_sight(startpos,
		vector.add(vector.multiply(dir, range), startpos), 1)
	local snd = minetest.sound_play("extinguisher",
		{pos = playerpos, gain = 0.5, max_hear_distance = range})
	local flight_time = 1
	if pos then
		local s = math.max(vector.distance(startpos, pos)-0.5, 0)
		flight_time = (math.sqrt(v * v + 2 * a * s) - v) / a
	end
	if not bl then
		minetest.after(flight_time, function()
			-- Extinguish the node
			minetest.sound_stop(snd)
			spray_foam(vector.round(pos))
		end)
	end
	minetest.add_particle({
		pos = startpos,
		velocity = vector.multiply(dir, v),
		acceleration = vector.multiply(dir, a),
		expirationtime = flight_time,
		size = 1,
		texture = "extinguisher_shot.png^[transform" .. math.random(0,7),
	})
end

local function stop_all_fire_sounds()
	local players = minetest.get_connected_players()
	for i = 1, #players do
		fire.update_player_sound(players[i])
	end
end

local c_fire, c_foam, c_lava, c_lavaf, c_obsidian, c_cobble
local function extinguish_fire(pos)
	local t1 = os.clock()
	-- Size of the extinguishment
	local r = 40
	c_fire = c_fire or minetest.get_content_id("fire:basic_flame")
	c_foam = c_foam or minetest.get_content_id("extinguisher:foam")
	c_lava = c_lava or minetest.get_content_id("default:lava_source")
	c_lavaf = c_lavaf or minetest.get_content_id("default:lava_flowing")
	c_cobble = c_cobble or minetest.get_content_id("default:cobble")
	c_obsidian = c_obsidian or minetest.get_content_id("default:obsidian")

	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(vector.add(pos, -r),
		vector.add(pos, r))
	local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	local nodes = manip:get_data()

	for z = -r, r do
		for y = -r, r do
			for x = -r, r do
				local dist_sqr = x * x + y * y + z * z
				if dist_sqr <= r * r + r then
					local near_border =
						math.floor(math.sqrt(dist_sqr) + 0.5) > r - 1
					if not near_border
					or math.random(2) == 1 then
						local vi = area:index(pos.x + x, pos.y + y, pos.z + z)
						local d_p = nodes[vi]
						if d_p == c_fire then
							nodes[vi] = c_foam
						elseif d_p == c_lava then
							nodes[vi] = c_obsidian
						elseif d_p == c_lavaf then
							nodes[vi] = c_cobble
						end
					end
				end
			end
		end
	end

	manip:set_data(nodes)
	manip:write_to_map()
	stop_all_fire_sounds()
	print(string.format("[extinguisher] exploded at %s after ca. %.2fs",
		minetest.pos_to_string(pos), os.clock() - t1))
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
	use_texture_alpha = "blend",
	tiles = {"extinguisher_foam.png"},
	drop = "",
	groups = {dig_immediate=3, puts_out_fire=1, not_in_creative_inventory=1, falling_node=1},
})

local adtime = 0
local time = minetest.get_us_time()
local count = 0
minetest.register_abm({
	nodenames = {"extinguisher:foam"},
	interval = 5,
	chance = 5,
	catch_up = false,
	action = function(pos)
		count = count+1
		local ct = minetest.get_us_time()
		if count > 10
		and ct-time < 1000000 then
			return
		end
		time = ct
		count = 0
		minetest.remove_node(pos)
		if adtime < 0.1 then
			minetest.check_for_falling(pos)
		end
	end,
})

minetest.register_node("extinguisher:automatic", {
	description = "Extinguisher",
	tiles = {"extinguisher_top.png", "extinguisher_bottom.png",
		"extinguisher.png", "extinguisher.png^[transformFX",
		"extinguisher_front.png", "extinguisher_back.png"},
	use_texture_alpha = "opaque",
	inventory_image = "extinguisher.png",
	wield_image = "extinguisher_pipe.png",
	paramtype = "light",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			-- Main bottle
			{-2/16, -0.5, -5/16, 3/16, 0, 0},
			{-1/16, 0, -5/16, 2/16, 3/16, 0},
			{-2/16, 0, -4/16, 3/16, 3/16, -1/16},
			{-1/16, 3/16, -4/16, 2/16, 5/16, -1/16},
			{0, 5/16, -3/16, 1/16, 6/16, -2/16},

			-- Outlet
			{0, 3/16, -1/16, 1/16, 4/16, 2/16},
			{-1/16, 3/16, 2/16, 0, 4/16, 4/16},
			{1/16, 3/16, 2/16, 2/16, 4/16, 4/16},
			{0, 4/16, 2/16, 1/16, 5/16, 6/16},
			{0, 2/16, 2/16, 1/16, 3/16, 6/16},

			-- Handle
			{0, 6/16, -6/16, 1/16, 7/16, -1/16},
			{-1/16, 6/16, -3/16, 2/16, 7/16, -2/16},
			{0, 5/16, -7/16, 1/16, 6/16, -5/16},
			{0, 4/16, -7/16, 1/16, 5/16, -6/16},
		},
	},
	groups = {dig_immediate=2},
	sounds = {dig=""},
	on_punch = function(pos, _, player)
		minetest.sound_play("extinguisher_touch", {pos=pos, gain=0.25, max_hear_distance=8})
		if player:get_wielded_item():get_name() == "default:torch" then
			minetest.after(math.random()*5, eexpl, pos)
		end
	end,
	on_use = function() -- do not dig or punch nodes
	end,
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

if minetest.registered_items["poisonivy:climbing"] then
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
end

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


