return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
   config = function()
      local configs = require("nvim-treesitter.configs")
      configs.setup({
        ensure_installed = {"vim", "lua", "javascript"},
        highlight = { enabled = true },
        indent = { enabled = true },
     })
    end
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    config = function() 
      require('rainbow-delimiters.setup').setup({})
--      local rd = require('rainbow-delimiters')
--
--      require('rainbow-delimiters.setup').setup {
--    strategy = {
--        -- ...
--    },
--    query = {
--        -- ...
--    },
--    highlight = {
--        -- ...
--    },
--}

  
    end
  }
}


