# gannotator

Leave inline comments on a git diff inside Neovim, then export the whole review as a markdown file you can hand to an LLM (Claude Code, or anything else that takes a file reference).

## Features

- Add comments on a single line or a visual range while reviewing a diff (`:DiffviewOpen`, `:Gdiff`, or any buffer).
- Comments render as bordered virtual lines underneath the code they target — never modifies your source files.
- Annotated lines get a subtle background tint, computed automatically as a small offset from your colorscheme's `Normal` background so it stays nearly invisible. Override via the `GannotatorAffectedLine` highlight group.
- Inline editing prompt appears in place of the rendered comment, sized and positioned to match. Save with `:w` / `:wq`, cancel with `:q` — no custom keymaps to remember.
- `:GAnnotatorExport` writes a markdown file (`.gannotator/review.md`) with each comment, the surrounding code context, and line ranges, ready to feed back to an LLM.
- All annotations live in a per-branch sidecar JSON (`.gannotator/<branch>.json`) inside your repo. Auto-gitignored on first use.
- Quickfix list of all annotations across files; `:GAnnotatorNext` / `Prev` to step between them in a buffer.
- No default keymaps, no surprise hooks. You opt in to everything you want bound.

## Installation

Using [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
{
  "peteyycz/gannotator",
  opts = {
    keymaps = {
      add    = "<leader>ca",
      edit   = "<leader>ce",
      delete = "<leader>cd",
      next   = "]a",
      prev   = "[a",
    },
  },
},
```

Using [`packer.nvim`](https://github.com/wbthomason/packer.nvim):

```lua
use({
  "peteyycz/gannotator",
  config = function()
    require("gannotator").setup({
      keymaps = {
        add    = "<leader>ca",
        edit   = "<leader>ce",
        delete = "<leader>cd",
        next   = "]a",
        prev   = "[a",
      },
    })
  end,
})
```

Default configuration:

```lua
require("gannotator").setup({
  sidecar_dir = ".gannotator",
  export_file = "review.md",
  virt_lines = {
    border = "rounded",
    hl_body = "Comment",
    hl_border = "FloatBorder",
  },
  auto_gitignore = true,
  context_lines = 20,
  keymaps = {},
  filetypes = { "diff", "DiffviewFiles", "DiffviewFileHistory" },
})
```

## Workflow

1. Run a Claude Code session; describe what you want done.
2. Once Claude finishes, switch to Neovim and open a diff (e.g. `:DiffviewOpen`).
3. Move to a line, press `<leader>ca` (or visually select a range first). Type, then `:wq`.
4. When done reviewing, run `:GAnnotatorExport`.
5. Back in Claude Code: `@.gannotator/review.md please address these comments`.

See `:help gannotator` for full command reference and the sidecar format.
