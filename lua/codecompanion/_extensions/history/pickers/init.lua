---Picker auto-resolution for codecompanion-history extension
---Similar to CodeCompanion's provider system but specific to history pickers

---@class HistoryPickerSpec
---@field module string module name to require
---@field condition? function condition function to check if the picker is available

---@type table<Pickers, HistoryPickerSpec>
local picker_configs = {
    telescope = {
        module = "telescope",
    },
    ["fzf-lua"] = {
        module = "fzf-lua",
    },
    snacks = {
        module = "snacks",
        condition = function(snacks_module)
            -- Snacks can be installed but the Picker is disabled
            return snacks_module
                and snacks_module.config
                and snacks_module.config.picker
                and snacks_module.config.picker.enabled
        end,
    },
}

---@param providers Pickers[] Provider names to check in order
---@param configs table<Pickers, HistoryPickerSpec> Provider configs
---@param fallback Pickers Fallback provider name
---@return Pickers available provider name
local function find_available_picker(providers, configs, fallback)
    for _, key in ipairs(providers) do
        local config = configs[key]
        if config then
            local success, loaded_module = pcall(require, config.module)
            if success then
                if config.condition then
                    if config.condition(loaded_module) then
                        return key
                    end
                else
                    return key
                end
            end
        end
    end
    return fallback
end

---Get the best available history picker
---@return Pickers resolved picker name
local function get_history_picker()
    -- Priority order for history pickers
    local providers = { "telescope", "fzf-lua", "snacks" }
    return find_available_picker(providers, picker_configs, "default")
end

return {
    history = get_history_picker(),
}
