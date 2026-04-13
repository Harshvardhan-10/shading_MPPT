%% 0. Data Extraction Check (Handles Array vs. Structure formats)
% If your "To Workspace" blocks were set to "Structure with Time", this extracts the raw arrays.
if isstruct(out.V_PV), v_pv_data = out.V_PV.Data; else, v_pv_data = out.V_PV; end
if isstruct(out.P_PV), p_pv_data = out.P_PV.Data; else, p_pv_data = out.P_PV; end
if isstruct(out.duty), duty_data = out.duty.Data; else, duty_data = out.duty; end
if isstruct(out.E), e_data = out.E.Data; else, e_data = out.E; end
if isstruct(out.dE), de_data = out.dE.Data; else, de_data = out.dE; end
if isstruct(out.E_sat), e_sat_data = out.E_sat.Data; else, e_sat_data = out.E_sat; end
if isstruct(out.dE_sat), de_sat_data = out.dE_sat.Data; else, de_sat_data = out.dE_sat; end

%% 1. Recreate the Digital Clock for the FLC
% Your physical data (out.tout) has 689k points, but control data has 201 points.
t_digital = linspace(out.tout(1), out.tout(end), length(duty_data));

%% Figure 1: MPPT Hill-Climbing Trajectory
figure('Name', 'MPPT Performance: P-V Trajectory', 'NumberTitle', 'off', 'Position', [100, 100, 700, 500]);
plot(v_pv_data, p_pv_data, 'b-', 'LineWidth', 1.5);
hold on;
% Mark where the simulation started
plot(v_pv_data(1), p_pv_data(1), 'g*', 'MarkerSize', 10, 'LineWidth', 2);
% Mark where the FLC finally settled
plot(v_pv_data(end), p_pv_data(end), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');

title('Controller Path on the Shaded P-V Curve');
xlabel('PV Array Voltage (V)');
ylabel('PV Array Power (W)');
grid on;
legend('Tracking Path', 'Start Point (t=0)', 'Final Resting Point', 'Location', 'Best');

%% Figure 2: The Physical System (Continuous High-Speed Data)
figure('Name', 'Physical Hardware Response', 'NumberTitle', 'off', 'Position', [150, 150, 800, 600]);

% Subplot A: Power Output
subplot(2,1,1);
plot(out.tout, p_pv_data, 'b', 'LineWidth', 1.5);
title('PV Array Output Power over Time');
ylabel('Power (W)');
grid on;

% Subplot B: Voltage Output
subplot(2,1,2);
plot(out.tout, v_pv_data, 'r', 'LineWidth', 1.5);
title('PV Array Voltage over Time');
xlabel('Time (seconds)');
ylabel('Voltage (V)');
grid on;

%% Figure 3: The Digital Brain / FLC Logic (Discrete Low-Speed Data)
figure('Name', 'Digital Control Logic (FLC)', 'NumberTitle', 'off', 'Position', [200, 200, 800, 600]);

% Subplot A: Duty Cycle Stepping
subplot(3,1,1);
stairs(t_digital, duty_data, 'k', 'LineWidth', 1.5);
title('MPPT Commanded Duty Cycle (ZOH Output)');
ylabel('Duty Cycle (D)');
ylim([0 1]);
grid on;

% Subplot B: Fuzzy Logic Error Inputs
subplot(3,1,2);
stairs(t_digital, e_data, 'b', 'LineWidth', 1.5);
hold on;
stairs(t_digital, de_data, 'm', 'LineWidth', 1.5);
title('Fuzzy Controller Inputs before saturation (Mathematical Slope)');
xlabel('Time (seconds)');
ylabel('Magnitude');
legend('E (Slope: dP/dV)', 'dE (Change in Slope)');
grid on;

% Subplot B: Fuzzy Logic Error Inputs
subplot(3,1,3);
stairs(t_digital, e_sat_data, 'b', 'LineWidth', 1.5);
hold on;
stairs(t_digital, de_sat_data, 'm', 'LineWidth', 1.5);
title('Fuzzy Controller Inputs (Mathematical Slope)');
xlabel('Time (seconds)');
ylabel('Magnitude');
legend('E (Slope: dP/dV)', 'dE (Change in Slope)');
grid on;