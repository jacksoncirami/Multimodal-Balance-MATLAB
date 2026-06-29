%% 1. Configuration & Setup
clear; clc;

% UPDATE THIS: Path to the 64-bit (x64) Bertec SDK DLL
bertec_dll_path = 'C:\Users\YOUR_USERNAME\Downloads\Bertec_SDK\x64\BertecDevice.dll'; 

fprintf('Loading Bertec .NET Assembly...\n');
try
    % Load the 64-bit assembly into MATLAB
    asm = NET.addAssembly(bertec_dll_path);
    deviceManager = Bertec.Device.DeviceManager();
    deviceManager.Initialize();
    fprintf('Bertec hardware initialized successfully!\n');
catch ME
    error('Failed to load Bertec DLL. Check path or ensure it is the 64-bit version. Error: %s', ME.message);
end

%% 2. Setup the LSL Outlet
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

% Define stream parameters (6 channels: Fx, Fy, Fz, Mx, My, Mz)
stream_name = 'BertecForcePlate';
stream_type = 'Force';
num_channels = 6; 
sample_rate = 1000; % Default Bertec sampling rate (Hz)
source_id = 'Bertec_FP_01';

info = lsl_streaminfo(lib, stream_name, stream_type, num_channels, sample_rate, 'cf_float32', source_id);
outlet = lsl_outlet(info);
fprintf('LSL stream "%s" is now broadcasting.\n', stream_name);

%% 3. Data Streaming Loop
% Create a figure window to capture a clean keypress stop event
stop_fig = figure('Name', 'Stop Bertec Stream', 'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
                  'Position', [100 100 300 100], 'Menu', 'none', 'ToolBar', 'none');
uicontrol('Style', 'text', 'String', 'Press ANY KEY in this window to stop streaming.', ...
          'Position', [20 30 260 40], 'FontSize', 10);

disp('Streaming Bertec data... Select the popup window and press any key to stop.');

try
    while ~strcmp(get(stop_fig, 'Tag'), 'stop')
        % Fetch data array from Bertec SDK
        forceData = deviceManager.GetLatestData();
        
        % If data exists, push it out to the network via LSL
        if ~isempty(forceData)
            outlet.push_sample(forceData);
        end
        
        % Brief pause to regulate execution speed without lagging
        pause(0.001); 
    end
catch ME
    warning('Streaming interrupted: %s', ME.message);
end

%% 4. Cleanup Connection
fprintf('Closing hardware connections...\n');
deviceManager.Close();
if ishandle(stop_fig); close(stop_fig); end
disp('Bertec stream closed cleanly.');
