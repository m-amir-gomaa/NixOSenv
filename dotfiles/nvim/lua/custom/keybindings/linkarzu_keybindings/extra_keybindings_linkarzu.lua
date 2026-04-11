-------------------------------------------------------------------------------
--                       Assets directory
-------------------------------------------------------------------------------

-- NOTE: Configuration for image storage path
-- Change this to customize where images are stored relative to the assets directory
-- If below you use "img/imgs", it will store in "assets/img/imgs"
-- Added option to choose image format and resolution lamw26wmal
local IMAGE_STORAGE_PATH = 'img/imgs'

-- This function is used in 2 places in the paste images in assets dir section
-- finds the assets/img/imgs directory going one dir at a time and returns the full path
local function find_assets_dir()
  local dir = vim.fn.expand '%:p:h'
  while dir ~= '/' do
    local full_path = dir .. '/assets/' .. IMAGE_STORAGE_PATH
    if vim.fn.isdirectory(full_path) == 1 then return full_path end
    dir = vim.fn.fnamemodify(dir, ':h')
  end
  return nil
end

-- Since I need to store these images in a different directory, I pass the options to img-clip
local function handle_image_paste(img_dir)
  local function paste_image(dir_path, file_name, ext, cmd)
    return require('img-clip').paste_image {
      dir_path = dir_path,
      use_absolute_path = false,
      relative_to_current_file = false,
      file_name = file_name,
      extension = ext or 'avif',
      process_cmd = cmd or 'convert - -quality 75 avif:-',
    }
  end
  local temp_buf = vim.api.nvim_create_buf(false, true) -- Create an unlisted, scratch buffer
  vim.api.nvim_set_current_buf(temp_buf) -- Switch to the temporary buffer
  local temp_image_path = vim.fn.tempname() .. '.avif'
  local image_pasted = paste_image(vim.fn.fnamemodify(temp_image_path, ':h'), vim.fn.fnamemodify(temp_image_path, ':t:r'))
  vim.api.nvim_buf_delete(temp_buf, { force = true }) -- Delete the buffer
  vim.fn.delete(temp_image_path) -- Delete the temporary file
  vim.defer_fn(function()
    local options = image_pasted and { 'no', 'yes', 'format', 'search' } or { 'search' }
    local prompt = image_pasted and 'Is this a thumbnail image? ' or 'No image in clipboard. Select search to continue.'
    -- -- I was getting a character in the textbox, don't want to debug right now
    -- vim.cmd("stopinsert")
    vim.ui.select(options, { prompt = prompt }, function(is_thumbnail)
      if is_thumbnail == 'search' then
        local assets_dir = find_assets_dir()
        -- Get the parent directory of the current file
        local current_dir = vim.fn.expand '%:p:h'
        -- remove warning: Cannot assign `string|nil` to parameter `string`
        if not assets_dir then
          print 'Assets directory not found, cannot proceed with search.'
          return
        end
        -- Get the parent directory of assets_dir (removing /img/imgs)
        local base_assets_dir = vim.fn.fnamemodify(assets_dir, ':h:h:h')
        -- Count how many levels we need to go up
        local levels = 0
        local temp_dir = current_dir
        while temp_dir ~= base_assets_dir and temp_dir ~= '/' do
          levels = levels + 1
          temp_dir = vim.fn.fnamemodify(temp_dir, ':h')
        end
        -- Build the relative path
        local relative_path = levels == 0 and './assets/' .. IMAGE_STORAGE_PATH or string.rep('../', levels) .. 'assets/' .. IMAGE_STORAGE_PATH
        vim.api.nvim_put({ '![Image](' .. relative_path .. '){: width="500" }' }, 'c', true, true)
        -- Capital "O" to move to the line above
        vim.cmd 'normal! O'
        -- This "o" is to leave a blank line above
        vim.cmd 'normal! o'
        vim.api.nvim_put({ '<!-- prettier-ignore -->' }, 'c', true, true)
        vim.cmd 'normal! jo'
        vim.api.nvim_put({ '_textimage_', '' }, 'c', true, true)
        -- find image path and add a / at the end of it
        vim.cmd 'normal! kkf)i/'
        -- Move one to the right and enter insert mode
        vim.cmd 'normal! la'
        -- -- This puts me in insert mode where the cursor is
        -- vim.api.nvim_feedkeys("i", "n", true)
        require('auto-save').on()
        return
      end
      if not is_thumbnail then
        print 'Image pasting canceled.'
        require('auto-save').on()
        return
      end
      if is_thumbnail == 'format' then
        local extension_options = { 'avif', 'webp', 'png', 'jpg' }
        vim.ui.select(extension_options, {
          prompt = 'Select image format:',
          default = 'avif',
        }, function(selected_ext)
          if not selected_ext then return end
          -- Define proceed_with_paste with proper parameter names
          local function proceed_with_paste(process_command)
            local prefix = vim.fn.strftime '%y%m%d-'
            local function prompt_for_name()
              vim.ui.input({ prompt = 'Enter image name (no spaces). Added prefix: ' .. prefix }, function(input_name)
                if not input_name or input_name:match '%s' then
                  print 'Invalid image name or canceled. Image not pasted.'
                  require('auto-save').on()
                  return
                end
                local full_image_name = prefix .. input_name
                local file_path = img_dir .. '/' .. full_image_name .. '.' .. selected_ext
                if vim.fn.filereadable(file_path) == 1 then
                  print 'Image name already exists. Please enter a new name.'
                  prompt_for_name()
                else
                  if paste_image(img_dir, full_image_name, selected_ext, process_command) then
                    vim.api.nvim_put({ '{: width="500" }' }, 'c', true, true)
                    vim.cmd 'normal! O'
                    vim.cmd 'stopinsert'
                    vim.cmd 'normal! o'
                    vim.api.nvim_put({ '<!-- prettier-ignore -->' }, 'c', true, true)
                    vim.cmd 'normal! j$o'
                    vim.cmd 'stopinsert'
                    vim.api.nvim_put({ '__' }, 'c', true, true)
                    vim.cmd 'normal! h'
                    vim.cmd 'silent! update'
                    vim.cmd 'edit!'
                    require('auto-save').on()
                  else
                    print 'No image pasted. File not updated.'
                    require('auto-save').on()
                  end
                end
              end)
            end
            prompt_for_name()
          end
          -- Resolution prompt handling
          vim.ui.select({ 'Yes', 'No' }, {
            prompt = 'Change image resolution?',
            default = 'No',
          }, function(resize_choice)
            local process_cmd
            if resize_choice == 'Yes' then
              vim.ui.input({
                prompt = 'Enter max height (default 1080): ',
                default = '1080',
              }, function(height_input)
                local height = tonumber(height_input) or 1080
                process_cmd = string.format('convert - -resize x%d -quality 100 %s:-', height, selected_ext)
                proceed_with_paste(process_cmd)
              end)
            else
              process_cmd = 'convert - -quality 75 ' .. selected_ext .. ':-'
              proceed_with_paste(process_cmd)
            end
          end)
        end)
        return
      end
      local prefix = vim.fn.strftime '%y%m%d-' .. (is_thumbnail == 'yes' and 'thux-' or '')
      local function prompt_for_name()
        vim.ui.input({ prompt = 'Enter image name (no spaces). Added prefix: ' .. prefix }, function(input_name)
          if not input_name or input_name:match '%s' then
            print 'Invalid image name or canceled. Image not pasted.'
            require('auto-save').on()
            return
          end
          local full_image_name = prefix .. input_name
          local file_path = img_dir .. '/' .. full_image_name .. '.avif'
          if vim.fn.filereadable(file_path) == 1 then
            print 'Image name already exists. Please enter a new name.'
            prompt_for_name()
          else
            if paste_image(img_dir, full_image_name) then
              vim.api.nvim_put({ '{: width="500" }' }, 'c', true, true)
              -- Create new line above and force normal mode
              vim.cmd 'normal! O'
              vim.cmd 'stopinsert' -- Explicitly exit insert mode
              -- Create blank line above and force normal mode
              vim.cmd 'normal! o'
              vim.cmd 'stopinsert'
              vim.api.nvim_put({ '<!-- prettier-ignore -->' }, 'c', true, true)
              -- Move down and create new line (without staying in insert mode)
              vim.cmd 'normal! j$o'
              vim.cmd 'stopinsert'
              vim.api.nvim_put({ '__' }, 'c', true, true)
              vim.cmd 'normal! h' -- Position cursor between underscores
              vim.cmd 'silent! update'
              vim.cmd 'edit!'
              require('auto-save').on()
            else
              print 'No image pasted. File not updated.'
              require('auto-save').on()
            end
          end
        end)
      end
      prompt_for_name()
    end)
  end, 100)
