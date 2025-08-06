local function is_auto_play_enabled()
    -- auto play fire spells without orbwalker
    local is_auto_play_active = auto_play.is_active();
    local auto_play_objective = auto_play.get_objective();
    local is_auto_play_fighting = auto_play_objective == objective.fight;
    if is_auto_play_active and is_auto_play_fighting then
        return true;
    end

    return false;
end

local blood_mist_buff_name = "Necromancer_BloodMist";
local blood_mist_buff_name_hash = blood_mist_buff_name;
local blood_mist_buff_name_hash_c = 493422;

local mount_buff_name = "Generic_SetCannotBeAddedToAITargetList";
local mount_buff_name_hash = mount_buff_name;
local mount_buff_name_hash_c = 1923;

local shrine_conduit_buff_name = "Shine_Conduit";
local shrine_conduit_buff_name_hash = shrine_conduit_buff_name;
local shrine_conduit_buff_name_hash_c = 421661;

-- Crackling Energy Snapshot buff ID
local portal_transfer_buff_id = 241932;
local portal_transfer_buff_name = "PortalTransferSetupBuff";

-- Crackling Energy tracking variables
local is_crackling_energy_loop_active = false;
local ball_cast_count = 0;
local ball_cast_threshold = 4;
local last_buff_check_time = 0;
local buff_check_interval = 0.5; -- Check for buff every 0.5 seconds
local spear_ready_time = 0; -- Time when spear will be ready to cast after threshold is met
local last_ball_track_time = 0; -- Last time we tracked a ball cast
local ball_track_cooldown = 0.3; -- Minimum time between ball cast tracking (in seconds)

-- Skin name patterns for infernal horde objectives
local horde_objectives = {
    "BSK_HellSeeker",
    "MarkerLocation_BSK_Occupied",
    "S05_coredemon",
    "S05_fallen",
    "BSK_Structure_BonusAether",
    "BSK_Miniboss",
    "BSK_elias_boss",
    "BSK_cannibal_brute_boss",
    "BSK_skeleton_boss"
}

local function is_action_allowed()

     -- evade abort
   local local_player = get_local_player();
   if not local_player then
       return false
   end  
   
   local player_position = local_player:get_position();
   if evade.is_dangerous_position(player_position) then
       return false;
   end

   local busy_spell_id_1 = 197833
   local active_spell_id = local_player:get_active_spell_id()
   if active_spell_id == busy_spell_id_1 then
       return false
   end 
  
    local is_mounted = false;
    local is_blood_mist = false;
    local is_shrine_conduit = false;
    local portal_transfer_buff_detected = false;
    local local_player_buffs = local_player:get_buffs();
    
    for _, buff in ipairs(local_player_buffs) do
          -- console.print("buff name ", buff:name());
          -- console.print("buff hash ", buff.name_hash);
          if buff.name_hash == blood_mist_buff_name_hash_c then
              is_blood_mist = true;
              break;
          end
  
          if buff.name_hash == mount_buff_name_hash_c then
            is_mounted = true;
              break;
          end
  
          if buff.name_hash == shrine_conduit_buff_name_hash_c then
            is_shrine_conduit = true;
              break;
          end
          
          -- Check for PortalTransferSetupBuff
          if buff.name_hash == portal_transfer_buff_id or buff:name() == portal_transfer_buff_name then
              portal_transfer_buff_detected = true;
              
              -- Check if the Crackling Energy Snapshot option is enabled in spear.lua
              local spear_module = require("spells/spear")
              local crackling_energy_snapshot_enabled = spear_module.get_crackling_energy_snapshot_enabled()
              
              -- Only start the loop if the option is enabled
              if crackling_energy_snapshot_enabled then
                  -- Start/restart the Crackling Energy loop when buff is detected
                  if not is_crackling_energy_loop_active then
                      is_crackling_energy_loop_active = true;
                      ball_cast_count = 0;
                      spear_ready_time = 0;
                      console.print("[CRACKLING ENERGY] Loop started - Buff detected: " .. buff:name() .. " (ID: " .. buff.name_hash .. ")");
                  end
              else
                  -- If the option is disabled, make sure the loop is inactive
                  if is_crackling_energy_loop_active then
                      is_crackling_energy_loop_active = false;
                      ball_cast_count = 0;
                      spear_ready_time = 0;
                      console.print("[CRACKLING ENERGY] Loop disabled - Option is turned off");
                  end
              end
          end
    end
  
      -- do not make any actions while in blood mist
      if is_blood_mist or is_mounted or is_shrine_conduit then
          -- console.print("Blocking Actions for Some Buff");
          return false;
      end

    return true

