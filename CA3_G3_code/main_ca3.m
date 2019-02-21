function main_ca3()
% (MLoNs) Computer Assignment - 3
% Group 3

%% 
clear variables;

close all;

clc;

rng(0); 

%% Load data
% Percentage of data for training
prcntof_data_for_training = 0.8;
% Load household (1) or crimes (0) dataset
flagData = 0;
% 1 means data is within [-1,1] and 0 means that we need to normalize
normalized_data = 1;

if flagData == 1 % load household data
    
    load('Individual_Household/x_data');
    %     load('Individual_Household/y_data'); % not normalized in [-1,1]
    load('Individual_Household/y_data_m11'); % normalized in [-1,1]
    n       = size(matX_input, 1); %#ok<*NODEF> % total nr of samples
    d       = size(matX_input, 2); % dimension of the feature vector
    d1      = d;
    d2      = d;
    n_train = ceil(n * prcntof_data_for_training); % nr of samples for training
    X_train = matX_input(1:n_train, :);
    y_train1= y_sub_metering_1_m11(1:n_train); %y_sub_metering_2; y_sub_metering_3;
    
    if normalized_data == 0
        % since y_train > 1. We modify it
        y_train = y_train1;
        y_train(y_train1<=0) = -1;
        y_train(y_train1>0)  = +1;
    else
        y_train = y_train1;
    end
    
    n_test  = n - n_train;    % nr of test samples
    X_test  = matX_input(n_train+1:end, :);
    y_test1 = y_sub_metering_1_m11(n_train+1:end); %#ok<*COLND> %y_sub_metering_2; y_sub_metering_3;
    
    if normalized_data == 0
        % since y_train > 1. We modify it
        y_test = y_test1;
        y_test(y_test1<=0) = -1;
        y_test(y_test1>0)  = +1;
    else
        y_test = y_test1;
    end
    
    clear matX_input;
    
elseif flagData == 0 % load crimes data
        load('Communities_Crime/x_data');
        load('Communities_Crime/y_data');
        
        n       = size(matX_input, 1); % total nr of samples
        d       = size(matX_input, 2); % dimension of the feature vector
        d1      = ceil(d/2);
        d2      = ceil(d1/2);
        n_train = ceil(n * prcntof_data_for_training); % nr of samples for training
        X_train = matX_input(1:n_train, :);
        y_train = y_data(1:n_train); %y_sub_metering_2; y_sub_metering_3;
        
        n_test  = n - n_train;    % nr of test samples
        X_test  = matX_input(n_train+1:end, :);
        y_test  = y_data(n_train+1:end); %y_sub_metering_2; y_sub_metering_3;
else % generate data
    d       = 10;
    n       = 200;
    data    = logistic_regression_data_generator(n, d);
    X_train = data.x_train.';
    y_train = data.y_train.';
    n_train = numel(y_train);
    
    X_test = data.x_test.';
    y_test = data.y_test.';
    n_test = numel(y_test);
    
end
%% Inputs
algorithms                = {'GD'; 'PGD';'SGD'; 'SVRG'; 'BCD'};

lambda                    = 0.1; %

nrof_iter                 = 500;
nrof_iter_inner_loop      = 20; % SVRG
mini_batch_size           = 10; %round(n*10/100); % for mini-batch SGD
mini_batch_rng_gen        = 1256;


% Create directory to save data
if ~exist('CA3_results', 'dir')
       mkdir('CA3_results')
end
% Create directory to save figures
if ~exist('CA3_figures', 'dir')
       mkdir('CA3_figures')
end
% Open file
fileID = fopen('General_Results.txt','a+');

%% initialize 
w3_init     = randn(d2,1);
W2_init     = randn(d2,d1);
W1_init     = randn(d1,d);


