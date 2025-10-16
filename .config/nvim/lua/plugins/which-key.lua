return
{
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
        spec = {
            { "<leader>s", group = "[s]earch" },
            { "<leader>f", group = "[f]ind" },
            { "<leader>l", group = "[l]sp" },
            { "<leader>G", group = "[G]it", mode = { "n", "v" } },
        },
    },
}
