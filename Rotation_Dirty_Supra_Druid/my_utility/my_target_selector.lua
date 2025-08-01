-- all in one (aio) target selector data
-- returns table:

-- bool, is_valid -- true once finds 1 valid target inside the list regardless of type
-- game_object, closest unit
-- game_object, lowest current health unit
-- game_object, highest current health unit
-- game_object, lowest max health unit
-- game_object, highest max health unit

-- bool, has_elite -- true once finds 1 elite inside the list
-- game_object, closest elite
-- game_object, lowest current health elite
-- game_object, highest current health elite
-- game_object, lowest max health elite
-- game_object, highest max health elite

-- bool, has_champion -- true once finds 1 champion inside the list
-- game_object, closest champion
-- game_object, lowest current health champion
-- game_object, highest current health champion
-- game_object, lowest max health champion
-- game_object, highest max health champion

-- bool, has_boss -- true once finds 1 boss inside the list
-- game_object, closest boss
-- game_object, lowest current health boss
-- game_object, highest current health boss
-- game_object, lowest max health boss
-- game_object, highest max health boss

local function get_unit_weight(unit)
    local score = 0
    local debuff_priorities = {
        [391682] = 1,    -- Inner Sight
        [39809] = 2,     -- Generic Crowd Control
        [290962] = 800,  -- Frozen
        [1285259] = 400, -- Trapped
        [356162] = 400   -- Smoke Bomb
    }

    local buffs = unit:get_buffs()
    if buffs then
        for i, debuff in ipairs(buffs) do
            local debuff_hash = debuff.name_hash
            local debuff_score = debuff_priorities[debuff_hash]
            if debuff_score then
                score = score + debuff_score
                -- console.print("Match found: debuff_score for hash " .. debuff_hash .. " is " .. debuff_score)
            end
        end
    end

    local max_health = unit:get_max_health()
    local current_health = unit:get_current_health()
    local health_percentage = current_health / max_health
    local is_fresh = health_percentage >= 1.0

    local is_vulnerable = unit:is_vulnerable()
    if is_vulnerable then
        score = score + 10000
    end

    if not is_vulnerable and is_fresh then
        score = score + 6000
    end

    local is_champion = unit:is_champion()
    if is_champion then
        if is_fresh then
            score = score + 20000
        else
            score = score + 5000
        end
    end

    local is_champion = unit:is_elite()
    if is_champion then
        score = score + 400
    end

    return score
end

-- Define the function to get the best weighted target
local function get_best_weighted_target(entity_list)
    local highest_score = -1
    local best_target = nil

    -- Iterate over all entities in the list
    for _, unit in ipairs(entity_list) do
        -- Calculate the score for each unit
        local score = get_unit_weight(unit)

        -- Update the best target if this unit's score is higher than the current highest
        if score > highest_score then
            highest_score = score
            best_target = unit
        end
    end

    return best_target
end

