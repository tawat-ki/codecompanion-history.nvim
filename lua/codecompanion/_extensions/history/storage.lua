---@class Storage
---@field path any Path object from plenary.path
local Storage = {}

---@param opts HistoryOpts
---@return Storage
function Storage.new(opts)
	local self = setmetatable({}, {
		__index = Storage,
	})
	self.path = require("plenary.path"):new(opts.file_path)
	-- Ensure storage directory exists
	self:_ensure_storage_dir()
	return self
end

---Ensure the storage directory exists
function Storage:_ensure_storage_dir()
	local dir = self.path:parent()
	if not dir:exists() then
		dir:mkdir({ parents = true })
	end
end

---Load all chats from storage
---@return table<string, ChatData>
function Storage:load_chats()
	if not self.path:exists() then
		return {}
	end

	local ok, content = pcall(function()
		return self.path:read()
	end)

	if not ok then
		vim.notify("Failed to read chat history: " .. content, vim.log.levels.ERROR)
		return {}
	end

	local ok2, decoded = pcall(vim.json.decode, content)
	if not ok2 then
		vim.notify("Failed to parse chat history: " .. decoded, vim.log.levels.ERROR)
		return {}
	end

	return decoded
end

---Save a chat to storage
---@param chat Chat
function Storage:save_chat(chat)
	local chats = self:load_chats()
	local save_id = chat.opts.save_id
	if not save_id then
		return vim.notify("Can't save chat with no id")
	end

	-- local messages = vim.tbl_filter(function(msg)
	-- 	return not (msg.role == config.constants.SYSTEM_ROLE and msg.opts.tag == "from_config")
	-- end, chat.messages)
	-- vim.notify(vim.inspect(messages))
	chats[save_id] = {
		save_id = save_id,
		title = chat.opts.title,
		messages = chat.messages,
		updated_at = os.time(),
		refs = chat.refs,
		schemas = chat.tools.schemas,
		in_use = chat.tools.in_use,
	}
	local ok, err = pcall(function()
		self.path:write(vim.json.encode(chats), "w")
	end)

	if not ok then
		return vim.notify("Failed to save chat: " .. err, vim.log.levels.ERROR)
	end
	-- self.history.ui:update_last_saved(chat, os.time())
end

---Delete a chat from storage
---@param id string
function Storage:delete_chat(id)
	if not id then
		return vim.notify("Can't delete chat with no id")
	end
	local chats = self:load_chats()
	chats[id] = nil

	local ok, err = pcall(function()
		self.path:write(vim.json.encode(chats), "w")
	end)

	if not ok then
		vim.notify("Failed to delete chat: " .. err, vim.log.levels.ERROR)
	end
end

return Storage