end

local function process_image()
  -- Any of these 2 work to toggle auto-save
  -- vim.cmd("ASToggle")
  require('auto-save').off()
  local img_dir = find_assets_dir()
  if not img_dir then
    vim.ui.select({ 'yes', 'no' }, {
      prompt = IMAGE_STORAGE_PATH .. ' directory not found. Create it?',
      default = 'yes',
    }, function(choice)
      if choice == 'yes' then
        img_dir = vim.fn.getcwd() .. '/assets/' .. IMAGE_STORAGE_PATH
        vim.fn.mkdir(img_dir, 'p')
        -- Start the image paste process after creating directory
        vim.defer_fn(function() handle_image_paste(img_dir) end, 100)
      else
        print 'Operation cancelled - directory not created'
        require('auto-save').on()
        return
      end
    end)
    return
  end
  handle_image_paste(img_dir)
end

-- Keymap to paste images in the 'assets' directory
-- This pastes images for my blogpost, I need to keep them in a different directory
-- so I pass those options to img-clip
vim.keymap.set({ 'n', 'i' }, '<M-1>', process_image, { desc = "[P]Paste image 'assets' directory" })

-------------------------------------------------------------------------------

-- Rename image under cursor lamw25wmal
-- If the image is referenced multiple times in the file, it will also rename
-- all the other occurrences in the file
vim.keymap.set('n', '<leader>iR', function()
  local function get_image_path()
    -- Get the current line
    local line = vim.api.nvim_get_current_line()
    -- Pattern to match image path in Markdown
    local image_pattern = '%[.-%]%((.-)%)'
    -- Extract relative image path
    local _, _, image_path = string.find(line, image_pattern)
    return image_path
  end
  -- Get the image path
  local image_path = get_image_path()
  if not image_path then
    vim.api.nvim_echo({ { 'No image found under the cursor', 'WarningMsg' } }, false, {})
    return
  end
  -- Check if it's a URL
  if string.sub(image_path, 1, 4) == 'http' then
    vim.api.nvim_echo({ { 'URL images cannot be renamed.', 'WarningMsg' } }, false, {})
    return
  end
  -- Get absolute paths
  local current_file_path = vim.fn.expand '%:p:h'
  local absolute_image_path = current_file_path .. '/' .. image_path
  -- Check if file exists
  if vim.fn.filereadable(absolute_image_path) == 0 then
    vim.api.nvim_echo({ { 'Image file does not exist:\n', 'ErrorMsg' }, { absolute_image_path, 'ErrorMsg' } }, false, {})
    return
  end
  -- Get directory and extension of current image
  local dir = vim.fn.fnamemodify(absolute_image_path, ':h')
  local ext = vim.fn.fnamemodify(absolute_image_path, ':e')
  local current_name = vim.fn.fnamemodify(absolute_image_path, ':t:r')
  -- Prompt for new name
  vim.ui.input({ prompt = 'Enter new name (without extension): ', default = current_name }, function(new_name)
    if not new_name or new_name == '' then
      vim.api.nvim_echo({ { 'Rename cancelled', 'WarningMsg' } }, false, {})
      return
    end
    -- Construct new path
    local new_absolute_path = dir .. '/' .. new_name .. '.' .. ext
    -- Check if new filename already exists
    if vim.fn.filereadable(new_absolute_path) == 1 then
      vim.api.nvim_echo({ { 'File already exists: ' .. new_absolute_path, 'ErrorMsg' } }, false, {})
      return
    end
    -- Rename the file
    local success, err = os.rename(absolute_image_path, new_absolute_path)
    if success then
      -- Get the old and new filenames (without path)
      local old_filename = vim.fn.fnamemodify(absolute_image_path, ':t')
      local new_filename = vim.fn.fnamemodify(new_absolute_path, ':t')
      -- -- Debug prints
      -- print("Old filename:", old_filename)
      -- print("New filename:", new_filename)
      -- Get buffer content
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- print("Number of lines in buffer:", #lines)
      -- Replace the text in each line that contains the old filename
      for i = 0, #lines - 1 do
        local line = lines[i + 1]
        -- First find the image markdown pattern with explicit end
        local img_start, img_end = line:find '!%[.-%]%(.-%)'
        if img_start and img_end then
          -- Get just the exact markdown part without any extras
          local markdown_part = line:match '!%[.-%]%(.-%)'
          -- Replace old filename with new filename
          local escaped_old = old_filename:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]', '%%%1')
          local escaped_new = new_filename:gsub('[%%]', '%%%%')
          -- Replace in the exact markdown part
          local new_markdown = markdown_part:gsub(escaped_old, escaped_new)
          -- Replace that exact portion in the line
          vim.api.nvim_buf_set_text(
            0,
            i,
            img_start - 1,
            i,
            img_start + #markdown_part - 1, -- Use exact length of markdown part
            { new_markdown }
          )
        end
      end
      -- "Update" saves only if the buffer has been modified since the last save
      vim.cmd 'update'
      vim.api.nvim_echo({
        { 'Image renamed successfully', 'Normal' },
      }, false, {})
    else
      vim.api.nvim_echo({
        { 'Failed to rename image:\n', 'ErrorMsg' },
        { tostring(err), 'ErrorMsg' },
      }, false, {})
    end
  end)
end, { desc = '[P]Rename image under cursor' })

