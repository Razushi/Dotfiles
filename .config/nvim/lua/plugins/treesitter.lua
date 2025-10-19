return
{
    -- NOTE: Sets up and configures treesitter stuff
    "nvim-treesitter/nvim-treesitter",
    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed  = { "c", "lua", "vim", "vimdoc", "query", "rust", "python" },
            -- auto_install = true,
            highlight = { enable = true },

            -- Keybinds using treesitter selections
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = "<Leader>ss", -- Set to 'false' to disable
                    node_incremental = "<Leader>sa",
                    scope_incremental = "<Leader>sc",
                    node_decremental = "<Leader>sx",
                },
            },
        })
    end,
}
