-- @noindex

_LAST_LICENSE_CHECK = 0
_CHECK_LICENSE_EVERY_MINUTES = 30
_FULL_VERSION = false
_REGISTERED_TO = nil
_LICENSE_RUNNING_OFFLINE = true

-- Simple JSON decoder with better error handling
function decode_json(str)
    -- Remove whitespace
    str = str:gsub("^%s*(.-)%s*$", "%1")

    -- Handle simple types first
    if str == "null" then
        return nil
    elseif str == "true" then
        return true
    elseif str == "false" then
        return false
    elseif str:match("^-?%d+%.%d+$") then
        return tonumber(str)
    elseif str:match("^-?%d+$") then
        return tonumber(str)
    elseif str:match("^\".*\"$") then
        -- Simple string parsing (doesn't handle all escape sequences)
        return str:sub(2, -2):gsub('\\"', '"'):gsub('\\\\', '\\')
    end

    -- Check for arrays and objects
    local first_char = str:sub(1, 1)
    local last_char = str:sub(-1, -1)

    if first_char == "[" and last_char == "]" then
        return parse_json_array(str)
    elseif first_char == "{" and last_char == "}" then
        return parse_json_object(str)
    else
        error("Invalid JSON: " .. str:sub(1, 100) .. (#str > 100 and "..." or ""))
    end
end

function parse_json_array(str)
    local result = {}
    local content = str:sub(2, -2):gsub("^%s*(.-)%s*$", "%1")

    if content == "" then
        return result
    end

    -- Simple array parsing (basic implementation)
    local items = split_json_elements(content)
    for i, item in ipairs(items) do
        result[i] = decode_json(item)
    end

    return result
end

function parse_json_object(str)
    local result = {}
    local content = str:sub(2, -2):gsub("^%s*(.-)%s*$", "%1")

    if content == "" then
        return result
    end

    local pairs_list = split_json_elements(content)
    for _, pair in ipairs(pairs_list) do
        local colon_pos = pair:find(":")
        if colon_pos then
            local key_str = pair:sub(1, colon_pos - 1):gsub("^%s*(.-)%s*$", "%1")
            local value_str = pair:sub(colon_pos + 1):gsub("^%s*(.-)%s*$", "%1")

            -- Ensure key_str and value_str are not empty
            if key_str ~= "" and value_str ~= "" then
                local ok_key, key = pcall(decode_json, key_str)
                local ok_value, value = pcall(decode_json, value_str)

                if ok_key and ok_value and key then
                    result[key] = value
                end
            end
        end
    end

    return result
end

function split_json_elements(str)
    local elements = {}
    local current = ""
    local depth = 0
    local in_string = false
    local escape_next = false

    for i = 1, #str do
        local char = str:sub(i, i)

        if escape_next then
            current = current .. char
            escape_next = false
        elseif char == "\\" and in_string then
            current = current .. char
            escape_next = true
        elseif char == '"' then
            current = current .. char
            in_string = not in_string
        elseif not in_string then
            if char == "{" or char == "[" then
                current = current .. char
                depth = depth + 1
            elseif char == "}" or char == "]" then
                current = current .. char
                depth = depth - 1
            elseif char == "," and depth == 0 then
                -- Only insert the value, never a position
                elements[#elements + 1] = current:gsub("^%s*(.-)%s*$", "%1")
                current = ""
            else
                current = current .. char
            end
        else
            current = current .. char
        end
    end

    if current ~= "" then
        -- Only insert the value, never a position
        elements[#elements + 1] = current:gsub("^%s*(.-)%s*$", "%1")
    end

    return elements
end

-- Main function to make curl request and parse JSON

-- Enhanced: supports GET and POST (with postdata as string of -d flags)
function curl_get_json(url, postdata)
    local cmd
    if postdata then
        cmd = string.format([[curl -s -X POST %s "%s"]], postdata, url)
    else
        cmd = string.format([[curl -s "%s"]], url)
    end
    local handle = io.popen(cmd)
    if not handle then
        return nil, "Failed to execute curl"
    end
    local response = handle:read("*a")
    local success, exit_type, exit_code = handle:close()
    if not success or exit_code ~= 0 then
        return nil, "Curl failed"
    end
    if not response or response == "" then
        return nil, "Empty response"
    end
    local ok, result = pcall(decode_json, response)
    if not ok then
        return nil, "JSON parsing failed: " .. result
    end
    return result, nil
end

-- Simple JWT decoder with more robust JSON handling
function decode_jwt_payload(jwt_token)
    local parts = {}
    for part in jwt_token:gmatch('[^.]+') do
        parts[#parts + 1] = part
    end

    if #parts ~= 3 then
        return nil, "Invalid JWT format"
    end

    -- Decode base64url payload (second part)
    local payload_b64 = parts[2]
    -- Add padding if needed
    local padding = 4 - (#payload_b64 % 4)
    if padding ~= 4 then
        payload_b64 = payload_b64 .. string.rep("=", padding)
    end

    -- Simple base64 decode (basic implementation)
    local decoded = base64_decode(payload_b64:gsub("-", "+"):gsub("_", "/"))
    if not decoded then
        return nil, "Failed to decode JWT payload"
    end

    -- Try a simpler, more robust JSON parsing approach
    local ok, payload = pcall(function()
        return parse_jwt_payload_json(decoded)
    end)

    if not ok then
        return nil, "Failed to parse JWT payload JSON: " .. tostring(payload)
    end

    return payload, nil
end

-- Specialized JSON parser for JWT payloads (expects simple object structure)
function parse_jwt_payload_json(str)
    -- Remove null bytes, whitespace, and create a clean copy
    local clean_str = str:gsub("%z", ""):gsub("^%s*(.-)%s*$", "%1")

    -- Verify we have a proper JSON object structure
    local first_char = clean_str:sub(1, 1)
    local last_char = clean_str:sub(-1, -1)

    if not (first_char == "{" and last_char == "}") then
        error("Not a JSON object: " .. clean_str:sub(1, 50))
    end

    -- Extract content between braces
    local content = clean_str:sub(2, -2)

    local result = {}
    local pos = 1

    while pos <= #content do
        -- Skip whitespace
        while pos <= #content and content:sub(pos, pos):match("%s") do
            pos = pos + 1
        end

        if pos > #content then break end

        -- Find key
        if content:sub(pos, pos) ~= '"' then
            break -- End of object or invalid format
        end

        local key_start = pos + 1
        local key_end = key_start

        -- Find end of key
        while key_end <= #content and content:sub(key_end, key_end) ~= '"' do
            if content:sub(key_end, key_end) == '\\' then
                key_end = key_end + 1 -- Skip escaped character
            end
            key_end = key_end + 1
        end

        if key_end > #content then
            error("Unterminated key")
        end

        local key = content:sub(key_start, key_end - 1)
        pos = key_end + 1

        -- Skip whitespace and colon
        while pos <= #content and (content:sub(pos, pos):match("%s") or content:sub(pos, pos) == ":") do
            pos = pos + 1
        end

        -- Parse value
        local value, new_pos = parse_json_value(content, pos)
        result[key] = value
        pos = new_pos

        -- Skip whitespace
        while pos <= #content and content:sub(pos, pos):match("%s") do
            pos = pos + 1
        end

        -- Skip comma
        if pos <= #content and content:sub(pos, pos) == "," then
            pos = pos + 1
        end
    end

    return result
end

-- Parse a single JSON value starting at position pos
function parse_json_value(str, pos)
    -- Skip whitespace
    while pos <= #str and str:sub(pos, pos):match("%s") do
        pos = pos + 1
    end

    if pos > #str then
        error("Unexpected end of input")
    end

    local char = str:sub(pos, pos)

    if char == '"' then
        -- String value
        local start = pos + 1
        local end_pos = start
        while end_pos <= #str and str:sub(end_pos, end_pos) ~= '"' do
            if str:sub(end_pos, end_pos) == '\\' then
                end_pos = end_pos + 1 -- Skip escaped character
            end
            end_pos = end_pos + 1
        end
        if end_pos > #str then
            error("Unterminated string")
        end
        return str:sub(start, end_pos - 1), end_pos + 1
    elseif char == '{' then
        -- Nested object - find matching closing brace
        local brace_count = 1
        local start = pos + 1
        local end_pos = start
        while end_pos <= #str and brace_count > 0 do
            local c = str:sub(end_pos, end_pos)
            if c == '{' then
                brace_count = brace_count + 1
            elseif c == '}' then
                brace_count = brace_count - 1
            elseif c == '"' then
                -- Skip string content
                end_pos = end_pos + 1
                while end_pos <= #str and str:sub(end_pos, end_pos) ~= '"' do
                    if str:sub(end_pos, end_pos) == '\\' then
                        end_pos = end_pos + 1
                    end
                    end_pos = end_pos + 1
                end
            end
            end_pos = end_pos + 1
        end
        local object_str = str:sub(pos, end_pos - 1)
        return parse_jwt_payload_json(object_str), end_pos
    elseif char:match("[%d%-]") then
        -- Number
        local start = pos
        while pos <= #str and str:sub(pos, pos):match("[%d%.%-]") do
            pos = pos + 1
        end
        return tonumber(str:sub(start, pos - 1)), pos
    elseif str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    else
        -- For other values, try to parse as string until comma or end
        local start = pos
        while pos <= #str and not str:sub(pos, pos):match("[,}]") do
            pos = pos + 1
        end
        local value = str:sub(start, pos - 1):gsub("^%s*(.-)%s*$", "%1")
        return value, pos
    end
end

-- Simple base64 decode with better error handling
function base64_decode(data)
    if not data or data == "" then
        return nil
    end

    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local char_map = {}
    for i = 1, #chars do
        char_map[chars:sub(i, i)] = i - 1
    end
    char_map['='] = 0

    local result = {}
    local buffer = 0
    local bits = 0

    for i = 1, #data do
        local char = data:sub(i, i)
        local value = char_map[char]
        if not value then
            return nil
        end

        buffer = buffer * 64 + value
        bits = bits + 6

        if bits >= 8 then
            bits = bits - 8
            local byte = math.floor(buffer / (2 ^ bits))
            buffer = buffer % (2 ^ bits)
            result[#result + 1] = string.char(byte)
        end
    end

    local decoded = table.concat(result)

    return decoded
end

-- Simple base64 encode
function base64_encode(data)
    if not data or data == "" then
        return ""
    end

    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result = {}
    local padding = 0

    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        b = b or 0
        c = c or 0

        local bitmap = a * 65536 + b * 256 + c

        result[#result + 1] = chars:sub(math.floor(bitmap / 262144) + 1, math.floor(bitmap / 262144) + 1)
        result[#result + 1] = chars:sub(math.floor((bitmap % 262144) / 4096) + 1, math.floor((bitmap % 262144) / 4096) + 1)

        if i + 1 <= #data then
            result[#result + 1] = chars:sub(math.floor((bitmap % 4096) / 64) + 1, math.floor((bitmap % 4096) / 64) + 1)
        else
            result[#result + 1] = '='
            padding = padding + 1
        end

        if i + 2 <= #data then
            result[#result + 1] = chars:sub((bitmap % 64) + 1, (bitmap % 64) + 1)
        else
            result[#result + 1] = '='
            padding = padding + 1
        end
    end

    return table.concat(result)
end

-- Simple JSON stringify
function json_stringify(obj)
    if type(obj) == "string" then
        return '"' .. obj:gsub('"', '\\"') .. '"'
    elseif type(obj) == "number" then
        return tostring(obj)
    elseif type(obj) == "boolean" then
        return obj and "true" or "false"
    elseif type(obj) == "table" then
        local pairs_list = {}
        for k, v in pairs(obj) do
            pairs_list[#pairs_list + 1] = '"' .. tostring(k) .. '":' .. json_stringify(v)
        end
        return '{' .. table.concat(pairs_list, ',') .. '}'
    else
        return "null"
    end
end

-- Request signed token from signing service
function request_signed_token(gumroadProductId, licenseKey, email, gumroadResponse, signingServiceUrl)
    -- Escape JSON strings properly for shell
    local function escapeJsonString(str)
        return str:gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    end

    -- Build JSON manually to avoid shell escaping issues
    local jsonData = string.format(
        '{"license_key":"%s","email":"%s","product_id":"%s","gumroad_response":%s}',
        escapeJsonString(licenseKey),
        escapeJsonString(email),
        escapeJsonString(gumroadProductId),
        gumroadResponse and json_stringify(gumroadResponse) or '{}'
    )

    -- Write JSON to temp file to avoid shell escaping issues
    local tmpFile = os.tmpname()
    local file = io.open(tmpFile, "w")
    if file then
        file:write(jsonData)
        file:close()
    else
        return nil, nil, "Failed to create temporary file for request data"
    end

    -- Use the proper Supabase anon key for authentication
    local anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkY3FrZXllcHFucmludnNpbm1zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5NDcxMzUsImV4cCI6MjA3MTUyMzEzNX0.8IMi4ACcZQqhRit2xa3gv3aZPBJVDGwM77o8ztSxxEE"

    local cmd = string.format(
        'curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer %s" -H "apikey: %s" --data @"%s" "%s"',
        anon_key, anon_key, tmpFile, signingServiceUrl
    )

    local handle = io.popen(cmd)
    local response_text, exit_code

    if handle then
        response_text = handle:read("*a")
        local success, exit_type, code = handle:close()
        exit_code = code
    end

    os.remove(tmpFile)

    if not response_text or response_text == "" then
        return nil, nil, "Empty response from signing service"
    end

    if exit_code ~= 0 then
        return nil, nil, "Curl command failed with exit code: " .. tostring(exit_code)
    end

    -- Parse JSON response
    local ok, response = pcall(decode_json, response_text)
    if not ok then
        return nil, nil, "Failed to parse response JSON: " .. tostring(response)
    end

    if not response.success then
        local errorMsg = response.error or "Signing service failed"
        return nil, nil, errorMsg
    end

    return response.signed_token, response.expires_at, nil
end

-- Store signed token
function store_signed_token(token)
    reaper.SetExtState(Scr.ext_name, "SIGNED_TOKEN", token, true)
end

-- Verify signed token offline
function verify_signed_token(licenseKey, email)
    local token = reaper.GetExtState(Scr.ext_name, "SIGNED_TOKEN")
    if not token or token == "" then
        return false, "No offline license available"
    end

    local payload, error = decode_jwt_payload(token)
    if not payload then
        -- Clear invalid token
        reaper.SetExtState(Scr.ext_name, "SIGNED_TOKEN", "", true)
        return false, "Invalid license token"
    end

    -- Verify token contents match current user
    if payload.sub ~= licenseKey or (payload.email and payload.email:lower() ~= email:lower()) then
        return false, "License mismatch"
    end

    -- Check expiration
    local current_time = os.time()
    if payload.exp and current_time > payload.exp then
        return false, "Offline license expired - please connect to internet"
    end

    return true, payload.purchase_data or {}
end

function OD_VerifyGumroadLicense(gumroadProductId, licenseKey, email, incrementUsesCount, logger, forceOnline, signingServiceUrl)
    -- Trim leading and trailing spaces in email and licenseKey
    email = email and email:match("^%s*(.-)%s*$") or ""
    licenseKey = licenseKey and licenseKey:match("^%s*(.-)%s*$") or ""

    if logger then
        logger:logInfo("License verification starting")
    end

    local url = "https://api.gumroad.com/v2/licenses/verify"

    -- Try online verification (always, unless we add a forceOffline parameter later)
    local inc_str = incrementUsesCount and "true" or "false"
    local postdata = string.format("-d \"product_id=%s\" -d \"license_key=%s\" -d \"increment_uses_count=%s\"", gumroadProductId, licenseKey, inc_str)

    if logger then
        logger:logInfo("Attempting online license verification...")
    end

    local result, err = curl_get_json(url, postdata)

    if result and result.success then
        if logger then
            logger:logInfo("Online verification successful")
        end
        local email_from_response = result.purchase and result.purchase.email
        if email_from_response and email_from_response:lower() == email:lower() then
            if logger then
                logger:logInfo("Email validation passed - user authenticated via online check")
            end
            -- Get signed token from signing service
            if signingServiceUrl and signingServiceUrl ~= "" then
                local signedToken, expiresAt, error = request_signed_token(gumroadProductId, licenseKey, email, result, signingServiceUrl)
                if signedToken then
                    store_signed_token(signedToken)
                    if logger then
                        logger:logInfo("Signed token stored for offline verification")
                    end
                else
                    local errorMsg = "Failed to get signed token: " .. tostring(error)
                    if logger then
                        logger:logError(errorMsg)
                    end
                end
            end

            return true, result, "success"
        else
            if logger then
                logger:logInfo("Email validation failed - provided: " .. tostring(email) .. ", expected: " .. tostring(email_from_response))
            end
            return false, "License verification failed", "invalid_license" -- Email mismatch = invalid license
        end
    else
        if logger then
            if result then
                logger:logInfo("Online verification failed - API returned success=false: " .. tostring(result.message or "unknown error"))
                -- If we got a response from Gumroad but success=false, it's likely an invalid license
                return false, result.message or "License verification failed", "invalid_license"
            else
                logger:logInfo("Online verification failed - network/API error: " .. tostring(err or "unknown error"))
                -- If we couldn't reach the API or parse response, it's a network/temporary error
            end
        end
    end

    -- Fall back to offline verification (unless forceOnline is true)
    if not forceOnline then
        if logger then
            logger:logInfo("Online verification failed, attempting offline verification...")
        end
        local offline_valid, offline_result = verify_signed_token(licenseKey, email)
        if offline_valid then
            if logger then
                logger:logInfo("Offline verification successful - user authenticated via stored token")
            end
            return true, { purchase = offline_result }, "offline_success"
        else
            if logger then
                logger:logInfo("Offline verification failed: " .. tostring(offline_result))
            end
        end
        return false, offline_result or "License verification failed", "network_error" -- Network error if online failed and offline failed
    else
        if logger then
            logger:logInfo("Online verification failed and forceOnline=true - authentication failed")
        end
    end

    return false, "License verification failed", "network_error"
end

function _SetFullVersion(isFullVersion, isOfflineMode, email, logger)
    -- Only log if the status is actually changing
    local statusChanged = (_FULL_VERSION ~= isFullVersion) or (_LICENSE_RUNNING_OFFLINE ~= isOfflineMode)

    _FULL_VERSION = isFullVersion
    _REGISTERED_TO = _FULL_VERSION and email or nil
    if isFullVersion then
        _LICENSE_RUNNING_OFFLINE = isOfflineMode or false
        if statusChanged and logger then
            local mode = isOfflineMode and "offline" or "online"
            logger:logInfo("License verified - running in " .. mode .. " mode")
        end
    else
        _LICENSE_RUNNING_OFFLINE = false
        if statusChanged and logger then
            logger:logWarning("License verification failed")
        end
    end
end

function _VerifyLicense(forceOnline, newEmail, newLicenseKey, logger)
    if not newEmail and not newLicenseKey then
        -- Get stored credentials
        local storedKey = r.GetExtState(Scr.ext_name, "LICENSE_KEY")
        local storedEmail = r.GetExtState(Scr.ext_name, "EMAIL")

        -- Try offline first (unless forced online)
        if not forceOnline and storedKey ~= "" and storedEmail ~= "" then
            local valid = verify_signed_token(storedKey, storedEmail)
            if valid then
                _SetFullVersion(true, true, storedEmail, logger)
                return true
            end
        end

        -- Try with stored credentials for online validation

        if storedKey ~= "" and storedEmail ~= "" then
            local valid, response, failureType = OD_VerifyGumroadLicense(GUMROAD_PRODUCT_ID, storedKey, storedEmail, false, logger, false, SIGNING_SERVICE_URL)
            if valid then
                local isOfflineMode = response and response.purchase and not response.success
                _SetFullVersion(true, isOfflineMode, storedEmail, logger)
                return true
            end
            -- Handle different failure types appropriately
            if failureType == "invalid_license" then
                -- Definitive license failure - clear all credentials
                if logger then
                    logger:logDebug("License is invalid - clearing stored credentials")
                end
                r.SetExtState(Scr.ext_name, "LICENSE_KEY", "", true)
                r.SetExtState(Scr.ext_name, "EMAIL", "", true)
                r.SetExtState(Scr.ext_name, "SIGNED_TOKEN", "", true)
            elseif failureType == "network_error" then
                -- Network/temporary error - keep credentials for retry
                if logger then
                    logger:logDebug("Network/temporary error during license verification - keeping credentials for retry")
                end
                -- Only clear the token since it might be expired
                r.SetExtState(Scr.ext_name, "SIGNED_TOKEN", "", true)
            else
                -- Unknown failure type - be conservative and clear token only
                r.SetExtState(Scr.ext_name, "SIGNED_TOKEN", "", true)
            end
        end
    end
    if newEmail and newEmail ~= '' and newLicenseKey and newLicenseKey ~= '' then
        -- Try verification with new credentials
        local valid, response, failureType = OD_VerifyGumroadLicense(GUMROAD_PRODUCT_ID, newLicenseKey, newEmail, true, logger, false, SIGNING_SERVICE_URL)
        if valid then
            -- Store successful credentials for future use
            r.SetExtState(Scr.ext_name, "LICENSE_KEY", newLicenseKey, true)
            r.SetExtState(Scr.ext_name, "EMAIL", newEmail, true)

            local isOfflineMode = response and response.purchase and not response.success
            _SetFullVersion(true, isOfflineMode, newEmail, logger)
        else
            -- For new credential verification, always clear stored credentials on failure
            -- since the user just entered them and they failed
            r.SetExtState(Scr.ext_name, "LICENSE_KEY", "", true)
            r.SetExtState(Scr.ext_name, "EMAIL", "", true)
            r.SetExtState(Scr.ext_name, "SIGNED_TOKEN", "", true)
            _SetFullVersion(false, false, nil, logger)
        end
        return valid
    end
    return false
end

function OD_CheckLicenseStatus(logger)
    -- Only check license status hourly, not every frame
    local currentTime = r.time_precise()
    _LAST_LICENSE_CHECK = _LAST_LICENSE_CHECK or 0
    local timeSinceLastCheck = currentTime - _LAST_LICENSE_CHECK

    if timeSinceLastCheck < _CHECK_LICENSE_EVERY_MINUTES * 60 and _LAST_LICENSE_CHECK > 0 then
        return
    end

    _LAST_LICENSE_CHECK = currentTime

    -- Check stored token to see when we last verified online
    local token = r.GetExtState(Scr.ext_name, "SIGNED_TOKEN")

    -- Get stored credentials first to avoid unnecessary checks
    local storedKey = r.GetExtState(Scr.ext_name, "LICENSE_KEY")
    local storedEmail = r.GetExtState(Scr.ext_name, "EMAIL")

    -- If we don't have credentials, no point in checking
    if storedKey == "" or storedEmail == "" then
        if logger then
            logger:logDebug("No license credentials stored, skipping license check")
        end
        _SetFullVersion(false, false, nil, logger)
        return
    end

    -- Now check if we need to verify the token
    if not token or token == "" then
        -- No token stored, but we have credentials, so verify
        if logger then
            logger:logDebug("No stored token but credentials exist, performing license check")
        end
        local valid = _VerifyLicense(false, nil, nil, logger)
        return
    end

    -- Try offline verification to check if token is valid
    local valid, result = verify_signed_token(storedKey, storedEmail)
    if valid then
        -- Token is valid, set full version and return
        _SetFullVersion(true, true, storedEmail, logger)
        return
    else
        -- Token is invalid/expired, clear only the token - keep email and license key
        r.SetExtState(Scr.ext_name, "SIGNED_TOKEN", "", true)
    end

    -- If we get here, token is invalid or expired but we have credentials, so verify online
    if logger then
        logger:logInfo("Token invalid or expired, performing license check")
    end
    local valid = _VerifyLicense(false, nil, nil, logger)
end

function OD_DeactivateLicense(logger)
    r.SetExtState(Scr.ext_name, "LICENSE_KEY", "", true)
    r.SetExtState(Scr.ext_name, "EMAIL", "", true)
    r.SetExtState(Scr.ext_name, "SIGNED_TOKEN", "", true)
    _SetFullVersion(false, false, nil, logger)
    if logger then
        logger:logInfo('License deactivated by user')
    end
end

function OD_ActivateLicense(email, key, logger)
    return _VerifyLicense(true, email, key, logger)
end

function OD_IsFullVersion()
    return _FULL_VERSION
end

function OD_GetRegistredTo()
    return _REGISTERED_TO
end
