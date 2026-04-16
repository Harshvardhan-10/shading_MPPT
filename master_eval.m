% =========================================================================
% Master MPPT Evaluation Framework
% Automates STC and Dynamic PSC testing across unified master models.
% =========================================================================
clc; clear;

% --- Automatically add all subfolders to the MATLAB path ---
project_root = fileparts(mfilename('fullpath'));
addpath(genpath(project_root));
disp('Subfolders added to path successfully.');

% --- 1. Define The 4 Master Models ---
models_all = {'pno_master', 'inc_master', 'flc_master', 'flc_ann_master'};

% --- 2. Define Theoretical Maximums (Ground Truth) ---
true_P_STC = 875.4362;     % UPDATE: Your true max power for uniform 1000 W/m^2
true_P_PSC = 517.5745;     % UPDATE: Your true max power for the [1000, 1000, 1000, 400, 200] pattern
% temp = 25;
temp = 25;
sample_time_FLC = 0.005;
sample_time_mv_avg = 1e-4;
init_duty = 0.5;
% --- 3. Initialize Output Tables --- 
results_STC = [];
results_Dynamic = [];

disp('Initiating Master Evaluation Sequence...');
disp('==============================================================');

%% SECTION A: NORMAL CONDITIONS (STC) EVALUATION
disp('Running Standard Test Conditions (Uniform 1000 W/m^2)...');

% Force the Step Time beyond simulation length (2.0s) so the cloud never hits
assignin('base', 't_step', 2.0); 

% Set all 5 panels to stay at 1000 W/m^2
for j = 1:5
    assignin('base', sprintf('irr_init_%d', j), 1000);
    assignin('base', sprintf('irr_final_%d', j), 1000); 
end

for i = 1:length(models_all)
    model = models_all{i};
    fprintf('  -> Evaluating %s...\n', model);
    
    % Load and run the simulation
    load_system(model);
    simOut = sim(model, 'ReturnWorkspaceOutputs', 'on');
    
    time = simOut.P_PV.Time;
    power = simOut.P_PV.Data;
    
    % Steady State Analysis (Analyze the last 20% of the simulation)
    ss_start = round(0.8 * length(power));
    ss_power = power(ss_start:end);
    
    avg_P = mean(ss_power);
    eff = (avg_P / true_P_STC) * 100;
    osc = max(ss_power) - min(ss_power); % Peak-to-peak ripple
    
    % Settling Time Calculation (Time to stay within 5% of final average)
    lower_b = avg_P * 0.95; upper_b = avg_P * 1.05;
    settle_time = time(end); % Default to max time if it never perfectly settles
    for k = length(power):-1:1
        if power(k) < lower_b || power(k) > upper_b
            settle_time = time(k); 
            break;
        end
    end
    
    % Append to STC Results
    metrics.Algorithm = model;
    metrics.Tracking_Efficiency = round(eff, 2);
    metrics.Settling_Time_s = round(settle_time, 4);
    metrics.Oscillations_W = round(osc, 2);
    results_STC = [results_STC; metrics];
end

%% SECTION B: DYNAMIC PARTIAL SHADING (MOVING CLOUD) EVALUATION
disp(' ');
disp('Running Dynamic PSC Conditions (Step change at t=0.5s)...');

% Trigger the moving cloud at exactly 0.5s
assignin('base', 't_step', 0.5); 

% Initial: Clear Sky. Final: Severe Shading on Panels 4 & 5
irradiances_final = [1000, 1000, 1000, 400, 200];
for j = 1:5
    assignin('base', sprintf('irr_init_%d', j), 1000);
    assignin('base', sprintf('irr_final_%d', j), irradiances_final(j));
end

for i = 1:length(models_all)
    model = models_all{i};
    fprintf('  -> Evaluating %s...\n', model);
    
    % Load and run the simulation
    load_system(model);
    simOut = sim(model, 'ReturnWorkspaceOutputs', 'on');
    
    time = simOut.P_PV.Time;
    power = simOut.P_PV.Data;
    
    % Isolate Phase 2 (Data strictly AFTER the cloud hits at 0.5s)
    phase2_idx = find(time >= 0.5);
    time_p2 = time(phase2_idx);
    power_p2 = power(phase2_idx);
    
    % Steady State Analysis of Phase 2
    p2_ss_start = round(0.8 * length(power_p2));
    p2_ss_power = power_p2(p2_ss_start:end);
    
    avg_P_PSC = mean(p2_ss_power);
    eff_PSC = (avg_P_PSC / true_P_PSC) * 100;
    
    % Recovery Time Calculation (Time AFTER 0.5s to settle within 5%)
    lower_b = avg_P_PSC * 0.95; upper_b = avg_P_PSC * 1.05;
    recov_end = time_p2(end);
    for k = length(power_p2):-1:1
        if power_p2(k) < lower_b || power_p2(k) > upper_b
            recov_end = time_p2(k); 
            break;
        end
    end
    
    recovery_time = recov_end - 0.5; % Subtract the cloud strike time
    
    % Detect Local Maxima Traps
    % If efficiency is below 85%, it missed the Global Peak
    if eff_PSC < 85
        trap_status = 'Trapped (Local Max)';
    else
        trap_status = 'Global Max Found';
    end
    
    % Append to Dynamic Results
    dyn_metrics.Algorithm = model;
    dyn_metrics.PSC_Efficiency = round(eff_PSC, 2);
    dyn_metrics.Recovery_Time_s = round(recovery_time, 4);
    dyn_metrics.Tracking_Status = trap_status;
    results_Dynamic = [results_Dynamic; dyn_metrics];
end

%% DISPLAY FINAL MATRICES
disp(' ');
disp('================================ NORMAL CONDITIONS (STC) ================================');
disp(struct2table(results_STC));

disp('================================ DYNAMIC CONDITIONS (PSC) ===============================');
disp(struct2table(results_Dynamic));
disp('=========================================================================================');