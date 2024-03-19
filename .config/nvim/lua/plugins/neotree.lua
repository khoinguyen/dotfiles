return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
    "MunifTanjim/nui.nvim",
    -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    's1n7ax/nvim-window-picker',
  },
  config = function()
    vim.keymap.set('n', '<C-n>', ':Neotree filesystem reveal<CR>', {})
    vim.keymap.set('n', '<C-g>', ':Neotree float git_status toggle<CR>', {})
    local function getTelescopeOpts(state, path)
      return {
        cwd = path,
        search_dirs = { path },
        attach_mappings = function(prompt_bufnr, _)
          local actions = require "telescope.actions"
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local action_state = require "telescope.actions.state"
            local selection = action_state.get_selected_entry()
            local filename = selection.filename
            if (filename == nil) then
              filename = selection[1]
            end
            -- any way to open the file without triggering auto-close event of neo-tree?
            require("neo-tree.sources.filesystem").navigate(state, state.path, filename)
          end)
          return true
        end
      }
    end
    require 'window-picker'.setup({
      filter_rules = {
        include_current_win = false,
        autoselect_one = true,
        -- filter using buffer options
        bo = {
          -- if the file type is one of following, the window will be ignored
          filetype = { 'neo-tree', "neo-tree-popup", "notify" },
          -- if the buffer type is one of following, the window will be ignored
          buftype = { 'terminal', "quickfix" },
        },
      },
    })
    require("neo-tree").setup({
      filesystem = {
        use_libuv_file_watcher = true,
        follow_current_file = {
          enabled = true,
        },
        window = {
          mappings = {
            ["tf"] = "telescope_find",
            ["tg"] = "telescope_grep",
          }
        },
        commands = {
          telescope_find = function(state)
            local node = state.tree:get_node()
            local path = node:get_id()
            require('telescope.builtin').find_files(getTelescopeOpts(state, path))
          end,
          telescope_grep = function(state)
            local node = state.tree:get_node()
            local path = node:get_id()
            require('telescope.builtin').live_grep(getTelescopeOpts(state, path))
          end,
        },
        filtered_items = {
          hide_dotfiles = false
        },

      },
      event_handlers = {
        {
          event = "neo_tree_buffer_enter",
          handler = function()
            vim.opt_local.relativenumber = true
          end
        }
      }
    })
  end
}
