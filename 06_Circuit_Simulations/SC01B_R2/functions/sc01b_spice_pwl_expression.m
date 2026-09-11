function expression=sc01b_spice_pwl_expression(time,voltage)
%SC01B_SPICE_PWL_EXPRESSION Exact continuous piecewise-linear source function.
assert(iscolumn(time) && iscolumn(voltage) && numel(time)==numel(voltage));
assert(all(isfinite(time)) && all(isfinite(voltage)) && all(diff(time)>0));
expression=string(sprintf('%.17g',voltage(1)));
for k=1:numel(time)-1
    delta=voltage(k+1)-voltage(k);
    if delta~=0
        expression=expression+string(sprintf('+ (%.17g)*min(max((time-(%.17g))/(%.17g),0),1)', ...
            delta,time(k),time(k+1)-time(k)));
    end
end
end