end

-- local function is_spell_owned(spell_id)

--     for i, x in ipairs(get_equipped_spell_ids()) do
--         if x == spell_id then
--             return true
--         end
--     end
-- end
-- Function to check if a spell is allowed based on crackling energy logic
local function check_crackling_energy_spell_restrictions(spell_id)
    -- Ball Lightning spell ID
    local ball_spell_id = 514030
    -- Lightning Spear spell ID
    local spear_spell_id = 292074
    
    -- Only apply restrictions if crackling energy loop is active
    if is_crackling_energy_loop_active then
        local current_time = get_time_since_inject()
        
        -- Check if we're casting ball lightning
        if spell_id == ball_spell_id then
            -- Always allow ball lightning while we're under the threshold
            return true
        end
            
        -- Check if we're casting lightning spear
        if spell_id == spear_spell_id then
            -- Only allow spear if we've reached the threshold and the timer is ready
            if ball_cast_count >= ball_cast_threshold then
                if spear_ready_time == 0 then
                    -- Set spear to be ready in 0.5 seconds when threshold is first reached
                    spear_ready_time = current_time + 0.5
                    console.print("[CRACKLING ENERGY] Threshold reached: " .. ball_cast_count .. "/" .. ball_cast_threshold .. ". Spear will be ready in 0.5s")
                    return false
                elseif current_time >= spear_ready_time then
                    -- Spear is ready to cast
                    console.print("[CRACKLING ENERGY] Casting Spear now")
                    return true
                else
                    -- Still waiting for spear timer
                    return false
                end
            else
                -- Not enough ball casts yet
                console.print("[CRACKLING ENERGY] Blocked Spear - Need " .. ball_cast_threshold .. " Ball casts first (Current: " .. ball_cast_count .. ")")
                return false
            end
        end
            
        -- Block all other spells during crackling energy loop
        return false
    end
    
    -- If we're not in crackling energy mode or the spell is allowed, return true
    return true
end

local function is_spell_allowed(spell_enable_check, next_cast_allowed_time, spell_id)
    if not spell_enable_check then
        return false;
    end;

    local current_time = get_time_since_inject();
    if current_time < next_cast_allowed_time then
        return false;
    end;

    if not utility.is_spell_ready(spell_id) then
        return false;
    end;

    if not utility.is_spell_affordable(spell_id) then
        return false;
    end;
    
    -- Check crackling energy restrictions
    if not check_crackling_energy_spell_restrictions(spell_id) then
        return false
    end

    -- "Combo & Clear", "Combo Only", "Clear Only"
    local current_cast_mode = spell_cast_mode
    
    -- evade abort
    local local_player = get_local_player();
    if local_player then
        local player_position = local_player:get_position();
        if evade.is_dangerous_position(player_position) then
            return false;
        end
    end    

    -- -- automatic
    -- if current_cast_mode == 4 then
    --     return true
    -- end

    if is_auto_play_enabled() then
        return true;
    end

    -- local is_pvp_or_clear = current_cast_mode == 0
    -- local is_pvp_only = current_cast_mode == 1
    -- local is_clear_only = current_cast_mode == 2

    local current_orb_mode = orbwalker.get_orb_mode()
    
    if current_orb_mode == orb_mode.none then
        return false
    end

    local is_current_orb_mode_pvp = current_orb_mode == orb_mode.pvp
    local is_current_orb_mode_clear = current_orb_mode == orb_mode.clear
    -- local is_current_orb_mode_flee = current_orb_mode == orb_mode.flee
    
    -- if is_pvp_only and not is_current_orb_mode_pvp then
    --     return false
    -- end

    -- if is_clear_only and not is_current_orb_mode_clear then
    --     return false
    -- end

     -- is pvp or clear (both)
     if not is_current_orb_mode_pvp and not is_current_orb_mode_clear then
        return false;
    end

    -- we already checked everything that we wanted. If orb = none, we return false. 
    -- PVP only & not pvp mode, return false . PvE only and not pve mode, return false.
    -- All checks passed at this point so we can go ahead with the logics

    return true

