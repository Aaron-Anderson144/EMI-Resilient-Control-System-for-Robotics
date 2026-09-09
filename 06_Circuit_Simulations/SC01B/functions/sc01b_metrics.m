function [metrics,events]=sc01b_metrics(r,p)
%SC01B_METRICS Bus-relative switching events and signed terminal energy.
% Drain and gate currents are positive INTO their respective device pins.
% Energy is integral(Vds*Id + Vgs*Ig) over declared event windows; it includes
% stored-charge transfer and is not identified as semiconductor heat.
% Voltage events use roots of Vswitch-q*Vbus, not nominal-bus thresholds.
% Gate/current timing is diagnostic: neither proves channel conduction.
% Initialization before p.validation.startTime_s is excluded from aggregate
% extrema/energy, but its initial load current is reported separately.

fields={'switch_V','bus_V','highVgs_V','lowVgs_V','highVds_V','lowVds_V', ...
    'highCurrent_A','lowCurrent_A','highGateCurrent_A','lowGateCurrent_A', ...
    'loadCurrent_A','feedCurrent_A'};
validateTrace(r,fields);
assert(isstruct(p) && isfield(p,'validation') && isfield(p.validation,'startTime_s'), ...
    'SC01B:MissingParameter','A validation start time is required.');
g=sc01b_gate_signals(p);
assert(isfinite(p.validation.startTime_s) && p.validation.startTime_s>=0 && ...
    p.driver.voltage_V>0 && p.device.voltageRating_V>0 && p.device.gateRating_V>0, ...
    'SC01B:InvalidParameter','Validation start and voltage ratings must be valid.');
assert(r.time_s(end)>p.validation.startTime_s, ...
    'SC01B:NoValidationRecord','No samples extend beyond the excluded preamble.');
assert(all(r.bus_V>0),'SC01B:InvalidBus','Bus-relative timing requires a positive local bus.');

validation=window(r,fields,p.validation.startTime_s,r.time_s(end));
metrics.ValidationStart_s=validation.time_s(1);
metrics.ValidationEnd_s=validation.time_s(end);
metrics.ValidationRecordClipped=validation.clipped;
metrics.InitialLoadCurrent_A=r.loadCurrent_A(1);
metrics.ValidationInitialLoadCurrent_A=validation.loadCurrent_A(1);
metrics.PeakSwitch_V=max(validation.switch_V);
metrics.MinSwitch_V=min(validation.switch_V);
metrics.PeakHighVds_V=max(validation.highVds_V);
metrics.PeakLowVds_V=max(validation.lowVds_V);
metrics.MinHighVds_V=min(validation.highVds_V);
metrics.MinLowVds_V=min(validation.lowVds_V);
metrics.PeakAbsHighVgs_V=max(abs(validation.highVgs_V));
metrics.PeakAbsLowVgs_V=max(abs(validation.lowVgs_V));
metrics.PeakAbsHighCurrent_A=max(abs(validation.highCurrent_A));
metrics.PeakAbsLowCurrent_A=max(abs(validation.lowCurrent_A));
metrics.PeakAbsLoadCurrent_A=max(abs(validation.loadCurrent_A));
metrics.PeakAbsFeedCurrent_A=max(abs(validation.feedCurrent_A));
metrics.LoadCurrentChange_A=validation.loadCurrent_A(end)-validation.loadCurrent_A(1);
metrics.MaxLoadCurrentDeparture_A=max(abs(validation.loadCurrent_A-validation.loadCurrent_A(1)));
metrics.HighVdsOverRating_V=max(0,metrics.PeakHighVds_V-p.device.voltageRating_V);
metrics.LowVdsOverRating_V=max(0,metrics.PeakLowVds_V-p.device.voltageRating_V);
metrics.HighGateOverRating_V=max(0,metrics.PeakAbsHighVgs_V-p.device.gateRating_V);
metrics.LowGateOverRating_V=max(0,metrics.PeakAbsLowVgs_V-p.device.gateRating_V);
metrics.DeviceVoltageLimitsPassed=metrics.HighVdsOverRating_V==0 && metrics.LowVdsOverRating_V==0;
metrics.GateVoltageLimitsPassed=metrics.HighGateOverRating_V==0 && metrics.LowGateOverRating_V==0;
metrics.HighTerminalEnergy_J=deviceEnergy(validation,'high');
metrics.LowTerminalEnergy_J=deviceEnergy(validation,'low');
metrics.HighGateCharge_C=trapz(validation.time_s,validation.highGateCurrent_A);
metrics.LowGateCharge_C=trapz(validation.time_s,validation.lowGateCurrent_A);
metrics.FeedCharge_C=trapz(validation.time_s,validation.feedCurrent_A);
metrics.GateDiagnosticLevel_V=0.5*p.driver.voltage_V;
metrics.GateMidpointOverlap_s=intersectionDuration(validation.time_s, ...
    validation.highVgs_V-metrics.GateDiagnosticLevel_V, ...
    validation.lowVgs_V-metrics.GateDiagnosticLevel_V);
