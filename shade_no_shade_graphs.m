irr_1 = 1000; % W/m2
irr_2 = 1000;
irr_3 = 1000;
irr_4 = 1000;
irr_5 = 1000;
temp = 25;

% Update base workspace in case model reads variables from there
assignin('base','irr_1',irr_1);
assignin('base','irr_2',irr_2);
assignin('base','irr_3',irr_3);
assignin('base','irr_4',irr_4);
assignin('base','irr_5',irr_5);
assignin('base','temp',temp);

% First simulation with initial irradiances
simOut1 = sim('pv_graph_finder.slx','StopTime','1');

% Extract variables from first run (timeseries expected)
if isfield(simOut1,'P_PV'); P1 = simOut1.P_PV; else P1 = simOut1.get('P_PV'); end
if isfield(simOut1,'I_PV'); I1 = simOut1.I_PV; else I1 = simOut1.get('I_PV'); end
if isfield(simOut1,'V_PV'); V1 = simOut1.V_PV; else V1 = simOut1.get('V_PV'); end

% Change irradiances for second simulation
irr_4 = 400;
irr_5 = 200;

% Update base workspace in case model reads variables from there
assignin('base','irr_4',irr_4);
assignin('base','irr_5',irr_5);

% Second simulation
simOut2 = sim('pv_graph_finder.slx','StopTime','1');

% Extract variables from second run
if isfield(simOut2,'P_PV'); P2 = simOut2.P_PV; else P2 = simOut2.get('P_PV'); end
if isfield(simOut2,'I_PV'); I2 = simOut2.I_PV; else I2 = simOut2.get('I_PV'); end
if isfield(simOut2,'V_PV'); V2 = simOut2.V_PV; else V2 = simOut2.get('V_PV'); end

% Convert timeseries to vectors for plotting
if isa(P1,'timeseries'); Pvec1 = P1.Data; else Pvec1 = P1; end
if isa(I1,'timeseries'); Ivec1 = I1.Data; else Ivec1 = I1; end
if isa(V1,'timeseries'); Vvec1 = V1.Data; else Vvec1 = V1; end

if isa(P2,'timeseries'); Pvec2 = P2.Data; else Pvec2 = P2; end
if isa(I2,'timeseries'); Ivec2 = I2.Data; else Ivec2 = I2; end
if isa(V2,'timeseries'); Vvec2 = V2.Data; else Vvec2 = V2; end

% If timeseries data are Nx2 with time in first column, extract second column
if size(Vvec1,2)>1 && all(diff(Vvec1(:,1))>=0); Vplot1 = Vvec1(:,2); else Vplot1 = Vvec1(:); end
if size(Vvec2,2)>1 && all(diff(Vvec2(:,1))>=0); Vplot2 = Vvec2(:,2); else Vplot2 = Vvec2(:); end

Pplot1 = Pvec1(:); Iplot1 = Ivec1(:);
Pplot2 = Pvec2(:); Iplot2 = Ivec2(:);

% ---Filter out mathematical spikes and negative power ---
% Keep only data where Current is between 0A (Voc) and 10A
valid1 = (Iplot1 >= 0) & (Iplot1 <= 10);
Vplot1 = Vplot1(valid1);
Iplot1 = Iplot1(valid1);
Pplot1 = Pplot1(valid1);

valid2 = (Iplot2 >= 0) & (Iplot2 <= 10);
Vplot2 = Vplot2(valid2);
Iplot2 = Iplot2(valid2);
Pplot2 = Pplot2(valid2);

% --- AUTOMATIC PEAK DETECTION ---
% Find the single Global Maximum for the STC curve
[STC_P_max, STC_idx] = max(Pplot1);
STC_V_max = Vplot1(STC_idx);

% Find all local/global maxima for the PSC curve
% 'MinPeakProminence' ensures it ignores tiny numerical ripples and only finds the real humps
[PSC_peaks, PSC_locs] = findpeaks(Pplot2, 'MinPeakProminence', 20);
PSC_V_peaks = Vplot2(PSC_locs);

% --- Plot P-V curves ---
figure('Name', 'P-V Curve Comparison', 'Position', [100, 100, 900, 500]);
plot(Vplot1, Pplot1, 'b-', 'LineWidth', 1.5); hold on;
plot(Vplot2, Pplot2, 'r--', 'LineWidth', 1.5);

% Plot and Label STC Peak
plot(STC_V_max, STC_P_max, 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
text(STC_V_max, STC_P_max + 40, sprintf('STC GMPP\n(%.1fV, %.0fW)', STC_V_max, STC_P_max), ...
    'Color', 'b', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% Plot and Label all PSC Peaks
plot(PSC_V_peaks, PSC_peaks, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
for i = 1:length(PSC_peaks)
    % Dynamically label whether it is a Local or Global max
    if PSC_peaks(i) == max(PSC_peaks)
        label_text = 'PSC GMPP';
    else
        label_text = 'LMPP';
    end
    text(PSC_V_peaks(i), PSC_peaks(i) + 40, sprintf('%s\n(%.1fV, %.0fW)', label_text, PSC_V_peaks(i), PSC_peaks(i)), ...
        'Color', 'r', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end

% Graph Formatting
xlabel('Voltage (V)', 'FontWeight', 'bold'); 
ylabel('Power (W)', 'FontWeight', 'bold');
title('P-V Curve Characteristics under STC and PSC', 'FontWeight', 'bold');
legend('Uniform Irradiance (1000 W/m^2)', 'Partial Shading (1000/1000/1000/400/200 W/m^2)', ...
       'Location', 'southwest');
xlim([0 220]); 
ylim([0 1000]); % Extended to 1000 to leave room for the text annotations
grid on;
% Save the P-V figure as .fig and .png
pvFig = gcf; % current figure is the P-V figure
pvFigName = 'PV_Curve_Comparison';
saveas(pvFig, [pvFigName, '.fig']);
print(pvFig, [pvFigName, '.png'], '-dpng', '-r300'); % 300 DPI

% --- Plot I-V curves ---
figure('Name', 'I-V Curve Comparison', 'Position', [150, 150, 800, 400]);
plot(Vplot1, Iplot1, 'b-', 'LineWidth', 1.5); hold on;
plot(Vplot2, Iplot2, 'r--', 'LineWidth', 1.5);
xlabel('Voltage (V)', 'FontWeight', 'bold'); 
ylabel('Current (A)', 'FontWeight', 'bold');
title('I-V Curve Characteristics under STC and PSC', 'FontWeight', 'bold');
legend('Uniform Irradiance', 'Partial Shading', 'Location', 'southwest');
xlim([0 220]);
ylim([0 6]); % Lock Y-axis to just above Isc (approx 5.something Amps)
grid on;
% Save the I-V figure as .fig and .png
ivFig = gcf; % current figure is the I-V figure
ivFigName = 'IV_Curve_Comparison';
saveas(ivFig, [ivFigName, '.fig']);
print(ivFig, [ivFigName, '.png'], '-dpng', '-r300'); % 300 DPI