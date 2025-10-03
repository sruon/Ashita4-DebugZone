addon.name    = 'debugzone';
addon.author  = 'sruon';
addon.version = '1.0';
addon.desc    = 'Captures all incoming and outgoing packets for debugging.';
addon.link    = '';

require('common');

local log_file = nil;

local filter_incoming =
{
    [0x00A] = true,
    [0x00B] = true,
};

local filter_outgoing =
{
    [0x00A] = true,
    [0x00B] = true,
    [0x00D] = true,
    [0x00F] = true,
    [0x05E] = true,
};

local top_row = '        |  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F      | 0123456789ABCDEF\n    ' ..
    string.rep('-', (16 + 1) * 3 + 2) .. '  ' .. string.rep('-', 16 + 6) .. '\n'

local chars = {}
for i = 0x00, 0xFF do
    if i >= 0x20 and i < 0x7F then
        chars[i] = string.char(i)
    else
        chars[i] = '.'
    end
end
chars[0x5C] = '\\\\'
chars[0x25] = '%%'

local line_replace = {}
for i = 0x01, 0x10 do
    line_replace[i] = '    %%%%3X |' ..
        string.rep(' %.2X', i) .. string.rep(' --', 0x10 - i) .. '  %%%%3X | ' .. '%%s\n'
end

local short_replace = {}
for i = 0x01, 0x10 do
    short_replace[i] = string.rep('%s', i) .. string.rep('-', 0x10 - i)
end

local function hexformat(str, size)
    local length = size
    local str_table = {}
    local from = 1
    local to = 16
    for i = 0, math.floor((length - 1) / 0x10) do
        local partial_str = { str:byte(from, to) }
        local char_table =
        {
            [0x01] = chars[partial_str[0x01]],
            [0x02] = chars[partial_str[0x02]],
            [0x03] = chars[partial_str[0x03]],
            [0x04] = chars[partial_str[0x04]],
            [0x05] = chars[partial_str[0x05]],
            [0x06] = chars[partial_str[0x06]],
            [0x07] = chars[partial_str[0x07]],
            [0x08] = chars[partial_str[0x08]],
            [0x09] = chars[partial_str[0x09]],
            [0x0A] = chars[partial_str[0x0A]],
            [0x0B] = chars[partial_str[0x0B]],
            [0x0C] = chars[partial_str[0x0C]],
            [0x0D] = chars[partial_str[0x0D]],
            [0x0E] = chars[partial_str[0x0E]],
            [0x0F] = chars[partial_str[0x0F]],
            [0x10] = chars[partial_str[0x10]],
        }
        local bytes = math.min(length - from + 1, 16)
        str_table[i + 1] = line_replace[bytes]
            :format(unpack(partial_str))
            :format(short_replace[bytes]:format(unpack(char_table)))
            :format(i, i)
        from = to + 1
        to = to + 0x10
    end
    return string.format('%s%s', top_row, table.concat(str_table))
end

local function log_packet(direction, packet_id, data, size)
    local timestamp = os.date('[%Y-%m-%d %H:%M:%S]');
    local header = string.format('%s %s packet 0x%03X\n', timestamp, direction, packet_id);
    local hex_dump = hexformat(data, size);
    local output = header .. hex_dump .. '\n';

    if log_file then
        log_file:write(output);
        log_file:flush();
    end
end

ashita.events.register('load', 'load_cb', function()
    local log_dir = string.format('%sconfig\\addons\\debugzone\\', AshitaCore:GetInstallPath());
    ashita.fs.create_dir(log_dir);

    local log_path = string.format('%spackets_%s.log', log_dir, os.date('%Y%m%d'));
    log_file = io.open(log_path, 'a');
end);

ashita.events.register('unload', 'unload_cb', function()
    if log_file then
        log_file:close();
        log_file = nil;
    end
end);

ashita.events.register('packet_in', 'packet_in_cb', function(e)
    if filter_incoming[e.id] then
        log_packet('Incoming', e.id, e.data, e.size);
    end
end);

ashita.events.register('packet_out', 'packet_out_cb', function(e)
    if filter_outgoing[e.id] then
        log_packet('Outgoing', e.id, e.data, e.size);
    end
end);