local function get_target_selector_data(source, list)
    local is_valid = false;

    local possible_targets_list = list;
    if #possible_targets_list == 0 then
        return
        {
            is_valid = is_valid,
        }
    end;

    local closest_unit = {};
    local closest_unit_distance = math.huge;

    local lowest_current_health_unit = {};
    local lowest_current_health_unit_health = math.huge;

    local highest_current_health_unit = {};
    local highest_current_health_unit_health = 0.0;

    local lowest_max_health_unit = {};
    local lowest_max_health_unit_health = math.huge;

    local highest_max_health_unit = {};
    local highest_max_health_unit_health = 0.0;

    local has_elite = false;
    local closest_elite = {};
    local closest_elite_distance = math.huge;

    local lowest_current_health_elite = {};
    local lowest_current_health_elite_health = math.huge;

    local highest_current_health_elite = {};
    local highest_current_health_elite_health = 0.0;

    local lowest_max_health_elite = {};
    local lowest_max_health_elite_health = math.huge;

    local highest_max_health_elite = {};
    local highest_max_health_elite_health = 0.0;

    local has_champion = false;
    local closest_champion = {};
    local closest_champion_distance = math.huge;

    local lowest_current_health_champion = {};
    local lowest_current_health_champion_health = math.huge;

    local highest_current_health_champion = {};
    local highest_current_health_champion_health = 0.0;

    local lowest_max_health_champion = {};
    local lowest_max_health_champion_health = math.huge;

    local highest_max_health_champion = {};
    local highest_max_health_champion_health = 0.0;

    local has_boss = false;
    local closest_boss = {};
    local closest_boss_distance = math.huge;

    local lowest_current_health_boss = {};
    local lowest_current_health_boss_health = math.huge;

    local highest_current_health_boss = {};
    local highest_current_health_boss_health = 0.0;

    local lowest_max_health_boss = {};
    local lowest_max_health_boss_health = math.huge;

    local highest_max_health_boss = {};
    local highest_max_health_boss_health = 0.0;

    for _, unit in ipairs(possible_targets_list) do
        local unit_position = unit:get_position()
        local distance_sqr = unit_position:squared_dist_to_ignore_z(source)

        local max_health = unit:get_max_health()
        local current_health = unit:get_current_health()

        -- update units data
        if distance_sqr < closest_unit_distance then
            closest_unit = unit;
            closest_unit_distance = distance_sqr;
            is_valid = true;
        end

        if current_health < lowest_current_health_unit_health then
            lowest_current_health_unit = unit;
            lowest_current_health_unit_health = current_health;
        end

        if current_health > highest_current_health_unit_health then
            highest_current_health_unit = unit;
            highest_current_health_unit_health = current_health;
        end

        if max_health < lowest_max_health_unit_health then
            lowest_max_health_unit = unit;
            lowest_max_health_unit_health = max_health;
        end

        if max_health > highest_max_health_unit_health then
            highest_max_health_unit = unit;
            highest_max_health_unit_health = max_health;
        end

        -- update elites data
        local is_unit_elite = unit:is_elite();
        if is_unit_elite then
            has_elite = true;
            if distance_sqr < closest_elite_distance then
                closest_elite = unit;
                closest_elite_distance = distance_sqr;
            end

            if current_health < lowest_current_health_elite_health then
                lowest_current_health_elite = unit;
                lowest_current_health_elite_health = current_health;
            end

            if current_health > highest_current_health_elite_health then
                highest_current_health_elite = unit;
                highest_current_health_elite_health = current_health;
            end

            if max_health < lowest_max_health_elite_health then
                lowest_max_health_elite = unit;
                lowest_max_health_elite_health = max_health;
            end

            if max_health > highest_max_health_elite_health then
                highest_max_health_elite = unit;
                highest_max_health_elite_health = max_health;
            end
        end

        -- update champions data
        local is_unit_champion = unit:is_champion()
        if is_unit_champion then
            has_champion = true
            if distance_sqr < closest_champion_distance then
                closest_champion = unit;
                closest_champion_distance = distance_sqr;
            end

            if current_health < lowest_current_health_champion_health then
                lowest_current_health_champion = unit;
                lowest_current_health_champion_health = current_health;
            end

            if current_health > highest_current_health_champion_health then
                highest_current_health_champion = unit;
                highest_current_health_champion_health = current_health;
            end

            if max_health < lowest_max_health_champion_health then
                lowest_max_health_champion = unit;
                lowest_max_health_champion_health = max_health;
            end

            if max_health > highest_max_health_champion_health then
                highest_max_health_champion = unit;
                highest_max_health_champion_health = max_health;
            end
        end

        -- update bosses data
        local is_unit_boss = unit:is_boss();
        if is_unit_boss then
            has_boss = true;
            if distance_sqr < closest_boss_distance then
                closest_boss = unit;
                closest_boss_distance = distance_sqr;
            end

            if current_health < lowest_current_health_boss_health then
                lowest_current_health_boss = unit;
                lowest_current_health_boss_health = current_health;
            end

            if current_health > highest_current_health_boss_health then
                highest_current_health_boss = unit;
                highest_current_health_boss_health = current_health;
            end

            if max_health < lowest_max_health_boss_health then
                lowest_max_health_boss = unit;
                lowest_max_health_boss_health = max_health;
            end

            if max_health > highest_max_health_boss_health then
                highest_max_health_boss = unit;
                highest_max_health_boss_health = max_health;
            end
        end
        ::continue::
    end

    return
    {
        is_valid = is_valid,

        closest_unit = closest_unit,
        lowest_current_health_unit = lowest_current_health_unit,
        highest_current_health_unit = highest_current_health_unit,
        lowest_max_health_unit = lowest_max_health_unit,
        highest_max_health_unit = highest_max_health_unit,

        has_elite = has_elite,
        closest_elite = closest_elite,
        lowest_current_health_elite = lowest_current_health_elite,
        highest_current_health_elite = highest_current_health_elite,
        lowest_max_health_elite = lowest_max_health_elite,
        highest_max_health_elite = highest_max_health_elite,

        has_champion = has_champion,
        closest_champion = closest_champion,
        lowest_current_health_champion = lowest_current_health_champion,
        highest_current_health_champion = highest_current_health_champion,
        lowest_max_health_champion = lowest_max_health_champion,
        highest_max_health_champion = highest_max_health_champion,

        has_boss = has_boss,
        closest_boss = closest_boss,
        lowest_current_health_boss = lowest_current_health_boss,
        highest_current_health_boss = highest_current_health_boss,
        lowest_max_health_boss = lowest_max_health_boss,
        highest_max_health_boss = highest_max_health_boss,

        list = possible_targets_list
    }
