return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",
  },
  opts = {
    workspaces = {
      {
        name = "main",
        path = "~/Documents/Scythic-obsidian/",
      },
    },
  },
  -- Various configurations
  config = function()
    require("obsidian").setup(
      {
        workspaces = {
          {
            name = "main",
            path = "~/Documents/Scythic-obsidian/",
          }
        },

        notes_subdir = "01 Ephemera",

        daily_notes = {
          folder = "Periodic Journal",
          date_format = "%Y-%m-%d",
          default_tags = {},
          template = "Daily Note Template.md",
        },

        new_notes_location = "notes_subdir",

        -- 'wiki' or 'markdown'
        preferred_link_style = "wiki",

        -- whether or not to auto-create and mange frontmatter
        disable_frontmatter = true,

        templates = {
          folder = "99 Meta/Templates",
          date_format = "%Y-%m-%d",
          time_format = "%H:%M",
        },

        -- Broken for some reason.
        --
        -- ---@param url string
        --   follow_url_func = function(url)
        --   vim.dn.jobstart({"open", url})
        --   end,
        --
        -- ---@param img string
        --   follow_img_func = function(img)
        --   vim.fn.jobstart({"xdg-open", url})
        --   end,

        picker = {
          name = "telescope.nvim",
          note_mappings = {
            new = "<C-x>",
            insert_link = "<C-l>",
          },
          tag_mappings = {
            tag_note = "<C-x>",
            insert_tag = "<C-l>",
          },
        },

        sort_by = "path",
        sort_reversed = false,

        search_max_lines = 1000,

        attachments = {
          img_folder = "99 Meta/Attachments"
        }

      }
    )
  end,
}