end

local function generate_points_around_target(target_position, radius, num_points)
    local points = {};
    for i = 1, num_points do
        local angle = (i - 1) * (2 * math.pi / num_points);
        local x = target_position:x() + radius * math.cos(angle);
        local y = target_position:y() + radius * math.sin(angle);
        table.insert(points, vec3.new(x, y, target_position:z()));
    end
    return points;
end

local function get_best_point(target_position, circle_radius, current_hit_list)
    local points = generate_points_around_target(target_position, circle_radius * 0.75, 8); -- Generate 8 points around target
    local hit_table = {};

    local player_position = get_player_position();
    for _, point in ipairs(points) do
        local hit_list = utility.get_units_inside_circle_list(point, circle_radius);

        local hit_list_collision_less = {};
        for _, obj in ipairs(hit_list) do
            local is_wall_collision = target_selector.is_wall_collision(player_position, obj, 2.0);
            if not is_wall_collision then
                table.insert(hit_list_collision_less, obj);
            end
        end

        table.insert(hit_table, {
            point = point, 
            hits = #hit_list_collision_less, 
            victim_list = hit_list_collision_less
        });
    end

    -- sort by the number of hits
    table.sort(hit_table, function(a, b) return a.hits > b.hits end);

    local current_hit_list_amount = #current_hit_list;
    if hit_table[1].hits > current_hit_list_amount then
        return hit_table[1]; -- returning the point with the most hits
    end
    
    return {point = target_position, hits = current_hit_list_amount, victim_list = current_hit_list};
end

function is_target_within_angle(origin, reference, target, max_angle)
    local to_reference = (reference - origin):normalize();
    local to_target = (target - origin):normalize();
    local dot_product = to_reference:dot(to_target);
    local angle = math.deg(math.acos(dot_product));
    return angle <= max_angle;
end

local function generate_points_around_target_rec(target_position, radius, num_points)
    local points = {}
    local angles = {}
    for i = 1, num_points do
        local angle = (i - 1) * (2 * math.pi / num_points)
        local x = target_position:x() + radius * math.cos(angle)
        local y = target_position:y() + radius * math.sin(angle)
        table.insert(points, vec3.new(x, y, target_position:z()))
        table.insert(angles, angle)
    end
    return points, angles
end

