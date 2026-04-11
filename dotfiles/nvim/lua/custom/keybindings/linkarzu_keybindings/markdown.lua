-- ############################################################################
--                         Begin of markdown section
-- ############################################################################

-- Copy all HTTPS links in current buffer to clipboard (one per line) lamw26wmal
vim.keymap.set('n', '<leader>ml', function()
  -- Get all lines in current buffer
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  -- Prepare a set for unique URLs and an ordered list to preserve first-seen order
  local seen = {}
  local urls = {}
  -- Lua pattern for https URLs
  local pat = 'https://%S+'
  -- Characters to trim from the end of a found URL (common closers/punctuation)
  local function rtrim_url(u)
    -- Remove trailing ), ], }, ., ,, ;, :, ?, !, ', ", >
    while u:match '[%)%]%}%.%,%;%:%?%!%\'%">%)]$' do
      u = u:sub(1, #u - 1)
    end
    -- Balance a trailing unmatched ')' from markdown links like (https://...))
    local open_paren = select(2, u:gsub('%(', ''))
    local close_paren = select(2, u:gsub('%)', ''))
    if close_paren > open_paren and u:sub(-1) == ')' then u = u:sub(1, #u - 1) end
    return u
  end
  -- Scan each line and collect matches
  for _, line in ipairs(lines) do
    for m in line:gmatch(pat) do
      local url = rtrim_url(m)
      if not seen[url] then
        seen[url] = true
        table.insert(urls, url)
      end
    end
  end
  -- If none found, inform and exit
  if #urls == 0 then
    print 'No https URLs found in buffer'
    return
  end
  -- Join and copy to system clipboard register +
  local blob = table.concat(urls, '\n')
  vim.fn.setreg('+', blob)
  -- Also put into unnamed register
  vim.fn.setreg('"', blob)
  -- Notify how many were copied
  print(('Copied %d URL(s) to clipboard'):format(#urls))
end, { desc = '[P]Markdown: copy all https links in buffer to clipboard' })

-- Check if Marksman LSP is running, start it if not, otherwise restart lamw26wmal
vim.keymap.set('n', '<leader>mR', function()
  local is_running = false
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.name == 'marksman' then
      is_running = true
      break
    end
  end
  if is_running then
    vim.cmd 'LspRestart marksman'
    vim.notify('Marksman LSP restarted', vim.log.levels.INFO)
  else
    vim.cmd 'LspStart marksman'
    vim.notify('Marksman LSP started', vim.log.levels.INFO)
  end
end, { desc = '[P]Start/Restart Marksman LSP' })

-- Select text inside codeblocks lamw26wmal
-- Select everything between the opening ```<lang> and the closing ``` fences
vim.keymap.set('n', 'vio', function()
  -- Find opening fence above cursor
  local cur = vim.fn.line '.'
  local open = nil
  for l = cur, 1, -1 do
    if vim.fn.getline(l):match '^%s*```%S+' then
      open = l
      break
    end
  end
  if not open then
    print 'No opening ```<lang> fence found'
    return
  end
  -- Find closing fence below the opening one
  local close = nil
  for l = open + 1, vim.fn.line '$' do
    if vim.fn.getline(l):match '^%s*```%s*$' then
      close = l
      break
    end
  end
  if not close then
    print 'No closing ``` fence found'
    return
  end
  if close - open <= 1 then
    print 'Code-block is empty'
    return
  end
  -- Visual-select lines open+1 .. close-1
  vim.cmd(('normal! %dGV%dG'):format(open + 1, close - 1))
end, { desc = '[P]Select inside fenced code-block' })

-- Keymap to auto-format and save all Markdown files in the CURRENT REPOSITORY,
-- lamw26wmal if the TOC is not updated, this will take care of it
vim.keymap.set('n', '<leader>mfA', function()
  -- Get the root directory of the git repository
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if not git_root or git_root == '' then
    print 'Could not determine the root directory for the Git repository.'
    return
  end
  -- Find all Markdown files in the repository
  local find_command = string.format("find %s -type f -name '*.md'", vim.fn.shellescape(git_root))
  local handle = io.popen(find_command)
  if not handle then
    print 'Failed to execute the find command.'
    return
  end
  local result = handle:read '*a'
  handle:close()
  if result == '' then
    print 'No Markdown files found in the repository.'
    return
  end
  -- Format and save each Markdown file
  for file in result:gmatch '[^\r\n]+' do
    local bufnr = vim.fn.bufadd(file)
    vim.fn.bufload(bufnr)
    require('conform').format { bufnr = bufnr }
    -- Save the buffer to write changes to disk
    vim.api.nvim_buf_call(bufnr, function() vim.cmd 'write' end)
    print('Formatted and saved: ' .. file)
  end
end, { desc = '[P]Format and save all Markdown files in the repo' })

local function process_embeds_in_buffer(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local embeds = {}
  local seen = {}
  local target_line = nil
  local current_section = nil
  local lines_to_remove = {}
  local protected_sections = {
    ['YouTube video'] = true,
    ['Other videos mentioned'] = true,
  }
  -- Collect embeds and find target section
  for i, line in ipairs(lines) do
    if line:match '^##%s+' then current_section = line:match '^##%s+(.-)%s*$' end
    if line:match '^## If you like my content, and want to support me' then target_line = i end
    if line:match '^{%% include embed/youtube.html id=' then
      if not protected_sections[current_section] then
        if not seen[line] then
          table.insert(embeds, line)
          seen[line] = true
        end
        table.insert(lines_to_remove, i)
      end
    end
  end
  if not target_line then return { error = "Target section 'If you like my content...' not found" } end
  -- Existing section handling
  local existing_section_start, existing_section_end = nil, nil
  for i = 1, #lines do
    if lines[i]:match '^## Other videos mentioned' then
      existing_section_start = i
      for j = i + 1, #lines do
        if lines[j]:match '^## ' then
          existing_section_end = j - 1
          break
        end
        existing_section_end = j
      end
      break
    end
  end
  -- Build new lines
  local new_lines = {}
  for i, line in ipairs(lines) do
    local in_removed = vim.tbl_contains(lines_to_remove, i)
    local in_existing_section = existing_section_start and i >= existing_section_start and i <= existing_section_end
    if not in_removed and not in_existing_section then table.insert(new_lines, line) end
  end
  -- Find new target position
  local new_target_pos = nil
  for i, line in ipairs(new_lines) do
    if line:match '^## If you like my content' then
      new_target_pos = i
      break
    end
  end
  if not new_target_pos then return { error = "Couldn't find target position after processing" } end
  -- Insert new section if embeds found
  if #embeds > 0 then
    local section_content = { '## Other videos mentioned', '' }
    for _, embed in ipairs(embeds) do
      table.insert(section_content, embed)
      table.insert(section_content, '')
    end
    table.insert(section_content, '')
    for i = #section_content, 1, -1 do
      table.insert(new_lines, new_target_pos, section_content[i])
    end
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  return {
    moved = #embeds,
    message = #embeds > 0 and ('Moved ' .. #embeds .. " embeds to 'Other videos mentioned' section") or 'No embeds to move',
  }
end

-- Move youtube embeds in my blogpost to their own section for the current
-- buffer lamw26wmal
-- http://youtube.com/post/Ugkx5K4nL8AtcH2Fjg6pyzQPamyqEugK-HNh?si=-pONtWziiB58yqmT
vim.keymap.set('n', '<leader>mfy', function()
  local result = process_embeds_in_buffer(0)
  if result.error then
    print(result.error)
  else
    print(result.message)
  end
end, { desc = '[P]Move YouTube embeds to dedicated section' })

-- Keymap youtube embeds for ALL the markdown files in the current repository
-- This will auto-format them, so don't worry about running and auto format for
-- all markdown files afterwards
vim.keymap.set('n', '<leader>mfY', function()
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if not git_root or git_root == '' then
    print 'Could not determine Git repository root.'
    return
  end
  local find_command = string.format("find %s -type f -name '*.md'", vim.fn.shellescape(git_root))
  local handle = io.popen(find_command)
  if not handle then
    print 'Failed to find Markdown files.'
    return
  end
  local files = {}
  for file in handle:lines() do
    table.insert(files, file)
  end
  handle:close()
  if #files == 0 then
    print 'No Markdown files found in repository.'
    return
  end
  for _, file in ipairs(files) do
    local bufnr = vim.fn.bufadd(file)
    vim.fn.bufload(bufnr)
    local result = process_embeds_in_buffer(bufnr)
    vim.api.nvim_buf_call(bufnr, function() vim.cmd 'write' end)
    local status = result.error and ('Error: ' .. result.error) or result.message
    print(string.format('%s: %s', file, status))
  end
end, { desc = '[P]Move YouTube embeds in all repo Markdown files' })

-- HACK: My complete Neovim markdown setup and workflow in 2024
-- https://youtu.be/c0cuvzK1SDo

-- Mappings for creating new groups that don't exist
-- When I press leader, I want to modify the name of the options shown
-- "m" is for "markdown" and "t" is for "todo"
-- https://github.com/folke/which-key.nvim?tab=readme-ov-file#%EF%B8%8F-mappings
local wk = require 'which-key'
wk.add {
  {
    mode = { 'n' },
    { '<leader>t', group = '[P]todo' },
  },
  {
    mode = { 'n', 'v' },
    { '<leader>m', group = '[P]markdown' },
    { '<leader>mf', group = '[P]fold' },
    { '<leader>mh', group = '[P]headings increase/decrease' },
    { '<leader>ml', group = '[P]links' },
    { '<leader>ms', group = '[P]spell' },
    { '<leader>msl', group = '[P]language' },
  },
}

-- Alternative solution proposed by @cashplease-s9m in my video
-- My complete Neovim markdown setup and workflow in 2025
-- https://youtu.be/1YEbKDlxfss
vim.keymap.set('v', '<leader>mj', ':g/^\\s*$/d<CR>:nohlsearch<CR>', { desc = '[P]Delete newlines in selected text (join)' })

-- -- In visual mode, delete all newlines within selected text
-- -- I like keeping my bulletpoints one after the next, sometimes formatting gets
-- -- in the way and they mess up, so this allows me to select all of them and just
-- -- delete newlines in between lamw25wmal
-- vim.keymap.set("v", "<leader>mj", function()
--   -- Get the visual selection range
--   local start_row = vim.fn.line("v")
--   local end_row = vim.fn.line(".")
--   -- Ensure start_row is less than or equal to end_row
--   if start_row > end_row then
--     start_row, end_row = end_row, start_row
--   end
--   -- Loop through each line in the selection
--   local current_row = start_row
--   while current_row <= end_row do
--     local line = vim.api.nvim_buf_get_lines(0, current_row - 1, current_row, false)[1]
--     -- vim.notify("Checking line " .. current_row .. ": " .. (line or ""), vim.log.levels.INFO)
--     -- If the line is empty, delete it and adjust end_row
--     if line == "" then
--       vim.cmd(current_row .. "delete")
--       end_row = end_row - 1
--     else
--       current_row = current_row + 1
--     end
--   end
-- end, { desc = "[P]Delete newlines in selected text (join)" })

-- Toggle bullet point at the beginning of the current line in normal mode
-- If in a multiline paragraph, make sure the cursor is on the line at the top
-- "d" is for "dash" lamw25wmal
vim.keymap.set('n', '<leader>md', function()
  -- Get the current cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_buffer = vim.api.nvim_get_current_buf()
  local start_row = cursor_pos[1] - 1
  local col = cursor_pos[2]
  -- Get the current line
  local line = vim.api.nvim_buf_get_lines(current_buffer, start_row, start_row + 1, false)[1]
  -- Check if the line already starts with a bullet point
  if line:match '^%s*%-' then
    -- Remove the bullet point from the start of the line
    line = line:gsub('^%s*%-', '')
    vim.api.nvim_buf_set_lines(current_buffer, start_row, start_row + 1, false, { line })
    return
  end
  -- Search for newline to the left of the cursor position
  local left_text = line:sub(1, col)
  local bullet_start = left_text:reverse():find '\n'
  if bullet_start then bullet_start = col - bullet_start end
  -- Search for newline to the right of the cursor position and in following lines
  local right_text = line:sub(col + 1)
  local bullet_end = right_text:find '\n'
  local end_row = start_row
  while not bullet_end and end_row < vim.api.nvim_buf_line_count(current_buffer) - 1 do
    end_row = end_row + 1
    local next_line = vim.api.nvim_buf_get_lines(current_buffer, end_row, end_row + 1, false)[1]
    if next_line == '' then break end
    right_text = right_text .. '\n' .. next_line
    bullet_end = right_text:find '\n'
  end
  if bullet_end then bullet_end = col + bullet_end end
  -- Extract lines
  local text_lines = vim.api.nvim_buf_get_lines(current_buffer, start_row, end_row + 1, false)
  local text = table.concat(text_lines, '\n')
  -- Add bullet point at the start of the text
  local new_text = '- ' .. text
  local new_lines = vim.split(new_text, '\n')
  -- Set new lines in buffer
  vim.api.nvim_buf_set_lines(current_buffer, start_row, end_row + 1, false, new_lines)
end, { desc = '[P]Toggle bullet point (dash)' })

-- HACK: Manage Markdown tasks in Neovim similar to Obsidian | Telescope to List Completed and Pending Tasks
-- https://youtu.be/59hvZl077hM
--
-- If there is no `untoggled` or `done` label on an item, mark it as done
-- and move it to the "## completed tasks" markdown heading in the same file, if
-- the heading does not exist, it will be created, if it exists, items will be
-- appended to it at the top lamw25wmal
--
-- If an item is moved to that heading, it will be added the `done` label
vim.keymap.set('n', '<M-x>', function()
  -- Customizable variables
  -- NOTE: Customize the completion label
  local label_done = 'done:'
  -- NOTE: Customize the timestamp format
  local timestamp = os.date '%y%m%d-%H%M'
  -- local timestamp = os.date("%y%m%d")
  -- NOTE: Customize the heading and its level
  local tasks_heading = '## Completed Tasks'
  -- Save the view to preserve folds
  vim.cmd 'mkview'
  local api = vim.api
  -- Retrieve buffer & lines
  local buf = api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local start_line = cursor_pos[1] - 1
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local total_lines = #lines
  -- If cursor is beyond last line, do nothing
  if start_line >= total_lines then
    vim.cmd 'loadview'
    return
  end
  ------------------------------------------------------------------------------
  -- (A) Move upwards to find the bullet line (if user is somewhere in the chunk)
  ------------------------------------------------------------------------------
  while start_line > 0 do
    local line_text = lines[start_line + 1]
    -- Stop if we find a blank line or a bullet line
    if line_text == '' or line_text:match '^%s*%-' then break end
    start_line = start_line - 1
  end
  -- Now we might be on a blank line or a bullet line
  if lines[start_line + 1] == '' and start_line < (total_lines - 1) then start_line = start_line + 1 end
  ------------------------------------------------------------------------------
  -- (B) Validate that it's actually a task bullet, i.e. '- [ ]' or '- [x]'
  ------------------------------------------------------------------------------
  local bullet_line = lines[start_line + 1]
  if not bullet_line:match '^%s*%- %[[x ]%]' then
    -- Not a task bullet => show a message and return
    print 'Not a task bullet: no action taken.'
    vim.cmd 'loadview'
    return
  end
  ------------------------------------------------------------------------------
  -- 1. Identify the chunk boundaries
  ------------------------------------------------------------------------------
  local chunk_start = start_line
  local chunk_end = start_line
  while chunk_end + 1 < total_lines do
    local next_line = lines[chunk_end + 2]
    if next_line == '' or next_line:match '^%s*%-' then break end
    chunk_end = chunk_end + 1
  end
  -- Collect the chunk lines
  local chunk = {}
  for i = chunk_start, chunk_end do
    table.insert(chunk, lines[i + 1])
  end
  ------------------------------------------------------------------------------
  -- 2. Check if chunk has [done: ...] or [untoggled], then transform them
  ------------------------------------------------------------------------------
  local has_done_index = nil
  local has_untoggled_index = nil
  for i, line in ipairs(chunk) do
    -- Replace `[done: ...]` -> `` `done: ...` ``
    chunk[i] = line:gsub('%[done:([^%]]+)%]', '`' .. label_done .. '%1`')
    -- Replace `[untoggled]` -> `` `untoggled` ``
    chunk[i] = chunk[i]:gsub('%[untoggled%]', '`untoggled`')
    if chunk[i]:match('`' .. label_done .. '.-`') then
      has_done_index = i
      break
    end
  end
  if not has_done_index then
    for i, line in ipairs(chunk) do
      if line:match '`untoggled`' then
        has_untoggled_index = i
        break
      end
    end
  end
  ------------------------------------------------------------------------------
  -- 3. Helpers to toggle bullet
  ------------------------------------------------------------------------------
  -- Convert '- [ ]' to '- [x]'
  local function bulletToX(line) return line:gsub('^(%s*%- )%[%s*%]', '%1[x]') end
  -- Convert '- [x]' to '- [ ]'
  local function bulletToBlank(line) return line:gsub('^(%s*%- )%[x%]', '%1[ ]') end
  ------------------------------------------------------------------------------
  -- 4. Insert or remove label *after* the bracket
  ------------------------------------------------------------------------------
  local function insertLabelAfterBracket(line, label)
    local prefix = line:match '^(%s*%- %[[x ]%])'
    if not prefix then return line end
    local rest = line:sub(#prefix + 1)
    return prefix .. ' ' .. label .. rest
  end
  local function removeLabel(line)
    -- If there's a label (like `` `done: ...` `` or `` `untoggled` ``) right after
    -- '- [x]' or '- [ ]', remove it
    return line:gsub('^(%s*%- %[[x ]%])%s+`.-`', '%1')
  end
  ------------------------------------------------------------------------------
  -- 5. Update the buffer with new chunk lines (in place)
  ------------------------------------------------------------------------------
  local function updateBufferWithChunk(new_chunk)
    for idx = chunk_start, chunk_end do
      lines[idx + 1] = new_chunk[idx - chunk_start + 1]
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end
  ------------------------------------------------------------------------------
  -- 6. Main toggle logic
  ------------------------------------------------------------------------------
  if has_done_index then
    chunk[has_done_index] = removeLabel(chunk[has_done_index]):gsub('`' .. label_done .. '.-`', '`untoggled`')
    chunk[1] = bulletToBlank(chunk[1])
    chunk[1] = removeLabel(chunk[1])
    chunk[1] = insertLabelAfterBracket(chunk[1], '`untoggled`')
    updateBufferWithChunk(chunk)
    vim.notify('Untoggled', vim.log.levels.INFO)
  elseif has_untoggled_index then
    chunk[has_untoggled_index] = removeLabel(chunk[has_untoggled_index]):gsub('`untoggled`', '`' .. label_done .. ' ' .. timestamp .. '`')
    chunk[1] = bulletToX(chunk[1])
    chunk[1] = removeLabel(chunk[1])
    chunk[1] = insertLabelAfterBracket(chunk[1], '`' .. label_done .. ' ' .. timestamp .. '`')
    updateBufferWithChunk(chunk)
    vim.notify('Completed', vim.log.levels.INFO)
  else
    -- Save original window view before modifications
    local win = api.nvim_get_current_win()
    local view = api.nvim_win_call(win, function() return vim.fn.winsaveview() end)
    chunk[1] = bulletToX(chunk[1])
    chunk[1] = insertLabelAfterBracket(chunk[1], '`' .. label_done .. ' ' .. timestamp .. '`')
    -- Remove chunk from the original lines
    for i = chunk_end, chunk_start, -1 do
      table.remove(lines, i + 1)
    end
    -- Append chunk under 'tasks_heading'
    local heading_index = nil
    for i, line in ipairs(lines) do
      if line:match('^' .. tasks_heading) then
        heading_index = i
        break
      end
    end
    if heading_index then
      for _, cLine in ipairs(chunk) do
        table.insert(lines, heading_index + 1, cLine)
        heading_index = heading_index + 1
      end
      -- Remove any blank line right after newly inserted chunk
      local after_last_item = heading_index + 1
      if lines[after_last_item] == '' then table.remove(lines, after_last_item) end
    else
      table.insert(lines, tasks_heading)
      for _, cLine in ipairs(chunk) do
        table.insert(lines, cLine)
      end
      local after_last_item = #lines + 1
      if lines[after_last_item] == '' then table.remove(lines, after_last_item) end
    end
    -- Update buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.notify('Completed', vim.log.levels.INFO)
    -- Restore window view to preserve scroll position
    api.nvim_win_call(win, function() vim.fn.winrestview(view) end)
  end
  -- Write changes and restore view to preserve folds
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd 'silent update'
  vim.cmd 'loadview'
end, { desc = "[P]Toggle task and move it to 'done'" })

-- -- Toggle bullet point at the beginning of the current line in normal mode
-- vim.keymap.set("n", "<leader>ml", function()
--   -- Notify that the function is being executed
--   vim.notify("Executing bullet point toggle function", vim.log.levels.INFO)
--   -- Get the current cursor position
--   local cursor_pos = vim.api.nvim_win_get_cursor(0)
--   vim.notify("Cursor position: row " .. cursor_pos[1] .. ", col " .. cursor_pos[2], vim.log.levels.INFO)
--   local current_buffer = vim.api.nvim_get_current_buf()
--   local row = cursor_pos[1] - 1
--   -- Get the current line
--   local line = vim.api.nvim_buf_get_lines(current_buffer, row, row + 1, false)[1]
--   vim.notify("Current line: " .. line, vim.log.levels.INFO)
--   if line:match("^%s*%-") then
--     -- If the line already starts with a bullet point, remove it
--     vim.notify("Bullet point detected, removing it", vim.log.levels.INFO)
--     line = line:gsub("^%s*%-", "", 1)
--     vim.api.nvim_buf_set_lines(current_buffer, row, row + 1, false, { line })
--   else
--     -- Otherwise, delete the line, add a bullet point, and paste the text
--     vim.notify("No bullet point detected, adding it", vim.log.levels.INFO)
--     line = "- " .. line
--     vim.api.nvim_buf_set_lines(current_buffer, row, row + 1, false, { line })
--   end
-- end, { desc = "Toggle bullet point at the beginning of the current line" })

-- HACK: neovim spell multiple languages
-- https://youtu.be/uLFAMYFmpkE
--
-- Keymap to switch spelling language to English lamw25wmal
-- To save the language settings configured on each buffer, you need to add
-- "localoptions" to vim.opt.sessionoptions in the `lua/config/options.lua` file
vim.keymap.set('n', '<leader>msle', function()
  vim.opt.spelllang = 'en'
  vim.cmd "echo 'Spell language set to English'"
end, { desc = '[P]Spelling language English' })

-- HACK: neovim spell multiple languages
-- https://youtu.be/uLFAMYFmpkE
--
-- Keymap to switch spelling language to German lamw25wmal
vim.keymap.set('n', '<leader>msls', function()
  vim.opt.spelllang = 'es'
  vim.cmd "echo 'Spell language set to German'"
end, { desc = '[P]Spelling language German' })

-- HACK: neovim spell multiple languages
-- https://youtu.be/uLFAMYFmpkE
--
-- Keymap to switch spelling language to both german and english lamw25wmal
vim.keymap.set('n', '<leader>mslb', function()
  vim.opt.spelllang = 'en,es'
  vim.cmd "echo 'Spell language set to German and English'"
end, { desc = '[P]Spelling language German and English' })

-- HACK: neovim spell multiple languages
-- https://youtu.be/uLFAMYFmpkE
--
-- Show spelling suggestions / spell suggestions
-- NOTE: I changed this to accept the first spelling suggestion
vim.keymap.set('n', '<leader>mss', function()
  -- Simulate pressing "z=" with "m" option using feedkeys
  -- vim.api.nvim_replace_termcodes ensures "z=" is correctly interpreted
  -- 'm' is the {mode}, which in this case is 'Remap keys'. This is default.
  -- If {mode} is absent, keys are remapped.
  --
  -- I tried this keymap as usually with
  vim.cmd 'normal! 1z='
  -- But didn't work, only with nvim_feedkeys
  -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("z=", true, false, true), "m", true)
end, { desc = '[P]Spelling suggestions' })

-- HACK: neovim spell multiple languages
-- https://youtu.be/uLFAMYFmpkE
--
-- markdown good, accept spell suggestion
-- Add word under the cursor as a good word
vim.keymap.set('n', '<leader>msg', function()
  vim.cmd 'normal! zg'
  -- I do a write so that harper is updated
  vim.cmd 'silent write'
end, { desc = '[P]Spelling add word to spellfile' })

-- HACK: neovim spell multiple languages
-- https://youtu.be/uLFAMYFmpkE
--
-- Undo zw, remove the word from the entry in 'spellfile'.
vim.keymap.set('n', '<leader>msu', function() vim.cmd 'normal! zug' end, { desc = '[P]Spelling undo, remove word from list' })

-- HACK: neovim spell multiple languages
-- https://youtu.be/uLFAMYFmpkE
--
-- Repeat the replacement done by |z=| for all matches with the replaced word
-- in the current window.
vim.keymap.set('n', '<leader>msr', function()
  -- vim.cmd(":spellr")
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(':spellr\n', true, false, true), 'm', true)
end, { desc = '[P]Spelling repeat' })

-- Surround the http:// url that the cursor is currently in with ``
vim.keymap.set('n', 'gsu', function()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- Adjust for 0-index in Lua
  -- This makes the `s` optional so it matches both http and https
  local pattern = 'https?://[^ ,;\'"<>%s)]*'
  -- Find the starting and ending positions of the URL
  local s, e = string.find(line, pattern)
  while s and e do
    if s <= col and e >= col then
      -- When the cursor is within the URL
      local url = string.sub(line, s, e)
      -- Update the line with backticks around the URL
      local new_line = string.sub(line, 1, s - 1) .. '`' .. url .. '`' .. string.sub(line, e + 1)
      vim.api.nvim_set_current_line(new_line)
      vim.cmd 'silent write'
      return
    end
    -- Find the next URL in the line
    s, e = string.find(line, pattern, e + 1)
    -- Save the file to update trouble list
  end
  print 'No URL found under cursor'
end, { desc = '[P]Add surrounding to URL' })

-- Remap 'gss' to 'gsa`' in visual mode
-- This surrounds with inline code, that I use a lot lamw25wmal
vim.keymap.set('v', 'gss', function()
  -- Use nvim_replace_termcodes to handle special characters like backticks
  local keys = vim.api.nvim_replace_termcodes('gsa`', true, false, true)
  -- Feed the keys in visual mode ('x' for visual mode)
  vim.api.nvim_feedkeys(keys, 'x', false)
  -- I tried these 3, but they didn't work, I assume because of the backtick character
  -- vim.cmd("normal! gsa`")
  -- vim.cmd([[normal! gsa`]])
  -- vim.cmd("normal! gsa\\`")
end, { desc = '[P] Surround selection with backticks (inline code)' })

-- This surrounds CURRENT WORD with inline code in NORMAL MODE lamw25wmal
vim.keymap.set('n', 'gss', function()
  -- Use nvim_replace_termcodes to handle special characters like backticks
  local keys = vim.api.nvim_replace_termcodes('gsaiw`', true, false, true)
  -- Feed the keys in visual mode ('x' for visual mode)
  vim.api.nvim_feedkeys(keys, 'x', false)
  -- I tried these 3, but they didn't work, I assume because of the backtick character
  -- vim.cmd("normal! gsa`")
  -- vim.cmd([[normal! gsa`]])
  -- vim.cmd("normal! gsa\\`")
end, { desc = '[P] Surround selection with backticks (inline code)' })

-- In visual mode, check if the selected text is already striked through and show a message if it is
-- If not, surround it
vim.keymap.set('v', '<leader>mx', function()
  -- Get the selected text range
  local start_row, start_col = unpack(vim.fn.getpos "'<", 2, 3)
  local end_row, end_col = unpack(vim.fn.getpos "'>", 2, 3)
  -- Get the selected lines
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  local selected_text = table.concat(lines, '\n'):sub(start_col, #lines == 1 and end_col or -1)
  if selected_text:match '^%~%~.*%~%~$' then
    vim.notify('Text already has strikethrough', vim.log.levels.INFO)
  else
    vim.cmd 'normal 2gsa~'
  end
end, { desc = '[P]Strike through current selection' })

-- In visual mode, check if the selected text is already bold and show a message if it is
-- If not, surround it with double asterisks for bold
vim.keymap.set('v', '<leader>mb', function()
  -- Get the selected text range
  local start_row, start_col = unpack(vim.fn.getpos "'<", 2, 3)
  local end_row, end_col = unpack(vim.fn.getpos "'>", 2, 3)
  -- Get the selected lines
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  local selected_text = table.concat(lines, '\n'):sub(start_col, #lines == 1 and end_col or -1)
  if selected_text:match '^%*%*.*%*%*$' then
    vim.notify('Text already bold', vim.log.levels.INFO)
  else
    vim.cmd 'normal 2gsa*'
  end
end, { desc = '[P]BOLD current selection' })

-- -- Multiline unbold attempt
-- -- In normal mode, bold the current word under the cursor
-- -- If already bold, it will unbold the word under the cursor
-- -- If you're in a multiline bold, it will unbold it only if you're on the
-- -- first line
vim.keymap.set('n', '<leader>mb', function()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_buffer = vim.api.nvim_get_current_buf()
  local start_row = cursor_pos[1] - 1
  local col = cursor_pos[2]
  -- Get the current line
  local line = vim.api.nvim_buf_get_lines(current_buffer, start_row, start_row + 1, false)[1]
  -- Check if the cursor is on an asterisk
  if line:sub(col + 1, col + 1):match '%*' then
    vim.notify('Cursor is on an asterisk, run inside the bold text', vim.log.levels.WARN)
    return
  end
  -- Search for '**' to the left of the cursor position
  local left_text = line:sub(1, col)
  local bold_start = left_text:reverse():find '%*%*'
  if bold_start then bold_start = col - bold_start end
  -- Search for '**' to the right of the cursor position and in following lines
  local right_text = line:sub(col + 1)
  local bold_end = right_text:find '%*%*'
  local end_row = start_row
  while not bold_end and end_row < vim.api.nvim_buf_line_count(current_buffer) - 1 do
    end_row = end_row + 1
    local next_line = vim.api.nvim_buf_get_lines(current_buffer, end_row, end_row + 1, false)[1]
    if next_line == '' then break end
    right_text = right_text .. '\n' .. next_line
    bold_end = right_text:find '%*%*'
  end
  if bold_end then bold_end = col + bold_end end
  -- Remove '**' markers if found, otherwise bold the word
  if bold_start and bold_end then
    -- Extract lines
    local text_lines = vim.api.nvim_buf_get_lines(current_buffer, start_row, end_row + 1, false)
    local text = table.concat(text_lines, '\n')
    -- Calculate positions to correctly remove '**'
    -- vim.notify("bold_start: " .. bold_start .. ", bold_end: " .. bold_end)
    local new_text = text:sub(1, bold_start - 1) .. text:sub(bold_start + 2, bold_end - 1) .. text:sub(bold_end + 2)
    local new_lines = vim.split(new_text, '\n')
    -- Set new lines in buffer
    vim.api.nvim_buf_set_lines(current_buffer, start_row, end_row + 1, false, new_lines)
    -- vim.notify("Unbolded text", vim.log.levels.INFO)
  else
    -- Bold the word at the cursor position if no bold markers are found
    local before = line:sub(1, col)
    local after = line:sub(col + 1)
    local inside_surround = before:match '%*%*[^%*]*$' and after:match '^[^%*]*%*%*'
    if inside_surround then
      vim.cmd 'normal gsd*.'
    else
      vim.cmd 'normal viw'
      vim.cmd 'normal 2gsa*'
    end
    vim.notify('Bolded current word', vim.log.levels.INFO)
  end
end, { desc = '[P]BOLD toggle bold markers' })

-- -- Crate task or checkbox lamw25wmal
-- -- These are marked with <leader>x using bullets.vim
-- vim.keymap.set("n", "<leader>ml", function()
--   vim.cmd("normal! i- [ ]  ")
--   vim.cmd("startinsert")
-- end, { desc = "[P]Toggle checkbox" })

-- HACK: Manage Markdown tasks in Neovim similar to Obsidian | Telescope to List Completed and Pending Tasks
-- https://youtu.be/59hvZl077hM
--
-- Crate task or checkbox lamw26wmal
-- These are marked with <leader>x using bullets.vim
-- I used <C-l> before, but that is used for pane navigation
vim.keymap.set({ 'n', 'i' }, '<M-l>', function()
  -- Get the current line/row/column
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row, _ = cursor_pos[1], cursor_pos[2]
  local line = vim.api.nvim_get_current_line()
  -- 1) If line is empty => replace it with "- [ ] " and set cursor after the brackets
  if line:match '^%s*$' then
    local final_line = '- [ ] '
    vim.api.nvim_set_current_line(final_line)
    -- "- [ ] " is 6 characters, so cursor col = 6 places you *after* that space
    vim.api.nvim_win_set_cursor(0, { row, 6 })
    return
  end
  -- 2) Check if line already has a bullet with possible indentation: e.g. "  - Something"
  --    We'll capture "  -" (including trailing spaces) as `bullet` plus the rest as `text`.
  local bullet, text = line:match '^([%s]*[-*]%s+)(.*)$'
  if bullet then
    -- Convert bullet => bullet .. "[ ] " .. text
    local final_line = bullet .. '[ ] ' .. text
    vim.api.nvim_set_current_line(final_line)
    -- Place the cursor right after "[ ] "
    -- bullet length + "[ ] " is bullet_len + 4 characters,
    -- but bullet has trailing spaces, so #bullet includes those.
    local bullet_len = #bullet
    -- We want to land after the brackets (four characters: `[ ] `),
    -- so col = bullet_len + 4 (0-based).
    vim.api.nvim_win_set_cursor(0, { row, bullet_len + 4 })
    return
  end
  -- 3) If there's text, but no bullet => prepend "- [ ] "
  --    and place cursor after the brackets
  local final_line = '- [ ] ' .. line
  vim.api.nvim_set_current_line(final_line)
  -- "- [ ] " is 6 characters
  vim.api.nvim_win_set_cursor(0, { row, 6 })
end, { desc = 'Convert bullet to a task or insert new task bullet' })

local function get_markdown_headings()
  local cursor_line = vim.fn.line '.'
  local parser = vim.treesitter.get_parser(0, 'markdown')
  if not parser then
    vim.notify('Markdown parser not available', vim.log.levels.ERROR)
    return nil, nil, nil, nil, nil, nil
  end
  local tree = parser:parse()[1]
  local query = vim.treesitter.query.parse(
    'markdown',
    [[
    (atx_heading (atx_h1_marker) @h1)
    (atx_heading (atx_h2_marker) @h2)
    (atx_heading (atx_h3_marker) @h3)
    (atx_heading (atx_h4_marker) @h4)
    (atx_heading (atx_h5_marker) @h5)
    (atx_heading (atx_h6_marker) @h6)
  ]]
  )
  -- Collect and sort all headings
  local headings = {}
  for id, node in query:iter_captures(tree:root(), 0) do
    local start_line = node:start() + 1 -- Convert to 1-based
    table.insert(headings, { line = start_line, level = id })
  end
  table.sort(headings, function(a, b) return a.line < b.line end)
  -- Find current heading and track its index
  local current_heading, current_idx, next_heading, next_same_heading
  for idx, h in ipairs(headings) do
    if h.line <= cursor_line then
      current_heading = h
      current_idx = idx
    elseif not next_heading then
      next_heading = h -- First heading after cursor
    end
  end
  -- Find next same-level heading if current exists
  if current_heading then
    -- Look for next same-level after current index
    for i = current_idx + 1, #headings do
      local h = headings[i]
      if h.level == current_heading.level then
        next_same_heading = h
        break
      end
    end
  end
  -- Return all values (nil if not found)
  return current_heading and current_heading.line or nil,
    current_heading and current_heading.level or nil,
    next_heading and next_heading.line or nil,
    next_heading and next_heading.level or nil,
    next_same_heading and next_same_heading.line or nil,
    next_same_heading and next_same_heading.level or nil
end

-- Print details of current markdown heading, next heading and next same level heading
vim.keymap.set('n', '<leader>mT', function()
  local cl, clvl, nl, nlvl, nsl, nslvl = get_markdown_headings()
  local message_parts = {}
  if cl then
    table.insert(message_parts, string.format('Current: H%d (line %d)', clvl, cl))
  else
    table.insert(message_parts, 'Not in a section')
  end
  if nl then table.insert(message_parts, string.format('Next: H%d (line %d)', nlvl, nl)) end
  if nsl then table.insert(message_parts, string.format('Next H%d: line %d', nslvl, nsl)) end
  vim.notify(table.concat(message_parts, ' | '), vim.log.levels.INFO)
end, { desc = 'Show current, next, and same-level Markdown headings' })

-- -- Create next heading similar to the way its done in emacs lamw26wmal
-- -- When inside tmux
-- -- C-CR does not work because Neovim recognizes both CR and C-CR as the same "\r",
-- -- you can see this with:
-- -- :lua print(vim.inspect(vim.fn.getcharstr()))
-- --
-- -- If I run this outside tmux, for C-CR, in Ghostty I get
-- -- "<80><fc>\4\r"
-- -- So to fix this, I'm sending the keys in my tmux.conf file
vim.keymap.set({ 'n', 'i' }, '<C-CR>', function()
  -- Capture all needed return values
  local _, level, next_line, next_level, next_same_line = get_markdown_headings()
  if not level then
    vim.notify('No heading context found', vim.log.levels.WARN)
    return
  end
  local heading_prefix = string.rep('#', level) .. ' '
  local insert_line = next_same_line and next_same_line or vim.fn.line '$' + 1
  -- If there’s a higher-level heading coming next, insert above it
  if next_line and next_level and (next_level < level) then insert_line = next_line end
  -- Insert heading line and an empty line after it
  vim.api.nvim_buf_set_lines(0, insert_line - 1, insert_line - 1, false, { heading_prefix, '' })
  -- Move cursor to the end of heading marker
  vim.api.nvim_win_set_cursor(0, { insert_line, #heading_prefix })
  -- Enter insert mode and type a space
  vim.api.nvim_feedkeys('i ', 'n', false)
end, { desc = '[P]Insert heading emacs style' })

-- -- When inside tmux
-- -- C-CR does not work because Neovim recognizes both CR and C-CR as the same "\r",
-- -- you can see this with:
-- -- :lua print(vim.inspect(vim.fn.getcharstr()))
-- --
-- -- If I run this outside tmux, for C-CR, in Ghostty I get
-- -- "<80><fc>\4\r"
-- -- So to fix this, I'm sending the keys in my tmux.conf file
-- vim.keymap.set({ "n", "i" }, "<C-CR>", function()
--   vim.notify("Ctrl+Enter detected", vim.log.levels.INFO)
-- end, { desc = "Ctrl+Enter CSIu mapping" })

-- Detect todos and toggle between ":" and ";", or show a message if not found
-- This is to "mark them as done"
vim.keymap.set('n', '<leader>td', function()
  -- Get the current line
  local current_line = vim.fn.getline '.'
  -- Get the current line number
  local line_number = vim.fn.line '.'
  if string.find(current_line, 'TODO:') then
    -- Replace the first occurrence of ":" with ";"
    local new_line = current_line:gsub('TODO:', 'TODO;')
    -- Set the modified line
    vim.fn.setline(line_number, new_line)
  elseif string.find(current_line, 'TODO;') then
    -- Replace the first occurrence of ";" with ":"
    local new_line = current_line:gsub('TODO;', 'TODO:')
    -- Set the modified line
    vim.fn.setline(line_number, new_line)
  else
    vim.cmd "echo 'todo item not detected'"
  end
end, { desc = '[P]TODO toggle item done or not' })

-- HACK: Create table of contents in neovim with markdown-toc
-- https://youtu.be/BVyrXsZ_ViA
--
-- Generate/update a Markdown TOC
-- To generate the TOC I use the markdown-toc plugin
-- https://github.com/jonschlinkert/markdown-toc
-- And the markdown-toc plugin installed as a LazyExtra
-- Function to update the Markdown TOC with customizable headings
local function update_markdown_toc(heading2, heading3)
  local path = vim.fn.expand '%' -- Expands the current file name to a full path
  local bufnr = 0 -- The current buffer number, 0 references the current active buffer
  -- Save the current view
  -- If I don't do this, my folds are lost when I run this keymap
  vim.cmd 'mkview'
  -- Retrieves all lines from the current buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local toc_exists = false -- Flag to check if TOC marker exists
  local frontmatter_end = 0 -- To store the end line number of frontmatter
  -- Check for frontmatter and TOC marker
  for i, line in ipairs(lines) do
    if i == 1 and line:match '^---$' then
      -- Frontmatter start detected, now find the end
      for j = i + 1, #lines do
        if lines[j]:match '^---$' then
          frontmatter_end = j
          break
        end
      end
    end
    -- Checks for the TOC marker
    if line:match '^%s*<!%-%-%s*toc%s*%-%->%s*$' then
      toc_exists = true
      break
    end
  end
  -- Inserts H2 and H3 headings and <!-- toc --> at the appropriate position
  if not toc_exists then
    local insertion_line = 1 -- Default insertion point after first line
    if frontmatter_end > 0 then
      -- Find H1 after frontmatter
      for i = frontmatter_end + 1, #lines do
        if lines[i]:match '^#%s+' then
          insertion_line = i + 1
          break
        end
      end
    else
      -- Find H1 from the beginning
      for i, line in ipairs(lines) do
        if line:match '^#%s+' then
          insertion_line = i + 1
          break
        end
      end
    end
    -- Insert the specified headings and <!-- toc --> without blank lines
    -- Insert the TOC inside a H2 and H3 heading right below the main H1 at the top lamw25wmal
    vim.api.nvim_buf_set_lines(bufnr, insertion_line, insertion_line, false, { heading2, heading3, '<!-- toc -->' })
  end
  -- Silently save the file, in case TOC is being created for the first time
  vim.cmd 'silent write'
  -- Silently run markdown-toc to update the TOC without displaying command output
  -- vim.fn.system("markdown-toc -i " .. path)
  -- I want my bulletpoints to be created only as "-" so passing that option as
  -- an argument according to the docs
  -- https://github.com/jonschlinkert/markdown-toc?tab=readme-ov-file#optionsbullets
  vim.fn.system('markdown-toc --bullets "-" -i ' .. path)
  vim.cmd 'edit!' -- Reloads the file to reflect the changes made by markdown-toc
  vim.cmd 'silent write' -- Silently save the file
  vim.notify('TOC updated and file saved', vim.log.levels.INFO)
  -- -- In case a cleanup is needed, leaving this old code here as a reference
  -- -- I used this code before I implemented the frontmatter check
  -- -- Moves the cursor to the top of the file
  -- vim.api.nvim_win_set_cursor(bufnr, { 1, 0 })
  -- -- Deletes leading blank lines from the top of the file
  -- while true do
  --   -- Retrieves the first line of the buffer
  --   local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
  --   -- Checks if the line is empty
  --   if line == "" then
  --     -- Deletes the line if it's empty
  --     vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {})
  --   else
  --     -- Breaks the loop if the line is not empty, indicating content or TOC marker
  --     break
  --   end
  -- end
  -- Restore the saved view (including folds)
  vim.cmd 'loadview'
end

-- HACK: Create table of contents in neovim with markdown-toc
-- https://youtu.be/BVyrXsZ_ViA
--
-- Keymap for English TOC
vim.keymap.set(
  'n',
  '<leader>mtt',
  function() update_markdown_toc('## Contents', '### Table of contents') end,
  { desc = '[P]Insert/update Markdown TOC (English)' }
)

-- HACK: Create table of contents in neovim with markdown-toc
-- https://youtu.be/BVyrXsZ_ViA
--
-- Keymap for German TOC lamw25wmal
vim.keymap.set(
  'n',
  '<leader>mts',
  function() update_markdown_toc('## Contenido', '### Tabla de contenido') end,
  { desc = '[P]Insert/update Markdown TOC (German)' }
)

-- Save the cursor position globally to access it across different mappings
_G.saved_positions = {}

-- Mapping to jump to the first line of the TOC
vim.keymap.set('n', '<leader>mm', function()
  -- Save the current cursor position
  _G.saved_positions['toc_return'] = vim.api.nvim_win_get_cursor(0)
  -- Perform a silent search for the <!-- toc --> marker and move the cursor two lines below it
  vim.cmd 'silent! /<!-- toc -->\\n\\n\\zs.*'
  -- Clear the search highlight without showing the "search hit BOTTOM, continuing at TOP" message
  vim.cmd 'nohlsearch'
  -- Retrieve the current cursor position (after moving to the TOC)
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  -- local col = cursor_pos[2]
  -- Move the cursor to column 15 (starts counting at 0)
  -- I like just going down on the TOC and press gd to go to a section
  vim.api.nvim_win_set_cursor(0, { row, 14 })
end, { desc = '[P]Jump to the first line of the TOC' })

-- Mapping to return to the previously saved cursor position
vim.keymap.set('n', '<leader>mn', function()
  local pos = _G.saved_positions['toc_return']
  if pos then vim.api.nvim_win_set_cursor(0, pos) end
end, { desc = '[P]Return to position before jumping' })

-- HACK: Manage Markdown tasks in Neovim similar to Obsidian | Telescope to List Completed and Pending Tasks
-- NOTE: This has been moved to the snacks plugin config
-- https://youtu.be/59hvZl077hM
--
-- -- Iterate through incomplete tasks in telescope
-- -- You can confirm in your teminal lamw25wmal with:
-- -- rg "^\s*-\s\[ \]" test-markdown.md
-- vim.keymap.set("n", "<leader>tt", function()
--   require("telescope.builtin").grep_string(require("telescope.themes").get_ivy({
--     prompt_title = "Incomplete Tasks",
--     -- search = "- \\[ \\]", -- Fixed search term for tasks
--     -- search = "^- \\[ \\]", -- Ensure "- [ ]" is at the beginning of the line
--     search = "^\\s*- \\[ \\]", -- also match blank spaces at the beginning
--     search_dirs = { vim.fn.getcwd() }, -- Restrict search to the current working directory
--     use_regex = true, -- Enable regex for the search term
--     initial_mode = "normal", -- Start in normal mode
--     layout_config = {
--       preview_width = 0.5, -- Adjust preview width
--     },
--     additional_args = function()
--       return { "--no-ignore" } -- Include files ignored by .gitignore
--     end,
--   }))
-- end, { desc = "[P]Search for incomplete tasks" })

-- HACK: Manage Markdown tasks in Neovim similar to Obsidian | Telescope to List Completed and Pending Tasks
-- NOTE: This has been moved to the snacks plugin config
-- https://youtu.be/59hvZl077hM
--
-- -- Iterate throuth completed tasks in telescope lamw25wmal
-- vim.keymap.set("n", "<leader>tc", function()
--   require("telescope.builtin").grep_string(require("telescope.themes").get_ivy({
--     prompt_title = "Completed Tasks",
--     -- search = [[- \[x\] `done:]], -- Regex to match the text "`- [x] `done:"
--     -- search = "^- \\[x\\] `done:", -- Matches lines starting with "- [x] `done:"
--     search = "^\\s*- \\[x\\] `done:", -- also match blank spaces at the beginning
--     search_dirs = { vim.fn.getcwd() }, -- Restrict search to the current working directory
--     use_regex = true, -- Enable regex for the search term
--     initial_mode = "normal", -- Start in normal mode
--     layout_config = {
--       preview_width = 0.5, -- Adjust preview width
--     },
--     additional_args = function()
--       return { "--no-ignore" } -- Include files ignored by .gitignore
--     end,
--   }))
-- end, { desc = "[P]Search for completed tasks" })
