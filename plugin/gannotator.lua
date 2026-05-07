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