end

local function dot2D(v1, v2)
    return v1.x * v2.x + v1.y * v2.y
end

-- Function to calculate the squared magnitude of a 2D vector (x, y only)
local function squaredMagnitude2D(v)
    return v.x * v.x + v.y * v.y
end

-- Function to subtract two 2D vectors (ignoring z)
local function subtract2D(v1, v2, field)
    if field == true then
        local X1 = v1:x() - v2:x();
        local V1 = v1:y() - v2:y();
        return vec2:new(X1, V1)
    end


    local X1 = v1:x() - v2.x;
    local V1 = v1:y() - v2.y;
    return vec2:new(X1, V1)
end

function CheckActorCollision(StartPoint, EndPoint, PositionToCheck, width)
    -- Vector from A to B
    --local StartPoint = vec2(2,1);
    --StartPoint = vec2:new(StartPoint:x(),StartPoint:y())
    --local temp = vec2.dot_product(StartPoint));
    --console.print(StartPoint:x(),StartPoint:y()," Pos",PositionToCheck:x(),PositionToCheck:y());
    local AB = subtract2D(EndPoint, StartPoint, true)

    -- Vector from A to C
    local AC = subtract2D(PositionToCheck, StartPoint, true)
    --console.print(AC.x);
    -- Dot product of AB and AC
    local dotProduct = dot2D(AB, AC)
    -- local dotProduct = vec2:dot_product(AB, AC)
    --console.print(dotProduct);
    -- If dot product is negative, PositionToCheck is not between StartPoint and EndPoint
    if dotProduct < 0 then
        return false
    end

    -- If dot product exceeds AB's squared magnitude, PositionToCheck is beyond EndPoint
    local AB_squaredMag = squaredMagnitude2D(AB)
    --console.print(AB_squaredMag);
    if dotProduct > AB_squaredMag then
        return false
    end

    -- Now, calculate the perpendicular distance from C to the line segment AB
    -- Projection scalar t = dot(AC, AB) / squaredMagnitude(AB)

    local t = dotProduct / AB_squaredMag
    --console.print(t);

    -- Project C onto the line AB: P = StartPoint + t * AB
    local vecx = StartPoint:x() + t * AB.x

    local vecy = StartPoint:y() + t * AB.y
    local P = vec2:new(vecx, vecy);




    -- Vector from C to P
    local CP = subtract2D(PositionToCheck, P, false)
    --console.print(CP.x,CP.y);
    -- Distance from C to the line AB
    local CP_distanceSquared = squaredMagnitude2D(CP)
    --console.print(CP_distanceSquared)
    -- If distance squared is less than the width squared, C is within the width tolerance
    return CP_distanceSquared <= width * width
end

