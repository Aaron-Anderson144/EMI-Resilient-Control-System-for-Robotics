function Z = edmd_lift(model,H)
%EDMD_LIFT Apply the training-only normalization and frozen dictionary.
assert(size(H,1)==2*model.delay+1 && isreal(H) && all(isfinite(H),'all'), ...
    'EDMD:History','History must be finite and match the fitted delay depth.');
q=(H-model.historyMean)./model.historyScale;
Z=[ones(1,size(H,2));q];
if model.degree==2
    for a=1:size(q,1)
        for b=a:size(q,1)
            Z(end+1,:)=q(a,:).*q(b,:); %#ok<AGROW>
        end
    end
end
end
