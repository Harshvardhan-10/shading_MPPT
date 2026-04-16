% 1. Load the perfectly sorted data
clean_data = readtable('ANN_Training_Sorted_Only.csv');
inputs = [clean_data.G1, clean_data.G2, clean_data.G3, clean_data.G4, clean_data.G5]'; 
targets = clean_data.V_GMPP'; 

% 2. Build a 2-Hidden-Layer Network [Layer1, Layer2]
% 20 neurons for logic separation, 10 neurons for voltage calculation
net = fitnet([20, 10]); 

% 3. Disable the "Early Stopping" trap
% This forces MATLAB to keep training even if the validation error bounces
net.trainParam.max_fail = 100; 
net.trainParam.epochs = 1000;  % Give it plenty of time to converge

% 4. Train the Network
disp('Training Deep Network. Please wait...');
[net, tr] = train(net, inputs, targets);

% 5. Test the Network and Plot
outputs = net(inputs);
errors = gsubtract(targets, outputs);
performance = perform(net, targets, outputs);

% Open the Regression and Error graphs automatically
figure; plotregression(targets, outputs, 'Regression');
figure; ploterrhist(errors, 'Error Histogram');

disp('Training Complete!');