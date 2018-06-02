-- Game Unprotector by Redouane
local function hex(t) -- convert table of ints to hexdump (table of strings, each string is the hexdump of 16 bytes)
	local _hex = { };
	local _t = { };
	for i = 1, #t do
		_t[#_t+1] = string.format('%02X', t[i]);
		if #_t == 16 then
			_hex[#_hex+1] = table.concat(_t, ' ');
			_t = { };
		end
	end
	return _hex;
end

local function parseInt(s) -- convert a string to an integer (little endian)
	if #s > 4 then
		return 0;
	end
	local n = 0;
	local i = 0;
	for c in s:gmatch'.' do
		n = n + c:byte() * (1 << i);
		i = i + 8;
	end
	return n;
end

local key = 'TESTNET'; -- constant key used by GameProtector
function string:charAt(i)
	return self:sub(i,i);
end

local function decode_password(enc) -- takes the encoded password, and returns its decoded form as a table of bytes
	local plain = { };
	local j = 1;
	for i = 1, #enc-1, 2 do
		local enc_word = enc:charAt(i+1):byte() * 256 + enc:charAt(i):byte();
		if enc_word == 0 then
			break;
		end
		local key_word = key:charAt(j % 7 == 6 and 7 or (j + 1) % 7):byte();
		local plain_word = enc_word - key_word;
		plain[i] = plain_word & 0xff;
		plain[i+1] = plain_word >> 8;
		j = j + 1;
	end
	return plain;
end

local function valid_file(file)
	file:seek('end',-0xc);
	local fingerprint = file:read(8);
	return fingerprint == "G\0M\0P\0T\0";
end

local function get_ascii_password(t) -- takes a table of bytes, returns false if any of its bytes is not in the range (0x20...0x7f), returns the string representing t otherwise (in t, every two bytes represent a character)
	local ascii = { };
	local j = 1;
	for i = 1, #t-1, 2 do
		if t[i+1] ~= 0 or t[i] >= 0x7f or t[i] < 0x20 then
			return false;
		end
		ascii[j] = string.char(t[i]);
		j = j + 1;
	end
	return table.concat(ascii);
end

local function get_password(file)
	file:seek('end', -0x34);
	local encoded = file:read(0x28);
	local plain = decode_password(encoded);
	local ascii_password = get_ascii_password(plain);
	if not ascii_password then
		print'-------------------- PASSWORD AS HEXDUMP ---------------------\n\n';
		print'              |';
		for i, line in ipairs(hex(plain)) do
			print(string.format(' 0x%08x   | %s', (i-1)*16, line));
		end
		print'              | ';
		print'\n\nWARNING : the password contains non-ascii characters, try using a unicode converter';
	else
		print('\n\n--------------------- PASSWORD IN PLAINTEXT ------------------------------\n\n');
		print(string.format('                password = %q\n', ascii_password));
	end
end

local function dump_embedded_file(file, new_filename)
	file:seek('end', -4);
	local filesize = parseInt(file:read(4));
	file:seek('end', -filesize);
	print(string.format('\n--------------------- SAVING EMBEDDED FILE AS %s -----------------', new_filename));
	local outfile = io.open(new_filename, 'wb');
	local embedded_file = file:read(filesize - 0x34); -- read it all at once, maybe change this later to deal with large files
	outfile:write(embedded_file);
	outfile:close();
end

if not arg[1] then
	print('Usage : lua ' .. arg[0] .. ' <filename>');
	os.exit(1);
end

local filename = arg[1];
local file = io.open(filename, 'rb');
if not file then
	print('Could not open the file ' .. filename);
	os.exit(1);
end

if not valid_file(file) then -- check if the file has been protected by GameProtector
	print'No ressource found';
	os.exit(1);
end

get_password(file);

dump_embedded_file(file, (filename:gsub('%.exe', '_ORIGINAL.exe')));

file:close();