metrics.TerminalCoincidenceFloor_A=max(1e-3,1e-3*metrics.PeakAbsLoadCurrent_A);
metrics.ForwardTerminalCurrentCoincidence_s=intersectionDuration(validation.time_s, ...
    validation.highCurrent_A-metrics.TerminalCoincidenceFloor_A, ...
    validation.lowCurrent_A-metrics.TerminalCoincidenceFloor_A);
metrics.ChannelOverlapKnown=false;
metrics.nativeChannelOverlap_s=NaN;
metrics.PeakSharedForwardChannelCurrent_A=NaN;
metrics.ChannelOverlapFloor_A=metrics.TerminalCoincidenceFloor_A;
if isfield(r,'highChannelCurrent_A') && isfield(r,'lowChannelCurrent_A')
    for channelName={'highChannelCurrent_A','lowChannelCurrent_A'}
        v=r.(channelName{1});
        assert(isnumeric(v) && isreal(v) && iscolumn(v) && numel(v)==numel(r.time_s) && all(isfinite(v)), ...
            'SC01B:InvalidTrace','Internal channel-current traces must match the native grid.');
    end
    channelWindow=window(r,{'highChannelCurrent_A','lowChannelCurrent_A'}, ...
        p.validation.startTime_s,r.time_s(end));
    metrics.ChannelOverlapKnown=true;
    metrics.nativeChannelOverlap_s=intersectionDuration(channelWindow.time_s, ...
        channelWindow.highChannelCurrent_A-metrics.ChannelOverlapFloor_A, ...
        channelWindow.lowChannelCurrent_A-metrics.ChannelOverlapFloor_A);
    metrics.PeakSharedForwardChannelCurrent_A=max(0,max(min( ...
        channelWindow.highChannelCurrent_A,channelWindow.lowChannelCurrent_A)));
end
metrics.DissipatedEnergyKnown=false;
metrics.AllFinite=true;

