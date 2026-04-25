% =========================================================================
% Dataset Generation (Unique Physical Cases Only)
% =========================================================================

% 1. Define High-Granularity Irradiance Levels (W/m^2)
irr_levels = 100:100:1000;
temp = 25;

disp('Step 1: Generating permutations and finding unique physical cases...');

% Generate all possible permutations in memory
[G1, G2, G3, G4, G5] = ndgrid(irr_levels, irr_levels, irr_levels, irr_levels, irr_levels);
all_permutations = [G1(:), G2(:), G3(:), G4(:), G5(:)];

% Sort each row in descending order to identify physical equivalents
sorted_permutations = sort(all_permutations, 2, 'descend');

% Extract unique physical combinations
[unique_combos, ~, ~] = unique(sorted_permutations, 'rows');
num_sims  = size(unique_combos, 1);
num_total = size(all_permutations, 1);

fprintf('Total Permutations Ignored: %d\n', num_total);
fprintf('Actual Unique Physical Scenarios to Save: %d\n\n', num_sims);

% Preallocate result arrays
V_gmpp_unique = zeros(num_sims, 1);
P_max_unique  = zeros(num_sims, 1);

% Load the Simulink model once
load_system('pv_graph_finder');

% =========================================================================
% Step 2: Run Simulink for the unique combinations
% =========================================================================
fprintf('Step 2: Running Simulink for unique combinations (grab a coffee!)...\n\n');

bar_width = 40;   % Width of the progress bar in characters
tic;              % Start overall timer

for i = 1:num_sims

    % --- Extract current irradiance set ---
    g1 = unique_combos(i, 1);
    g2 = unique_combos(i, 2);
    g3 = unique_combos(i, 3);
    g4 = unique_combos(i, 4);
    g5 = unique_combos(i, 5);

    % --- Push variables to base workspace for Simulink ---
    assignin('base', 'irr_1', g1);
    assignin('base', 'irr_2', g2);
    assignin('base', 'irr_3', g3);
    assignin('base', 'irr_4', g4);
    assignin('base', 'irr_5', g5);

    % --- Run simulation ---
    simOut = sim('pv_graph_finder', 'ReturnWorkspaceOutputs', 'on');

    % Extract Voltage and Power arrays from the workspace
    V_array = simOut.V_PV; 
    P_array = simOut.P_PV; 
    
    % --- Hardware Threshold (0.1 < d < 0.9) ---
    % Set the physical minimum voltage based on D_max = 0.9
    V_min_threshold = 40; 
    
    % Create a logical mask: Only keep data where voltage is above 40V
    valid_indices = V_array >= V_min_threshold;
    
    % Filter the arrays
    valid_V_array = V_array(valid_indices);
    valid_P_array = P_array(valid_indices);
    
    % Find the Global Maximum Power Point strictly on the VALID data
    [max_power, local_target_index] = max(valid_P_array);
    V_gmpp = valid_V_array(local_target_index);

    % --- Store results ---
    V_gmpp_unique(i) = V_gmpp;
    P_max_unique(i)  = max_power;

    % ── Live progress bar ─────────────────────────────────────────────
    elapsed = toc;
    eta     = (elapsed / i) * (num_sims - i);      % Estimated time remaining
    pct     = i / num_sims;
    filled  = round(pct * bar_width);

    bar = [repmat(char(9608), 1, filled), ...       % █ filled portion
           repmat(char(9617), 1, bar_width - filled)]; % ░ empty portion

    fprintf('\r  [%s] %5.1f%%  %d/%d  Elapsed: %s  ETA: %s Irr: %d %d %d %d %d | V=%.2fV  P=%.2fW', ...
        bar, pct * 100, i, num_sims, ...
        format_duration(elapsed), format_duration(eta), ...
        g1, g2, g3, g4, g5, V_gmpp, max_power);
    % ──────────────────────────────────────────────────────────────────

end

fprintf('\n\n'); % Move past the progress bar line
elapsed_total = toc;
fprintf('Simulations complete! Total time: %s\n\n', format_duration(elapsed_total));

% =========================================================================
% Step 3: Save the dataset
% =========================================================================
disp('Step 3: Saving dataset...');

% Combine UNIQUE inputs and outputs into final dataset matrix
final_dataset = [unique_combos, V_gmpp_unique, P_max_unique];

dataset_table = array2table(final_dataset, 'VariableNames', ...
    {'G1', 'G2', 'G3', 'G4', 'G5', 'V_GMPP', 'P_Max'});

% Save as a new CSV to differentiate from the inflated one
writetable(dataset_table, 'ANN_Training_Sorted_Only.csv');

disp('Dataset is ready');


% =========================================================================
% Helper Function: Format seconds into human-readable duration string
% =========================================================================
function s = format_duration(seconds)
    if seconds < 60
        s = sprintf('%ds', round(seconds));
    elseif seconds < 3600
        s = sprintf('%dm %ds', floor(seconds / 60), round(mod(seconds, 60)));
    else
        s = sprintf('%dh %dm', floor(seconds / 3600), floor(mod(seconds, 3600) / 60));
    end
end