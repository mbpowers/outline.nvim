local parser = require 'outline.parser'
local cfg = require('outline.config')
local ui = require 'outline.ui'

local M = {}

local function is_buffer_outline(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  return string.match(name, 'OUTLINE') ~= nil and ft == 'Outline'
end

local hlns = vim.api.nvim_create_namespace 'outline-icon-highlight'

function M.write_outline(bufnr, lines)
  if not is_buffer_outline(bufnr) then
    return
  end

  lines = vim.tbl_map(function(line)
    lines, _ = string.gsub(line, "\n", " ")
    return lines
  end, lines)

  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

function M.add_highlights(bufnr, hl_info, nodes)
  for _, line_hl in ipairs(hl_info) do
    local line, hl_start, hl_end, hl_type = unpack(line_hl)
    vim.api.nvim_buf_add_highlight(
      bufnr,
      hlns,
      hl_type,
      line - 1,
      hl_start,
      hl_end
    )
  end

  M.add_hover_highlights(bufnr, nodes)
end

local ns = vim.api.nvim_create_namespace 'outline-virt-text'

function M.write_details(bufnr, lines)
  if not is_buffer_outline(bufnr) then
    return
  end
  if not cfg.o.outline_items.show_symbol_details then
    return
  end

  for index, value in ipairs(lines) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, index - 1, -1, {
      virt_text = { { value, 'OutlineDetails' } },
      virt_text_pos = 'eol',
      hl_mode = 'combine',
    })
  end
end

function M.write_lineno(bufnr, lines, max)
  if not is_buffer_outline(bufnr) then
    return
  end
  if not cfg.o.outline_items.show_symbol_lineno then
    return
  end
  local maxwidth = #tostring(max)

  for index, value in ipairs(lines) do
    local leftpad = string.rep(' ', maxwidth-#value)
    vim.api.nvim_buf_set_extmark(bufnr, ns, index - 1, -1, {
      virt_text = { {leftpad..value, 'OutlineLineno' } },
      virt_text_pos = 'overlay',
      virt_text_win_col = 0,
      hl_mode = 'combine',
    })
  end
end

local function clear_virt_text(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
end

M.add_hover_highlights = function(bufnr, nodes)
  if not cfg.o.outline_items.highlight_hovered_item then
    return
  end

  -- clear old highlight
  ui.clear_hover_highlight(bufnr)
  for _, node in ipairs(nodes) do
    if not node.hovered then
      goto continue
    end

    local marker_fac = (cfg.o.symbol_folding.markers and 1) or 0
    if node.prefix_length then
      ui.add_hover_highlight(
        bufnr,
        node.line_in_outline - 1,
        node.prefix_length
      )
    end
    ::continue::
  end
end

-- runs the whole writing routine where the text is cleared, new data is parsed
-- and then written
function M.parse_and_write(bufnr, flattened_outline_items)
  local lines, hl_info = parser.get_lines(flattened_outline_items)
  M.write_outline(bufnr, lines)

  clear_virt_text(bufnr)
  local details = parser.get_details(flattened_outline_items)
  local lineno, lineno_max = parser.get_lineno(flattened_outline_items)
  M.add_highlights(bufnr, hl_info, flattened_outline_items)
  M.write_details(bufnr, details)
  M.write_lineno(bufnr, lineno, lineno_max)
end

return M