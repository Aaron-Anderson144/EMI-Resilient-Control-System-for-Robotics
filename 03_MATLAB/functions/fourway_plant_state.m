function state = fourway_plant_state(x,voltage_V,load_Nm,time_s,params)
%FOURWAY_PLANT_STATE Exact held-input state at scalar/vector local times.
% Output has one [theta; velocity; current] column per requested time.
validateattributes(time_s,{'numeric'},{'real','finite','nonnegative','vector'});
segment = fourway_plant_segment(x,voltage_V,load_Nm,params);
state = segment.stateAt(time_s);
end
