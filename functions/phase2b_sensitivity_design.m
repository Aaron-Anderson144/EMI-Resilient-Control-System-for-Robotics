function values = phase2b_sensitivity_design(catalog, sampleCount, seed)
%PHASE2B_SENSITIVITY_DESIGN Seeded stratified design without extra toolboxes.
% Each input occupies each of N strata once. Linear/log coordinates follow
% the catalog. This is a space-filling design, not a calibrated risk model.
arguments
    catalog table
    sampleCount (1,1) double {mustBeInteger,mustBePositive}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end
stream = RandStream('mt19937ar', 'Seed', seed);
values = zeros(sampleCount, height(catalog));
for j = 1:height(catalog)
    u = (randperm(stream, sampleCount).'-1+rand(stream,sampleCount,1))/sampleCount;
    if catalog.Scale(j) == "log"
        values(:,j) = exp(log(catalog.Low(j))+u.*log(catalog.High(j)/catalog.Low(j)));
    else
        values(:,j) = catalog.Low(j)+u.*(catalog.High(j)-catalog.Low(j));
        if catalog.Scale(j) == "integer"
            values(:,j) = round(values(:,j));
        end
    end
end
end
