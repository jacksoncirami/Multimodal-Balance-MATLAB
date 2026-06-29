%% 1. Configuration & Network Setup
clear; clc;

% UPDATE THIS: Path to your pre-compiled Win64 LSL folder
addpath(genpath('C:\Users\hpuminds\Downloads\liblsl-Matlab-1.14.0-Win_amd64_R2020b\liblsl-Matlab'));

% Default Bertec network parameters
bertec_ip = '127.0.0.1'; % Localhost
bertec_port = 5000;       % Adjust to match your Bertec server port settings
num_channels = 6;         % Fx, Fy, Fz, Mx, My, Mz

fprintf('Connecting to Bertec Network Stream at %s:%d...\n', bertec_ip, bertec_port);
try
    % Open a native network client connection inside MATLAB
    bertec_client = tcpclient(bertec_ip, bertec_port, 'Timeout', 10);
    fprintf('Connected to Bertec background server successfully!\n');
catch ME
    error('Could not connect. Ensure your Bertec Device Utility app is open and streaming.');
end

%% 2. Setup the LSL Network Outlet
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

stream_name = 'BertecForcePlate';
stream_type = 'Force';
sample_rate = 1000; 
source_id = 'Bertec_FP_01';

info = lsl_streaminfo(lib, stream_name, stream_type, num_channels, sample_rate, 'cf_float32', source_id);
outlet = lsl_outlet(info);
fprintf('LSL stream "%s" is now broadcasting.\n', stream_name);

%% 3. Data Streaming Loop
stop_fig = figure('Name', 'Stop Bertec Stream', 'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
                  'Position', [100 100 300 100], 'Menu', 'none', 'ToolBar', 'none');
uicontrol('Style', 'text', 'String', 'Press ANY KEY in this window to stop streaming.', ...
          'Position', [20 30 260 40], 'FontSize', 10);

bytes_per_sample = 4 * num_channels; % 4 bytes per float32 channel sample
disp('Streaming Bertec data... Select the popup window and press any key to stop.');

try
    while ~strcmp(get(stop_fig, 'Tag'), 'stop')
        bytes_available = bertec_client.NumBytesAvailable;
        
        if bytes_available >= bytes_per_sample
            samples_to_read = floor(bytes_available / bytes_per_sample);
            total_bytes = samples_to_read * bytes_per_sample;
            
            % Read raw binary data blocks directly through the network
            raw_data = read(bertec_client, total_bytes, 'uint8');
            float_data = typecast(raw_data, 'single');
            formatted_data = reshape(float_data, num_channels, samples_to_read);
            
            % Push samples sequentially out to LSL
            for i = 1:samples_to_read
                outlet.push_sample(formatted_data(:, i));
            end
        end
        pause(0.001); 
    end
catch ME
    warning('Streaming interrupted: %s', ME.message);
end

%% 4. Cleanup Connection
fprintf('Closing network sockets...\n');
clear bertec_client;
if ishandle(stop_fig); close(stop_fig); end
disp('Bertec stream closed cleanly.');
