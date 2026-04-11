-- HACK: Upload images from Neovim to Imgur
-- https://youtu.be/Lzl_0SzbUBo
--
-- Upload images to my own imgur account (authenticated)
--
-- NOTE: This command is for macOS because that's the OS I use
-- if you use Linux, it will try, but if it fails you'll have to adapt the
-- `local upload_command` and make sure you have the dependencies needed
--
-- NOTE: Issue where image in clipboard was not "detected" has been fixed
--
-- This script uploads images to Imgur using an access token, and refreshes the token if it's expired.
-- It reads environment variables from a specified file and updates them as needed.
--
-- If you want to upload the images to your own imgur account, follow the
-- registration quickstart section in https://apidocs.imgur.com/
-- You can use postman's web version or the desktop app, the instructions tell
-- you even how to import imgur's api collection in postman lamw25wmal
--
-- For the new postman version go to the `Imgur API` folder, then click on the
-- `Authorization` tab, set the auth type to `oauth 2.0`, fill in the fields in
-- the `Configure new token` section, and click `Get New Access Token` at the
-- bottom, this will give you a lot of details including the refresh token
--
-- Configuration:
-- - Ensure your environment variables are stored in a file formatted as `VARIABLE="value"`.
-- NOTE: Here's a sample file to copy and paste:
-- IMGUR_ACCESS_TOKEN="xxxxxxx"
-- IMGUR_REFRESH_TOKEN="yyyyyyy"
-- IMGUR_CLIENT_ID="zzzzzz"
-- IMGUR_CLIENT_SECRET="wwwwww"
--
-- Path to your environment variables file
local env_file_path = vim.fn.expand '~/Library/Mobile Documents/com~apple~CloudDocs/github/imgur_credentials'
-- Configuration variables
-- update these names to match the names you have in the file above
local access_token_var = 'IMGUR_ACCESS_TOKEN'
local refresh_token_var = 'IMGUR_REFRESH_TOKEN'
local client_id_var = 'IMGUR_CLIENT_ID'
local client_secret_var = 'IMGUR_CLIENT_SECRET'
-- Keymap setup
vim.keymap.set({ 'n', 'i' }, '<M-i>', function()
  vim.notify('UPLOADING IMAGE TO IMGUR...', vim.log.levels.INFO)
  -- Slight delay to show the message
  vim.defer_fn(function()
    -- Function to read environment variables from the specified file
    local function load_env_variables()
      local env_vars = {}
      local file = io.open(env_file_path, 'r')
      if file then
        for line in file:lines() do
          -- Updated pattern to match lines without 'export'
          for key, value in string.gmatch(line, '([%w_]+)="([^"]+)"') do
            env_vars[key] = value
          end
        end
        file:close()
      else
        vim.notify('Failed to open ' .. env_file_path .. ' to load environment variables.', vim.log.levels.ERROR)
      end
      return env_vars
    end
    -- Load environment variables
    local env_vars = load_env_variables()
    -- Set environment variables in Neovim
    for key, value in pairs(env_vars) do
      vim.fn.setenv(key, value)
    end
    -- Retrieve the necessary variables
    local imgur_access_token = env_vars[access_token_var]
    local imgur_refresh_token = env_vars[refresh_token_var]
    local imgur_client_id = env_vars[client_id_var]
    local imgur_client_secret = env_vars[client_secret_var]
    if not imgur_access_token or imgur_access_token == '' then
      vim.notify('Imgur Access Token not found. Please set ' .. access_token_var .. ' in your environment file.', vim.log.levels.ERROR)
      return
    end
    -- Predeclare the functions to handle mutual references
    local upload_to_imgur
    local refresh_access_token
    local upload_attempts = 0 -- Keep track of upload attempts to prevent infinite loops
    -- Function to refresh the access token if expired
    refresh_access_token = function(callback)
      vim.notify('Access token invalid or expired. Refreshing access token...', vim.log.levels.WARN)
      local refresh_command = string.format(
        [[curl --silent --request POST "https://api.imgur.com/oauth2/token" \
        --data "refresh_token=%s" \
        --data "client_id=%s" \
        --data "client_secret=%s" \
        --data "grant_type=refresh_token"]],
        imgur_refresh_token,
        imgur_client_id,
        imgur_client_secret
      )
      -- print("Refresh command: " .. refresh_command) -- Log the refresh command
      local new_access_token = nil
      local new_refresh_token = nil
      vim.fn.jobstart(refresh_command, {
        stdout_buffered = true,
        on_stdout = function(_, data)
          local json_data = table.concat(data, '\n')
          -- print("Refresh token response JSON: " .. json_data) -- Log the response JSON
          local response = vim.fn.json_decode(json_data)
          if response and response.access_token then
            new_access_token = response.access_token
            new_refresh_token = response.refresh_token
            -- print("New access token obtained: " .. new_access_token) -- Log the new access token
            -- print("New refresh token obtained: " .. new_refresh_token) -- Log the new refresh token
          else
            vim.notify('Failed to refresh access token: ' .. (response and response.error_description or 'Unknown error'), vim.log.levels.ERROR)
          end
        end,
        on_exit = function()
          if new_access_token and new_refresh_token then
            -- Update environment variables in Neovim
            vim.fn.setenv(access_token_var, new_access_token)
            vim.fn.setenv(refresh_token_var, new_refresh_token)
            imgur_access_token = new_access_token
            imgur_refresh_token = new_refresh_token
            vim.notify('Access token refreshed successfully.', vim.log.levels.INFO)
            -- Write the new access token and refresh token to the environment file to persist them
            local file = io.open(env_file_path, 'r+')
            if not file then
              vim.notify('Error: Could not open ' .. env_file_path .. ' for writing.', vim.log.levels.ERROR)
              return
            end
            local content = file:read '*all'
            if content then
              -- Update Access Token
              local pattern_access = access_token_var .. '="[^"]*"'
              local replacement_access = access_token_var .. '="' .. new_access_token .. '"'
              content = content:gsub(pattern_access, replacement_access)
              -- Update Refresh Token
              local pattern_refresh = refresh_token_var .. '="[^"]*"'
              local replacement_refresh = refresh_token_var .. '="' .. new_refresh_token .. '"'
              content = content:gsub(pattern_refresh, replacement_refresh)
              file:seek('set', 0)
              file:write(content)
              file:close()
            else
              vim.notify('Failed to read ' .. env_file_path .. ' content.', vim.log.levels.ERROR)
              file:close()
            end
            -- Reload environment variables from the environment file
            env_vars = load_env_variables()
            for key, value in pairs(env_vars) do
              vim.fn.setenv(key, value)
            end
            -- Callback after refreshing the token
            if callback then callback() end
          else
            vim.notify('Failed to refresh access token.', vim.log.levels.ERROR)
          end
        end,
      })
    end
    -- Function to execute image upload command to Imgur
    upload_to_imgur = function()
      upload_attempts = upload_attempts + 1
      if upload_attempts > 2 then
        vim.notify('Maximum upload attempts reached. Please check your credentials.', vim.log.levels.ERROR)
        return
      end
      -- Detect the operating system
      local is_mac = vim.fn.has 'macunix' == 1
      local is_linux = vim.fn.has 'unix' == 1 and not is_mac
      local clipboard_command = ''
      if is_mac then
        -- macOS command to get image from clipboard
        clipboard_command = [[osascript -e 'get the clipboard as «class PNGf»' | sed 's/«data PNGf//; s/»//' | xxd -r -p]]
      elseif is_linux then
        -- Linux command to get image from clipboard using xclip
        clipboard_command = [[xclip -selection clipboard -t image/png -o]]
        -- Alternative for Wayland-based systems (uncomment if needed)
        -- clipboard_command = [[wl-paste --type image/png]]
      else
        vim.notify('Unsupported operating system for clipboard image upload.', vim.log.levels.ERROR)
        return
      end
      local upload_command = string.format(
        [[
          %s \
          | curl --silent --write-out "HTTPSTATUS:%%{http_code}" --request POST --form "image=@-" \
          --header "Authorization: Bearer %s" "https://api.imgur.com/3/image"
        ]],
        clipboard_command,
        imgur_access_token
      )
      -- print("Upload command: " .. upload_command) -- Log the upload command
      local url = nil
      local error_status = nil
      local error_message = nil
      local account_id = nil
      vim.fn.jobstart(upload_command, {
        stdout_buffered = true,
        on_stdout = function(_, data)
          local output = table.concat(data, '\n')
          local json_data, http_status = output:match '^(.*)HTTPSTATUS:(%d+)$'
          if not json_data or not http_status then
            -- print("Failed to parse response and HTTP status code.")
            error_status = nil
            error_message = 'Unknown error'
            return
          end
          -- print("Upload response JSON: " .. json_data)
          -- print("HTTP status code: " .. http_status)
          local response = vim.fn.json_decode(json_data)
          error_status = tonumber(http_status)
          if error_status >= 200 and error_status < 300 and response and response.success then
            url = response.data.link
            account_id = response.data.account_id
            -- print("Upload successful. URL: " .. url)
          else
            -- Extract error message from different possible response formats
            if response.data and response.data.error then
              error_message = response.data.error
            elseif response.errors and response.errors[1] and response.errors[1].detail then
              error_message = response.errors[1].detail
            else
              error_message = 'Unknown error'
            end
            -- print("Upload failed. Status: " .. tostring(error_status) .. ", Error: " .. error_message)
          end
        end,
        on_exit = function()
          if url and account_id ~= vim.NIL and account_id ~= nil then
            -- Format the URL as Markdown
            local markdown_url = string.format('![imgur](%s)', url)
            vim.notify('Image uploaded to Imgur.', vim.log.levels.INFO)
            -- Insert formatted Markdown link into buffer at cursor position
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { markdown_url })
          elseif error_status == 401 or error_status == 429 then
            vim.notify('Access token expired or invalid, refreshing...', vim.log.levels.WARN)
            refresh_access_token(function() upload_to_imgur() end)
          elseif error_status == 400 and error_message == "We don't support that file type!" then
            vim.notify('Failed to upload image: ' .. error_message, vim.log.levels.ERROR)
          else
            vim.notify('Failed to upload image to Imgur: ' .. (error_message or 'Unknown error'), vim.log.levels.ERROR)
          end
        end,
      })
    end
    -- Attempt to upload the image
    upload_to_imgur()
  end, 100)
