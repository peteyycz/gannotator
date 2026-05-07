local config = require("gannotator.config")
local sidecar = require("gannotator.sidecar")
local diff = require("gannotator.diff")

local M = {}

local NS = vim.api.nvim_create_namespace("gannotator")
local PROMPT_NS = vim.api.nvim_create_namespace("gannotator_prompt")
local SIGN_GROUP = "gannotator"
local SIGN_NAME = "GannotatorComment"

local function box_width()
  return math.min(80, math.max(40, vim.api.nvim_win_get_width(0) - 10))
end

local function ensure_sign_defined()
  local existing = vim.fn.sign_getdefined(SIGN_NAME)
  if existing and #existing > 0 then return end
  vim.fn.sign_define(SIGN_NAME, {
    text = config.options.sign.text,
    texthl = config.options.sign.hl,
  })
end

local function wrap_lines(text, width)
  local out = {}
  for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
    if raw == "" then
      table.insert(out, "")
    else
      local line = raw
      while vim.fn.strdisplaywidth(line) > width do
        local cut = width
        for i = width, 1, -1 do
          if line:sub(i, i):match("%s") then
            cut = i - 1
            break
          end
        end
        if cut <= 0 then cut = width end
        table.insert(out, line:sub(1, cut))
        line = line:sub(cut + 1):gsub("^%s+", "")
      end
      table.insert(out, line)
    end
  end
  return out
end

local function box(text, width)
  local hl_body = config.options.virt_lines.hl_body
  local hl_border = config.options.virt_lines.hl_border
  local lines = wrap_lines(text, width)
  local inner = width
  local top = "╭─ comment " .. string.rep("─", math.max(0, inner - 9)) .. "╮"
  local bot = "╰" .. string.rep("─", inner + 1) .. "╯"
  local virt = {}
  table.insert(virt, { { top, hl_border } })
  for _, l in ipairs(lines) do
    local pad = inner - vim.fn.strdisplaywidth(l)
    if pad < 0 then pad = 0 end
    table.insert(virt, {
      { "│ ", hl_border },
      { l, hl_body },
      { string.rep(" ", pad), hl_body },
      { "│", hl_border },
    })
  end
  table.insert(virt, { { bot, hl_border } })
  return virt
end

local function clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  pcall(vim.fn.sign_unplace, SIGN_GROUP, { buffer = bufnr })
end

function M.render(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  opts = opts or {}
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local file = diff.buffer_relpath(bufnr)
  if not file then return end

  ensure_sign_defined()
  clear(bufnr)

  local annotations = sidecar.for_file(file)
  if #annotations == 0 then return end

  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local width = box_width()

  for _, ann in ipairs(annotations) do
    if opts.skip_id ~= ann.id then
      local sign_line = math.min(ann.start_line, total_lines)
      pcall(vim.fn.sign_place, 0, SIGN_GROUP, SIGN_NAME, bufnr, {
        lnum = sign_line,
        priority = 10,
      })

      local anchor = math.min(ann.end_line, total_lines) - 1
      if anchor < 0 then anchor = 0 end
      vim.api.nvim_buf_set_extmark(bufnr, NS, anchor, 0, {
        virt_lines = box(ann.comment, width),
        virt_lines_above = false,
      })
    end
  end
end

function M.render_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      M.render(bufnr)
    end
  end
end

local function prompt_inline(bufnr, anchor_line, opts, on_submit)
  opts = opts or {}
  local width = box_width()
  local content_lines = {}
  if opts.initial and opts.initial ~= "" then
    content_lines = vim.split(opts.initial, "\n")
  end
  local height = math.max(4, math.min(10, #content_lines))

  -- Spacer: empty virtual lines below the anchor that visually push the
  -- surrounding code down so the float doesn't overlap subsequent lines.
  -- height + 2 accounts for the float's top/bottom borders.
  local spacer = {}
  for _ = 1, height + 2 do
    table.insert(spacer, { { "", "Normal" } })
  end
  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, PROMPT_NS, anchor_line - 1, 0, {
    virt_lines = spacer,
    virt_lines_above = false,
  })

  local pbuf = vim.api.nvim_create_buf(false, true)
  vim.bo[pbuf].buftype = "acwrite"
  vim.bo[pbuf].bufhidden = "wipe"
  vim.bo[pbuf].swapfile = false
  vim.api.nvim_buf_set_name(pbuf, "gannotator://comment-" .. tostring(pbuf))
  if #content_lines > 0 then
    vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, content_lines)
  end
  vim.bo[pbuf].modified = false

  local win = vim.api.nvim_open_win(pbuf, true, {
    relative = "win",
    bufpos = { anchor_line - 1, 0 },
    row = 1,
    col = 0,
    width = width + 1,
    height = height,
    border = config.options.virt_lines.border,
    title = opts.title or " comment ",
    title_pos = "left",
    style = "minimal",
  })
  vim.wo[win].wrap = true

  -- :w / :wq → submit. Reset modified so subsequent :q doesn't complain.
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = pbuf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(pbuf, 0, -1, false)
      local text = vim.trim(table.concat(lines, "\n"))
      if text ~= "" then on_submit(text) end
      vim.bo[pbuf].modified = false
    end,
  })

  -- :q → always allow, even with unsaved changes (treat as cancel).
  vim.api.nvim_create_autocmd("QuitPre", {
    buffer = pbuf,
    callback = function()
      vim.bo[pbuf].modified = false
    end,
  })

  -- Cleanup spacer extmark + on_close hook regardless of how the window dies.
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      pcall(vim.api.nvim_buf_del_extmark, bufnr, PROMPT_NS, mark_id)
      if opts.on_close then opts.on_close() end
    end,
  })

  vim.cmd("startinsert")
