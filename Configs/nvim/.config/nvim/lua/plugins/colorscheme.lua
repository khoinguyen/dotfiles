return {
  { "sainnhe/gruvbox-material" },
  {
    "akinsho/bufferline.nvim",
    optional = true,
    --    opts = function(_, opts)
    --      if (vim.g.colors_name or ""):find("gruvbox") then
    --        opts.highlights = require("gruvbox.groups.integrations.bufferline").get()
    --      end
    --    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox-material",
      background = "dark",
    },
  },
}
