
SupplyRocketEntity = {
	initial_properties = {
		physical = true,
		collide_with_objects = true,
		collisionbox = {-2.5, 0, -2.5, 2.5, 6, 2.5},
		selectionbox = {-2.5, 0, -2.5, 2.5, 6, 2.5},
		visual_size = {x = 1, y = 1, z = 1 },
		mesh = "rocket.obj",
		textures = { "omg_missions_rocket.png" },
		visual = "mesh",
		use_texture_alpha = true,
	},
	time = 0,
	stage = 0,
	time_since_last_damage = nil,
	target_pos = vector.new(),
	rocket_particle_spawner = nil,
	
	on_activate = function(self, staticdata, dtime_s)
		local state = minetest.deserialize(staticdata, true)
		if not state then return end
		self._owning_player_name = state.owning_player_name
		self.stage = state.stage
		self.time = state.time
		self.time_since_last_damage = state.time_since_last_damage
		self.target_pos = state.target_pos

		self.object:set_acceleration(vector.new(0, 1, 0))
		self:recalculate_velocity()
		if self.stage < 2 then
			self.rocket_particle_spawner = self:create_rocket_particle_spawner()
		end
	end,
	get_staticdata = function(self)
		return minetest.serialize(
			{
				owning_player_name = self._owning_player_name,
				stage = self.stage,
				time = self.time,
				time_since_last_damage = self.time_since_last_damage,
				target_pos = self.target_pos,
			})
		end,

	recalculate_velocity = function(self)
		local y_diff = vector.subtract(self.object:get_pos(), self.target_pos).y
		local acceleration = 1
		if y_diff > 0 then
			local time_to_touchdown = math.sqrt(2 * y_diff / acceleration)
			self.object:set_velocity(vector.new(0, - acceleration * time_to_touchdown, 0))
		else
			self.object:set_velocity(vector.new(0, 0, 0))
		end
	end,
}

minetest.register_entity("omg_missions:supply_rocket", SupplyRocketEntity)


function SupplyRocketEntity.on_step(self, dtime, moveresult)
	self.time = self.time + dtime

	local do_damage = false
	if (not self.time_since_last_damage) or (self.time_since_last_damage + .5 < self.time) then
		do_damage = true
		self.time_since_last_damage = self.time
	end
	-- damage players and objects close to the engine
	local objects = minetest.get_objects_inside_radius(self.object:get_pos(), 16)
	for _, other_object in ipairs(objects) do
		local pos_diff = vector.subtract(other_object:get_pos(), self.object:get_pos())
		local dist = vector.distance(self.object:get_pos(), other_object:get_pos())
		if pos_diff.y < 0 and vector.length(vector.new(pos_diff.x, 0, pos_diff.z)) < 4 then
			local damage = (4 / dist)
			if other_object:is_player() then
				local dir = vector.normalize(pos_diff)
				local moveoff = vector.multiply(dir, 8 / dist)
				other_object:add_velocity(moveoff)

				if do_damage then
					other_object:set_hp(other_object:get_hp() - damage)
				end
			elseif other_object ~= self.object then
				tool_capabilities ={
					full_punch_interval = 1.0,
					damage_groups = {fleshy = damage},
				}
				other_object:punch(self.object, dtime, tool_capabilities)
			end
		end
	end
	
	local y_diff = vector.subtract(self.object:get_pos(), self.target_pos).y + .5
	if self.stage == 0 and self.object:get_velocity().y > -.2 then
		self.object:set_acceleration(vector.new(0, 0, 0))
		self.object:set_velocity(vector.new(0, -.2, 0))
		self.stage = 1
	elseif self.stage <= 1 and self.time >= 24 then
		-- liftoff again and disappear
		if self.object:get_acceleration().y < 1 then
			--minetest.chat_send_player(self._owning_player_name, "Rocket lifts off again, as it could not land!")
		end
		self.object:set_acceleration(vector.new(0, 2, 0))
		if y_diff > 45 then
			self.object:remove()
		end
	elseif self.stage == 1 and math.abs(y_diff) > .15 then
		self.object:set_velocity(vector.new(0, -1.2 * y_diff, 0))
	elseif self.stage == 1 and math.abs(y_diff) < .15 then
		self.object:set_velocity(vector.new(0, 0, 0))
		if self.rocket_particle_spawner then
			minetest.delete_particlespawner(self.rocket_particle_spawner)
			self.rocket_particle_spawner = nil
		end
		self.stage = 2
	elseif self.stage == 2 and self.time >= 18 then
		self.object:remove()
		Mission.spawn_supplies(self.target_pos)
	end
end

function SupplyRocketEntity.spawn_above_pos(pos)
	local new_obj = minetest.add_entity(vector.offset(pos, 0, 50, 0), "omg_missions:supply_rocket")
	new_obj:set_velocity(vector.new(0, -10, 0))
	new_obj:set_acceleration(vector.new(0, 1, 0))
	new_obj:get_luaentity().rocket_particle_spawner = new_obj:get_luaentity():create_rocket_particle_spawner()
	new_obj:get_luaentity().target_pos = pos
end



function SupplyRocketEntity.create_rocket_particle_spawner(self)
	return minetest.add_particlespawner(
		{
			amount = 240,
			-- Number of particles spawned over the time period `time`.

			time = 0,
			-- Lifespan of spawner in seconds.
			-- If time is 0 spawner has infinite lifespan and spawns the `amount` on
			-- a per-second basis.

			collisiondetection = true,
			-- If true collide with `walkable` nodes and, depending on the
			-- `object_collision` field, objects too.

			collision_removal = false,
			-- If true particles are removed when they collide.
			-- Requires collisiondetection = true to have any effect.

			object_collision = true,
			-- If true particles collide with objects that are defined as
			-- `physical = true,` and `collide_with_objects = true,`.
			-- Requires collisiondetection = true to have any effect.

			attached = self.object,

			texture = "default_furnace_fire_fg.png",
			glow = 8,

			-- Legacy definition fields

			minpos = {x=-.3, y=0, z=-.3},
			maxpos = {x=.3, y=-.1, z=.3},
			minvel = {x=-1.5, y=-6, z=-1.5},
			maxvel = {x=1.5, y=-12, z=1.5},
			minacc = {x=0, y=0, z=0},
			maxacc = {x=0, y=0, z=0},
		}
	)
end
