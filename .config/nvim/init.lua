require("options")
require("lazynvim")
require("keymaps")

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"


-- Use conform to format on save
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*",
    callback = function(args)
        require("conform").format({ bufnr = args.buf })
    end,
})
