return {
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.5',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-ui-select.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim', build = 'make'
      },
      "RutaTang/quicknote.nvim",
      "smartpde/telescope-recent-files"
    },
    config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set('n', '<C-p>', builtin.find_files, {})
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
      vim.keymap.set('n', '<leader>gb', [[<cmd>Telescope buffers<CR>]])
      require("telescope").setup {
        extensions = {
          fzf = {
            fuzzy = true,                   -- false will only do exact matching
            override_generic_sorter = true, -- override the generic sorter
            override_file_sorter = true,    -- override the file sorter
            case_mode = "smart_case",       -- or "ignore_case" or "respect_case"
            -- the default case_mode is "smart_case"
          },
          ["ui-select"] = {
            require("telescope.themes").get_dropdown {
              -- even more opts
            }
          },
          quicknote = {
            defaultScope = "CWD",
          }
        }
      }
      require("telescope").load_extension("ui-select")
      require("telescope").load_extension("quicknote")
      require('telescope').load_extension('fzf')
      require('telescope').load_extension('recent_files')
      vim.api.nvim_set_keymap("n", "<Leader><Leader>",
        [[<cmd>lua require('telescope').extensions.recent_files.pick()<CR>]],
        { noremap = true, silent = true })
    end
  },
}
