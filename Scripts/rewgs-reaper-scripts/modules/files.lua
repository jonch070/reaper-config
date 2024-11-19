function write_to_file(file, text)
    local file = io.open(file, "w" )
    if file ~= nil then
        if text ~= nil then
            file:write(text)
        end
        file:close()
    end
end
