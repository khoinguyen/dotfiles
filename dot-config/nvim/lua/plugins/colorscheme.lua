-- return {
--   "neanias/everforest-nvim",
--   version = false,
--   lazy = false,
--   priority = 1000, -- make sure to load this before all the other start plugins
--   -- Optional; default configuration will be used if setup isn't called.
--   config = function()
--     require("everforest").setup({
--       -- Your config here
--     })
--   end,
-- }

return {
  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    priority = 1000,
    config = function()
      require('catppuccin').setup({
        flavour = "frappe",
        integrations = {
          background = { -- :h background
            light = "latte",
            dark = "frappe",
          },
          cmp = true,
          gitsigns = true,
          treesitter = true,
          notify = false,
          neotree = false,
          harpoon = true,
          mini = {
            enabled = true,
            indentscope_color = "",
          },
          native_lsp = {
            enabled = true,
            virtual_text = {
              errors = { "italic" },
              hints = { "italic" },
              warnings = { "italic" },
              information = { "italic" },
            },
            underlines = {
              errors = { "underline" },
              hints = { "underline" },
              warnings = { "underline" },
              information = { "underline" },
            },
            inlay_hints = {
              background = true,
            },
          },
        }
      })
      vim.cmd.colorscheme "catppuccin-frappe"
      vim.keymap.set("n", "<leader>tl", ":set bg=light<CR>", {})
      vim.keymap.set("n", "<leader>td", ":set bg=dark<CR>", {})

    end
  },

}

-- return {
--   "rebelot/kanagawa.nvim",
--   config = function()
--     require('kanagawa').setup({
--       compile = false,             -- enable compiling the colorscheme
--       undercurl = true,            -- enable undercurls
--       commentStyle = { italic = true },
--       functionStyle = {},
--       keywordStyle = { italic = true},
--       statementStyle = { bold = true },
--       typeStyle = {},
--       transparent = false,         -- do not set background color
--       dimInactive = false,         -- dim inactive window `:h hl-NormalNC`
--       terminalColors = true,       -- define vim.g.terminal_color_{0,17}
--       colors = {                   -- add/modify theme and palette colors
--       palette = {},
--       theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
--     },
--     overrides = function(colors) -- add/modify highlights
--       return {}
--     end,
--     theme = "wave",              -- Load "wave" theme when 'background' option is not set
--     background = {               -- map the value of 'background' option to a theme
--       dark = "wave",           -- try "dragon" !
--       light = "lotus"
--     },
--   })
--   vim.cmd("colorscheme kanagawa")
--
--   end
-- }