%% Preliminaries: Cost-function, gradient, and Hessian
J_cost_L2_logistic_reg                 = @(X, y,N, W1, W2, w3) (1/N)*norm(w3'*(1./(1+exp(-W2*(1./(1+exp(-W1*X))))))-y,2)^2;

grad_J_cost_L2_w3 = @(X, y,N, W1, W2, w3) 2/N*(w3'*(1./(1+exp(-W2*(1./(1+exp(-W1*X))))))-y)*1./(1+exp(-W2*(1./(1+exp(-W1*X)))));
grad_J_cost_L2_W2 = @(X, y,N, W1, W2, w3) 2/N*(w3'*(1./(1+exp(-W2*(1./(1+exp(-W1*X))))))-y)* (w3 .* exp(-W2*(1./(1+exp(-W1*X))))./(1+exp(-W2*(1./(1+exp(-W1*X))))).^2)*ones(1,d1) .* repmat(1./(1+exp(-W1*X)).',d2,1);
%repmat(w3,1,d).* repmat(exp(-W2*(1./(1+exp(-W1*X))))./(1+exp(-W2*(1./(1+exp(-W1*X))))).^2 ,1,d) .* repmat(1./(1+exp(-W1*X)).',d,1);
grad_J_cost_L2_W1 = @(X, y,N, W1, W2, w3) 2/N*(w3'*(1./(1+exp(-W2*(1./(1+exp(-W1*X))))))-y)* diag(exp(-W1*X)./(1+exp(-W1*X)).^2 * (w3 .* (exp(-W2*(1./(1+exp(-W1*X)))))./(1+exp(-W2*(1./(1+exp(-W1*X))))).^2).' * W2)  * X.';
%diag((exp(-W1*X)./(1+exp(-W1*X)).^2)*ones(1,d) * (w3.*exp(-W2*(1./(1+exp(-W1*X))))./(1+exp(-W2*(1./(1+exp(-W1*X))))).^2 * ones(1,d).*W2)) *ones(1,d).*repmat(X.',d,1);


%% Some more inputs for the algorithms
algo_struct.w3_init                 = w3_init;
algo_struct.W2_init                 = W2_init;
algo_struct.W1_init                 = W1_init;
algo_struct.lambda_reg            = lambda;
algo_struct.cost_func_handle       = J_cost_L2_logistic_reg;
%algo_struct.grad_handle            = grad_J_cost_L2_logistic_reg;
algo_struct.grad_w3_handle = grad_J_cost_L2_w3;
algo_struct.grad_W2_handle = grad_J_cost_L2_W2;
algo_struct.grad_W1_handle = grad_J_cost_L2_W1;

algo_struct.nrof_iter              = nrof_iter;
algo_struct.nrof_iter_inner_loop   = nrof_iter_inner_loop; % valid for SVRG
algo_struct.step_size              = 1e-4; % fixed value is used if enabled
algo_struct.step_size_method       = 'fixed'; %'fixed' 'adaptive' 'adaptive_bb' 'decay'
algo_struct.mini_batch_size        = mini_batch_size; % mini_batch_size==1 => SGD ... mini_batch_size > 1 => mini_batch SGD
algo_struct.mini_batch_rng_gen     = mini_batch_rng_gen; % random number


%% Algorithms: core processing

lambda_vec      = [0];
if strcmpi(algo_struct.step_size_method, 'fixed')
    % 1e-3 is the stepsize used in the figures of the HW
    step_sizes_vec  = 1e-2;%logspace(-5, -3, 5); % if fixed
else
    step_sizes_vec  = algo_struct.step_size; % adaptive
end


norm_grad_vs_iter__gd = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
norm_grad_vs_iter__sgd = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
norm_grad_vs_iter__svrg = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
norm_grad_vs_iter__pgd = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
norm_grad_vs_iter__bcd = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));

step_vs_iter__gd                  = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
step_vs_iter__sgd                 = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
step_vs_iter__svrg                = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
step_vs_iter__pgd                  = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
step_vs_iter__bcd                 = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));

cost_vs_iter_stepsize_train__gd   = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
cost_vs_iter_stepsize_train__sgd  = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
cost_vs_iter_stepsize_train__svrg = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
cost_vs_iter_stepsize_train__pgd   = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));
cost_vs_iter_stepsize_train__bcd  = zeros(nrof_iter+1, numel(lambda_vec), numel(step_sizes_vec));

cost_vs_iter_stepsize_test__gd   = zeros(1, numel(lambda_vec), numel(step_sizes_vec));
cost_vs_iter_stepsize_test__sgd  = zeros(1, numel(lambda_vec), numel(step_sizes_vec));
cost_vs_iter_stepsize_test__svrg = zeros(1, numel(lambda_vec), numel(step_sizes_vec));
cost_vs_iter_stepsize_test__sag  = zeros(1, numel(lambda_vec), numel(step_sizes_vec));
cost_vs_iter_stepsize_test__cvx  = zeros(1, numel(lambda_vec), numel(step_sizes_vec));