-- HACK: Paste unformatted text from Neovim to Slack, Discord, Word or any other app
-- https://youtu.be/S3drTCO7Ct4
--
-- NOTE: New method of yanking text without LF (Line Feed) characters
-- This method is preferred because the old method requires a lot of edge cases,
-- for example codeblocks, or blockquotes which use `>`
--
-- Prettier is what autoformats all my files, including the markdown files
-- proseWrap: "always" is only enabled for markdown, which wraps all my markdown
-- lines at 80 characters, even existing lines are autoformatted
--
-- So only for markdown files, I'm copying all the text, to a temp file, applying
-- the prettier --prose-wrap never --write command on that file, then copying
-- the text in that file to my system clipboard
--
-- This gives me text without LF characters that I can pate in slack, the
-- browser, etc
if vim.g.simpler_scrollback ~= 'deeznuts' then
  vim.keymap.set('v', 'y', function()
    -- Check if the current buffer's filetype is markdown
    if vim.bo.filetype ~= 'markdown' then
      -- Not a Markdown file, copy the selection to the system clipboard
      vim.cmd 'normal! "+y'
      -- Optionally, notify the user
      vim.notify('Yanked to system clipboard', vim.log.levels.INFO)
      return
    end
    -- Yank the selected text into register 'z' without affecting the unnamed register
    vim.cmd 'silent! normal! "zy'
    -- Get the yanked text from register 'z'
    local text = vim.fn.getreg 'z'
    -- Path to a temporary file (uses a unique temporary file name)
    local temp_file = vim.fn.tempname() .. '.md'
    -- Write the selected text to the temporary file
    local file = io.open(temp_file, 'w')
    if file == nil then
      vim.notify('Error: Cannot write to temporary file.', vim.log.levels.ERROR)
      return
    end
    file:write(text)
    file:close()
    -- Run Prettier on the temporary file to format it
    -- Adding > /dev/null 2>&1' because if the command produces output, I see that
    -- in the neovim buffer
    local cmd = 'prettier --prose-wrap never --write "' .. temp_file .. '" > /dev/null 2>&1'
    local result = os.execute(cmd)
    if result ~= 0 then
      vim.notify('Error: Prettier formatting failed.', vim.log.levels.ERROR)
      os.remove(temp_file)
      return
    end
    -- Read the formatted text from the temporary file
    file = io.open(temp_file, 'r')
    if file == nil then
      vim.notify('Error: Cannot read from temporary file.', vim.log.levels.ERROR)
      os.remove(temp_file)
      return
    end
    local formatted_text = file:read '*all'
    file:close()
    -- Copy the formatted text to the system clipboard
    vim.fn.setreg('+', formatted_text)
    -- Delete the temporary file
    os.remove(temp_file)
    -- Notify the user
    vim.notify('yanked markdown with --prose-wrap never', vim.log.levels.INFO)
  end, { desc = '[P]Copy selection formatted with Prettier', noremap = true, silent = true })
