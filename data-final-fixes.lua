if not settings.startup["teleporters-planet-lock"].value then return end

local require_aquilo = settings.startup["teleporters-require-aquilo"].value

-- Standard Space Age planets mapping
local known_planets = {
    nauvis = { science = nil },
    vulcanus = { science = "metallurgic-science-pack" },
    fulgora = { science = "electromagnetic-science-pack" },
    gleba = { science = "agricultural-science-pack" },
    aquilo = { science = "cryogenic-science-pack" },
}

local function item_exists(name)
    return data.raw.item[name] or data.raw.tool[name]
end

-- Helper to find which tech unlocks a planet
-- Missing Mirandus/quantum science pack, lost beyond?, issues with dual unlock with secretas/frozeta
local function find_planet_unlock_tech(planet_name)
    for _, tech in pairs(data.raw.technology) do
        if tech.effects then
            for _, effect in pairs(tech.effects) do
                if effect.type == "unlock-space-location" and effect.space_location == planet_name then
                    return tech
                end
            end
        end
    end
    return nil
end

-- Build a map of technology children for efficient traversal
local tech_children = nil
local function get_tech_children()
    if tech_children then return tech_children end
    tech_children = {}
    for name, tech in pairs(data.raw.technology) do
        if tech.prerequisites then
            for _, prereq in pairs(tech.prerequisites) do
                tech_children[prereq] = tech_children[prereq] or {}
                table.insert(tech_children[prereq], name)
            end
        end
    end
    return tech_children
end

-- Helper to find science packs unlocked by children of a tech (Recursive BFS)
local function find_child_science_pack(parent_tech_name)
    local children_map = get_tech_children()
    local queue = { parent_tech_name }
    local visited = { [parent_tech_name] = true }
    local head = 1 -- Queue head index for efficient popping

    while head <= #queue do
        local current_name = queue[head]
        head = head + 1

        -- Check if current tech unlocks a science pack (skip the start node itself if desired, but here we check it too just in case)
        -- Actually, the original logic checked children, so let's check if the current node unlocks it.
        -- The original function was called with the planet unlock tech. We probably want to find a *descendant* that unlocks science.
        -- If the planet unlock tech itself unlocks science, that's fine too.

        local tech = data.raw.technology[current_name]
        if tech and tech.effects then
            for _, effect in pairs(tech.effects) do
                if effect.type == "unlock-recipe" then
                    local recipe = data.raw.recipe[effect.recipe]
                    if recipe then
                        local results = recipe.results
                        -- if not results and recipe.result then
                        --     -- Normalize simple result
                        --     results = { { type = "item", name = recipe.result, amount = recipe.result_count or 1 } }
                        -- end

                        if results then
                            for _, result in pairs(results) do
                                local item_name = result.name or result[1]
                                if item_name and (item_name:find("science-pack", 1, true) or data.raw.tool[item_name]) then
                                    return item_name
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Add children to queue
        local children = children_map[current_name]
        if children then
            for _, child_name in pairs(children) do
                if not visited[child_name] then
                    visited[child_name] = true
                    table.insert(queue, child_name)
                end
            end
        end
    end
    return nil
end

-- Helper to find which tech unlocks a specific item (science pack)
local function find_tech_unlocking_item(item_name)
    for _, tech in pairs(data.raw.technology) do
        if tech.effects then
            for _, effect in pairs(tech.effects) do
                if effect.type == "unlock-recipe" then
                    local recipe = data.raw.recipe[effect.recipe]
                    if recipe then
                        local results = recipe.results
                        -- if not results and recipe.result then
                        --     results = { { type = "item", name = recipe.result, amount = recipe.result_count or 1 } }
                        -- end

                        if results then
                            for _, result in pairs(results) do
                                if (result.name or result[1]) == item_name then
                                    return tech.name
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function create_tech(planet, science)
    -- Avoid duplicates
    if data.raw.technology["teleport-to-" .. planet] then return end

    local ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
        { "production-science-pack", 1 },
        { "utility-science-pack",    1 }
    }

    if item_exists("space-science-pack") then
        table.insert(ingredients, { "space-science-pack", 1 })
    end
    if item_exists("wood-science-pack") then
        table.insert(ingredients, { "wood-science-pack", 1 })
    end
    if item_exists("steam-science-pack") then
        table.insert(ingredients, { "steam-science-pack", 1 })
    end

    if science and item_exists(science) then
        local already_exists = false
        for _, ingredient in pairs(ingredients) do
            if ingredient[1] == science then
                already_exists = true
                break
            end
        end

        if not already_exists then
            table.insert(ingredients, { science, 1 })
        end
    end

    if require_aquilo and planet ~= "aquilo" then
        if item_exists("cryogenic-science-pack") then
            local has_cryo = false
            if science == "cryogenic-science-pack" then has_cryo = true end

            if not has_cryo then
                table.insert(ingredients, { "cryogenic-science-pack", 1 })
            end
        end
    end

    local prerequisites = {}
    if data.raw.technology["space-science-pack"] then
        table.insert(prerequisites, "space-science-pack")
    end

    -- Some planets are special since their science can't be processed by normal labs.
    if planet == "cerys" then
        ingredients = { { "cerysian-science-pack", 1 } }
    elseif planet == "moshine" then
        ingredients = { { "datacell-empty", 1 } }
    elseif planet == "nix" then
        ingredients = { { "anomaly-science-pack", 1 } }
        table.insert(prerequisites, "anomaly-science-pack")
    elseif planet == "ringworld" then
        ingredients = { { "ring-science-pack", 1 },
            { "space-science-pack",  1 },
            { "nanite-science-pack", 1 },
        }
    elseif planet == "shipyard" then
        ingredients = { { "nanite-science-pack", 1 } }
    end

    if science then
        local science_tech = find_tech_unlocking_item(science)
        if science_tech then
            local already_has_prereq = false
            for _, prereq in pairs(prerequisites) do
                if prereq == science_tech then
                    already_has_prereq = true
                    break
                end
            end

            if not already_has_prereq then
                table.insert(prerequisites, science_tech)
            end
        end
    end

    -- Add base teleporter technology as prerequisite
    table.insert(prerequisites, "teleporter")

    data:extend({
        {
            type = "technology",
            name = "teleport-to-" .. planet,
            localised_name = { "technology-name.teleport-to-planet", { "space-location-name." .. planet } },
            localised_description = { "technology-description.teleport-to-planet", { "space-location-name." .. planet } },
            icon = "__Teleporters-Balanced__/data/entities/teleporters/teleporter-technology.png",
            icon_size = 256,
            effects = {},
            prerequisites = prerequisites,
            unit = {
                count = 1000,
                ingredients = ingredients,
                time = 60
            },
            order = "c-a"
        }
    })
end

-- Process all planets
for name, planet in pairs(data.raw["planet"]) do
    local science = nil

    if known_planets[name] then
        science = known_planets[name].science
    elseif name == "quality-condensor" then
        science = nil
    else
        -- Dynamic discovery
        local unlock_tech = find_planet_unlock_tech(name)
        if unlock_tech then
            science = find_child_science_pack(unlock_tech.name)
        end
    end
    -- TODO fix Frozeta and Cubium teleportation. Cubium maybe needs cube mastery 4?
    -- For some reason, quality condenser shows up as a planet. Lets ignore it.
    if name ~= "quality-condenser" then
        create_tech(name, science)
    end
end
