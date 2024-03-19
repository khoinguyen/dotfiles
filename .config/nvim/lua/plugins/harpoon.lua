return {
  'ThePrimeagen/harpoon',
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("telescope").load_extension('harpoon')
    vim.keymap.set('n', '<leader>\\', ':Telescope harpoon marks<CR>', {})
    vim.keymap.set('n', '<leader>/', ':lua require("harpoon.mark").add_file()<CR>', {})
    vim.keymap.set('n', '<leader>n', ':lua require("harpoon.ui").nav_next()<CR>', {})
  end
}
