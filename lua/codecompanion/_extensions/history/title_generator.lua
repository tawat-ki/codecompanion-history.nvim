local client = require("codecompanion.http")
local config = require("codecompanion.config")
local CONSTANTS = {
    STATUS_ERROR = "error",
    STATUS_SUCCESS = "success",
}

---@class TitleGenerator
---@field opts HistoryOpts
local TitleGenerator = {}

---@param opts HistoryOpts
---@return TitleGenerator
function TitleGenerator.new(opts)
    local self = setmetatable({}, {
        __index = TitleGenerator,
    })
    self.opts = opts
    return self --[[@as TitleGenerator]]
end

---Generate title for chat
---@param chat Chat The chat object containing messages and ID
---@param callback fun(title: string|nil) Callback function to receive the generated title
function TitleGenerator:generate(chat, callback)
    -- Early returns for existing title or disabled auto-generation
    if chat.opts.title then
        return callback(chat.opts.title)
    end
    callback("Deciding title...")
    -- Return early if no messages
    if #chat.messages == 0 then
        return callback(nil)
    end
    -- Get first user and llm messages
    local first_user_msg, first_llm_msg
    for _, msg in ipairs(chat.messages) do
        if not first_user_msg and msg.role == config.constants.USER_ROLE then
            first_user_msg = msg
        elseif not first_llm_msg and msg.role == config.constants.LLM_ROLE then
            first_llm_msg = msg
        end
        if first_user_msg and first_llm_msg then
            break
        end
    end
    if not first_user_msg then
        return callback(nil)
    end
    -- Create prompt for title generation
    local prompt = string.format(
        [[Generate a very short and concise title (max 5 words) for this chat based on the following conversation:
Do not include any special characters or quotes. Your response shouldn't contain any other text, just the title.

Examples: 

1. User: What is the capital of France?
   Assistant: The capital of France is Paris.
   Title: Capital of France
2. User: How do I create a new file in Vim?
   Assistant: You can create a new file in Vim by using the command :e filename.
   Title: Vim Commands

---
User: %s

Assistant: %s

---

Title:]],
        first_user_msg.content:sub(1, 500),
        first_llm_msg and first_llm_msg.content:sub(1, 500) or ""
    )
    self:_make_adapter_request(chat, prompt, callback)
end

---@param chat Chat
---@param prompt string
---@param callback fun(title: string|nil)
function TitleGenerator:_make_adapter_request(chat, prompt, callback)
    local settings = chat.adapter:map_schema_to_params(chat.settings)
    settings.opts.stream = false
    local payload = {
        messages = chat.adapter:map_roles({
            { role = "user", content = prompt },
        }),
    }
    client.new({ adapter = settings }):request(payload, {
        callback = function(err, data, adapter)
            if err and err.stderr ~= "{}" then
                vim.notify("Error while generating title: " .. err.stderr)
                return callback(nil)
            end
            if data then
                local result = chat.adapter.handlers.chat_output(adapter, data)
                if result and result.status then
                    if result.status == CONSTANTS.STATUS_SUCCESS then
                        return callback(vim.trim(result.output.content))
                    elseif result.status == CONSTANTS.STATUS_ERROR then
                        vim.notify("Error while generating title: " .. result.output)
                        return callback(nil)
                    end
                end
            end
        end,
    })
end

-- ---Make request to Groq API
-- ---@private
-- ---@param prompt string The prompt for title generation
-- ---@param callback function Callback to receive the title
-- function TitleGenerator:_make_groq_request(prompt, callback)
-- 	-- Check for API key
-- 	local api_key = os.getenv("GROQ_API_KEY")
-- 	if not api_key then
-- 		vim.notify("GROQ_API_KEY environment variable not set", vim.log.levels.ERROR)
-- 		return callback(nil)
-- 	end
-- 	client.static.opts.post.default({
-- 		url = "https://api.groq.com/openai/v1/chat/completions",
-- 		headers = {
-- 			["Authorization"] = "Bearer " .. os.getenv("GROQ_API_KEY"),
-- 			["Content-Type"] = "application/json",
-- 		},
-- 		body = vim.json.encode({
-- 			messages = {
-- 				{ role = "user", content = prompt },
-- 			},
-- 			model = "llama-3.3-70b-versatile",
-- 		}),
-- 		callback = function(response)
-- 			vim.schedule(function()
-- 				if not response then
-- 					return callback(nil)
-- 				end

-- 				-- Handle HTTP errors
-- 				if response.status < 200 or response.status >= 300 then
-- 					vim.notify("Failed to generate title: " .. response.body, vim.log.levels.ERROR)
-- 					return callback(nil)
-- 				end

-- 				-- Parse response
-- 				local ok, data = pcall(vim.json.decode, response.body)
-- 				if not ok or not data or not data.choices or not data.choices[1] or not data.choices[1].message then
-- 					vim.notify("Failed to generate title: Invalid response", vim.log.levels.ERROR)
-- 					return callback(nil)
-- 				end

-- 				-- Clean up title
-- 				local title = data.choices[1].message.content
-- 				title = title:gsub('"', ""):gsub("^%s*(.-)%s*$", "%1")
-- 				callback(title)
-- 			end)
-- 		end,
-- 		error = function(err)
-- 			vim.schedule(function()
-- 				vim.notify("Failed to generate title: " .. err, vim.log.levels.ERROR)
-- 				callback(nil)
-- 			end)
-- 		end,
-- 	})
-- end

return TitleGenerator