%i_lambda = 0;
fprintf('\n');
% Time all the algorithms with these variables
time_fGD = zeros(1,numel(lambda_vec)); % full-GD
time_pGD = zeros(1,numel(lambda_vec)); % perturbed-GD
time_mbSGD = zeros(1,numel(lambda_vec)); % (mini-batch) SGD
time_mbSVRG = zeros(1,numel(lambda_vec)); % (mini-batch) SVRG
time_bcd = zeros(1,numel(lambda_vec)); % (mini-batch) SVRG



for i_lambda = 1:numel(lambda_vec)
    
    lambda                                               = lambda_vec(i_lambda);
    algo_struct.lambda_reg                               = lambda;
    
    
    if ~strcmpi(algo_struct.step_size_method, 'fixed')
        [L_approx, mu_approx] = compute_approx_step_size(X_train, n_train, d, lambda);
    end
    
    for i_step_size = 1:numel(step_sizes_vec)
                
        step_size              = step_sizes_vec(i_step_size);
        algo_struct.step_size  = step_size;
        
        if ~strcmpi(algo_struct.step_size_method, 'fixed')
            algo_struct.step_size  = 1/L_approx;
            % Used for saving the data
            alpha_str = strcat('Alpha_',algo_struct.step_size_method);
        else
            % Used for saving the data
            alpha_str = strcat('Alpha_',algo_struct.step_size_method,'_',num2str(algo_struct.step_size));
        end
        algo_struct.alpha_str = alpha_str;
        
        if mod(i_lambda+1,100)==0; fprintf('.'); end
                
%         full-GD
        tic
        [cost_vs_iter_stepsize_train__gd(:,i_lambda,i_step_size), step_vs_iter__gd(:,i_lambda,i_step_size),...
            norm_grad_vs_iter__gd(:,i_lambda,i_step_size)] = gradient_descent(X_train, y_train, n_train, algo_struct);
        timing = toc;
        time_fGD(i_lambda) = time_fGD(i_lambda) + timing;
        time_fGD_batch = time_fGD(i_lambda); %#ok<*NASGU>

%         %perturbed-GD
        tic
        [cost_vs_iter_stepsize_train__pgd(:,i_lambda,i_step_size), step_vs_iter__pgd(:,i_lambda,i_step_size),...
            norm_grad_vs_iter__pgd(:,i_lambda,i_step_size)] = perturbed_gradient_descent(X_train, y_train, n_train, algo_struct);
        timing = toc;
        time_pGD(i_lambda) = time_pGD(i_lambda) + timing;
        time_pGD_batch = time_pGD(i_lambda); %#ok<*NASGU>

        
        % (mini-batch) SGD
        tic
        [cost_vs_iter_stepsize_train__sgd(:,i_lambda,i_step_size), step_vs_iter__sgd(:,i_lambda,i_step_size),...
            norm_grad_vs_iter__sgd(:,i_lambda,i_step_size)] = stochastic_gradient_descent(X_train, y_train, n_train, algo_struct);
        timing = toc;
        time_mbSGD(i_lambda) = time_mbSGD(i_lambda) + timing;
        time_mbSGD_batch = time_mbSGD(i_lambda);
        
        % (mini-batch) SVRG
        tic
        [ cost_vs_iter_stepsize_train__svrg(:,i_lambda,i_step_size), step_vs_iter__svrg(:,i_lambda,i_step_size),...
            norm_grad_vs_iter__svrg(:,i_lambda,i_step_size)] = stochastic_variance_reduced_gradient(X_train, y_train, n_train, algo_struct);
        timing = toc;
        time_mbSVRG(i_lambda) = time_mbSVRG(i_lambda) + timing;
        time_mbSVRG_batch = time_mbSVRG(i_lambda);
%         
        % block coordinate descent
        tic
        [cost_vs_iter_stepsize_train__bcd(:,i_lambda,i_step_size), step_vs_iter__bcd(:,i_lambda,i_step_size),...
            norm_grad_vs_iter__bcd(:,i_lambda,i_step_size)] = block_coordinate_descent(X_train, y_train, n_train, algo_struct);
        timing = toc;
        time_bcd(i_lambda) = time_bcd(i_lambda) + timing;
        time_bcd_batch = time_bcd(i_lambda); %#ok<*NASGU>

        
