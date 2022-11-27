local storage = minetest.get_mod_storage()

Mission = {
    get_current = function ()
        local progress = storage:get("progressv0")
        if progress then return progress
        else
            storage:set_string("progressv0", "first")
            return "first"
        end
    end,
    set_current = function (current)
        storage:set_string("progressv0", current)
    end
}

setmetatable(Mission, {
    __call = function(self, items)
        local new = {}
        setmetatable(new, {__index = Mission})
        --for k, v in pairs(Mission) do new[k] = v end
        new.items = items
        return new
    end})

local function give_or_drop_item(player, itemstack)
    local inv = minetest.get_inventory({type="player", name=player:get_player_name()})
    local remaining = inv:add_item("main", itemstack)
    minetest.add_item(player:get_pos(), remaining)
end

local function find_stack_in_table(t, itemstack)
    for _, i in ipairs(t) do
        if i:get_name() == itemstack:get_name() then
            return i
        end
    end
end

local function create_itemstack(nodename, count)
    local itemstack = ItemStack(nodename)
    itemstack:set_count(count)
    return itemstack
end

-- check if all itemstacks of t_needed are in t_has
-- TODO: currently, does not check if an itemstack is split
local function check_has_all_itemstacks(t_has, t_needed)
    for _, i_needed in ipairs(t_needed) do
        minetest.debug("needed: " .. dump(i_needed:get_name() .. ", " .. i_needed:get_count()))
        local i_has = find_stack_in_table(t_has, i_needed)
        if i_has then minetest.debug("has: " .. dump(i_has:get_name() .. ", " .. i_has:get_count())) end
        if not i_has or i_needed:get_count() > i_has:get_count() then
            return false
        end
    end
    return true
end

-- check if all itemstacks of t_needed are in t_has
-- TODO: currently, does not check if an itemstack is split
local function get_itemstacks_state(t_has, t_needed)
    local summary = {}
    for _, i_needed in ipairs(t_needed) do
        minetest.debug("needed: " .. dump(i_needed:get_name() .. ", " .. i_needed:get_count()))
        local i_has = find_stack_in_table(t_has, i_needed)
        if i_has then
            table.insert(summary, { name = i_needed:get_name(), count = i_has:get_count(), needed = i_needed:get_count()})
        else
            table.insert(summary, { name = i_needed:get_name(), count = 0, needed = i_needed:get_count()})
        end
    end
    return summary
end

Mission.has_achieved_objective = function(self, player, inv_list)
    return inv_list and check_has_all_itemstacks(inv_list, self.items)
end

-- returns a table with entries containing name, count, needed to know what is still missing
Mission.get_objective_progress = function(self, inv_list)
    if inv_list then
        return get_itemstacks_state(inv_list, self.items)
    end
end

Mission.reward_player = function(self, player)
    local drop = ItemStack("omg_missions:landing_site_marker")
    give_or_drop_item(player, drop)
    if Mission.get_current() == "first" then
        Mission.set_current("second")
    elseif Mission.get_current() == "second" then
        Mission.set_current("third")
    end

end

function Mission.get_current_objective()
    if Mission.get_current() == "first" then
        return Mission({ create_itemstack("farming:wheat", 12) })
    elseif Mission.get_current() == "second" then
        return Mission({ create_itemstack("default:dirt", 20), create_itemstack("wool:white", 2) })
    elseif Mission.get_current() == "third" then
        return Mission({ create_itemstack("default:tree", 4), create_itemstack("wool:white", 2) })
    end
end

local function is_itemstack(object)
    return object.get_meta and object:get_meta().set_tool_capabilities
end

local function is_list_of_itemstacks(object)
    return type(object) == "table" and #object > 0 and is_itemstack(object[1])
end

local function set_rocket_payload(rocket, payload)
    local i = 1
    -- notice that we swapped order so we fill rocket from bottom to top
    for y = 2, 4 do
        -- don´t put anything in the middle
        for z = 1, 3, 2 do
            for x = 1, 3 do
                if i <= #payload and payload[i] then
                    local node = payload[i]
                    if is_itemstack(payload[i]) or is_list_of_itemstacks(payload[i]) then
                        node = "scifi_nodes:crate"
                    end
                    rocket[(z * 7 + y) * 5 + x + 1].name = node
                else
                    rocket[(z * 7 + y) * 5 + x + 1].name = "vacuum:vacuum"
                end
                i = i + 1
            end
        end
    end
end

-- after creation of the nodes, fill the inventory
local function set_rocket_crate_content(base_pos, payload)
    local i = 1
    -- notice that we swapped order so we fill rocket from bottom to top
    for y = 2, 4 do
        for z = -1, 1, 2 do
            for x = -1, 1 do
                if i <= #payload and payload[i] then
                    if is_itemstack(payload[i]) or is_list_of_itemstacks(payload[i]) then
                        local meta = minetest.get_meta(vector.offset(base_pos, x, y, z))
                        local inv = meta:get_inventory()
                        if inv then
                            if is_itemstack(payload[i]) then
                                inv:add_item("main", payload[i])
                            else
                                for j = 1, #payload[i] do
                                    inv:add_item("main", payload[i][j])
                                end
                            end
                        else
                            minetest.debug("inventory expected at " .. vector.offset(base_pos, x, y, z) .. ", but there is none!")
                        end
                    end
                end
                i = i + 1
            end
        end
    end