end, { desc = '[P]Paste image to Imgur' })

-- -- Upload images to imgur, this uploads the images UN-authentiated, it means
-- -- it uploads them anonymously, not tied to your account
-- -- used this as a start
-- -- https://github.com/evanpurkhiser/image-paste.nvim/blob/main/lua/image-paste.lua
-- -- Configuration:
-- -- Path to your environment variables file
-- local env_file_path = vim.fn.expand("~/Library/Mobile Documents/com~apple~CloudDocs/github/imgur_credentials")
-- vim.keymap.set({ "n", "v", "i" }, "<C-f>", function()
--   print("UPLOADING IMAGE TO IMGUR...")
--   -- Slight delay to show the message
--   vim.defer_fn(function()
--     -- Function to read environment variables from the specified file
--     local function load_env_variables()
--       local env_vars = {}
--       local file = io.open(env_file_path, "r")
--       if file then
--         for line in file:lines() do
--           for key, value in string.gmatch(line, 'export%s+([%w_]+)="([^"]+)"') do
--             env_vars[key] = value
--           end
--         end
--         file:close()
--       else
--         print("Failed to open " .. env_file_path .. " to load environment variables.")
--       end
--       return env_vars
--     end
--     -- Load environment variables
--     local env_vars = load_env_variables()
--     -- Retrieve the Imgur Client ID from the loaded environment variables
--     local imgur_client_id = env_vars["IMGUR_CLIENT_ID"]
--     if not imgur_client_id or imgur_client_id == "" then
--       print("Imgur Client ID not found. Please set IMGUR_CLIENT_ID in your environment file.")
--       return
--     end
--     -- Function to execute image upload command to Imgur
--     local function upload_to_imgur()
--       local upload_command = string.format(
--         [[
--         osascript -e "get the clipboard as «class PNGf»" | sed "s/«data PNGf//; s/»//" | xxd -r -p \
--         | curl --silent --fail --request POST --form "image=@-" \
--           --header "Authorization: Client-ID %s" "https://api.imgur.com/3/upload" \
--         | jq --raw-output .data.link
--       ]],
--         imgur_client_id
--       )
--       local url = nil
--       vim.fn.jobstart(upload_command, {
--         stdout_buffered = true,
--         on_stdout = function(_, data)
--           url = vim.fn.join(data):gsub("^%s*(.-)%s*$", "%1")
--         end,
--         on_exit = function(_, exit_code)
--           if exit_code == 0 and url ~= "" then
--             -- Format the URL as Markdown
--             local markdown_url = string.format("![imgur](%s)", url)
--             print("Image uploaded to Imgur: " .. markdown_url)
--             -- Insert formatted Markdown link into buffer at cursor position
--             local row, col = unpack(vim.api.nvim_win_get_cursor(0))
--             vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { markdown_url })
--           else
--             print("Failed to upload image to Imgur.")
--           end
--         end,
--       })
--     end
--     -- Call the upload function
--     upload_to_imgur()
--   end, 100)
-- end, { desc = "[P]Paste image to Imgur" })

