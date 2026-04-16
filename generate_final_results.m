% =========================================================================
% MASTER REPORT GENERATOR
% Fulfills IIT Bombay DESE Guidelines for Reproducibility
% Generates all Data Tables and Thesis Figures for MPPT Analysis
% =========================================================================
clc; clear; close all;

% --- Automatically add all subfolders to the MATLAB path ---
project_root = fileparts(mfilename('fullpath'));
addpath(genpath(project_root));
disp('Project paths loaded successfully.');

% --- 1. Define Models and Parameters ---
models_all = {'pno_master', 'inc_master', 'flc_master', 'flc_ann_master'};
sim_time   = '1.0';

true_P_STC = 875.4362;     % true max power for uniform 1000 W/m^2
true_P_PSC = 517.5745;     % true max power for the [1000, 1000, 1000, 400, 200] pattern
temp = 25;
sample_time_FLC = 0.005;
sample_time_mv_avg = 1e-4;
init_duty = 0.5;

% Initialize Storage
data_STC = struct();
data_PSC = struct();
results_STC    = [];
results_Dynamic = [];

disp('==============================================================');
disp('PART 1: RUNNING SIMULATIONS & COLLECTING DATA');
disp('==============================================================');

%% --- SECTION A: NORMAL CONDITIONS (STC) ---
disp('Running STC Conditions (1000 W/m^2)...');
assignin('base', 't_step', 2.0); % Cloud never hits
for j = 1:5
    assignin('base', sprintf('irr_init_%d', j), 1000);
    assignin('base', sprintf('irr_final_%d', j), 1000);
end

for i = 1:length(models_all)
    model = models_all{i};
    fprintf('  -> Simulating %s...\n', model);
    load_system(model);
    simOut = sim(model, 'StopTime', sim_time, 'ReturnWorkspaceOutputs', 'on');

    % Use P_PV time as the master reference vector (densest / continuous)
    t_ref = simOut.P_PV.Time;

    % Store signals — discrete/ZOH signals use 'previous', continuous use 'linear'
    data_STC.(model).Time  = t_ref;
    data_STC.(model).P_PV  = simOut.P_PV.Data;
    data_STC.(model).V_PV  = interp1(simOut.V_PV.Time,  simOut.V_PV.Data,  t_ref, 'linear',   'extrap');
    data_STC.(model).I_PV  = interp1(simOut.I_PV.Time,  simOut.I_PV.Data,  t_ref, 'linear',   'extrap');
    data_STC.(model).duty  = interp1(simOut.duty.Time,   simOut.duty.Data,  t_ref, 'previous', 'extrap');

    if contains(model, 'flc')
        data_STC.(model).E      = interp1(simOut.E.Time,      simOut.E.Data,      t_ref, 'previous', 'extrap');
        data_STC.(model).dE     = interp1(simOut.dE.Time,     simOut.dE.Data,     t_ref, 'previous', 'extrap');
        data_STC.(model).E_sat  = interp1(simOut.E_sat.Time,  simOut.E_sat.Data,  t_ref, 'previous', 'extrap');
        data_STC.(model).dE_sat = interp1(simOut.dE_sat.Time, simOut.dE_sat.Data, t_ref, 'previous', 'extrap');
    end

    if strcmp(model, 'flc_ann_master')
        data_STC.(model).trigger      = interp1(simOut.trigger.Time,      double(simOut.trigger.Data),      t_ref, 'previous', 'extrap');
        data_STC.(model).target_duty  = interp1(simOut.target_duty.Time,  simOut.target_duty.Data,  t_ref, 'previous', 'extrap');
        data_STC.(model).pred_V_GMPP  = interp1(simOut.pred_V_GMPP.Time,  simOut.pred_V_GMPP.Data,  t_ref, 'previous', 'extrap');
    end

    % --- Metrics Calculation ---
    time  = t_ref;
    power = data_STC.(model).P_PV;
    ss_power = power(round(0.8 * length(power)):end);

    avg_P = mean(ss_power);
    eff   = (avg_P / true_P_STC) * 100;
    osc   = max(ss_power) - min(ss_power);

    % Settling Time (last exit from ±5% band)
    lower_b     = avg_P * 0.95;
    upper_b     = avg_P * 1.05;
    settle_time = time(end);
    for k = length(power):-1:1
        if power(k) < lower_b || power(k) > upper_b
            settle_time = time(k);
            break;
        end
    end

    metrics.Algorithm          = model;
    metrics.Tracking_Efficiency = round(eff,         2);
    metrics.Settling_Time_s    = round(settle_time,  4);
    metrics.Oscillations_W     = round(osc,          2);
    results_STC = [results_STC; metrics];