rows=cell(2*numel(g.highOn_s),1);
for pulse=1:numel(g.highOn_s)
    for kind=1:2
        if kind==1
            command=g.highOn_s(pulse);direction=1;name="high_on";
            lowCommand=g.lowOff_s(pulse);lowDirection=-1;
            driverDeadTime=command-lowCommand;
        else
            command=g.highOff_s(pulse);direction=-1;name="high_off";
            lowCommand=g.lowOn_s(pulse);lowDirection=1;
            driverDeadTime=lowCommand-command;
        end
        a=max(p.validation.startTime_s,command-0.1e-6);b=command+0.5e-6;
        row=emptyEvent();
        row.EventId="pulse_"+pulse+"_"+name;row.Kind=name;row.Pulse=pulse;
        row.CommandTime_s=command;row.RequestedWindowStart_s=a;row.RequestedWindowEnd_s=b;
        row.DriverCommandDeadTime_s=driverDeadTime;
        row.GateDiagnosticLevel_V=metrics.GateDiagnosticLevel_V;
        row.ChannelOverlapKnown=metrics.ChannelOverlapKnown;row.DissipatedEnergyKnown=false;
        w=window(r,fields,a,b);
        row.Clipped=w.clipped || command-0.1e-6<p.validation.startTime_s;
        if isempty(w.time_s)
            row.Status="outside_record";row.CurrentTimingStatus="outside_record";
            rows{2*(pulse-1)+kind}=row;continue;
        end
        row.WindowStart_s=w.time_s(1);row.WindowEnd_s=w.time_s(end);
        row.Ipre_A=interp1(r.time_s,r.loadCurrent_A,command,'linear',NaN);
        row.HighCurrentPre_A=interp1(r.time_s,r.highCurrent_A,a,'linear',NaN);
        row.LowCurrentPre_A=interp1(r.time_s,r.lowCurrent_A,a,'linear',NaN);
        row.SwitchBeforeFraction=w.switch_V(1)/w.bus_V(1);
        row.SwitchAfterFraction=w.switch_V(end)/w.bus_V(end);
        [vt,voltageOK,grazing,recrossings]=progressTimes(w.time_s,w.switch_V,w.bus_V,direction);
        row.SwitchT10_s=vt(1);row.SwitchT50_s=vt(2);row.SwitchT90_s=vt(3);
        row.EdgeTime_s=vt(3)-vt(1);
        if direction<0,row.EdgeTime_s=vt(1)-vt(3);end
        row.VoltageResolved=voltageOK;row.VoltageGrazing=grazing;
        row.VoltageRecrossingCount=recrossings;
        [gt,gateOK,gateGrazing]=progressTimes(w.time_s,w.highVgs_V, ...
            p.driver.voltage_V*ones(size(w.time_s)),direction);
        row.HighGateT10_s=gt(1);row.HighGateT50_s=gt(2);row.HighGateT90_s=gt(3);
        row.GateResolved=gateOK;row.GateGrazing=gateGrazing;
        lowWindow=window(r,fields,max(p.validation.startTime_s,lowCommand-0.1e-6),lowCommand+0.5e-6);
        row.CounterpartGateClipped=lowWindow.clipped;
        if ~isempty(lowWindow.time_s)
            [lt,lowOK,lowGrazing]=progressTimes(lowWindow.time_s,lowWindow.lowVgs_V, ...
                p.driver.voltage_V*ones(size(lowWindow.time_s)),lowDirection);
            row.LowGateT50_s=lt(2);
            row.CounterpartGateResolved=lowOK && ~lowGrazing;
            if direction>0,row.GateMidpointDeadTime_s=gt(2)-lt(2);
            else,row.GateMidpointDeadTime_s=lt(2)-gt(2);end
        end
        if isfinite(row.Ipre_A) && abs(row.Ipre_A)>1e-6
            [ct,currentOK,currentGrazing]=progressTimes(w.time_s, ...
                w.highCurrent_A/row.Ipre_A,ones(size(w.time_s)),direction);
            row.HighCurrentT10_s=ct(1);row.HighCurrentT50_s=ct(2);row.HighCurrentT90_s=ct(3);
            row.CurrentResolved=currentOK && ~currentGrazing;
            if row.CurrentResolved,row.CurrentTimingStatus="resolved";
            else,row.CurrentTimingStatus="missing_or_ambiguous_crossing";end
        else
            row.CurrentTimingStatus="unavailable_zero_or_missing_precurrent";
        end
        row.PeakHighVds_V=max(w.highVds_V);row.PeakLowVds_V=max(w.lowVds_V);
        row.PeakAbsHighVgs_V=max(abs(w.highVgs_V));row.PeakAbsLowVgs_V=max(abs(w.lowVgs_V));
        row.HighDrainTerminalEnergy_J=productIntegral(w.time_s,w.highVds_V,w.highCurrent_A);
        row.HighGateTerminalEnergy_J=productIntegral(w.time_s,w.highVgs_V,w.highGateCurrent_A);
        row.LowDrainTerminalEnergy_J=productIntegral(w.time_s,w.lowVds_V,w.lowCurrent_A);
        row.LowGateTerminalEnergy_J=productIntegral(w.time_s,w.lowVgs_V,w.lowGateCurrent_A);
        row.HighTerminalEnergy_J=row.HighDrainTerminalEnergy_J+row.HighGateTerminalEnergy_J;
        row.LowTerminalEnergy_J=row.LowDrainTerminalEnergy_J+row.LowGateTerminalEnergy_J;
        row.Resolved=row.VoltageResolved && row.GateResolved && row.CounterpartGateResolved && ...
            ~row.VoltageGrazing && ~row.GateGrazing && ~row.Clipped && ~row.CounterpartGateClipped;
        if row.Clipped || row.CounterpartGateClipped,row.Status="clipped";
        elseif row.Resolved,row.Status="resolved";
        else,row.Status="missing_or_ambiguous_crossing";end
        rows{2*(pulse-1)+kind}=row;
    end