-- ############################################################################

-- HACK: Upload images from Neovim to Imgur
-- https://youtu.be/Lzl_0SzbUBo
--
-- -- Open image under cursor in the Preview app (macOS)
-- vim.keymap.set('n', '<leader>io', function()
--   local function get_image_path()
--     -- Get the current line
--     local line = vim.api.nvim_get_current_line()
--     -- Pattern to match image path in Markdown
--     local image_pattern = '%[.-%]%((.-)%)'
--     -- Extract relative image path
--     local _, _, image_path = string.find(line, image_pattern)
--     return image_path
--   end
--   -- Get the image path
--   local image_path = get_image_path()
--   if image_path then
--     -- Check if the image path starts with "http" or "https"
--     if string.sub(image_path, 1, 4) == 'http' then
--       print "URL image, use 'gx' to open it in the default browser."
--     else
--       -- Construct absolute image path
--       local current_file_path = vim.fn.expand '%:p:h'
--       local absolute_image_path = current_file_path .. '/' .. image_path
--       -- Construct command to open image in Preview
--       local command = 'open -a Preview ' .. vim.fn.shellescape(absolute_image_path)
--       -- Execute the command
--       local success = os.execute(command)
--       if success then
--         print('Opened image in Preview: ' .. absolute_image_path)
--       else
--         print('Failed to open image in Preview: ' .. absolute_image_path)
--       end
--     end
--   else
--     print 'No image found under the cursor'
--   end
-- end, { desc = '[P](macOS) Open image under cursor in Preview' })

