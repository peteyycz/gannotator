local config = require("gannotator.config")
local sidecar = require("gannotator.sidecar")

local M = {}

local function strip_diffview_prefix(name)
  -- diffview buffer names look like: diffview:///<git_dir>/<sha>/<relpath>
  -- or panel:diffview://... — strip everything up to the last meaningful path.
  local stripped = name:gsub("^diffview://+", "")
  -- Common pattern: <git_dir>/<sha-or-symbol>/<relpath>. We can't reliably
  -- split that without knowing git_dir, so fall back to letting the caller
  -- match against the working tree path below.
  return stripped
end

function M.buffer_relpath(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then return nil end

  local p = sidecar.paths()
  local root = p and p.root or vim.fn.getcwd()

  if name:match("^diffview://") then
    name = strip_diffview_prefix(name)
  end

  -- If absolute and under git root, return relative.
  if name:sub(1, #root) == root then
    local rel = name:sub(#root + 2)
    if rel ~= "" then return rel end
  end

  -- Walk path-separator boundaries from left to right and pick the first
  -- suffix that resolves to a real file under root. Bounded by segment count.
  local idx = 1
  while idx do
    local candidate = name:sub(idx)
    if vim.fn.filereadable(root .. "/" .. candidate) == 1 then
      return candidate
    end
    local nxt = name:find("/", idx + 1, true)
    if not nxt then break end
    idx = nxt + 1
  end

  return nil
end

function M.context_for(file, start_line, end_line)
  local p = sidecar.paths()
  if not p then return nil end
  local abs = p.root .. "/" .. file
  if vim.fn.filereadable(abs) == 0 then return nil end

  local n = config.options.context_lines
  local from = math.max(1, start_line - n)
  local to = end_line + n

  local lines = vim.fn.readfile(abs)
  local slice = {}
  for i = from, math.min(to, #lines) do
    table.insert(slice, string.format("%5d  %s", i, lines[i] or ""))
  end
  return {
    from = from,
    to = math.min(to, #lines),
    text = table.concat(slice, "\n"),
  }
end

function M.is_diff_buffer(bufnr)
  bufnr = bufnr or 0
  local ft = vim.bo[bufnr].filetype
  for _, allowed in ipairs(config.options.filetypes) do
    if ft == allowed then return true end
  end
  -- Also allow regular file buffers — annotation works on either the
  -- diffview pane or directly on a file you opened to review.
  return vim.api.nvim_buf_get_name(bufnr) ~= ""
end

return M
