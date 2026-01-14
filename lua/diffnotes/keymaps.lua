local M = {}

local config = require("diffnotes.config")
local comments = require("diffnotes.comments")
local export = require("diffnotes.export")

---@param tabpage number
---@param orig_buf number
---@param mod_buf number
function M.setup_keymaps(tabpage, orig_buf, mod_buf)
  local cfg = config.get()
  local km = cfg.keymaps
  local readonly = cfg.codediff.readonly

  local function set_keymap(bufnr, mode, lhs, rhs, opts)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    opts = opts or {}
    opts.buffer = bufnr
    vim.keymap.set(mode, lhs, rhs, opts)
  end

  local function set_both(mode, lhs, rhs, opts)
    set_keymap(orig_buf, mode, lhs, rhs, opts)
    set_keymap(mod_buf, mode, lhs, rhs, opts)
  end

  -- Simple keymaps in readonly mode
  if readonly then
    set_both("n", "i", function() comments.add_with_menu() end, { desc = "Add comment (pick type)" })
    set_both("n", "d", function() comments.delete_at_cursor() end, { desc = "Delete comment" })
    set_both("n", "e", function() comments.edit_at_cursor() end, { desc = "Edit comment" })
  else
    -- Leader keymaps in edit mode
    set_both("n", km.add_note, function() comments.add_at_cursor("note") end, { desc = "Add note" })
    set_both("n", km.add_suggestion, function() comments.add_at_cursor("suggestion") end, { desc = "Add suggestion" })
    set_both("n", km.add_issue, function() comments.add_at_cursor("issue") end, { desc = "Add issue" })
    set_both("n", km.add_praise, function() comments.add_at_cursor("praise") end, { desc = "Add praise" })
    set_both("n", km.delete_comment, function() comments.delete_at_cursor() end, { desc = "Delete comment" })
    set_both("n", km.edit_comment, function() comments.edit_at_cursor() end, { desc = "Edit comment" })
  end

  -- Common keymaps
  set_both("n", "c", function() comments.list() end, { desc = "List all comments" })
  set_both("n", "C", function() require("diffnotes").clear() end, { desc = "Clear all comments" })
  set_both("n", km.next_comment, function() comments.goto_next() end, { desc = "Next comment" })
  set_both("n", km.prev_comment, function() comments.goto_prev() end, { desc = "Previous comment" })
  set_both("n", km.export, function() export.to_clipboard() end, { desc = "Export to clipboard" })

  -- Close and export
  set_both("n", "q", function() require("diffnotes").close() end, { desc = "Close" })

  -- Toggle readonly mode
  set_both("n", "R", function() require("diffnotes").toggle_readonly() end, { desc = "Toggle readonly mode" })

  -- File navigation in explorer mode
  local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
  if ok then
    local explorer = lifecycle.get_explorer(tabpage)
    if explorer then
      local explorer_mod = require("codediff.ui.explorer")
      set_both("n", "<Tab>", function()
        explorer_mod.navigate_next(explorer)
      end, { desc = "Next file" })
      set_both("n", "<S-Tab>", function()
        explorer_mod.navigate_prev(explorer)
      end, { desc = "Previous file" })
      set_both("n", "f", function()
        explorer_mod.toggle_visibility(explorer)
      end, { desc = "Toggle file panel" })
    end
  end
end

return M
