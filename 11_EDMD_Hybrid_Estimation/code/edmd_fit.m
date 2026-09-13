function model = edmd_fit(trainingRecords, options)
%EDMD_FIT Fit an affine-in-input EDMD predictor from training trajectories.
% z(k+1)=A*z(k)+B*((u(k)-inputMean)/inputScale), y=C*z+outputMean.
% degree=1 is the matched learned linear baseline; degree=2 adds quadratics.
% This is an offline predictor, not a fault-tolerant observer or controller.
arguments
    trainingRecords (1,:) cell
    options.delay (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.degree (1,1) double {mustBeMember(options.degree,[1,2])} = 2
    options.ridge (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-6
    options.svdTolerance (1,1) double {mustBePositive,mustBeFinite} = 1e-9
end
p=edmd_snapshot_pairs(trainingRecords,options.delay);
d=options.delay; yTrain=p.H(1:d+1,:); uTrain=p.U;
if d>0, uTrain=[uTrain,reshape(p.H(d+2:end,:),1,[])]; end
yMean=mean(yTrain,'all'); yScale=std(yTrain(:),1);
uMean=mean(uTrain); uScale=std(uTrain,1);
assert(yScale>1e-12 && uScale>1e-12,'EDMD:Excitation', ...
    'Training requires variation in both measured position and applied input.');
model=struct('schema','edmd-offline-v1','delay',d,'degree',options.degree, ...
    'ridge',options.ridge,'svdTolerance',options.svdTolerance, ...
    'sampleTime',p.sampleTime,'outputMean',yMean,'outputScale',yScale, ...
    'inputMean',uMean,'inputScale',uScale, ...
    'historyMean',[repmat(yMean,d+1,1);repmat(uMean,d,1)], ...
    'historyScale',[repmat(yScale,d+1,1);repmat(uScale,d,1)]);
ZX=edmd_lift(model,p.H); ZY=edmd_lift(model,p.Hnext);
W=[ZX;(p.U-uMean)/uScale]; m=size(W,2);
assert(m>=size(W,1),'EDMD:TooFewPairs', ...
    'Snapshot count is below regressor dimension; reduce the dictionary.');
[left,S,right]=svd(W/sqrt(m),'econ'); s=diag(S);
keep=s>options.svdTolerance*s(1);
weights=s(keep)./(s(keep).^2+options.ridge);
operator=((ZY/sqrt(m)*right(:,keep)).*weights')*left(:,keep)';
model.A=operator(:,1:end-1); model.B=operator(:,end);
% Known bookkeeping is exact. All delay coordinates share physical scaling.
model.A(1,:)=0; model.A(1,1)=1; model.B(1)=0;
for row=3:d+2
    model.A(row,:)=0; model.A(row,row-1)=1; model.B(row)=0;
end
if d>0
    row=d+3; model.A(row,:)=0; model.B(row)=1;
    for row=d+4:2*d+2
        model.A(row,:)=0; model.A(row,row-1)=1; model.B(row)=0;
    end
end
model.C=zeros(1,size(ZX,1)); model.C(2)=yScale;
model.training=struct('runCount',numel(trainingRecords),'pairCount',m, ...
    'featureCount',size(ZX,1),'regressorRank',nnz(keep),'singularValues',s, ...
    'minimumHistory',min(p.H,[],2),'maximumHistory',max(p.H,[],2), ...
    'minimumInput',min(p.U),'maximumInput',max(p.U), ...
    'liftedFitRMSE',sqrt(mean((ZY-model.A*ZX-model.B*((p.U-uMean)/uScale)).^2,'all')));
model.spectralRadius=max(abs(eig(model.A)));
model.notes='Finite learned predictor; spectral radius is not a closed-loop stability certificate.';
end
