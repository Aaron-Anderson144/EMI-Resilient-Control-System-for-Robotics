function counts=fourway_decoder_count_at(decoder,times)
%FOURWAY_DECODER_COUNT_AT Persistent count after events at the sample time.
% No time tolerance advances a future event into the present sample.
counts=zeros(size(times));
for k=1:numel(times)
 index=find(decoder(:,1)<=times(k),1,'last');
 if ~isempty(index),counts(k)=decoder(index,5);end
end
end
