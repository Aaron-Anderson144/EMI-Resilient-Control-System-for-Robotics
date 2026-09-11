function varargout=fourway_exact(config,varargin)
%FOURWAY_EXACT Dispatch the source-hash-pinned compiled exact reference.
% Native acceptance can query arbitrary times with a fifth input after
% config: [state,events,decoder,boundaries,query]=fourway_exact(config,state,
% stopTime,intendedTransitions,queryTimes). query=[time,vp,vn,ir].
[varargout{1:nargout}]=feval(config.engine_function,config,varargin{:});
end