end

%% --- SECTION B: DYNAMIC CONDITIONS (PSC) ---
disp('Running Dynamic PSC Conditions (Step at t=0.5s)...');
assignin('base', 't_step', 0.5);
irradiances_final = [1000, 1000, 1000, 400, 200];
for j = 1:5
    assignin('base', sprintf('irr_init_%d', j), 1000);
    assignin('base', sprintf('irr_final_%d', j), irradiances_final(j));
end

for i = 1:length(models_all)
    model = models_all{i};
    fprintf('  -> Simulating %s...\n', model);
    load_system(model);
    simOut = sim(model, 'StopTime', sim_time, 'ReturnWorkspaceOutputs', 'on');

    % Use P_PV time as the master reference vector
    t_ref = simOut.P_PV.Time;

    % Store signals
    data_PSC.(model).Time  = t_ref;
    data_PSC.(model).P_PV  = simOut.P_PV.Data;
    data_PSC.(model).V_PV  = interp1(simOut.V_PV.Time,  simOut.V_PV.Data,  t_ref, 'linear',   'extrap');
    data_PSC.(model).I_PV  = interp1(simOut.I_PV.Time,  simOut.I_PV.Data,  t_ref, 'linear',   'extrap');
    data_PSC.(model).duty  = interp1(simOut.duty.Time,   simOut.duty.Data,  t_ref, 'previous', 'extrap');

    if contains(model, 'flc')
        data_PSC.(model).E      = interp1(simOut.E.Time,      simOut.E.Data,      t_ref, 'previous', 'extrap');
        data_PSC.(model).dE     = interp1(simOut.dE.Time,     simOut.dE.Data,     t_ref, 'previous', 'extrap');
        data_PSC.(model).E_sat  = interp1(simOut.E_sat.Time,  simOut.E_sat.Data,  t_ref, 'previous', 'extrap');
        data_PSC.(model).dE_sat = interp1(simOut.dE_sat.Time, simOut.dE_sat.Data, t_ref, 'previous', 'extrap');
    end

    if strcmp(model, 'flc_ann_master')
        data_PSC.(model).trigger      = interp1(simOut.trigger.Time,      double(simOut.trigger.Data),      t_ref, 'previous', 'extrap');
        data_PSC.(model).target_duty  = interp1(simOut.target_duty.Time,  simOut.target_duty.Data,  t_ref, 'previous', 'extrap');
        data_PSC.(model).pred_V_GMPP  = interp1(simOut.pred_V_GMPP.Time,  simOut.pred_V_GMPP.Data,  t_ref, 'previous', 'extrap');
    end

    % --- Metrics Calculation ---
    time  = t_ref;
    power = data_PSC.(model).P_PV;

    phase2_idx = find(time >= 0.5);
    time_p2    = time(phase2_idx);
    power_p2   = power(phase2_idx);

    p2_ss_power = power_p2(round(0.8 * length(power_p2)):end);
    avg_P_PSC   = mean(p2_ss_power);
    eff_PSC     = (avg_P_PSC / true_P_PSC) * 100;

    lower_b   = avg_P_PSC * 0.95;
    upper_b   = avg_P_PSC * 1.05;
    recov_end = time_p2(end);
    for k = length(power_p2):-1:1
        if power_p2(k) < lower_b || power_p2(k) > upper_b
            recov_end = time_p2(k);
            break;
        end
    end

    trap_status = 'Global Max Found';
    if eff_PSC < 85
        trap_status = 'Trapped (Local Max)';
    end

    dyn_metrics.Algorithm        = model;
    dyn_metrics.PSC_Efficiency   = round(eff_PSC,            2);
    dyn_metrics.Recovery_Time_s  = round(recov_end - 0.5,    4);
    dyn_metrics.Tracking_Status  = trap_status;
    results_Dynamic = [results_Dynamic; dyn_metrics];
end

disp('==============================================================');
disp('PART 2: GENERATING THESIS FIGURES');
disp('==============================================================');

% Common Plot Settings
set(0, 'DefaultLineLineWidth', 1.5);
set(0, 'DefaultAxesFontSize', 12);
set(0, 'DefaultAxesFontWeight', 'bold');

