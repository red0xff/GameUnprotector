require'iuplua';

-- GUI Stuff
local is_valid = false;
local file;
local valid_file, decode_password, get_password, get_ascii_password, dump_embedded_file;
local file_label = iup.label{ title='File to unprotect' };
local filename = iup.text{canfocus='no',title='text', readonly='YES', size="215x20"};
local valid = iup.text{ value='waiting for your choice', size='150x15', readonly='yes', fontsize='15', alignment='acenter', fgcolor='150 150 150', bgcolor='0 0 0'}
local select_file = iup.button{ title='Select file', size='40x26' };
local hbox1 = iup.hbox{file_label, filename, select_file, valid, gap="20"};
local filedlg = iup.filedlg{dialogtype = "LOAD", title = "Load protected file", 
                      filter = "*.exe", filterinfo = "GameProtector protected files"};


local outfile = iup.text{title='text', size="275x20"};

local save_button = iup.button{ title='Recover the unprotected file', size='300x26' };
local password_label = iup.text{ value='<Your password will be displayed here>', bgcolor='0 0 0', fgcolor='150 150 150', fontsize='22',alignment = "ACENTER", size='200x10' };

local password_button = iup.button{ title='Get password', size='70x26' };
local hbox2 = iup.hbox{ password_label, password_button };
local hbox3 = iup.hbox{ outfile, save_button};

local function file_choice()
	if is_valid then file:close();
	end
	filedlg:popup(iup.ANYWHERE, iup.ANYWHERE);
	local state = filedlg.status;
	if state == '0' then
		filename.value = filedlg.value;
		file = io.open(filename.value, 'rb');
		-- check if valid file
		if valid_file(file) then
			valid.value = 'File is valid';
			valid.fgcolor = '0 255 120';
			is_valid = true;
			outfile.value = filename.value:gsub('%.exe','_ORIGINAL.exe');
		else
			is_valid = false;
			valid.value = 'File is not valid';
			valid.fgcolor = '255 0 0';
		end
	else
		valid.value = 'File not selected';
		valid.fgcolor = '255 120 0';
	end
end


select_file.action = file_choice;


function password_button:action()
	password_label.value = get_password(file);--'passw0rd123';
	password_label.fgcolor = '0 255 120';
end

function save_button:action()
	if is_valid then
		dump_embedded_file(file, outfile.value);
		iup.Message('Information', 'File saved under the name ' .. outfile.value);
	end
end

local frame = iup.frame{
							iup.vbox{
								iup.fill{},
								hbox2,
								hbox3,
								iup.fill{},
								gap='30'
							},
							title='Frame'
};



local hbox = iup.hbox{
				iup.fill{},	
				iup.vbox{
					iup.fill{},
					hbox1,
					frame,
					iup.fill{},
					gap='30'
				},
				iup.fill{},
				gap='30'
};
local dialog = iup.dialog{hbox, title='Game UNprotector (By Redouane)'}
dialog:show();


-- Game Protector stuff
-- Game Unprotector by Redouane
local function hex(t) -- convert table of ints to hexdump (table of strings, each string is the hexdump of 16 bytes)
	local _hex = { };
	for i = 1, #t do
		_hex[i] = string.format('%02X', t[i]);
	end
	return table.concat(_hex, ' ');
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

decode_password = function(enc) -- takes the encoded password, and returns its decoded form as a table of bytes
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

valid_file = function(file)
	file:seek('end',-0xc);
	local fingerprint = file:read(8);
	return fingerprint == "G\0M\0P\0T\0";
end

get_password = function(file)
	file:seek('end', -0x34);
	local encoded = file:read(0x28);
	local plain = decode_password(encoded);
	local ascii_password = get_ascii_password(plain);
	if not ascii_password then
		iup.Message('WARNING','The password contains non-ascii characters, The hexdump of the password has been displayed in the password field, try using a unicode converter');
		return hex(plain);
	else
		return ascii_password;
	end
end
get_ascii_password = function(t) -- takes a table of bytes, returns false if any of its bytes is not in the range (0x20...0x7f), returns the string representing t otherwise (in t, every two bytes represent a character)
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

dump_embedded_file = function(file, new_filename)
	file:seek('end', -4);
	local filesize = parseInt(file:read(4));
	file:seek('end', -filesize);
	local outfile = io.open(new_filename, 'wb');
	local embedded_file = file:read(filesize - 0x34); -- read it all at once, maybe change this later to deal with large files
	outfile:write(embedded_file);
	outfile:close();
end

if (iup.MainLoopLevel()==0) then -- Main loop
  iup.MainLoop()
  iup.Close()
end