-- ############################################################################

-- HACK: Upload images from Neovim to Imgur
-- https://youtu.be/Lzl_0SzbUBo
--
-- Open image under cursor in Finder (macOS)
--
-- THIS ONLY WORKS IF YOU'RE NNNNNOOOOOOTTTTT USING ABSOLUTE PATHS,
-- BUT INSTEAD YOURE USING RELATIVE PATHS
--
-- If using absolute paths, use the default `gx` to open the image instead
vim.keymap.set('n', '<leader>if', function()
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
  if image_path then
    -- Check if the image path starts with "http" or "https"
    if string.sub(image_path, 1, 4) == 'http' then
      print "URL image, use 'gx' to open it in the default browser."
    else
      -- Construct absolute image path
      local current_file_path = vim.fn.expand '%:p:h'
      local absolute_image_path = current_file_path .. '/' .. image_path
      -- Open the containing folder in Finder or forklift and select the image file
      -- Line below for finder
      -- local command = "open -R " .. vim.fn.shellescape(absolute_image_path)
      -- Line below for forklift
      local command = 'open -a ForkLift ' .. vim.fn.shellescape(absolute_image_path)
      local success = vim.fn.system(command)
      if success == 0 then
        print('Opened image in Finder: ' .. absolute_image_path)
      else
        print('Failed to open image in Finder: ' .. absolute_image_path)
      end
    end
  else
    print 'No image found under the cursor'
  end
end, { desc = '[P](macOS) Open image under cursor in Finder' })

-- ############################################################################

