local config = require("gannotator.config")
local sidecar = require("gannotator.sidecar")
local ui = require("gannotator.ui")
local export = require("gannotator.export")

local M = {}

M.config = config
M.sidecar = sidecar
M.ui = ui
M.export = export

function M.setup(opts)
  config.setup(opts)
  M._setup_autocmds()
  M._apply_keymaps()
end

function M._apply_keymaps()
  local km = config.options.keymaps or {}
  local map = function(mode, lhs, rhs, desc)
    if not lhs or lhs == "" then return end
    vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
  end
  if km.add then
    map("n", km.add, "<cmd>GAnnotatorAdd<cr>", "gannotator: add comment")
    map("x", km.add, ":<C-u>'<,'>GAnnotatorAdd<cr>", "gannotator: add comment (range)")
  end
  map("n", km.edit, "<cmd>GAnnotatorEdit<cr>", "gannotator: edit comment")
  map("n", km.delete, "<cmd>GAnnotatorDelete<cr>", "gannotator: delete comment")
  map("n", km.next, "<cmd>GAnnotatorNext<cr>", "gannotator: next comment")
  map("n", km.prev, "<cmd>GAnnotatorPrev<cr>", "gannotator: prev comment")
end

function M._setup_autocmds()
  local group = vim.api.nvim_create_augroup("Gannotator", { clear = true })
  vim.api.nvim_create_autocmd({
    "BufEnter",
    "BufWinEnter",
    "BufWritePost",
    "BufReadPost",
  }, {
    group = group,
    callback = function(args)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          ui.render(args.buf)
        end
      end)
    end,
  })
end

function M.add(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local s = opts.line1 or vim.api.nvim_win_get_cursor(0)[1]
  local e = opts.line2 or s
  if e < s then s, e = e, s end
  ui.add(bufnr, s, e)
end

function M.edit() ui.edit() end
function M.delete() ui.delete() end
function M.next() ui.next() end
function M.prev() ui.prev() end
function M.list() ui.list() end

function M.export_review()
  local path = export.write()
  if path then
    local p = sidecar.paths()
    local rel = p and path:sub(#p.root + 2) or path
    vim.notify(string.format("[gannotator] wrote %s", rel), vim.log.levels.INFO)
  end
end

function M.clear()
  vim.ui.select({ "yes", "no" }, { prompt = "Clear all annotations on this branch?" }, function(choice)
    if choice == "yes" then
      sidecar.clear()
      ui.render_all()
      vim.notify("[gannotator] cleared", vim.log.levels.INFO)
    end
  end)
end

function M.show()
  local diff = require("gannotator.diff")
  local bufnr = vim.api.nvim_get_current_buf()
  local file = diff.buffer_relpath(bufnr)
  if not file then return end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local ann = sidecar.at_line(file, line)
  if not ann then
    vim.notify("[gannotator] no comment on this line", vim.log.levels.INFO)
    return
  end
  local lines = vim.split(ann.comment, "\n")
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.min(80, math.max(40, width + 2))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = math.min(#lines, 10),
    border = config.options.virt_lines.border,
    title = " comment ",
    title_pos = "left",
    style = "minimal",
    focusable = false,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })
end

return M