%        
        
        
        %% Append the time in the saving data
        % Gradient Descent
        str_GD = strcat('CA3_results/fullGD_',algo_struct.alpha_str,'_Lambda',num2str(lambda_vec(i_lambda)));
        save(strcat(str_GD,'.mat'),'time_fGD_batch','-append');
        % perturbed gradient descent
        str_pGD = strcat('CA3_results/perturbedGD_',algo_struct.alpha_str,'_Lambda',num2str(lambda_vec(i_lambda)));
        save(strcat(str_pGD,'.mat'),'time_pGD_batch','-append');
        % (mini-batch) SGD
        str_mbSGD = strcat('CA3_results/mbSGD_',algo_struct.alpha_str,'_Lambda',num2str(lambda_vec(i_lambda)),...
            '_BatchS',num2str(mini_batch_size));
        save(strcat(str_mbSGD,'.mat'),'time_mbSGD_batch','-append');
        % (mini-batch) SVRG
        str_mbSVRG = strcat('CA3_results/mbSVRG_',algo_struct.alpha_str,'_Lambda',num2str(lambda_vec(i_lambda)),...
            '_BatchS',num2str(mini_batch_size),'_Epoch',num2str(nrof_iter_inner_loop));
        save(strcat(str_mbSVRG,'.mat'),'time_mbSVRG_batch','-append');
        % Block coordinate descent
        str_BCD = strcat('CA3_results/BCD_',algo_struct.alpha_str,'_Lambda',num2str(lambda_vec(i_lambda)));
        save(strcat(str_BCD,'.mat'),'time_bcd_batch','-append');

       %% Print in the file the time used for each
        fprintf(fileID,'############################################################\n');
        fprintf(fileID,'Time for GD with lambda=%1.2f is %1.6f\n',lambda_vec(i_lambda),time_fGD_batch );
        fprintf(fileID,'Time for pGD with lambda=%1.2f is %1.6f\n',lambda_vec(i_lambda),time_pGD_batch );
        fprintf(fileID,'Time for mini-batch SGD with lambda=%1.2f is %1.6f\n',lambda_vec(i_lambda),time_mbSGD_batch );
        fprintf(fileID,'Time for mini-batch SVRG with lambda=%1.2f is %1.6f\n',lambda_vec(i_lambda),time_mbSVRG_batch );
        fprintf(fileID,'Time for BCD with lambda=%1.2f is %1.6f\n',lambda_vec(i_lambda),time_bcd_batch );
        %fprintf(fileID,'Time for mini-batch SAG with lambda=%1.2f is %1.6f\n',lambda_vec(i_lambda),time_mbSAG_batch );
    end
    disp(lambda_vec(i_lambda));
end
fprintf('\n');



fprintf(fileID,'############################################################');
%% Plots
figNr = 0;

% PLOT: iteration vs cost for all algorithms when using a single step size
plot(10*log10(squeeze(cost_vs_iter_stepsize_train__gd)),'LineWidth',2);
hold on
plot(10*log10(squeeze(cost_vs_iter_stepsize_train__pgd)),'LineWidth',2);
plot(10*log10(squeeze(cost_vs_iter_stepsize_train__sgd)),'LineWidth',2);
plot(10*log10(squeeze(cost_vs_iter_stepsize_train__svrg)),'LineWidth',2);
plot(10*log10(squeeze(cost_vs_iter_stepsize_train__bcd)),'LineWidth',2);
xlabel('Iteration');
ylabel('Cost [dB]');


name_fig=strcat('CA3_figures/Cost_Iterations_dataset',num2str(flagData,'%100.0e\n'));
    % Save figure
legend('GD','pGD','SGD','SVRG','BCD','Location','Best');
savefig(name_fig);
print('-depsc','-r300',name_fig);


