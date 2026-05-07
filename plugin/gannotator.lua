if vim.g.loaded_gannotator then return end
vim.g.loaded_gannotator = true

local function shift_channel(c, delta)
  c = c + delta
  if c < 0 then return 0 end
  if c > 255 then return 255 end
  return c
end

local function subtle_tint_of_normal()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  if not normal or not normal.bg then return nil end
  local bg = normal.bg
  local r = math.floor(bg / 65536) % 256
  local g = math.floor(bg / 256) % 256
  local b = bg % 256
  -- Dark theme → lighten; light theme → darken. Small delta keeps it subtle.
  local dark = (r + g + b) / 3 < 128
  local delta = dark and 8 or -8
  r = shift_channel(r, delta)
  g = shift_channel(g, delta)
  b = shift_channel(b, delta)
  return string.format("#%02x%02x%02x", r, g, b)
end

local function set_highlights()
  local tint = subtle_tint_of_normal()
  if tint then
    vim.api.nvim_set_hl(0, "GannotatorAffectedLine", { bg = tint, default = true })
  else
    vim.api.nvim_set_hl(0, "GannotatorAffectedLine", { link = "CursorLine", default = true })
  end
end
set_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("GannotatorHighlights", { clear = true }),
  callback = set_highlights,
})

local function cmd(name, fn, opts)
  vim.api.nvim_create_user_command(name, fn, opts or {})
end

cmd("GAnnotatorAdd", function(args)
  require("gannotator").add({ line1 = args.line1, line2 = args.line2 })
end, { range = true })

cmd("GAnnotatorEdit", function() require("gannotator").edit() end, {})
cmd("GAnnotatorDelete", function() require("gannotator").delete() end, {})
cmd("GAnnotatorShow", function() require("gannotator").show() end, {})
cmd("GAnnotatorList", function() require("gannotator").list() end, {})
cmd("GAnnotatorExport", function() require("gannotator").export_review() end, {})
cmd("GAnnotatorClear", function() require("gannotator").clear() end, {})
cmd("GAnnotatorNext", function() require("gannotator").next() end, {})
cmd("GAnnotatorPrev", function() require("gannotator").prev() end, {})
