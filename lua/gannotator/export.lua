local sidecar = require("gannotator.sidecar")
local diff = require("gannotator.diff")

local M = {}

local function ext_for(file)
  local ext = file:match("%.([%w_]+)$")
  return ext or ""
end

local function group_by_file(annotations)
  local groups = {}
  local order = {}
  for _, ann in ipairs(annotations) do
    if not groups[ann.file] then
      groups[ann.file] = {}
      table.insert(order, ann.file)
    end
    table.insert(groups[ann.file], ann)
  end
  for _, f in ipairs(order) do
    table.sort(groups[f], function(a, b) return a.start_line < b.start_line end)
  end
  return groups, order
end

function M.render()
  local annotations = sidecar.list()
  local p = sidecar.paths()
  if not p then return nil, "not in a git repo" end

  local groups, files = group_by_file(annotations)
  local out = {}
  table.insert(out, "# Code review notes")
  table.insert(out, "")
  table.insert(out, string.format("- Branch: `%s`", p.branch))
  table.insert(out, string.format("- Generated: %s", os.date("!%Y-%m-%dT%H:%M:%SZ")))
  table.insert(out, string.format("- %d comment(s) across %d file(s)", #annotations, #files))
  table.insert(out, "")

  if #annotations == 0 then
    table.insert(out, "_No comments._")
  end

  for _, file in ipairs(files) do
    table.insert(out, "---")
    table.insert(out, "")
    table.insert(out, string.format("## `%s`", file))
    table.insert(out, "")
    for _, ann in ipairs(groups[file]) do
      local range
      if ann.start_line == ann.end_line then
        range = tostring(ann.start_line)
      else
        range = string.format("%d-%d", ann.start_line, ann.end_line)
      end
      table.insert(out, string.format("### Lines %s", range))
      table.insert(out, "")

      local ctx = diff.context_for(file, ann.start_line, ann.end_line)
      if ctx then
        table.insert(out, "```" .. ext_for(file))
        table.insert(out, ctx.text)
        table.insert(out, "```")
        table.insert(out, "")
      end

      table.insert(out, "**Comment:**")
      table.insert(out, "")
      for line in (ann.comment .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(out, "> " .. line)
      end
      table.insert(out, "")
    end
  end

  return table.concat(out, "\n"), nil
end

function M.write()
  local p = sidecar.paths()
  if not p then
    vim.notify("[gannotator] not in a git repo", vim.log.levels.ERROR)
    return nil
  end
  local content, err = M.render()
  if not content then
    vim.notify("[gannotator] " .. err, vim.log.levels.ERROR)
    return nil
  end
  vim.fn.mkdir(p.dir, "p")
  vim.fn.writefile(vim.split(content, "\n"), p.export)
  return p.export
end

return M
