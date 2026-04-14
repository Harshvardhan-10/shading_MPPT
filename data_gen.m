% =========================================================================
% Optimized Automated Dataset Generation with Artificial Inflation
% =========================================================================

% 1. Define High-Granularity Irradiance Levels (W/m^2)
irr_levels = 100:50:1000;
temp = 25;

disp('Step 1: Generating permutations and finding unique physical cases...');

% Generate all possible permutations in memory
[G1, G2, G3, G4, G5] = ndgrid(irr_levels, irr_levels, irr_levels, irr_levels, irr_levels);
all_permutations = [G1(:), G2(:), G3(:), G4(:), G5(:)];

% Sort each row in descending order to identify physical equivalents
sorted_permutations = sort(all_permutations, 2, 'descend');

% Extract unique physical combinations
% 'ic' maps every permutation back to its unique physical simulation
[unique_combos, ~, ic] = unique(sorted_permutations, 'rows');
num_sims  = size(unique_combos, 1);
num_total = size(all_permutations, 1);

fprintf('Total Permutations for ANN : %d\n', num_total);
fprintf('Actual Simulink Runs Required: %d\n\n', num_sims);

% Preallocate result arrays
V_gmpp_unique = zeros(num_sims, 1);
P_max_unique  = zeros(num_sims, 1);

% Load the Simulink model once
load_system('pv_graph_finder');

% =========================================================================
% Step 2: Run Simulink for unique combinations only
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

    % --- Extract voltage and power arrays ---
    V_array = simOut.V_PV;
    P_array = simOut.P_PV;

    % --- Find Global Maximum Power Point ---
    [max_power, target_index] = max(P_array);
    V_gmpp = V_array(target_index);

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

    fprintf('\r  [%s] %5.1f%%  %d/%d  Elapsed: %s  ETA: %s  | V=%.2fV  P=%.2fW', ...
        bar, pct * 100, i, num_sims, ...
        format_duration(elapsed), format_duration(eta), ...
        V_gmpp, max_power);
    % ──────────────────────────────────────────────────────────────────

end

fprintf('\n\n'); % Move past the progress bar line
elapsed_total = toc;
fprintf('Simulations complete! Total time: %s\n\n', format_duration(elapsed_total));

% =========================================================================
% Step 3: Artificially Inflate Dataset to Full Permutation Count
% =========================================================================
disp('Step 3: Artificially inflating dataset to full permutation count...');

% Use 'ic' mapping to instantly expand unique results to all permutations
full_V_gmpp = V_gmpp_unique(ic);
full_P_max  = P_max_unique(ic);

% Combine inputs and outputs into final dataset matrix
final_dataset = [all_permutations, full_V_gmpp, full_P_max];

% =========================================================================
% Step 4: Save the Dataset
% =========================================================================
disp('Step 4: Saving dataset...');

dataset_table = array2table(final_dataset, 'VariableNames', ...
    {'G1', 'G2', 'G3', 'G4', 'G5', 'V_GMPP', 'P_Max'});

% CSV is much faster and safer than XLSX for large datasets
writetable(dataset_table, 'ANN_Training_Dataset_100k.csv');

disp('Done! Your dataset is ready for ANN training.');


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