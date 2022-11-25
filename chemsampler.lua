
local chemsampler_formspec =
    "size[8,7;]" ..
    "list[context;input;0,0.3;3,1;]" ..
    "list[current_player;main;0,2.85;8,1;]" ..
    "list[current_player;main;0,4.08;8,3;8]" ..
    "listring[context;books]" ..
    "listring[current_player;main]"
    --default.get_hotbar_bg(0,2.85)

local function update_formspec(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local formspec = chemsampler_formspec

    local mission = Mission.get_current_objective()
    if mission then
        objective_progress = mission:get_objective_progress(inv:get_list("input"))
        for i, itemprogress in ipairs(objective_progress) do
            formspec = formspec .. "item_image[" .. (i - 1) .. "," .. 0.3 .. ";1,1;" .. itemprogress.name .. "]"
            local current_count_string = itemprogress.count >= itemprogress.needed and minetest.colorize("#00FF00", tostring(itemprogress.count)) or tostring(itemprogress.count)
            formspec = formspec .. "label[" .. (i - 1) .. "," .. 1.3 .. ";" .. current_count_string .. "/" .. tostring(itemprogress.needed) .. "]"
        end
    end

    formspec = formspec .. "label[0,1.8;current mission: " .. Mission.get_current() .. "]"
    meta:set_string("formspec", formspec)
end


minetest.register_node("omg_missions:chemsampler", {
    description = "Chemicals Sampler",
    tiles = {"omg_missions_ChemSampler_Top.png", "omg_missions_ChemSampler_Bottom.png", "omg_missions_ChemSampler_Right.png", "omg_missions_ChemSampler_Left.png", "omg_missions_ChemSampler_Back.png", "omg_missions_ChemSampler_Front.png"},
    is_ground_content = false,
    groups = {dig_immediate = 3},
    paramtype2 = "facedir",
    --sounds = default.node_sound_stone_defaults()
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        inv:set_size("input", 3 * 1)
        update_formspec(pos)
    end,
    on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        update_formspec(pos)
    end,
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
        update_formspec(pos)
        local mission = Mission.get_current_objective()
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        if mission then
            local completed = mission:has_achieved_objective(player, inv:get_list("input"))
            if completed then mission:reward_player(player) end
        end
    end,
    on_metadata_inventory_take = function(pos, listname, index, stack, player)
        update_formspec(pos)
    end,
})