local function get_best_point_rec(target_position, rectangle_radius, width, current_hit_list)
    local points, angles = generate_points_around_target_rec(target_position, rectangle_radius, 8)
    local hit_table = {}

    for i, point in ipairs(points) do
        local angle = angles[i]
        -- Calculate the destination point based on width and angle
        local destination = vec3.new(point:x() + width * math.cos(angle), point:y() + width * math.sin(angle), point:z())

        local hit_list = utility.get_units_inside_rectangle_list(point, destination, width)
        table.insert(hit_table, {point = point, hits = #hit_list, victim_list = hit_list})
    end

    table.sort(hit_table, function(a, b) return a.hits > b.hits end)

    local current_hit_list_amount = #current_hit_list
    if hit_table[1].hits > current_hit_list_amount then
        return hit_table[1] -- returning the point with the most hits
    end

    return {point = target_position, hits = current_hit_list_amount, victim_list = current_hit_list}
end

local horde_objectives = {
    "BSK_HellSeeker",
    "MarkerLocation_BSK_Occupied",
    "S05_coredemon",
    "S05_fallen",
    "BSK_Structure_BonusAether",
    "BSK_Miniboss",
    "BSK_elias_boss",
    "BSK_cannibal_brute_boss",
    "BSK_skeleton_boss"
}

-- Function to track ball lightning casts with improved performance
local function track_ball_cast()
    local current_time = get_time_since_inject()
    
    -- Only track if we're in crackling energy loop and haven't reached the threshold
    if is_crackling_energy_loop_active and ball_cast_count < ball_cast_threshold then
        -- Check if tracking is off cooldown
        if current_time - last_ball_track_time >= ball_track_cooldown then
            -- Update the last track time
            last_ball_track_time = current_time
            
            -- Increment the counter
            ball_cast_count = ball_cast_count + 1
            
            -- Use a single conditional check for logging and threshold notification
            if ball_cast_count >= ball_cast_threshold then
                console.print("[CRACKLING ENERGY] Threshold reached: " .. ball_cast_count .. "/" .. ball_cast_threshold)
            else
                console.print("[CRACKLING ENERGY] Ball cast tracked: " .. ball_cast_count .. "/" .. ball_cast_threshold)
            end
            
            return ball_cast_count
        else
            -- Only print debug information if significantly under cooldown to reduce spam
            local remaining = ball_track_cooldown - (current_time - last_ball_track_time)
            if remaining > 0.1 then
                console.print("[CRACKLING ENERGY] Ball cast tracking on cooldown: " .. string.format("%.1f", remaining) .. " seconds remaining")
            end
            return ball_cast_count
        end
    end
    return ball_cast_count -- Return current count even if not incremented
end

-- Function to check if we have enough ball casts
local function has_enough_ball_casts()
    return ball_cast_count >= ball_cast_threshold
end

-- Function to get the current ball cast count
local function get_ball_cast_count()
    return ball_cast_count
end

-- Function to end the Crackling Energy loop
local function end_crackling_energy_loop()
    is_crackling_energy_loop_active = false
    ball_cast_count = 0
    spear_ready_time = 0
    console.print("[CRACKLING ENERGY] Loop ended - Spear cast complete")
    console.print("[CRACKLING ENERGY] Returning to normal spell casting")
    return true
end

-- Function to check if the Crackling Energy loop is active
local function is_crackling_energy_loop_active_check()
    -- First check if the Crackling Energy Snapshot option is enabled
    local spear_module = require("spells/spear")
    local crackling_energy_snapshot_enabled = spear_module.get_crackling_energy_snapshot_enabled()
    
    -- If the option is disabled, the loop should never be active
    if not crackling_energy_snapshot_enabled then
        if is_crackling_energy_loop_active then
            is_crackling_energy_loop_active = false
            ball_cast_count = 0
            spear_ready_time = 0
        end
        return false
    end
    
    -- Check for the buff periodically to ensure we're still in the loop
    local current_time = get_time_since_inject();
    if current_time - last_buff_check_time > buff_check_interval then
        last_buff_check_time = current_time;
        
        -- If the loop is active, verify the buff is still present
        if is_crackling_energy_loop_active then
            local local_player = get_local_player();
            if local_player then
                local buff_found = false;
                local buffs = local_player:get_buffs();
                
                for _, buff in ipairs(buffs) do
                    if buff.name_hash == portal_transfer_buff_id or buff:name() == portal_transfer_buff_name then
                        buff_found = true;
                        break;
                    end
                end
                
                -- If buff is no longer present and we haven't reached threshold yet,
                -- print a message but keep the loop active until we cast spear
                if not buff_found and not has_enough_ball_casts() then
                    console.print("[CRACKLING ENERGY] Warning: Buff no longer detected but continuing loop")
                end
            end
        end
    end
    
    return is_crackling_energy_loop_active
end

local plugin_label = "BASE_SORCERER_PLUGIN_"

return
{
    plugin_label = plugin_label,
    is_spell_allowed = is_spell_allowed,
    is_action_allowed = is_action_allowed,

    is_auto_play_enabled = is_auto_play_enabled,

    -- decrepify & bone_prision
    get_best_point = get_best_point,
    generate_points_around_target = generate_points_around_target,

    -- blight
    is_target_within_angle = is_target_within_angle,

    -- bone spear rect
    get_best_point_rec = get_best_point_rec,
    
    -- infernal horde objectives
    horde_objectives = horde_objectives,
    
    -- Crackling Energy Snapshot functionality
    is_crackling_energy_loop_active = is_crackling_energy_loop_active_check,
    track_ball_cast = track_ball_cast,
    has_enough_ball_casts = has_enough_ball_casts,
    get_ball_cast_count = get_ball_cast_count,
    end_crackling_energy_loop = end_crackling_energy_loop,
    ball_cast_threshold = ball_cast_threshold
}