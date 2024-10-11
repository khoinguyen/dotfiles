return {
  { "RutaTang/quicknote.nvim", config=function()
        -- you must call setup to let quicknote.nvim works correctly
        require("quicknote").setup({
          mode = "resident"
        })
        vim.keymap.set('n', 'tn',":lua require('quicknote').OpenNoteAtCurrentLine()<CR>" )
  end
  , dependencies = { "nvim-lua/plenary.nvim"} },
}