end
events=struct2table(vertcat(rows{:}));
events=sortrows(events,'CommandTime_s');
metrics.EventCount=height(events);
metrics.UnresolvedEventCount=sum(~events.Resolved);
metrics.ClippedEventCount=sum(events.Clipped | events.CounterpartGateClipped);
metrics.UnresolvedCurrentTimingCount=sum(~events.CurrentResolved & ...
    events.CurrentTimingStatus~="unavailable_zero_or_missing_precurrent");
metrics.UnavailableCurrentTimingCount=sum(events.CurrentTimingStatus=="unavailable_zero_or_missing_precurrent");
metrics.VoltageGrazingEventCount=sum(events.VoltageGrazing);
metrics.VoltageRecrossingCount=sum(events.VoltageRecrossingCount);
end

function validateTrace(r,fields)
assert(isstruct(r) && isscalar(r),'SC01B:InvalidTrace','Result must be a scalar structure.');
for name=[{'time_s'},fields]
    assert(isfield(r,name{1}),'SC01B:MissingSignal','Required trace is missing: %s',name{1});
    v=r.(name{1});
    assert(isnumeric(v) && isreal(v) && iscolumn(v) && numel(v)>=2 && all(isfinite(v)), ...
        'SC01B:InvalidTrace','Trace %s must be a finite real numeric column.',name{1});
    assert(numel(v)==numel(r.time_s),'SC01B:InvalidTrace','Trace lengths must match.');
end
assert(all(diff(r.time_s)>0),'SC01B:InvalidTrace','Native time must increase strictly.');
end

function w=window(r,fields,a,b)
w.clipped=a<r.time_s(1) || b>r.time_s(end);
a=max(a,r.time_s(1));b=min(b,r.time_s(end));
if b<=a,w.time_s=zeros(0,1);return;end
w.time_s=[a;r.time_s(r.time_s>a & r.time_s<b);b];
for k=1:numel(fields),w.(fields{k})=interp1(r.time_s,r.(fields{k}),w.time_s,'linear');end
end

function [times,resolved,grazing,recrossings]=progressTimes(t,value,scale,direction)
fractions=[0.1 0.5 0.9];times=NaN(1,3);grazing=false;recrossings=0;
for k=1:3
    offset=value-fractions(k)*scale;
    [crossings,touch]=crossingTimes(t,offset,direction);
    grazing=grazing || touch;
    recrossings=recrossings+max(0,numel(crossings)-1);
    if ~isempty(crossings),times(k)=crossings(1);end
end
if direction>0
    endpointOK=value(1)<=0.1*scale(1) && value(end)>=0.9*scale(end);
    orderOK=times(1)<times(2) && times(2)<times(3);
else
    endpointOK=value(1)>=0.9*scale(1) && value(end)<=0.1*scale(end);
    orderOK=times(3)<times(2) && times(2)<times(1);
end
resolved=endpointOK && orderOK && all(isfinite(times)) && recrossings==0;
end

function [times,grazing]=crossingTimes(t,d,direction)
nz=find(d~=0);left=nz(1:end-1);right=nz(2:end);
crossed=sign(d(left))~=sign(d(right)) & sign(d(right))==direction;
left=left(crossed);right=right(crossed);times=t(left);
adjacent=right==left+1;
times(adjacent)=t(left(adjacent))+(t(right(adjacent))-t(left(adjacent))).* ...
    (-d(left(adjacent)))./(d(right(adjacent))-d(left(adjacent)));