-- HACK: Upload images from Neovim to Imgur
-- https://youtu.be/Lzl_0SzbUBo
--
-- Delete image file under cursor using trash app (macOS)
vim.keymap.set('n', '<leader>id', function()
  local function get_image_path()
    local line = vim.api.nvim_get_current_line()
    local image_pattern = '%[.-%]%((.-)%)'
    local _, _, image_path = string.find(line, image_pattern)
    if not image_path then
      local typst_pattern = '#?image%(%s*"([^"]+)"'
      _, _, image_path = string.find(line, typst_pattern)
    end
    return image_path
  end
  local image_path = get_image_path()
  if not image_path then
    vim.api.nvim_echo({ { 'No image found under the cursor', 'WarningMsg' } }, false, {})
    return
  end
  if string.sub(image_path, 1, 4) == 'http' then
    vim.api.nvim_echo({ { 'URL image cannot be deleted from disk.', 'WarningMsg' } }, false, {})
    return
  end
  local current_file_path = vim.fn.expand '%:p:h'
  local absolute_image_path = current_file_path .. '/' .. image_path
  -- Check if file exists
  if vim.fn.filereadable(absolute_image_path) == 0 then
    vim.api.nvim_echo({ { 'Image file does not exist:\n', 'ErrorMsg' }, { absolute_image_path, 'ErrorMsg' } }, false, {})
    return
  end
  if vim.fn.executable 'trash' == 0 then
    vim.api.nvim_echo({
      { '- Trash utility not installed. Make sure to install it first\n', 'ErrorMsg' },
      { '- In macOS run `brew install trash`\n', nil },
    }, false, {})
    return
  end
  -- Cannot see the popup as the cursor is on top of the image name, so saving
  -- its position, will move it to the top and then move it back
  local current_pos = vim.api.nvim_win_get_cursor(0) -- Save cursor position
  vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- Move to top
  vim.ui.select({ 'yes', 'no' }, { prompt = 'Delete image file? ' }, function(choice)
    vim.api.nvim_win_set_cursor(0, current_pos) -- Move back to image line
    if choice == 'yes' then
      local success, _ = pcall(function() vim.fn.system { 'trash', vim.fn.fnameescape(absolute_image_path) } end)
      -- Verify if file still exists after deletion attempt
      if success and vim.fn.filereadable(absolute_image_path) == 1 then
        -- Try with rm if trash deletion failed
        -- Keep in mind that if deleting with `rm` the images won't go to the
        -- macos trash app, they'll be gone
        -- This is useful in case trying to delete imaes mounted in a network
        -- drive, like for my blogpost lamw25wmal
        --
        -- Cannot see the popup as the cursor is on top of the image name, so saving
        -- its position, will move it to the top and then move it back
        current_pos = vim.api.nvim_win_get_cursor(0) -- Save cursor position
        vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- Move to top
        vim.ui.select({ 'yes', 'no' }, { prompt = 'Trash deletion failed. Try with rm command? ' }, function(rm_choice)
          vim.api.nvim_win_set_cursor(0, current_pos) -- Move back to image line
          if rm_choice == 'yes' then
            local rm_success, _ = pcall(function() vim.fn.system { 'rm', vim.fn.fnameescape(absolute_image_path) } end)
            if rm_success and vim.fn.filereadable(absolute_image_path) == 0 then
              vim.api.nvim_echo({
                { 'Image file deleted from disk using rm:\n', 'Normal' },
                { absolute_image_path, 'Normal' },
              }, false, {})
              -- require("image").clear()
              vim.cmd 'edit!'
              vim.cmd 'normal! dd'
            else
              vim.api.nvim_echo({
                { 'Failed to delete image file with rm:\n', 'ErrorMsg' },
                { absolute_image_path, 'ErrorMsg' },
              }, false, {})
            end
          end
        end)
      elseif success and vim.fn.filereadable(absolute_image_path) == 0 then
        vim.api.nvim_echo({
          { 'Image file deleted from disk:\n', 'Normal' },
          { absolute_image_path, 'Normal' },
        }, false, {})
        -- require("image").clear()
        vim.cmd 'edit!'
        vim.cmd 'normal! dd'
      else
        vim.api.nvim_echo({
          { 'Failed to delete image file:\n', 'ErrorMsg' },
          { absolute_image_path, 'ErrorMsg' },
        }, false, {})
      end
    else
      vim.api.nvim_echo({ { 'Image deletion canceled.', 'Normal' } }, false, {})
    end
  end)
end, { desc = '[P](macOS) Delete image file under cursor' })

-- ############################################################################

-- -- HACK: Upload images from Neovim to Imgur
-- -- https://youtu.be/Lzl_0SzbUBo
-- --
-- -- Refresh the images in the current buffer
-- -- Useful if you delete an actual image file and want to see the changes
-- -- without having to re-open neovim
-- vim.keymap.set("n", "<leader>ir", function()
--   -- First I clear the images
--   -- require("image").clear()
--   -- I'm using [[ ]] to escape the special characters in a command
--   -- vim.cmd([[lua require("image").clear()]])
--   -- Reloads the file to reflect the changes
--   vim.cmd("edit!")
--   print("Images refreshed")
-- end, { desc = "[P]Refresh images" })

-- ############################################################################

-- -- HACK: Upload images from Neovim to Imgur
-- -- https://youtu.be/Lzl_0SzbUBo
-- --
-- -- Set up a keymap to clear all images in the current buffer
-- vim.keymap.set("n", "<leader>ic", function()
--   -- This is the command that clears the images
--   -- require("image").clear()
--   -- I'm using [[ ]] to escape the special characters in a command
--   -- vim.cmd([[lua require("image").clear()]])
--   print("Images cleared")
-- end, { desc = "[P]Clear images" })
