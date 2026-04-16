% MPPT Initialization Sweep Script
clear; clc; close all;

irr = 1000; % W/m2
temp = 25;
sample_time_FLC = 0.005;
sample_time_mv_avg = 1e-4;

% --- Configuration ---
% Replace with your exact Simulink model name (without .slx)
modelName = 'Shading_Fuzzy_single_phase_inverter'; 

% Array of initial duty cycles to test (from near-open to near-short circuit)
init_duty_array = [0.1, 0.3, 0.5, 0.7, 0.9];

% Pre-allocate arrays to store the final steady-state values
final_V = zeros(length(init_duty_array), 1);
final_P = zeros(length(init_duty_array), 1);

% --- Simulation Loop ---
fprintf('Starting MPPT Initial Condition Sweep...\n');

for i = 1:length(init_duty_array)
    % Assign the current initial duty cycle to the base workspace
    % Simulink will read 'init_duty' from here
    init_duty = init_duty_array(i);
    % assignin('base', 'init_duty', init_duty);
    
    fprintf('Running simulation with init_duty = %.2f... ', init_duty);
    
    % Run the simulation
    % 'SrcWorkspace', 'current' ensures it uses the init_duty we just assigned
    out = sim(modelName, 'SrcWorkspace', 'current', 'ReturnWorkspaceOutputs', 'on');
    
    % Extract Voltage and Power arrays
    % If saved as raw Arrays (assuming you named the variables V_pv and P_pv)
    v_data = out.V_PV; 
    p_data = out.P_PV;
    
    % Capture the final resting point (last value in the simulation)
    final_V(i) = v_data(end);
    final_P(i) = p_data(end);
    
    % Save the full transient path of the FIRST run to use as our background P-V curve
    if i == 1
        background_V = v_data;
        background_P = p_data;
    end
    
    fprintf('Settled at V = %.1f V, P = %.1f W\n', final_V(i), final_P(i));
end

% --- Plotting the Results ---
figure('Name', 'FLC Settling Points vs Initial Duty Cycle', 'Color', 'w');
hold on; grid on;

% 1. Plot the background P-V curve (using the transient sweep from the first run)
plot(background_V, background_P, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5, ...
    'DisplayName', 'P-V Curve Transient Path');

% 2. Scatter plot the final resting points, color-coded
colors = lines(length(init_duty_array));
for i = 1:length(init_duty_array)
    scatter(final_V(i), final_P(i), 150, colors(i,:), 'filled', 'o', ...
        'MarkerEdgeColor', 'k', ...
        'DisplayName', sprintf('Final Point (D_{init} = %.2f)', init_duty_array(i)));
end

% Formatting
title('Impact of Initial Duty Cycle on FLC Settling Point (Partial Shading)', 'FontSize', 14);
xlabel('PV Array Voltage (V)', 'FontSize', 12);
ylabel('PV Array Power (W)', 'FontSize', 12);
legend('Location', 'best');
xlim([0 max(background_V)*1.1]);
ylim([0 max(background_P)*1.2]);
hold off;

fprintf('\nSweep Complete. Plot generated.\n');