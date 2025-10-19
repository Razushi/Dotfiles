vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.expandtab = true

-- Set indents to 4 spaces
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4

vim.opt.clipboard = "unnamedplus"
vim.opt.scrolloff = 10

-- Preview command effects in split window
vim.opt.inccommand = "split"

-- Give things like tab completions irrelavent of case
vim.opt.ignorecase = true

vim.opt.termguicolors = true

-- Fold your code ---
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldnestmax = 4
vim.opt.foldenable = false
-- Use manual if no treesitter parsers exist
vim.api.nvim_create_autocmd({ "FileType" }, {
    callback = function()

        -- check if treesitter has parser 
        if require("nvim-treesitter.parsers").has_parser() then

            -- use treesitter folding
            vim.wo.foldmethod = "expr"
            vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        else

            -- use alternative foldmethod
            vim.opt.foldmethod = "manual"
        end
    end,
})
