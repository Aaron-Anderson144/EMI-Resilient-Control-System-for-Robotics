function sc01b_export_trace(r,path)
%SC01B_EXPORT_TRACE Preserve recorded knots and explicitly named units.
fields=["time_s","switch_V","bus_V","highVgs_V","lowVgs_V","highVds_V","lowVds_V", ...
    "highCurrent_A","lowCurrent_A","highGateCurrent_A","lowGateCurrent_A","loadCurrent_A","feedCurrent_A", ...
    "highChannelCurrent_A","lowChannelCurrent_A","highDiodeCurrent_A","lowDiodeCurrent_A"];
fields=fields(isfield(r,fields));t=table;
for k=1:numel(fields),t.(fields(k))=r.(fields(k))(:);end
writetable(t,path);
end
