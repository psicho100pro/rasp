sudo apt install lua5.4 liblua5.4-dev
sudo update-alternatives --install /usr/bin/lua lua /usr/bin/lua5.4 50
sudo update-alternatives --install /usr/bin/luac luac /usr/bin/luac5.4 50
sudo ln -sf /usr/bin/lua5.4 /usr/local/bin/lua
sudo ln -sf /usr/bin/luac5.4 /usr/local/bin/luac
sudo ln -sf /usr/bin/lua5.4 /usr/bin/lua
sudo ln -sf /usr/bin/luac5.4 /usr/bin/luac
hash -r



sudo apt update && sudo apt install imapfilter -y

sudo useradd -r -s /bin/false -d /var/lib/imapfilter imapfilter
sudo mkdir -p /etc/imapfilter /var/lib/imapfilter

sudo chown -R imapfilter:imapfilter /etc/imapfilter /var/lib/imapfilter
sudo chmod 700 /etc/imapfilter /var/lib/imapfilter

sudo bash -c 'cat <<EOF > /etc/systemd/system/imapfilter.service
[Unit]
Description=IMAPFilter Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=imapfilter
Group=imapfilter
WorkingDirectory=/var/lib/imapfilter
ExecStart=/usr/bin/imapfilter -c /etc/imapfilter/config.lua -v
Restart=on-failure
RestartSec=10

# Hardening / Bezpečnostní izolace
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload

sudo nano /etc/imapfilter/config.lua

-- https://linux.die.net/man/5/imapfilter_config

os.setlocale("C", "time")
options.timeout = 120
options.keepalive = 300
options.subscribe = true

account = IMAP {
    server = 'imap.centrum.cz',
    port = 993,
    username = 'psicho100pro@centrum.cz',
    password = '',
    ssl = 'tls',
    ssl_params = { verify = "none" }
}

local id_cache = {}
local last_run = nil

local function process_messages(source_folder, target_folder, cmd, use_cache)
    local select_method = use_cache and "is_unseen" or "select_all"
    
    if select(1, source_folder:check_status()) > 0 then
        local to_move = Set {} 
        local messages = source_folder[select_method](source_folder)
        
        if messages and #messages > 0 then
            for _, msg in ipairs(messages) do
                local mbox, uid = table.unpack(msg)
                local uid_str = tostring(uid)
                
                if not (use_cache and id_cache[uid_str]) then
                    local ok_b, b = pcall(function() return mbox[uid]:fetch_message() end)
                    if ok_b and b then
                        local pipe = io.popen(cmd, "w")
                        if pipe then
                            pipe:write(b)
                            if select(3, pipe:close()) == 0 then 
                                table.insert(to_move, msg) 
                            end
                            if use_cache then id_cache[uid_str] = true end
                        end
                    end
                end
            end
            
            if #to_move > 0 then
                to_move:move_messages(target_folder)
            end
        end
    end
end

while true do

    if select(1, account['spam koš']:check_status()) > 0 then account['spam koš']:select_all():move_messages(account.ToSpam) end
    
    process_messages(account.ToSpam, account.Spam, "rspamc learn_spam > /dev/null 2>&1")
    process_messages(account.ToHam, account.INBOX, "rspamc learn_ham > /dev/null 2>&1")
    process_messages(account.INBOX, account.Spam, "rspamc 2>&1 | grep -qE 'Spam: true|Action: add header'", true)
    
    local h, d = tonumber(os.date("%H")), os.date("%d")
    
    if h >= 1 and h < 3 and last_run ~= d then
        account['koš']:is_older(1):is_unseen():mark_seen()
        account.Spam:is_older(3):is_unseen():mark_seen()
        account['koš']:is_older(30):delete_messages()
        last_run = d
    end
    collectgarbage("step", 100)
    account.INBOX:enter_idle()

end


sudo chown imapfilter:imapfilter /etc/imapfilter/config.lua
sudo chmod 600 /etc/imapfilter/config.lua

sudo systemctl enable --now imapfilter
