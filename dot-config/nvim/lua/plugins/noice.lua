return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    -- add any options here
  },
  dependencies = {
    -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
    "MunifTanjim/nui.nvim",
    -- OPTIONAL:
    --   `nvim-notify` is only needed, if you want to use the notification view.
    --   If not available, we use `mini` as the fallback
    "rcarriga/nvim-notify",
  },
  config = function()
    require("noice").setup({
      routes = {
        {
          view = "split",
          filter = { event = "msg_show", min_height = 20 },
        },
        {
          view = "mini",
          filter = {
            cmdline = true
          }
        },
        {
          view = "split",
          filter = {
            cmdline = true, min_height = 3
          }
        }
      },
    })
  end

}
