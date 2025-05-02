local config = require("codecompanion.config")
local utils = require("codecompanion._extensions.history.utils")

---@class UI
---@field storage Storage
---@field title_generator TitleGenerator
---@field default_buf_title string
---@field picker "telescope"|"default"
local UI = {}

---@param opts HistoryOpts
---@param storage Storage
---@param title_generator TitleGenerator
---@return UI
function UI.new(opts, storage, title_generator)
    local self = setmetatable({}, {
        __index = UI,
    })

    self.storage = storage
    self.title_generator = title_generator
    self.default_buf_title = opts.default_buf_title
    self.picker = opts.picker

    return self --[[@as UI]]
end

-- Private method for setting buffer title with retry
---@param bufnr number
---@param title string|string[]
---@param attempt? number
function UI:_set_buf_title(bufnr, title, attempt)
    attempt = attempt or 0

    vim.schedule(function()
        ---Takes a array of strings and justifies them to fit the available width
        ---@param str_array string[]
        ---@return string
        local function justify_strings(str_array)
            -- Validate input
            if #str_array == 0 then
                return ""
            end
            if #str_array == 1 then
                return str_array[1]
            end

            -- Get the window ID for this buffer
            local win_id = vim.fn.bufwinid(bufnr)
            if win_id == -1 then
                return table.concat(str_array, " ")
            end

            -- Get available width (subtract 10 for the sparkle and some padding, any file icons in winbar)
            local width = vim.api.nvim_win_get_width(win_id) - 10

            -- Calculate total string length
            local total_len = 0
            for _, str in ipairs(str_array) do
                if type(str) ~= "string" then
                    return table.concat(str_array, " ")
                end
                total_len = total_len + vim.api.nvim_strwidth(str)
            end

            -- Calculate remaining space and gaps
            local remaining_space = math.max(0, width - total_len)
            local num_gaps = #str_array - 1
            if num_gaps <= 0 or remaining_space <= 0 then
                return table.concat(str_array, " ")
            end

            -- Calculate even gap size and extra spaces to distribute
            local gap_size = math.floor(remaining_space / num_gaps)
            local extra_spaces = remaining_space % num_gaps

            -- Construct the justified string
            local result = {}
            for i, str in ipairs(str_array) do
                table.insert(result, str)
                if i < #str_array then
                    -- Add gap and distribute extra spaces
                    table.insert(result, string.rep(" ", gap_size + (i <= extra_spaces and 1 or 0)))
                end
            end

            -- Combine and truncate if necessary
            local final_result = table.concat(result)
            if vim.api.nvim_strwidth(final_result) > width then
                final_result = vim.fn.strcharpart(final_result, 0, width - 1) .. "…"
            end

            return final_result
        end

        -- Process title based on type
        local final_title
        if type(title) == "table" then
            final_title = justify_strings(title)
        else
            final_title = tostring(title)
        end

        -- local icon = " "
        local icon = "✨ "
        -- throws error if buffer with same name already exists so we add a counter to the title
        local success, err = pcall(function()
            local _title = final_title .. " " .. (attempt > 0 and "(" .. tostring(attempt) .. ")" or "")
            vim.api.nvim_buf_set_name(bufnr, icon .. _title)
        end)

        if not success then
            if attempt > 10 then
                vim.notify("Failed to set buffer title: " .. err, vim.log.levels.ERROR)
                return
            end
            self:_set_buf_title(bufnr, final_title, attempt + 1)
        end
    end)
end

---Format chat data for display
---@param chats table<string, ChatData>
---@return ChatData[]
local function format_chat_items(chats)
    local items = {}
    for _, chat_item in pairs(chats) do
        local save_id = chat_item.save_id
        table.insert(
            items,
            vim.tbl_extend("keep", {
                save_id = save_id,
                messages = chat_item.messages,
                name = chat_item.title or save_id,
                title = chat_item.title or save_id,
                updated_at = chat_item.updated_at or 0,
            }, chat_item)
        )
    end
    -- Sort items by updated_at in descending order
    table.sort(items, function(a, b)
        return a.updated_at > b.updated_at
    end)
    return items
end

