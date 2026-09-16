function variants=fourway_v2_native_variants()
% Enumerate the complete frozen finite behavior grid without selecting a law.
[~,~,p]=fourway_v2_native_parameters(40,7,100);items=cell(16,1);n=0;
for threshold=p.receiver.thresholdPairs.'
    for latency=p.receiver.postThresholdLatency_s.'
        for law=string(p.receiver.pulseLaws).'
            n=n+1;
            items{n}=struct('id',sprintf('%s_%gns_%s',threshold.id,latency*1e9,law), ...
                'threshold_id',threshold.id,'rise_V',threshold.rise_V,'fall_V',threshold.fall_V, ...
                'latencyRise_s',latency,'latencyFall_s',latency,'pulseLaw',char(law)); %#ok<AGROW>
        end
    end
end
assert(n==16,'FOURWAYV2:NativeVariantCount','All sixteen frozen variants are required.');
variants=vertcat(items{:});
end
