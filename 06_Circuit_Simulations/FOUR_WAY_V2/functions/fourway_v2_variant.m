function variant=fourway_v2_variant(id)
% Explicit finite hypotheses, not statistical samples or hardware corners.
c=jsondecode(fileread(fullfile(fourway_v2_root(),'06_Circuit_Simulations','RECEIVER_V2','receiver_characterization_config.json')));
variants=struct([]);k=0;
for p=1:numel(c.receiver.thresholdPairs)
 for d=c.receiver.postThresholdLatency_s(:)'
  for law=string(c.receiver.pulseLaws(:))'
   k=k+1;t=c.receiver.thresholdPairs(p);
   v=struct('id',string(sprintf('V%02d',k)),'threshold_id',string(t.id), ...
    'rise_V',t.rise_V,'fall_V',t.fall_V,'latencyRise_s',d,'latencyFall_s',d,'pulseLaw',law);
   if k==1,variants=v;else,variants(k)=v;end %#ok<AGROW>
  end
 end
end
if nargin==0,variant=variants;return;end
if isnumeric(id),assert(isscalar(id)&&id==fix(id)&&id>=1&&id<=16);variant=variants(id);
else
 index=find(string({variants.id})==string(id));
 assert(isscalar(index),'EMIProject:V2Variant','Unknown frozen V2 hypothesis.');variant=variants(index);
end
end
