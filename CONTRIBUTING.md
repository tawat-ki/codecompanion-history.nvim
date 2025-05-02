# Contributing to CodeCompanion History Extension

Thank you for considering contributing! This document provides guidelines and information to help you get started contributing to the project.

## Project Overview

CodeCompanion History is an extension for [codecompanion.nvim](https://codecompanion.olimorris.dev/) that provides persistent chat history functionality. It hooks into CodeCompanion's events to automatically save chat sessions and allows users to browse and restore them.

The extension handles:
- Automatic saving of chat sessions
- Title generation for chats
- State preservation (messages, tools, references)
- History browsing via Telescope or default UI

## Development Environment Setup

### Prerequisites

- Neovim 0.8.0+
- [lua-language-server](https://github.com/LuaLS/lua-language-server)
- [stylua](https://github.com/JohnnyMorganz/StyLua)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for enhanced UI)
- [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim)

### Development Setup

1. Fork and clone the repository:
```bash
git clone https://github.com/ravitemer/codecompanion-history.nvim
cd codecompanion-history.nvim
```

2. Add repo to your runtime

```lua
vim.opt.runtimepath:prepend(os.getenv("HOME") .. "path/to/codecompanion-history.nvim")
```

3. Configure for development:
```lua
local codecompanion = require("codecompanion")

codecompanion.setup({
    extensions = {
        history = {
            enabled = true,
            opts = {
                file_path = vim.fn.expand("~/cc_history_dev.json"), -- Different path for development
                auto_generate_title = true,
                default_buf_title = "[CC-Dev]",
                keymap = "gh",
                picker = "telescope",
            }
        }
    }
})
```

## Project Structure

- `lua/codecompanion/_extensions/history/` - Main extension code
  - `init.lua` - Extension entry point and setup
  - `storage.lua` - Chat state persistence
  - `title_generator.lua` - Smart title generation
  - `ui.lua` - History browser interface
  - `pickers/` - UI implementations
  - `types.lua` - Type definitions
  - `utils.lua` - Shared utilities

## Making Changes

### 1. Set up development environment:
- See the above [Development Environment Setup](#development-environment-setup) for details

### 2. Make changes:
- Follow existing code patterns
- Update relevant documentation
- Add tests for new functionality
- Run `make format` to format code using stylua
- Run `make docs` to generate documentation

#### Code Style
- Use [stylua](https://github.com/JohnnyMorganz/StyLua) for code formatting
- Configuration is in `stylua.toml`
- Run `make format` before submitting PRs
- Follow existing code patterns and naming conventions

#### Documentation
Documentation is built using [panvimdoc](https://github.com/kdheepak/panvimdoc):

```bash
make docs  # Generate plugin documentation
```

### Testing

The extension uses [Mini.Test](https://github.com/echasnovski/mini.nvim/tree/main/lua/mini/test):

```bash
make test           # Run all tests
make test_file FILE=path/to/test_file.lua  # Run specific test file
```

When adding new features:
- Add tests in `tests/`
- Test chat state restoration
- Ensure proper error handling

## Pull Request Process

1. Update documentation if behavior changes
2. Add tests for new features
3. Format code: `make format`
4. Generate docs: `make docs`
5. Include:
   - Clear description
   - Related issue references
   - Screenshots/gifs if UI changes
   - Log examples if relevant


## Getting Help

- Check creating extensions [guide](https://codecompanion.olimorris.dev/extending/extensions.html)
- Open an issue with detailed description
- Search existing issues/PRs first
- Provide error logs and steps to reproduce

## License

By contributing, you agree that your contributions will be licensed under the MIT License.


