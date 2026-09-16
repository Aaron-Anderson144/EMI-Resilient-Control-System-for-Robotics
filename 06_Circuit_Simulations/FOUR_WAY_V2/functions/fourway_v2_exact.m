function varargout=fourway_v2_exact(config,varargin)
% [state,roots,decoder,boundaries,queries,logic] = exact(config,state,end,tr,q).
[varargout{1:nargout}]=feval(config.engine_function,config,varargin{:});
end
