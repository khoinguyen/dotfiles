local function close_neotree()
  --  vim.cmd(":Neotree close")
end
local function reveal_neotree()
  --vim.cmd(":Neotree reveal")
end
return {
  'rmagatti/auto-session',
  config = function()
    require("auto-session").setup {
      log_level = "error",
      auto_session_suppress_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
      bypass_session_save_file_types = {"neo-tree"},
      pre_save_cmds = {
        close_neotree
      },
      post_restore_cmds = {
        reveal_neotree
      }

    }
  end
}
