local config = require("gannotator.config")

local M = {}

local function git_root()
  local out = vim.fn.systemlist("git rev-parse --show-toplevel")
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
    return nil
  end
  return out[1]
end

local function git_branch()
  local out = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
    return "HEAD"
  end
  return out[1]
end

local function safe_branch(name)
  return (name:gsub("/", "__"))
end

local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

local function ensure_gitignore(root, dir_name)
  if not config.options.auto_gitignore then return end
  local gi = root .. "/.gitignore"
  local entry = dir_name .. "/"
  local lines = {}
  if vim.fn.filereadable(gi) == 1 then
    lines = vim.fn.readfile(gi)
    for _, line in ipairs(lines) do
      if line == entry or line == "/" .. entry or line == dir_name then
        return
      end
    end
  end
  table.insert(lines, entry)
  vim.fn.writefile(lines, gi)
end

function M.paths()
  local root = git_root()
  if not root then return nil end
  local dir = root .. "/" .. config.options.sidecar_dir
  local branch = git_branch()
  return {
    root = root,
    dir = dir,
    branch = branch,
    sidecar = dir .. "/" .. safe_branch(branch) .. ".json",
    export = dir .. "/" .. config.options.export_file,
  }
end

local function blank(branch)
  return { version = 1, branch = branch, annotations = {} }
end

function M.load()
  local p = M.paths()
  if not p then return nil end
  if vim.fn.filereadable(p.sidecar) == 0 then
    return blank(p.branch)
  end
  local raw = table.concat(vim.fn.readfile(p.sidecar), "\n")
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return blank(p.branch)
  end
  data.annotations = data.annotations or {}
  return data
end

function M.save(data)
  local p = M.paths()
  if not p then
    vim.notify("[gannotator] not in a git repo", vim.log.levels.ERROR)
    return false
  end
  ensure_dir(p.dir)
  ensure_gitignore(p.root, config.options.sidecar_dir)
  local encoded = vim.json.encode(data)
  vim.fn.writefile({ encoded }, p.sidecar)
  return true
end

local function new_id()
  return string.format("%d-%d", os.time(), math.random(100000, 999999))
end

function M.add(file, start_line, end_line, comment)
  local data = M.load()
  if not data then return nil end
  local ann = {
    id = new_id(),
    file = file,
    start_line = start_line,
    end_line = end_line,
    comment = comment,
    created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
  table.insert(data.annotations, ann)
  M.save(data)
  return ann
end

function M.update(id, comment)
  local data = M.load()
  if not data then return nil end
  for _, ann in ipairs(data.annotations) do
    if ann.id == id then
      ann.comment = comment
      ann.updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
      M.save(data)
      return ann
    end
  end
  return nil
end

function M.delete(id)
  local data = M.load()
  if not data then return false end
  for i, ann in ipairs(data.annotations) do
    if ann.id == id then
      table.remove(data.annotations, i)
      M.save(data)
      return true
    end
  end
  return false
end

function M.list()
  local data = M.load()
  if not data then return {} end
  return data.annotations
end

function M.for_file(file)
  local out = {}
  for _, ann in ipairs(M.list()) do
    if ann.file == file then
      table.insert(out, ann)
    end
  end
  return out
end

function M.at_line(file, line)
  for _, ann in ipairs(M.for_file(file)) do
    if line >= ann.start_line and line <= ann.end_line then
      return ann
    end
  end
  return nil
end

function M.clear()
  local data = M.load()
  if not data then return false end
  data.annotations = {}
  M.save(data)
  return true
end

return M