---@return nil
function UI:open_saved_chats()
    local chats = self.storage:load_chats()
    if vim.tbl_isempty(chats) then
        vim.notify("No chat history found", vim.log.levels.INFO)
        return
    end
    -- Use picker instance
    local items = format_chat_items(chats)
    local is_picker_available, resolved_picker =
        pcall(require, "codecompanion._extensions.history.pickers." .. self.picker)
    if not is_picker_available then
        resolved_picker = require("codecompanion._extensions.history.pickers.default")
        -- vim.notify(
        -- 	string.format("Codecompanion History: Picker %s not available using default", self.picker),
        -- 	vim.log.levels.WARN
        -- )
    elseif self.picker ~= "default" then
        require(self.picker)
    end
    local codecompanion = require("codecompanion")
    local last_chat = codecompanion.last_chat()
    resolved_picker
        :new(items, {
            ---@param chat_data ChatData
            ---@return string[] lines
            on_preview = function(chat_data)
                return self:_get_preview_lines(chat_data)
            end,
            ---@param chat_data ChatData
            on_delete = function(chat_data)
                self.storage:delete_chat(chat_data.save_id)
                self:open_saved_chats()
            end,
            ---@param chat_data ChatData
            on_select = function(chat_data)
                local chat_module = require("codecompanion.strategies.chat")
                local opened_chats = chat_module.buf_get_chat()
                local active_chat = codecompanion.last_chat()
                for _, data in ipairs(opened_chats) do
                    if data.chat.opts.save_id == chat_data.save_id then
                        if (active_chat and not active_chat.ui:is_active()) or active_chat ~= data.chat then
                            if active_chat and active_chat.ui:is_active() then
                                active_chat.ui:hide()
                            end
                            data.chat.ui:open()
                        else
                            vim.notify("Chat already open", vim.log.levels.INFO)
                        end
                        return
                    end
                end
                self:create_chat(chat_data)
            end,
        })
        :browse(last_chat and last_chat.opts.save_id)
end

---Creates a new chat from the given chat data restoring what it can
---@param chat_data? ChatData
---@return Chat
function UI:create_chat(chat_data)
    chat_data = chat_data or {}
    local messages = chat_data.messages or {}
    local save_id = chat_data.save_id
    local title = chat_data.title

    messages = messages or {}

    --HACK: Ensure last message is from user to show header
    if #messages > 0 and messages[#messages].role ~= "user" then
        table.insert(messages, {
            role = "user",
            content = "",
            opts = { visible = true },
        })
    end
    local context_utils = require("codecompanion.utils.context")
    local last_active_buffer = require("codecompanion._extensions.history.utils").get_editor_info().last_active
    -- vim.notify(vim.api.nvim_buf_get_name(last_active_buffer and last_active_buffer.bufnr or 0))
    local context = context_utils.get(last_active_buffer and last_active_buffer.bufnr or nil)
    local chat = require("codecompanion.strategies.chat").new({
        save_id = save_id,
        messages = messages,
        context = context,
        title = title,
        ignore_system_prompt = true,
    })
    chat.refs = chat_data.refs or {}
    chat.references:render()
    chat.tools.schemas = chat_data.schemas or {}
    chat.tools.in_use = chat_data.in_use or {}
    return chat
end

---Retrieve the lines to be displayed in the preview window
---@param chat_data ChatData
function UI:_get_preview_lines(chat_data)
    local messages = chat_data.messages
    local lines = {}
    local last_set_role

    local function spacer()
        table.insert(lines, "")
    end

    local function set_header(tbl, role)
        local header = "## " .. role
        table.insert(tbl, header)
        table.insert(tbl, "")
    end
    local system_role = config.constants.SYSTEM_ROLE
    local user_role = config.constants.USER_ROLE
    local assistant_role = config.constants.LLM_ROLE

    local function add_messages_to_buf(msgs)
        for i, msg in ipairs(msgs) do
            if msg.role ~= system_role or (msg.opts and msg.opts.visible ~= false) then
                -- For workflow prompts: Ensure main user role doesn't get spaced
                if i > 1 and last_set_role ~= msg.role and msg.role ~= user_role then
                    spacer()
                end

                if msg.role == user_role and last_set_role ~= user_role then
                    set_header(lines, user_role)
                end
                if msg.role == assistant_role and last_set_role ~= assistant_role then
                    set_header(lines, assistant_role)
                end

                local trimempty = not (msg.role == "user" and msg.content == "")
                for _, text in ipairs(vim.split(msg.content or "", "\n", { plain = true, trimempty = trimempty })) do
                    table.insert(lines, text)
                end
                last_set_role = msg.role
            end
        end
    end

    add_messages_to_buf(messages)
    return lines
end

---@param chat Chat
---@param saved_at number
function UI:update_last_saved(chat, saved_at)
    --saved at icon
    local icon = " "
    self:_set_buf_title(chat.bufnr, { chat.opts.title or self.default_buf_title, icon .. utils.format_time(saved_at) })
end

return UI