-- get target list with few parameters
-- collision parameter table: {is_enabled(bool), width(float)};
-- floor parameter table: {is_enabled(bool), height(float)};
-- angle parameter table: {is_enabled(bool), max_angle(float)};
local actor_table = { "Door", "Block" }
local function get_target_list(source, range, collision_table, floor_table, angle_table)
    local entity_list = {}
    local entity_list_visible = {}
    local possible_targets_list = target_selector.get_near_target_list(source, range);

    for _, unit in ipairs(possible_targets_list) do
        -- only targetable units
        if unit:is_untargetable() or unit:is_immune() then
            goto continue
        end

        local unit_position = unit:get_position()

        -- Check floor and angle conditions
        if floor_table[1] == true then
            local z_difference = math.abs(source:z() - unit_position:z())
            local is_other_floor = z_difference > floor_table[2]
            if is_other_floor then
                goto continue
            end
        end

        if angle_table[1] == true then
            local cursor_position = get_cursor_position();
            local angle = unit_position:get_angle(cursor_position, source);
            local is_outside_angle = angle > angle_table[2]
            if is_outside_angle then
                goto continue
            end
        end

        -- Add to entity_list regardless of collision
        table.insert(entity_list, unit)

        -- Check collision
        if collision_table[1] == true then
            local is_invalid = prediction.is_wall_collision(source, unit_position, collision_table[2]);
            if is_invalid then
                goto continue;
            end

            all_objects = actors_manager.get_all_actors()
            for _, obj in ipairs(all_objects) do
                if not obj:is_enemy() and obj:is_interactable() then
                    local skin_name = obj:get_skin_name()
                    for _, pattern in ipairs(actor_table) do
                        if skin_name:match(pattern) and CheckActorCollision(source, unit_position, obj:get_position(), 3) then
                            goto continue;
                        end
                    end
                end
            end
        end

        -- Add to entity_list_visible
        table.insert(entity_list_visible, unit)

        ::continue::
    end

    return entity_list_visible, entity_list
end

-- return table:
-- hits_amount(int)
-- score(float)
-- main_target(gameobject)
-- victim_list(table game_object)
local function get_most_hits_rectangle(source, lenght, width)
    local data = target_selector.get_most_hits_target_rectangle_area_heavy(source, lenght, width);

    local is_valid = false;
    local hits_amount = data.n_hits;
    if hits_amount < 1 then
        return
        {
            is_valid = is_valid,
        }
    end

    local main_target = data.main_target;
    is_valid = hits_amount > 0 and main_target ~= nil;
    return
    {
        is_valid = is_valid,
        hits_amount = hits_amount,
        main_target = main_target,
        victim_list = data.victim_list,
        score = data.score
    }
end

-- return table:
-- is_valid(bool)
-- hits_amount(int)
-- score(float)
-- main_target(gameobject)
-- victim_list(table game_object)
local function get_most_hits_circular(source, distance, radius)
    local data = target_selector.get_most_hits_target_circular_area_heavy(source, distance, radius);

    local is_valid = false;
    local hits_amount = data.n_hits;
    if hits_amount < 1 then
        return
        {
            is_valid = is_valid,
        }
    end

    local main_target = data.main_target;
    is_valid = hits_amount > 0 and main_target ~= nil;
    return
    {
        is_valid = is_valid,
        hits_amount = hits_amount,
        main_target = main_target,
        victim_list = data.victim_list,
        score = data.score
    }
end

local function is_valid_area_spell_static(area_table, min_hits)
    if not area_table.is_valid then
        return false;
    end

    return area_table.hits_amount >= min_hits;
end

local function is_valid_area_spell_smart(area_table, min_hits)
    if not area_table.is_valid then
        return false;
    end

    if is_valid_area_spell_static(area_table, min_hits) then
        return true;
    end

    if area_table.score >= min_hits then
        return true;
    end

    for _, victim in ipairs(area_table.victim_list) do
        if victim:is_elite() or victim:is_champion() or victim:is_boss() then
            return true;
        end
    end

    return false;
end

local function is_valid_area_spell_percentage(area_table, entity_list, min_percentage)
    if not area_table.is_valid then
        return false;
    end

    local entity_list_size = #entity_list;
    local hits_amount = area_table.hits_amount;
    local percentage = hits_amount / entity_list_size;
    if percentage >= min_percentage then
        return true;
    end
end


local function is_valid_area_spell_aio(area_table, min_hits, entity_list, min_percentage)
    if not area_table.is_valid then
        return false;
    end

    if is_valid_area_spell_smart(area_table, min_hits) then
        return true;
    end

    if is_valid_area_spell_percentage(area_table, entity_list, min_percentage) then
        return true;
    end

    return false;
end

return
{
    get_target_list = get_target_list,
    get_target_selector_data = get_target_selector_data,

    get_most_hits_rectangle = get_most_hits_rectangle,
    get_most_hits_circular = get_most_hits_circular,

    is_valid_area_spell_static = is_valid_area_spell_static,
    is_valid_area_spell_smart = is_valid_area_spell_smart,
    is_valid_area_spell_percentage = is_valid_area_spell_percentage,
    is_valid_area_spell_aio = is_valid_area_spell_aio,

    get_unit_weight = get_unit_weight,
    get_best_weighted_target = get_best_weighted_target,
}
