%% 1. Configuration & Setup
clear; clc;

% Modern Trigno Discover local loopback WebSockets URL
discover_url = 'ws://127.0.0.1:50040'; 
num_channels = 4;        % MATCHES YOUR 4 ACTIVE SENSORS EXACTLY
sample_rate = 2000;      % Fixed Delsys EMG Sampling Rate (Hz)

%% 2. Connect to Modern Trigno Discover WebSocket API
fprintf('Connecting to Trigno Discover API pipeline...\n');
try
    % Use MATLAB's native webclient socket engine 
    delsys_socket = webclient(discover_url);
    fprintf('Connected to Trigno Discover successfully!\n');
catch ME
    error('Connection refused. Make sure Trigno Discover has Live Preview graphs actively drawing on your screen! Error: %s', ME.message);
end

%% 3. Setup the LSL Network Outlet
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

stream_name = 'Delsys_Trigno_EMG';
stream_type = 'EMG';
source_id = 'Delsys_Trigno_01';

info = lsl_streaminfo(lib, stream_name, stream_type, num_channels, sample_rate, 'cf_float32', source_id);
outlet = lsl_outlet(info);
fprintf('LSL stream "%s" is now broadcasting on your network.\n', stream_name);

%% 4. Data Streaming Loop
stop_fig = figure('Name', 'Stop Delsys Stream', 'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
                  'Position', [450 100 300 100], 'Menu', 'none', 'ToolBar', 'none');
uicontrol('Style', 'text', 'String', 'Press ANY KEY in this window to stop streaming.', ...
          'Position', [20 30 260 40], 'FontSize', 10);

disp('Streaming Delsys data... Keep Trigno Discover live preview running.');

try
    while ~strcmp(get(stop_fig, 'Tag'), 'stop')
        % Read incoming messages from the web socket connection
        if delsys_socket.NumMessagesAvailable > 0
            raw_msg = read(delsys_socket);
            
            % Convert Trigno Discover's modern text/binary data frame format
            if ~isempty(raw_msg)
                % Cast raw incoming matrix bytes to single precision float
                float_data = typecast(raw_msg, 'single');
                
                % Strip system metadata header blocks if present, parse sensor matrix
                if length(float_data) >= num_channels
                    formatted_data = reshape(float_data(1:num_channels), num_channels, 1);
                    
                    % Instantly push the 4 sensor values out to LSL
                    outlet.push_sample(formatted_data);
                end
            end
        end
        pause(0.0005); % Ultra-low pause pacing for high speed 2000Hz rendering
    end
catch ME
    warning('Streaming interrupted: %s', ME.message);
end

%% 5. Cleanup Connection
fprintf('Closing network sockets cleanly...\n');
clear delsys_socket;
if ishandle(stop_fig); close(stop_fig); end
disp('Delsys stream closed.');
