% --- FUZZY LOGIC THESIS PLOTS ---
clc; close all;

% 1. Load your FIS file (Change the name to match your actual file!)
fis = readfis('fuzzy_mppt.fis'); 

% 2. Plot Membership Function: Error (E)
figure('Name', 'MF: Error', 'Position', [100, 100, 600, 300]);
plotmf(fis, 'input', 1);
title('Membership Functions for Error (E)', 'FontWeight', 'bold');
xlabel('Normalized Error');

% 3. Plot Membership Function: Change in Error (dE)
figure('Name', 'MF: Change in Error', 'Position', [150, 150, 600, 300]);
plotmf(fis, 'input', 2);
title('Membership Functions for Change in Error (dE)', 'FontWeight', 'bold');
xlabel('Normalized Change in Error');

% 4. Plot Membership Function: Output (Duty Cycle Change)
figure('Name', 'MF: Output', 'Position', [200, 200, 600, 300]);
plotmf(fis, 'output', 1);
title('Membership Functions for Duty Cycle Step (dD)', 'FontWeight', 'bold');
xlabel('Duty Cycle Step Size');

% 5. The "Money Shot": 3D Control Surface
figure('Name', '3D Control Surface', 'Position', [250, 250, 700, 600]);
gensurf(fis);
title('Fuzzy Logic 3D Control Surface', 'FontWeight', 'bold');
xlabel('Error (E)'); 
ylabel('Change in Error (dE)'); 
zlabel('Output Step (dD)');
colormap('jet'); % Adds the classic academic color grading