%% FIGURE 1: STC Steady-State Ripple Comparison (Zoomed)
figure('Name', 'Fig 1: STC Steady-State Ripple', 'Position', [100, 100, 800, 400]);
plot(data_STC.pno_master.Time,     data_STC.pno_master.P_PV,     'r');       hold on;
plot(data_STC.inc_master.Time,     data_STC.inc_master.P_PV,     'b');
plot(data_STC.flc_ann_master.Time, data_STC.flc_ann_master.P_PV, 'k', 'LineWidth', 2);
xlim([0.8 1.0]);
ylim([800 950]);
xlabel('Time (s)'); ylabel('PV Power (W)');
title('Steady-State Power Ripple under Standard Test Conditions');
legend('P&O', 'InC', 'Proposed ANN-FLC', 'Location', 'best');
grid on;

%% FIGURE 2: PSC Dynamic Recovery (The Moving Cloud Trap)
figure('Name', 'Fig 2: Dynamic PSC Tracking', 'Position', [150, 150, 800, 400]);
plot(data_PSC.pno_master.Time,     data_PSC.pno_master.P_PV,     'r');       hold on;
plot(data_PSC.flc_master.Time,     data_PSC.flc_master.P_PV,     'b');
plot(data_PSC.flc_ann_master.Time, data_PSC.flc_ann_master.P_PV, 'k', 'LineWidth', 2);
xlim([0 1.0]);
xlabel('Time (s)'); ylabel('PV Power (W)');
title('Dynamic Response to Partial Shading (Step at t=0.5s)');
legend('P&O (Trapped)', 'Standalone FLC (Trapped)', 'ANN-FLC (Global Peak)', 'Location', 'best');
grid on;

%% FIGURE 3: The Deadzone Comparison (Duty Cycle Tracking)
figure('Name', 'Fig 3: Hardware Deadzone Elimination', 'Position', [200, 200, 800, 400]);
plot(data_STC.flc_master.Time,     data_STC.flc_master.duty,     'b');       hold on;
plot(data_STC.flc_ann_master.Time, data_STC.flc_ann_master.duty, 'k', 'LineWidth', 2);
xlim([0 0.8]);
xlabel('Time (s)'); ylabel('Duty Ratio');
title('Duty Cycle Initialization: Standalone FLC vs. Hybrid ANN-FLC');
legend('Standalone FLC (Deadzone Delay)', 'ANN-FLC (Instant Prediction)', 'Location', 'best');
grid on;

%% FIGURE 4: Anatomy of the Hybrid System
figure('Name', 'Fig 4: Internal Hybrid Logic', 'Position', [250, 50, 800, 700]);

subplot(3,1,1);
plot(data_PSC.flc_ann_master.Time, data_PSC.flc_ann_master.P_PV, 'k');
xlim([0.4 0.6]);
ylabel('Power (W)'); title('System Power Response'); grid on;

subplot(3,1,2);
plot(data_PSC.flc_ann_master.Time, data_PSC.flc_ann_master.trigger, 'r', 'LineWidth', 2);
xlim([0.4 0.6]); ylim([-0.2 1.2]);
ylabel('Trigger Signal'); title('5% Power Drop Activation'); grid on;

subplot(3,1,3);
plot(data_PSC.flc_ann_master.Time, data_PSC.flc_ann_master.duty,        'b'); hold on;
plot(data_PSC.flc_ann_master.Time, data_PSC.flc_ann_master.target_duty, 'k--');
xlim([0.4 0.6]);
xlabel('Time (s)'); ylabel('Duty Ratio');
title('Duty Cycle Handover (Integrator Reset)');
legend('Actual System Duty', 'ANN Target Prediction', 'Location', 'best');
grid on;

%% FIGURE 5: FLC Phase Plane (Error vs Change in Error)
figure('Name', 'Fig 5: FLC Logic Saturation', 'Position', [300, 250, 800, 400]);
plot(data_PSC.flc_master.Time, data_PSC.flc_master.E_sat,  'r'); hold on;
plot(data_PSC.flc_master.Time, data_PSC.flc_master.dE_sat, 'b');
xlim([0.4 0.8]);
xlabel('Time (s)'); ylabel('Saturated Input Magnitude');
title('Fuzzy Logic Controller Inputs During Shading Event');
legend('Saturated Error (E)', 'Saturated Change in Error (dE)', 'Location', 'best');
grid on;

%% DISPLAY FINAL MATRICES FOR TABLES
disp(' ');
disp('================================ NORMAL CONDITIONS (STC) ================================');
disp(struct2table(results_STC));
disp('================================ DYNAMIC CONDITIONS (PSC) ===============================');
disp(struct2table(results_Dynamic));
disp('=========================================================================================');
disp('Script execution complete. You may now export the figures for your report.');