if numel(step_sizes_vec) > 1 % Plot only if we have many step sizes to plot
    % PLOT: iteration vs. lambda for best step-size
    figNr = figNr + 1;
    y_label_txt = 'iteration'; x_label_txt = 'lambda'; z_label_txt = 'cost [dB]';
    plot_3d_mesh_with_4_subplots(figNr, true, 1, squeeze(cost_vs_iter_stepsize_train__gd(:,:,indices_struct__gd.indx3)),x_label_txt, y_label_txt, z_label_txt, 'GD');
    plot_3d_mesh_with_4_subplots(figNr, false, 2, squeeze(cost_vs_iter_stepsize_train__sgd(:,:,indices_struct__sgd.indx3)),x_label_txt, y_label_txt, z_label_txt, 'SGD');
    plot_3d_mesh_with_4_subplots(figNr, false, 3, squeeze(cost_vs_iter_stepsize_train__svrg(:,:,indices_struct__svrg.indx3)),x_label_txt, y_label_txt, z_label_txt, 'SVRG');
    plot_3d_mesh_with_4_subplots(figNr, false, 4, squeeze(cost_vs_iter_stepsize_train__sag(:,:,indices_struct__sag.indx3)),x_label_txt, y_label_txt, z_label_txt, 'SAG');
    
    try
        figNr = figNr + 1;
        x_label_txt = 'iteration'; y_label_txt = 'step size';
        plot_2d_with_4_subplots(figNr, true, 1, squeeze(step_vs_iter__gd(:,indices_struct__gd.indx2,:)),x_label_txt, y_label_txt, 'GD');
        plot_2d_with_4_subplots(figNr, false, 2, squeeze(step_vs_iter__sgd(:,indices_struct__sgd.indx2,:)),x_label_txt, y_label_txt, 'SGD');
        plot_2d_with_4_subplots(figNr, false, 3, squeeze(step_vs_iter__svrg(:,indices_struct__svrg.indx2,:)),x_label_txt, y_label_txt, 'SVRG');
        plot_2d_with_4_subplots(figNr, false, 4, squeeze(step_vs_iter__sag(:,indices_struct__sag.indx2,:)),x_label_txt, y_label_txt, 'SAG');
    catch
    end
    
    % PLOT: Lambda vs. step size for best iteration
    if strcmpi(algo_struct.step_size_method, 'fixed')
        figNr = figNr + 1;
        y_label_txt = 'lambda'; x_label_txt = 'step size'; z_label_txt = 'cost [dB]';
        plot_3d_mesh_with_4_subplots(figNr, true, 1, squeeze(cost_vs_iter_stepsize_train__gd(indices_struct__gd.indx1,:,:)),x_label_txt, y_label_txt, z_label_txt, 'GD');
        plot_3d_mesh_with_4_subplots(figNr, false, 2, squeeze(cost_vs_iter_stepsize_train__sgd(indices_struct__sgd.indx1,:,:)),x_label_txt, y_label_txt, z_label_txt, 'SGD');
        plot_3d_mesh_with_4_subplots(figNr, false, 3, squeeze(cost_vs_iter_stepsize_train__svrg(indices_struct__svrg.indx1,:,:)),x_label_txt, y_label_txt, z_label_txt, 'SVRG');
        plot_3d_mesh_with_4_subplots(figNr, false, 4, squeeze(cost_vs_iter_stepsize_train__sag(indices_struct__sag.indx1,:,:)),x_label_txt, y_label_txt, z_label_txt, 'SAG');
    end
    
    % PLOT: iteration vs. step-size for best lambda
    if strcmpi(algo_struct.step_size_method, 'fixed')
        figNr = figNr + 1;
        y_label_txt = 'iteration'; x_label_txt = 'step size'; z_label_txt = 'cost [dB]';
        plot_3d_mesh_with_4_subplots(figNr, true, 1, squeeze(cost_vs_iter_stepsize_train__gd(:,indices_struct__gd.indx2,:)),x_label_txt, y_label_txt, z_label_txt, 'GD');
        plot_3d_mesh_with_4_subplots(figNr, false, 2, squeeze(cost_vs_iter_stepsize_train__sgd(:,indices_struct__sgd.indx2,:)),x_label_txt, y_label_txt, z_label_txt, 'SGD');
        plot_3d_mesh_with_4_subplots(figNr, false, 3, squeeze(cost_vs_iter_stepsize_train__svrg(:,indices_struct__svrg.indx2,:)),x_label_txt, y_label_txt, z_label_txt, 'SVRG');
        plot_3d_mesh_with_4_subplots(figNr, false, 4, squeeze(cost_vs_iter_stepsize_train__sag(:,indices_struct__sag.indx2,:)),x_label_txt, y_label_txt, z_label_txt, 'SAG');
    end
