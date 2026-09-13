function pairs = edmd_snapshot_pairs(records, delay)
%EDMD_SNAPSHOT_PAIRS Causal scalar input/output histories within valid runs.
% command u(k) acts on [t(k),t(k+1)); target is y(k+1).
% Each record needs y,u,t,valid and sampleTime. valid means usable fresh data,
% not the existing observer's acceptance decision. No truth fields are read.
arguments
    records (1,:) cell
    delay (1,1) double {mustBeInteger,mustBeNonnegative} = 2
end
assert(~isempty(records),'EDMD:NoRecords','Provide at least one trajectory.');
H = []; Hnext = []; U = []; runIndex = []; sampleIndex = [];
sampleTime = NaN;
for r = 1:numel(records)
    rec = records{r};
    assert(isstruct(rec) && all(isfield(rec,{'y','u','t','valid','sampleTime'})), ...
        'EDMD:RecordSchema','Record needs y,u,t,valid,sampleTime.');
    assert(~isfield(rec,'domainValid') || isequal(rec.domainValid,true), ...
        'EDMD:ReceiverDomain','Out-of-domain records cannot be fitted or scored.');
    assert(isnumeric(rec.y) && isreal(rec.y) && isvector(rec.y) && ...
        isnumeric(rec.u) && isreal(rec.u) && isvector(rec.u), ...
        'EDMD:RecordSchema','This prototype supports one scalar output and input.');
    y=double(rec.y(:)); u=double(rec.u(:)); t=double(rec.t(:));
    v=rec.valid(:); n=numel(y);
    assert(numel(u)==n && numel(t)==n && numel(v)==n && n>delay+1, ...
        'EDMD:RecordLength','Aligned records must contain more than delay+1 samples.');
    assert(isreal(v) && all(isfinite(v)) && all(v==0 | v==1), ...
        'EDMD:Validity','valid must contain logical values.');
    dt=rec.sampleTime;
    assert(isnumeric(dt) && isscalar(dt) && isfinite(dt) && dt>0 && ...
        isreal(t) && all(isfinite(t)) && all(abs(diff(t)-dt)<max(1e-12,dt*1e-8)), ...
        'EDMD:Timestamps','Records must have contiguous uniform timestamps.');
    if isnan(sampleTime), sampleTime=dt; end
    assert(abs(sampleTime-dt)<max(1e-12,dt*1e-8),'EDMD:SampleTime', ...
        'All trajectories must share the same sample time.');
    v=logical(v) & isfinite(y) & isfinite(u);
    indices=(delay+1:n-1)';
    use=false(size(indices));
    for j=1:numel(indices)
        k=indices(j); use(j)=all(v(k-delay:k+1));
    end
    indices=indices(use);
    h=zeros(2*delay+1,numel(indices)); hn=h;
    for j=1:numel(indices)
        k=indices(j);
        h(:,j)=[y(k:-1:k-delay);u(k-1:-1:k-delay)];
        hn(:,j)=[y(k+1:-1:k+1-delay);u(k:-1:k+1-delay)];
    end
    H=[H,h]; Hnext=[Hnext,hn]; U=[U,u(indices)']; %#ok<AGROW>
    runIndex=[runIndex,repmat(r,1,numel(indices))]; %#ok<AGROW>
    sampleIndex=[sampleIndex,indices']; %#ok<AGROW>
end
assert(~isempty(U),'EDMD:NoPairs','No valid consecutive snapshot histories.');
pairs=struct('H',H,'Hnext',Hnext,'U',U,'sampleTime',sampleTime, ...
    'runIndex',runIndex,'sampleIndex',sampleIndex);
end