end

function M.add(bufnr, start_line, end_line)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = diff.buffer_relpath(bufnr)
  if not file then
    vim.notify("[gannotator] cannot resolve file path for buffer", vim.log.levels.WARN)
    return
  end
  prompt_inline(bufnr, end_line, { title = " new comment " }, function(text)
    sidecar.add(file, start_line, end_line, text)
    M.render(bufnr)
  end)
end

function M.edit(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = diff.buffer_relpath(bufnr)
  if not file then return end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local ann = sidecar.at_line(file, line)
  if not ann then
    vim.notify("[gannotator] no comment on this line", vim.log.levels.INFO)
    return
  end
  -- Hide the existing rendered box while editing so the inline prompt
  -- occupies its slot, then re-render normally on close.
  M.render(bufnr, { skip_id = ann.id })
  prompt_inline(bufnr, ann.end_line, {
    title = " edit comment ",
    initial = ann.comment,
    on_close = function() M.render(bufnr) end,
  }, function(text)
    sidecar.update(ann.id, text)
  end)
end

function M.delete(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = diff.buffer_relpath(bufnr)
  if not file then return end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local ann = sidecar.at_line(file, line)
  if not ann then
    vim.notify("[gannotator] no comment on this line", vim.log.levels.INFO)
    return
  end
  sidecar.delete(ann.id)
  M.render(bufnr)
end

local function sorted_starts(file)
  local lines = {}
  for _, ann in ipairs(sidecar.for_file(file)) do
    table.insert(lines, ann.start_line)
  end
  table.sort(lines)
  return lines
end

function M.next(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = diff.buffer_relpath(bufnr)
  if not file then return end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  for _, l in ipairs(sorted_starts(file)) do
    if l > cur then
      vim.api.nvim_win_set_cursor(0, { l, 0 })
      return
    end
  end
end

function M.prev(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = diff.buffer_relpath(bufnr)
  if not file then return end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local starts = sorted_starts(file)
  for i = #starts, 1, -1 do
    if starts[i] < cur then
      vim.api.nvim_win_set_cursor(0, { starts[i], 0 })
      return
    end
  end
end

function M.list()
  local items = {}
  for _, ann in ipairs(sidecar.list()) do
    local p = sidecar.paths()
    local abs = p and (p.root .. "/" .. ann.file) or ann.file
    table.insert(items, {
      filename = abs,
      lnum = ann.start_line,
      end_lnum = ann.end_line,
      text = ann.comment:gsub("\n", " "),
    })
  end
  vim.fn.setqflist({}, " ", { title = "gannotator", items = items })
  vim.cmd("copen")
end

return M