end
fclose(fileID);
end % of main function

% Additional functions necessary to manipulate the necessary parameters are
% coming now

%% compute approximate step size based on the approx Hessian of the cost function of the logistic regression
function [L, mu] = compute_approx_step_size(X, N, d, lambda)
        
    J_hessian_cost_approx = (1/N)* (X.' * X) + lambda*eye(d);
    
    eig_values            = eig(J_hessian_cost_approx);
    L                     = max(eig_values);
    mu                    = min(eig_values);
    
end

%% Find minima of a matrix
function [min_val, indices_struct] = find_minima_multidimensional_array(X, dim_len)

[min_val,idx]            = min(X(:));
switch dim_len
    case 1
        [indx1]                   = ind2sub(size(X),idx);
        indices_struct.indx1      = indx1;
    case 2
        [indx1,indx2]            = ind2sub(size(X),idx);
        indices_struct.indx1     = indx1;
        indices_struct.indx2     = indx2;
    case 3
        [indx1, indx2, indx3]    = ind2sub(size(X),idx);
        indices_struct.indx1     = indx1;
        indices_struct.indx2     = indx2;
        indices_struct.indx3     = indx3;
    case 4
        [indx1, indx2, indx3, indx4]  = ind2sub(size(X),idx);
        indices_struct.indx1          = indx1;
        indices_struct.indx2          = indx2;
        indices_struct.indx3          = indx3;
        indices_struct.indx4          = indx4;
    otherwise        
        error('not supported yet for dim_len > 4, but easy to extend');
end

end

%% RUN CVX
function w_cvx  = run_cvx_for_l2_logistic_regression(X, y, N, ~, lambda)

cvx_begin quiet
    variable w_cvx(d,1) 
    minimize ( (1/N)*sum(log(1 + exp(- y.* (X*w_cvx))), 1) + lambda*0.5* power(norm(w_cvx,2), 2) )   
cvx_end

end

%% Plotting functions
function plot_2d_with_4_curves(figNr, clf_flag, subplot_nr, cost_multidim_array, x_label_txt, y_label_txt)

figure(figNr); 
if clf_flag
clf;
end
% Colors
colors{1} = [1 0 0]; % red
colors{2} = [0 0 1]; % blue
colors{3} = [0 0 0]; % black
colors{4} = [141 20 223]./ 255; % dark purple
hold on;grid;box on;
plot(10*log10(squeeze(cost_multidim_array)),'LineWidth',2,'Color',colors{subplot_nr});
xlabel(x_label_txt);
ylabel(y_label_txt);
end

function plot_2d_with_4_curves_and_subplots(figNr, subplot_nr, cost_multidim_array, x_label_txt, y_label_txt,title_txt)

figure(figNr);
% Colors
colors{1} = [1 0 0]; % red
colors{2} = [0 0 1]; % blue
colors{3} = [0 0 0]; % black
colors{4} = [141 20 223]./ 255; % dark purple
hold on;grid;box on;
subplot(2,2,figNr-1);
plot(10*log10(squeeze(cost_multidim_array)),'LineWidth',2,'Color',colors{subplot_nr});
xlabel(x_label_txt);
ylabel(y_label_txt);
title(title_txt);
end

function plot_3d_mesh_with_4_subplots(figNr, clf_flag, subplot_nr, cost_multidim_array, x_label_txt, y_label_txt, z_label_txt, title_txt)

figure(figNr); 
if clf_flag
clf;
end
subplot(2,2,subplot_nr);
mesh(10*log10(squeeze(cost_multidim_array)));
view(30, 30);
shading interp;
xlabel(x_label_txt);
ylabel(y_label_txt);
zlabel(z_label_txt);
title(title_txt);
end

function plot_2d_with_4_subplots(figNr, clf_flag, subplot_nr, cost_multidim_array, x_label_txt, y_label_txt, title_txt)

figure(figNr); 
if clf_flag
clf;
end
subplot(2,2,subplot_nr);
plot(10*log10(squeeze(cost_multidim_array)));
xlabel(x_label_txt);
ylabel(y_label_txt);
title(title_txt);
end