times(~adjacent)=t(left(~adjacent)+1);
tol=1e-10*max(1,max(abs(d)));
near=abs(d)<=tol;
mid=d(2:end-1);pre=d(1:end-2);post=d(3:end);
extreme=(mid>=pre & mid>=post & (mid>pre | mid>post)) | ...
    (mid<=pre & mid<=post & (mid<pre | mid<post));
grazing=any(near(2:end-1) & extreme) || any(diff(d)==0 & near(1:end-1));
end

function energy=productIntegral(t,v,i)
energy=sum(diff(t)/6.*(2*v(1:end-1).*i(1:end-1)+ ...
    v(1:end-1).*i(2:end)+v(2:end).*i(1:end-1)+2*v(2:end).*i(2:end)));
end

function energy=deviceEnergy(w,prefix)
energy=productIntegral(w.time_s,w.([prefix 'Vds_V']),w.([prefix 'Current_A']))+ ...
    productIntegral(w.time_s,w.([prefix 'Vgs_V']),w.([prefix 'GateCurrent_A']));
end

function duration=intersectionDuration(t,a,b)
% Intersect the positive intervals of two piecewise-linear diagnostics.
[aStart,aEnd]=positiveBounds(a);[bStart,bEnd]=positiveBounds(b);
duration=sum(diff(t).*max(0,min(aEnd,bEnd)-max(aStart,bStart)));
end

function [first,last]=positiveBounds(v)
left=v(1:end-1);right=v(2:end);first=zeros(size(left));last=zeros(size(left));
last(left>0 & right>0)=1;
rising=left<=0 & right>0;
first(rising)=-left(rising)./(right(rising)-left(rising));last(rising)=1;
falling=left>0 & right<=0;
last(falling)=-left(falling)./(right(falling)-left(falling));
end

function row=emptyEvent()
row=struct('EventId',"",'Kind',"",'Pulse',NaN,'CommandTime_s',NaN, ...
    'RequestedWindowStart_s',NaN,'RequestedWindowEnd_s',NaN, ...
    'WindowStart_s',NaN,'WindowEnd_s',NaN,'DriverCommandDeadTime_s',NaN, ...
    'GateDiagnosticLevel_V',NaN,'Ipre_A',NaN,'HighCurrentPre_A',NaN,'LowCurrentPre_A',NaN, ...
    'SwitchBeforeFraction',NaN,'SwitchAfterFraction',NaN, ...
    'SwitchT10_s',NaN,'SwitchT50_s',NaN,'SwitchT90_s',NaN,'EdgeTime_s',NaN, ...
    'HighGateT10_s',NaN,'HighGateT50_s',NaN,'HighGateT90_s',NaN, ...
    'LowGateT50_s',NaN,'GateMidpointDeadTime_s',NaN, ...
    'HighCurrentT10_s',NaN,'HighCurrentT50_s',NaN,'HighCurrentT90_s',NaN, ...
    'PeakHighVds_V',NaN,'PeakLowVds_V',NaN,'PeakAbsHighVgs_V',NaN,'PeakAbsLowVgs_V',NaN, ...
    'HighDrainTerminalEnergy_J',NaN,'HighGateTerminalEnergy_J',NaN, ...
    'LowDrainTerminalEnergy_J',NaN,'LowGateTerminalEnergy_J',NaN, ...
    'HighTerminalEnergy_J',NaN,'LowTerminalEnergy_J',NaN, ...
    'Clipped',false,'CounterpartGateClipped',false,'VoltageResolved',false, ...
    'GateResolved',false,'CounterpartGateResolved',false,'CurrentResolved',false, ...
    'VoltageGrazing',false,'GateGrazing',false,'VoltageRecrossingCount',0, ...
    'ChannelOverlapKnown',false,'DissipatedEnergyKnown',false, ...
    'Resolved',false,'Status',"unresolved",'CurrentTimingStatus',"unresolved");
end
