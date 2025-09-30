return {
  "debugloop/telescope-undo.nvim",
  dependencies = {
    {
      "nvim-telescope/telescope.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
    },
  },
  -- keys = {
  --   {
  --     "<leader>u",
  --     "<cmd>Telescope undo<cr>",
  --     desc = "Undo history",
  --   },
  -- },
  opts = {
    extensions = {
      undo = {
      },
    },
  },
  config = function(_, opts)
    require("telescope").setup(opts)
    require("telescope").load_extension("undo")
    vim.keymap.set('n', '<leader>su', '<cmd>Telescope undo<cr>', { desc = '[S]earch [U]ndo' })
  end,
}
