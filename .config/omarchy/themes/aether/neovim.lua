return {
    {
        "bjarneo/aether.nvim",
        name = "aether",
        priority = 1000,
        opts = {
            disable_italics = false,
            colors = {
                -- Monotone shades (base00-base07)
                base00 = "#121212", -- Default background
                base01 = "#8a8a8d", -- Lighter background (status bars)
                base02 = "#121212", -- Selection background
                base03 = "#8a8a8d", -- Comments, invisibles
                base04 = "#bebebe", -- Dark foreground
                base05 = "#ffffff", -- Default foreground
                base06 = "#ffffff", -- Light foreground
                base07 = "#bebebe", -- Light background

                -- Accent colors (base08-base0F)
                base08 = "#D35F5F", -- Variables, errors, red
                base09 = "#B91C1C", -- Integers, constants, orange
                base0A = "#b91c1c", -- Classes, types, yellow
                base0B = "#FFC107", -- Strings, green
                base0C = "#bebebe", -- Support, regex, cyan
                base0D = "#e68e0d", -- Functions, keywords, blue
                base0E = "#D35F5F", -- Keywords, storage, magenta
                base0F = "#b90a0a", -- Deprecated, brown/yellow
            },
        },
        config = function(_, opts)
            require("aether").setup(opts)
            vim.cmd.colorscheme("aether")

            -- Enable hot reload
            require("aether.hotreload").setup()
        end,
    },
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "aether",
        },
    },
}
