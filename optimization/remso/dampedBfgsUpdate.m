function [ M,skipping,damping,minEig ] = dampedBfgsUpdate(M,yG,du,varargin)
% Dampeg BFGS Hessian approximation
%
% SYNOPSIS:
%  [M,skipping,damping,minEig] = dampedBfgsUpdate(M,yG,du,nru)
%  [M,skipping,damping,minEig] = dampedBfgsUpdate(M,yG,du,nru, 'pn', pv, ...)
% PARAMETERS:
%
%   M - Current hessian approximation
%
%   yG - Lagrangian gradient difference.
%
%   du - variables step difference
%
%   'pn'/pv - List of 'key'/value pairs defining optional parameters. The
%             supported options are:
%
%   dF - Damping factor according to M.J.D Powell
%
%   epsd - variables minimum step threshold.
%
%   it - it number for debug
%
% RETURNS:
%
%   M - Updated Hessian approximation
%   
%   skipping - true if updated was not performed 
%
%   damping - true if the damping procedure is used
%
%   minEig - Minimum eigen value of the updated hessian 
%
% SEE ALSO:
%
%


opt = struct('dF',0.2,'epsd',1e-5);
opt = merge_options(opt, varargin{:});

minEig = 0;
skipping = norm(du) < opt.epsd;
 if skipping;
     warning(['bfgs not updated: too short step ',num2str(norm(du))]);
     return;
 end

Mdu = M*du;
duTMdu =  du'*Mdu;
sTy = dot(yG,du);

% skipping = (sTy <= sqrt(eps)*norm(du)*norm(yG));
% if skipping;
%     warning(['bfgs not updated: curvature ratio is ',num2str(sTy/(sqrt(eps)*norm(du)*norm(yG)))]);
%     return;
% end

if sTy >= opt.dF * duTMdu
    theta = 1;
    damping = false;
else
    theta = (1-opt.dF)*duTMdu/(duTMdu-sTy); 
    damping = true;
end

r = theta*yG+(1-theta)*(M*du)';


MT = M +  (r'*r)/dot(r,du) - (Mdu*Mdu')/(duTMdu);

MT = (MT + MT')/2;  % CPLEX keeps complaining that the approximation is not symetric

minEig = min(eig(MT)); 
if minEig < 0
    skipping = true;
    warning(['bfgs not updated: negative eigenvalue detected:', num2str(min(eig(MT)))]);
else
    M = MT;
end




end

