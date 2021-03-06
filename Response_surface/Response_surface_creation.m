%Create response surface for each aeroderivative and test them against each other
% Test with regression and neural networks
%Load data
load('RS_AVL_CLEAN.mat')
addpath('D:\misc_functs_matlab\ExportFigs')%Personal file for plotting figures

Y = RS_AVL_Cm0;% Choose variable to obtain

% Create Validation batch for each relevant aeroderivative
randomPoints = round(rand(1000,1)*1000);
validation_input = RS_AVL_input(randomPoints(:),:);
validation_output = Y(randomPoints(:));
RS_AVL_input(randomPoints(:),:)=[];
Y(randomPoints(:))=[];
% RS_AVL_CLa(randomPoints(:))=[];% RS_AVL_Cm0(randomPoints(:))=[];% RS_AVL_Cma(randomPoints(:))=[];

%Define regressors
X = RS_AVL_input;
%Define models to test
modelfun1 = @AVL_regression_coupled;
modelfun2 = @AVL_regression_simple;
modelfun3 = @AVL_regression_1st_order;

%Number of regressors for each model
beta0_1=zeros(66,1);%Verify that the starting point does not affect the results 
beta0_2=zeros(46,1);
beta0_3=zeros(11,1);

%% Regression

%Algorithm options
% opts = statset('nlinfit');
% opts.RobustWgtFun = 'bisquare';
% opts.MaxIter = 10000;

%Run model
% mdl = fitnlm(X,Y,modelfun,beta0,'Options',opts)
mdl1 = fitnlm(X,Y,modelfun1,beta0_1)
mdl2 = fitnlm(X,Y,modelfun2,beta0_2)
mdl3 = fitnlm(X,Y,modelfun3,beta0_3)

%Validate against the validation batch
i=1:length(RS_AVL_input);
error1 =predict(mdl1,RS_AVL_input(i,:))-Y(i)';%test batch
error_validation1 = predict(mdl1,validation_input)-validation_output';%validation batch
error2 =predict(mdl2,RS_AVL_input(i,:))-Y(i)';
error_validation2 = predict(mdl2,validation_input)-validation_output';
error3 =predict(mdl3,RS_AVL_input(i,:))-Y(i)';
error_validation3 = predict(mdl3,validation_input)-validation_output';

%Plot the results. Verify that validation results are OK.
edges= -0.02:0.001:0.02;

histogram(error1,edges)
hold on 
histogram(error_validation1,edges)
xlim([edges(1),edges(end)])
xlabel('Error')
ylabel('Number of points')
title('Regression histogram C_{L0}')
grid on
legend({'Regression points','Validation'})

set(gcf,'color','w');
export_fig('B')

%Obtain the MSE for each model
MSE1 = (sum(error1.^2)+sum(error_validation1.^2))/length(Y);
MSE2 = (sum(error2.^2)+sum(error_validation2.^2))/length(Y);
MSE3 = (sum(error3.^2)+sum(error_validation3.^2))/length(Y);

%% Neural Networks

X = RS_AVL_input';
T = Y;%Target, equivalent 
Xi=[];%Initial input delays
Ai=[];%Initial layer delay
EW=[];%Error weights

net = feedforwardnet(20);%Number of nodes in the neural network

%options
net.trainParam.epochs = 10000000;% Number of iterations/generations
net.trainParam.time = 11%*60; %time limit(s)
% net.trainParam.min_grad = 10^-7; %Gradient limit
net.trainParam.goal = 0;%Performance goal
net.trainParam.max_fail = 100;%Maximum validation failures/ number of iterations with the NN not improving performance

%Use parallel computing
[mdl1NN,tr] = train(net,X,T,Xi,Ai,EW,'useParallel','yes','showResources','yes',...
    'useGPU','yes','CheckpointFile','MyCheckpoint','CheckpointDelay',120);

%Calculate errors
errorNN = mdl1NN(RS_AVL_input(:,:)')-Y(:)';%test batch
error_validationNN = mdl1NN(validation_input')-validation_output;%validation batch

%Obtain the MSE for the model
MSE1_test = (sum(errorNN.^2)/length(Y);
MSE1_validation =sum(error_validationNN.^2))/length(Y);

%Other types of nets

%Algorithm options
algorithm = 'traingdm';%Change training algorithm. 'traingdm': Gradient descent with momentum
%'traingdx':Adaptative learning and momentum backpropagation
%'trainbfg': BFGS Quasi-Newton
%'trainbr': Bayesian Regularization

t_limit= 11*60;
net2 = net_generation('cascadeforward',35,algorithm,t_limit);
[mdl2NN,tr] = train(net2,X,T,Xi,Ai,EW,'useParallel','yes','showResources','yes',...
    'useGPU','yes','CheckpointFile','MyCheckpoint','CheckpointDelay',120);


% Test for different neural networks
net_type = {'feedforward','cascadeforward'}
n_nodes = [25,35,45];
algorithms = {'trainlm','trainrp','trainscg','trainbfg'};

net_aux = net_generation('cascadeforward',35,algorithm,t_limit);
t_limit = 10*60;

for i=1:length(net_type)
    for j=1:length(n_nodes)
        for k=1:length(algorithms)
           net_aux =  net_generation(net_type{i},n_nodes(j),algorithms{k},t_limit);
           [mdlNN{i,j,k},tr] = train(net_aux,X,T,Xi,Ai,EW,'useParallel','yes','showResources','yes',...
               'useGPU','yes','CheckpointFile','MyCheckpoint','CheckpointDelay',120);
           
           %Calculate errors
           errorNN{i,j,k} = mdlNN{i,j,k}(RS_AVL_input(:,:)')-Y(:)';%test batch
           error_validationNN{i,j,k} = mdlNN{i,j,k}(validation_input')-validation_output;%validation batch
           
           %Obtain the MSE for the model
           MSE1_test{i,j,k} = sum(errorNN{i,j,k}.^2)/length(Y);
           MSE1_validation{i,j,k} = sum(error_validationNN{i,j,k}.^2)/length(error_validationNN{i,j,k});

        end
    end
end