end

-- Copy the current line and all diagnostics on that line to system clipboard
vim.keymap.set('n', 'yd', function()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line_num = pos[1] - 1 -- 0-indexed
  local line_text = vim.api.nvim_buf_get_lines(0, line_num, line_num + 1, false)[1]
  local diagnostics = vim.diagnostic.get(0, { lnum = line_num })
  if #diagnostics == 0 then
    vim.notify('No diagnostic found on this line', vim.log.levels.WARN)
    return
  end
  local message_lines = {}
  for _, d in ipairs(diagnostics) do
    for msg_line in d.message:gmatch '[^\n]+' do
      table.insert(message_lines, msg_line)
    end
  end
  local formatted = {}
  table.insert(formatted, 'Line:\n' .. line_text .. '\n')
  table.insert(formatted, 'Diagnostic on that line:\n' .. table.concat(message_lines, '\n'))
  vim.fn.setreg('+', table.concat(formatted, '\n\n'))
  vim.notify('Line and diagnostic copied to clipboard', vim.log.levels.INFO)
end, { desc = '[P]Yank line and diagnostic to system clipboard' })

-- Disabled this because I use these keymaps to navigate markdown headers
-- Ctrl+d and u are used to move up or down a half screen
-- but I don't like to use ctrl, so enabled this as well, both options work
-- zz makes the cursor to stay in the middle
-- If you want to return back to ctrl+d and ctrl+u
-- vim.keymap.set("n", "gk", "<C-u>zz", { desc = "[P]Go up a half screen" })
-- vim.keymap.set("n", "gj", "<C-d>zz", { desc = "[P]Go down a half screen" })

