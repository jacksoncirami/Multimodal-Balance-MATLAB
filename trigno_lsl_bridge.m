
delsys_ip = 'localhost'; % Change if Trigno is on another PC
emg_port = 50043;        % Default Delsys EMG server port
num_channels = 16;       % Adjust to match your active Trigno sensors
sample_rate = 2000;      % Trigno EMG fixed sampling rate (Hz)

%% 2. Connect to the Delsys Server via TCP/IP
fprintf('Connecting to Delsys Trigno Server at %s:%d...\n', delsys_ip, emg_port);
try
    % Use large input buffer to avoid dropping 2000Hz packets
    delsys_client = tcpclient(delsys_ip, emg_port, 'Timeout', 10);
    fprintf('Connected to Delsys hardware successfully!\n');
catch ME
    error('Could not connect to Delsys. Is Trigno Control Utility running?');
end

%% 3. Setup the LSL Outlet
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

% Define stream parameters
stream_name = 'Delsys_Trigno_EMG';
stream_type = 'EMG';
source_id = 'Delsys_Trigno_01';

% Create stream description (cf_float32 is single-precision float)
info = lsl_streaminfo(lib, stream_name, stream_type, num_channels, sample_rate, 'cf_float32', source_id);
outlet = lsl_outlet(info);
fprintf('LSL stream "%s" is now broadcasting on the network.\n', stream_name);

%% 4. Data Streaming Loop
% Delsys streams data as 32-bit single precision floats (4 bytes per sample)
bytes_per_sample = 4 * num_channels; 

disp('Streaming data... Press Ctrl+C to stop.');
try
    while true
        % Check if a complete packet of data is waiting in the buffer
        bytes_available = delsys_client.NumBytesAvailable;
        
        if bytes_available >= bytes_per_sample
            % Calculate how many full multi-channel samples we can read
            samples_to_read = floor(bytes_available / bytes_per_sample);
            total_bytes = samples_to_read * bytes_per_sample;
            
            % Read binary float data from the network stream
            raw_data = read(delsys_client, total_bytes, 'uint8');
            
            % Convert raw bytes into single-precision matrix
            float_data = typecast(raw_data, 'single');
            
            % Reshape into [channels x samples]
            formatted_data = reshape(float_data, num_channels, samples_to_read);
            
            % Push each multi-channel sample sequentially to LSL
            for i = 1:samples_to_read
                outlet.push_sample(formatted_data(:, i));
            end
        end
        
        % Minimal pause to keep CPU usage low without lagging the data
        pause(0.001); 
    end
catch ME
    fprintf('\nStreaming stopped.\n');
end

%% 5. Cleanup Connection
clear delsys_client;
