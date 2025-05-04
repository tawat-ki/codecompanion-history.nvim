local h = require("tests.helpers")
local eq, new_set = MiniTest.expect.equality, MiniTest.new_set
local T = new_set()

local child = h.new_child_neovim()
T = new_set({
    hooks = {
        pre_case = function()
            child.setup()
            child.lua([[
              h = require('tests.helpers')
              cc_h = require('tests.cc_helpers')
              codecompanion = cc_h.setup_plugin({
                extensions = {
                  history = {
                    enabled = true,
                    opts = {
                      keymap = "gh",
                      auto_generate_title = true,
                      continue_last_chat = false,
                      delete_on_clearing_chat = false,
                      picker = "default", -- Use default picker to avoid telescope dependency
                      enable_logging = true,
                    }
                  }
                }
              })
            ]])
        end,
        post_case = function() end,
        post_once = child.stop,
    },
})

T["should update chat title"] = function()
    child.lua([[
    _G.History = require("codecompanion._extensions.history").History
    _G.History._get_title = function()
      return "AutoSavingChat"
    end
    _G.chat = codecompanion.toggle()
  ]])
    --make sure the title is updated
    h.sleep(1000)
    local name = child.lua([[
      local bufnr = _G.chat.bufnr
      return vim.api.nvim_buf_get_name(bufnr)
    ]])
    if not vim.endswith(name, "AutoSavingChat") then
        error("Chat buffer name should be updated")
    end
end
return T
