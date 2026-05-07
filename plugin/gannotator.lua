if vim.g.loaded_gannotator then return end
vim.g.loaded_gannotator = true

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

local function setup_keymaps()
  local km = require("gannotator.config").options.keymaps
  local map = function(mode, lhs, rhs, desc)
    if not lhs or lhs == "" then return end
    vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
  end
  map("n", km.add, "<cmd>GAnnotatorAdd<cr>", "gannotator: add comment")
  map("x", km.add, ":<C-u>'<,'>GAnnotatorAdd<cr>", "gannotator: add comment (range)")
  map("n", km.edit, "<cmd>GAnnotatorEdit<cr>", "gannotator: edit comment")
  map("n", km.delete, "<cmd>GAnnotatorDelete<cr>", "gannotator: delete comment")
  map("n", km.next, "<cmd>GAnnotatorNext<cr>", "gannotator: next comment")
  map("n", km.prev, "<cmd>GAnnotatorPrev<cr>", "gannotator: prev comment")
end

-- Defer keymap setup so user setup() opts win.
vim.schedule(setup_keymaps)
