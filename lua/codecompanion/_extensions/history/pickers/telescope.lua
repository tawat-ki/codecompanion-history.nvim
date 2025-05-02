local DefaultPicker = require("codecompanion._extensions.history.pickers.default")
local utils = require("codecompanion._extensions.history.utils")

---@class TelescopePicker : DefaultPicker
local TelescopePicker = setmetatable({}, {
    __index = DefaultPicker,
})
TelescopePicker.__index = TelescopePicker

---@param current_save_id? string
function TelescopePicker:browse(current_save_id)
    require("telescope.pickers")
        .new({}, {
            prompt_title = "Saved Chats",
            finder = require("telescope.finders").new_table({
                results = self.chats,
                entry_maker = function(entry)
                    local is_current = current_save_id and current_save_id == entry.save_id
                    local relative_time = utils.format_relative_time(entry.updated_at)
                    local display_title =
                        string.format("%s %s (%s)", is_current and "🌟" or " ", entry.name, relative_time)

                    return vim.tbl_extend("keep", {
                        value = entry,
                        display = display_title,
                        ordinal = entry.name,
                        name = entry.name,
                        save_id = entry.save_id,
                        title = entry.name,
                        messages = entry.messages,
                    }, entry)
                end,
            }),
            sorter = require("telescope.config").values.generic_sorter({}),
            previewer = require("telescope.previewers").new_buffer_previewer({
                title = "Chat Preview",
                define_preview = function(preview_state, entry)
                    local lines = self.handlers.on_preview(entry)
                    if not lines then
                        return
                    end
                    vim.bo[preview_state.state.bufnr].filetype = "markdown"
                    vim.api.nvim_buf_set_lines(preview_state.state.bufnr, 0, -1, false, lines)
                end,
            }),
            attach_mappings = function(prompt_bufnr)
                local action_state = require("telescope.actions.state")
                local actions = require("telescope.actions")
                local delete_item = function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection then
                        self.handlers.on_delete(selection)
                    end
                end
                vim.keymap.set({ "i", "n" }, "x", delete_item, {
                    buffer = prompt_bufnr,
                    silent = true,
                    nowait = true,
                })
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection then
                        self.handlers.on_select(selection.value)
                    end
                end)
                return true
            end,
        })
        :find()
end

return TelescopePicker
