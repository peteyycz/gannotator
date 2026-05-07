local M = {}

M.defaults = {
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
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
