function g=sc01b_gate_signals(p)
%SC01B_GATE_SIGNALS Driver-source events, including documented typical delay.
assert(numel(p.control.highOn_s)==numel(p.control.highOff_s));
highOn=p.control.highOn_s+p.driver.riseDelay_s;
highOff=p.control.highOff_s+p.driver.fallDelay_s;
lowOff=p.control.highOn_s-p.control.deadTime_s+p.driver.fallDelay_s;
lowOn=p.control.highOff_s+p.control.deadTime_s+p.driver.riseDelay_s;
events=[highOn highOff lowOff lowOn];
assert(all(events>0 & events+p.driver.commandRamp_s<p.simulation.stopTime_s), ...
    'SC01B:InvalidGateTiming','Every driver event must lie inside the record.');
t=unique([0 p.simulation.stopTime_s events events+p.driver.commandRamp_s]).';
high=double(p.control.initialHigh)*ones(size(t));low=1-high;
for k=1:numel(highOn)
    high=high+ramp(t,highOn(k),p.driver.commandRamp_s)-ramp(t,highOff(k),p.driver.commandRamp_s);
    low=low-ramp(t,lowOff(k),p.driver.commandRamp_s)+ramp(t,lowOn(k),p.driver.commandRamp_s);
end
assert(all(high>=-1e-12 & high<=1+1e-12 & low>=-1e-12 & low<=1+1e-12));
assert(~any(high>0 & low>0),'SC01B:CommandOverlap','Driver commands overlap.');
high(abs(high)<1e-12)=0;high(abs(high-1)<1e-12)=1;
low(abs(low)<1e-12)=0;low(abs(low-1)<1e-12)=1;
off=0;if isfield(p.driver,'offVoltage_V'),off=p.driver.offVoltage_V;end
g.time_s=t;g.high_V=off+high*(p.driver.voltage_V-off);g.low_V=off+low*(p.driver.voltage_V-off);
g.highOn_s=highOn;g.highOff_s=highOff;g.lowOn_s=lowOn;g.lowOff_s=lowOff;
g.high=timeseries(g.high_V,t);g.low=timeseries(g.low_V,t);
end
function y=ramp(t,t0,duration)
y=min(1,max(0,(t-t0)/duration));
end
