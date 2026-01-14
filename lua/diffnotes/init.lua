local M = {}

local config = require("diffnotes.config")
local highlights = require("diffnotes.highlights")
local hooks = require("diffnotes.hooks")
local keymaps = require("diffnotes.keymaps")
local store = require("diffnotes.store")
local export = require("diffnotes.export")
local comments = require("diffnotes.comments")

local initialized = false
local augroup = nil

---@param opts? DiffnotesConfig
function M.setup(opts)
  if initialized then
    return
  end

  config.setup(opts)
  highlights.setup()

  -- Set up autocmd to detect CodeDiff sessions
  augroup = vim.api.nvim_create_augroup("diffnotes", { clear = true })

  vim.api.nvim_create_autocmd("TabEnter", {
    group = augroup,
    callback = function()
      vim.defer_fn(function()
        M._check_codediff_session()
      end, 100)
    end,
  })

  vim.api.nvim_create_autocmd("TabClosed", {
    group = augroup,
    callback = function()
      hooks.on_session_closed()
    end,
  })

  initialized = true
end

-- Check if current tab is a CodeDiff session and set up hooks/keymaps
function M._check_codediff_session()
  local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
  if not ok then
    return
  end

  local tabpage = vim.api.nvim_get_current_tabpage()
  local sess = lifecycle.get_session(tabpage)
  if not sess then
    return
  end

  -- This is a codediff session
  local orig_buf, mod_buf = lifecycle.get_buffers(tabpage)

  -- Set up hooks
  hooks.on_session_created(tabpage)

  -- Set up keymaps
  keymaps.setup_keymaps(tabpage, orig_buf, mod_buf)
end

function M.open()
  local ok, _ = pcall(require, "codediff")
  if not ok then
    vim.notify("codediff.nvim is required", vim.log.levels.ERROR, { title = "Diffnotes" })
    return
  end

  -- Load persisted comments
  store.load()

  -- Open CodeDiff in explorer mode
  vim.cmd("CodeDiff")

  -- Wait for CodeDiff to initialize, then set up our hooks
  vim.defer_fn(function()
    M._check_codediff_session()
  end, 200)
end

function M.close()
  -- Export comments to clipboard before closing
  local count = store.count()
  if count > 0 then
    local markdown = export.generate_markdown()
    vim.fn.setreg("+", markdown)
    vim.fn.setreg("*", markdown)
    vim.notify(string.format("Exported %d comment(s) to clipboard", count), vim.log.levels.INFO, { title = "Diffnotes" })
  end

  -- Close the tab
  vim.cmd("tabclose")
  hooks.on_session_closed()
end

function M.export()
  export.to_clipboard()
end

function M.preview()
  export.preview()
end

function M.clear()
  store.clear()
  require("diffnotes.marks").clear_all()
  vim.notify("All comments cleared", vim.log.levels.INFO, { title = "Diffnotes" })
end

function M.count()
  return store.count()
end

function M.add_note()
  comments.add_at_cursor("note")
end

function M.add_suggestion()
  comments.add_at_cursor("suggestion")
end

function M.add_issue()
  comments.add_at_cursor("issue")
end

function M.add_praise()
  comments.add_at_cursor("praise")
end

function M.toggle_readonly()
  local cfg = config.get()
  cfg.codediff.readonly = not cfg.codediff.readonly

  local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
  if not ok then
    return
  end

  local tabpage = hooks.get_current_tabpage()
  if not tabpage then
    return
  end

  local orig_buf, mod_buf = lifecycle.get_buffers(tabpage)

  -- Update buffer readonly state
  if orig_buf and vim.api.nvim_buf_is_valid(orig_buf) then
    vim.api.nvim_set_option_value("modifiable", not cfg.codediff.readonly, { buf = orig_buf })
    vim.api.nvim_set_option_value("readonly", cfg.codediff.readonly, { buf = orig_buf })
  end
  if mod_buf and vim.api.nvim_buf_is_valid(mod_buf) then
    vim.api.nvim_set_option_value("modifiable", not cfg.codediff.readonly, { buf = mod_buf })
    vim.api.nvim_set_option_value("readonly", cfg.codediff.readonly, { buf = mod_buf })
  end

  -- Re-setup keymaps with new readonly state
  keymaps.setup_keymaps(tabpage, orig_buf, mod_buf)

  local mode = cfg.codediff.readonly and "readonly" or "edit"
  vim.notify("Switched to " .. mode .. " mode", vim.log.levels.INFO, { title = "Diffnotes" })
end

return M
