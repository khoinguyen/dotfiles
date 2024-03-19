
vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set nu rnu")
vim.g.mapleader = " "
vim.cmd("autocmd BufEnter * :lua require('lazygit.utils').project_root_dir()")
vim.cmd("nnoremap <silent> <leader>gg :LazyGit<CR>")
