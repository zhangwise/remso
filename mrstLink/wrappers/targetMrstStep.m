function [ varargout ] = targetMrstStep(x0,u,target,simulator,wellSol,schedule,reservoirP,varargin)
%
% Simulate a single step and apply a target function on the results
%
% SYNOPSIS:
%  [f,Jac,convergence,simVars] = mrstTimePointFuncWrapper(xfk,uk,vk,target,schedule,wellSol,)
%  [f,Jac,convergence,simVars] = mrstTimePointFuncWrapper(xfk,uk,vk,target,schedule,wellSol, 'pn', pv, ...)
%
% PARAMETERS:
%
%   x0 - initial state in Remso format
%
%   u - controls in Remso format
%
%   target -  Function follwing structure defined in dummyMrstFunc
%
%   simulator - simulator function
%
%   wellSol - wellSol mock object
%
%   schedule - schedule mock object
%
%   reservoirP - reservoir parameters
%
%   'pn'/pv - List of 'key'/value pairs defining optional parameters. The
%             supported options are:
%
%   gradients - true if partial derivatives are computed.
%
%   leftSeed - vector for vector-Jacobian product.
%
%   (xRightSeeds,uRightSeeds) - for Jacobian-vector product
%
%   (xScale,vScale,uScale) - Variables scaling
%
%   (guessX,guessV) - guess of the simulation result
%
%    simVars - for hot starting
%
% RETURNS:
%
%   f - value of the target function.
%
%   Jac - Jacobain of the targe function
%
%   convergence - convergence information of the simulation step
%
%   simVars - simulation variables
%
% SEE ALSO:
%
%
opt = struct('gradients',false,'xScale',[],'vScale',[],'uScale',[],'xRightSeeds',[],'uRightSeeds',[],'guessX',[],'guessV',[],'saveJacobians',true,'simVars',[]);
opt = merge_options(opt, varargin{:});

nx = numel(x0);
nu = numel(u);

simulate = true;  % if the simVars provided, skip the simulation part
if ~isempty(opt.simVars)
   % simulate = ~opt.simVars.convergence.converged;
   simulate = false;
end

if simulate
    
    [ shootingVars.state0,JacTX] = stateVector2stateMrst( x0,'xScale',opt.xScale,...
        'partials',opt.gradients);
    [ shootingVars.schedule,JacTU ] = controls2Schedule( u,schedule,'uScale',opt.uScale,...
        'partials',opt.gradients);
    
    if ~isempty(opt.guessX)
        shootingGuess = cell(1,1);
        [ shootingGuess{1} ] = stateVector2stateMrst( opt.guessX,'xScale',opt.xScale);
        if ~isempty(opt.guessV)
            [shootingGuess{1}.wellSol] = algVar2wellSol( opt.guessV,wellSol,'vScale',opt.vScale);
        end
    else
        shootingGuess = [];
    end
    
    
    [shootingSol,JacRes,convergence] = simulator(shootingVars,reservoirP,'shootingGuess',shootingGuess);
    
    
    forwardStates = shootingSol.ForwardStates;
    
    targetObj = target(1,...
        forwardStates{end},...
        forwardStates{end}.wellSol,...
        shootingVars.schedule,'ComputePartials', opt.gradients);
    
    simVars.forwardStates = forwardStates;
    if opt.saveJacobians
        simVars.JacRes = JacRes;
    else
        simVars.JacRes = [];
    end
    simVars.convergence = convergence;
	if opt.saveJacobians
        simVars.targetObj = targetObj;
	else
        simVars.targetObj = double(targetObj);
	end
    
    
else
    
    forwardStates = opt.simVars.forwardStates;
    JacRes = opt.simVars.JacRes;
    convergence = opt.simVars.convergence;
    targetObj = opt.simVars.targetObj;
    simVars = opt.simVars;
end




Jac = [];
if opt.gradients
    if ~simulate
        [ shootingVars.state0,JacTX ] = stateVector2stateMrst( x0,...
            'xScale',opt.xScale,...
            'partials',opt.gradients);
    end
    if ~iscell(targetObj)
        [ shootingVars.schedule,JacTU ] = controls2Schedule( u,schedule,...
            'uScale',opt.uScale,...
            'partials',opt.gradients);
        
        targetObj = target(1,...
            forwardStates{end},...
            forwardStates{end}.wellSol,...
            shootingVars.schedule,'ComputePartials', opt.gradients);
    end
    targetObj = cat(targetObj);
    
    lS  = @(k) targetObj.jac{1};
    
    if (size(opt.uRightSeeds,1)==0)
        uRightSeeds = [speye(nu),sparse(nu,nx)];
        xRightSeeds = [sparse(nx,nu),speye(nx)];
    else
        uRightSeeds = opt.uRightSeeds;
        xRightSeeds = opt.xRightSeeds;
    end
    
    % TODO: Include in Jac*Vector in transformation functions
    % there should be some little advantage!
    uRightSeeds = JacTU*uRightSeeds;
    xRightSeeds = JacTX*xRightSeeds;
    
    gradients = runGradientStep(reservoirP.G, ...
        reservoirP.rock, ...
        reservoirP.fluid, ...
        schedule,...
        lS,...
        reservoirP.system,...
        'Verbose', false,...
        'ForwardStates', [{shootingVars.state0},forwardStates],...
        'xRightSeeds',xRightSeeds,...
        'uRightSeeds',uRightSeeds,...
        'fwdJac',JacRes);
    
    
    if (size(opt.uRightSeeds,1)==0)
        Jac.Ju = gradients(:,1:nu);
        Jac.Jx = gradients(:,nu+1:nu+nx);
    else
        Jac.J = gradients;
    end
   
end

varargout{1} = double(targetObj);
varargout{2} = Jac;
varargout{3} = convergence;
varargout{4} = simVars;


end