end

local function rocket_nodes()
    local t = {}
    for dz = -2, 2 do
        for dy = 0, 6 do
            for dx = -2, 2 do
                local node = { name = "vacuum:vacuum" }
                if dy == 2 and (dx == -2 and dz == 0) then
                    node = { name = "scifi_nodes:white_door_closed", param2 = 1 }
                elseif dy == 3 and (dx == -2 and dz == 0) then
                    node = { name = "scifi_nodes:white_door_closed_top", param2 = 1 }
                -- lowest layer, landing gear
                elseif  dy == 0 and ((dx == -2 or dx == 2) and (dz == -2 or dz == 2)) then
                    node = { name = "scifi_nodes:greybolts" }
                -- lowest layer, engine
                elseif  dy == 0 and dx == 0 and dz == 0 then
                    node = { name = "scifi_nodes:engine" }
                -- exterior
                elseif  dy > 0 and dy <= 5 and ((dx ~= -2 and dx ~= 2) or (dz ~= -2 and dz ~= 2)) then
                    node = { name = "scifi_nodes:greybolts" }
                elseif dy == 6 and ((dx ~= -2 and dx ~= 2) and (dz ~= -2 and dz ~= 2)) then
                    node = { name = "scifi_nodes:greybolts" }
                end
                -- fill inner with air
                if  dy >= 2 and dy <= 4 and (dx >= -1 and dx <= 1) and (dz >= -1 and dz <= 1) then
                    node = { name = "air" }
                end
				table.insert(t, node)
			end
		end
	end
    return t
end


local function fully_charged_battery()
    itemstack = ItemStack("technic:battery")
    technic.refill_RE_charge(itemstack)
    return itemstack
end


function Mission.get_rewards()
    if Mission.get_current() == "first" then
        -- starting items
        return {
            -- technic
            create_itemstack("technic:solar_array_lv", 12), create_itemstack("technic:lv_cable", 60), "technic:switching_station",
            "technic:switching_station", create_itemstack("technic:lv_lamp", 4), create_itemstack("technic:lv_led", 4),
            "technic:lv_electric_furnace", "technic:lv_battery_box0", { fully_charged_battery(), fully_charged_battery() },
            -- other stuff
            create_itemstack("scifi_nodes:white_door_closed", 4),
            -- suit
            {ItemStack("spacesuit:helmet"), ItemStack("spacesuit:chestplate"), ItemStack("spacesuit:pants"), ItemStack("spacesuit:boots"), ItemStack("spacesuit:helmet"), ItemStack("spacesuit:chestplate"), ItemStack("spacesuit:pants"), ItemStack("spacesuit:boots")},
            -- air
            "vacuum:airpump", { create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99)},
            "vacuum:airpump", { create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99)},
            {create_itemstack("farming:seed_wheat", 8), create_itemstack("farming:seed_cotton", 4), create_itemstack("farming:wheat", 3) },
            {create_itemstack("farming:seed_wheat", 8), create_itemstack("farming:seed_cotton", 4), create_itemstack("farming:wheat", 3) },
            "omg_missions:chemsampler" }
    elseif Mission.get_current() == "second" then
        return {
            -- technic
            create_itemstack("technic:solar_array_lv", 12), create_itemstack("technic:lv_cable", 60), "technic:switching_station",
            create_itemstack("technic:lv_lamp", 4), create_itemstack("technic:lv_led", 8), create_itemstack("technic:lv_lamp", 4),
            "technic:lv_electric_furnace", "technic:lv_battery_box0", { fully_charged_battery(), fully_charged_battery() },
            -- other stuff
            create_itemstack("scifi_nodes:white_door_closed", 4),
            -- air
            "vacuum:airpump", { create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99)},
            "vacuum:airpump", { create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99), create_itemstack("vacuum:air_bottle", 99)}
        }
    elseif Mission.get_current() == "third" then
        return {
            create_itemstack("technic:solar_array_lv", 12), create_itemstack("technic:solar_array_lv", 12),
            create_itemstack("default:sapling", 2), create_itemstack("default:sapling", 2), 
        }
    end
    return {}
end

local function place_schematic(pos, schematic)
    local i = 1
    for dz = -2, 2 do
        for dy = 0, 6 do
            for dx = -2, 2 do
                if i <= #schematic and schematic[i] and schematic[i] then
                    minetest.add_node(vector.offset(pos, dx, dy, dz), schematic[i])
                end
				i = i + 1
			end
		end
	end
end


function Mission.spawn_supplies(pos)
    local rocket_schematic = {
        size = vector.new(5, 7, 5),
        data = rocket_nodes()
    }
    local rewards = Mission.get_rewards()
    set_rocket_payload(rocket_schematic.data, rewards)
    place_schematic(pos, rocket_schematic.data)--, "random", nil, true, {place_center_x = true, place_center_z = true})
    set_rocket_crate_content(pos, rewards)
end