-- Launch, limiting search/replace to current file
-- https://github.com/MagicDuck/grug-far.nvim?tab=readme-ov-file#-cookbook
vim.keymap.set(
  { 'v', 'n' },
  '<leader>s1',
  '<cmd>lua require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })<cr>',
  { noremap = true, silent = true }
)

vim.keymap.set(
  { 'n', 'x' },
  '<leader>sv',
  function() require('grug-far').open { visualSelectionUsage = 'operate-within-range' } end,
  { desc = 'grug-far: Search within range' }
)

-- Replaces the word I'm currently on, opens a terminal so that I start typing the new word
-- It replaces the word globally across the entire file
vim.keymap.set('n', '<leader>su', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "[P]Replace word I'm currently on GLOBALLY" })

-- Replaces the current word with the same word in uppercase, globally
vim.keymap.set(
  'n',
  '<leader>sU',
  [[:%s/\<<C-r><C-w>\>/<C-r>=toupper(expand('<cword>'))<CR>/gI<Left><Left><Left>]],
  { desc = "[P]GLOBALLY replace word I'm on with UPPERCASE" }
)

-- Replaces the current word with the same word in lowercase, globally
vim.keymap.set(
  'n',
  '<leader>sL',
  [[:%s/\<<C-r><C-w>\>/<C-r>=tolower(expand('<cword>'))<CR>/gI<Left><Left><Left>]],
  { desc = "[P]GLOBALLY replace word I'm on with lowercase" }
)

-- ############################################################################

-- Set up a keymap to refresh the current buffer
vim.keymap.set('n', '<leader>br', function()
  -- Reloads the file to reflect the changes
  vim.cmd 'edit!'
  print 'Buffer reloaded'
end, { desc = '[P]Reload current buffer' })
