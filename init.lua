omg_missions_path = minetest.get_modpath("omg_missions")

dofile(omg_missions_path.."/mission.lua");
dofile(omg_missions_path.."/chemsampler.lua");

local function is_clear_for_landing(pos)
	for dx = -2, 2 do
		for dz = -2, 2 do
			for dy = 0, 6 do
				local node = minetest.get_node(vector.offset(pos, dx, dy, dz)).name
				if node ~= "air" and node ~= "vacuum:vacuum" then
					return false
				end
			end
		end
	end
	return true
end


minetest.register_node("omg_missions:landing_site_marker", {
	description = "LandingSiteMarker",
	tiles = {"omg_missions_LandingSiteMarker.png"},
	paramtype = "light",
	buildable_to = true,
	floodable = true,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.45, 0.5},
		},
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.45, 0.5},
		},
	},
	--inventory_image = "default_snowball.png",
	wield_image = "omg_missions_LandingSiteMarker.png",
	groups = {crumbly = 3},
	--sounds = default.node_sound_snow_defaults(),
	on_place = function(itemstack, placer, pointed_thing)
		-- check area
		local pos = pointed_thing.above
		if not is_clear_for_landing(pos) then
			minetest.debug("no space for landing!")
			return nil
		else
			return minetest.item_place(itemstack, placer, pointed_thing)
		end
	end,
	on_construct = function(pos)
		minetest.get_node_timer(pos):start(math.random(10, 20))
	end,

	on_timer = function(pos)
		Mission.spawn_supplies(pos)
	end
})