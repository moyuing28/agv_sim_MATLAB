function [candidates,reason] = getFillingCandidateSourceLanes(parentTask,assessment,state,data,nearestOnly)
% Public entry retains live reassessment and original error checks.
if nargin<5, nearestOnly=false; end
[candidates,reason]=getFillingCandidateSourceLanesCore(parentTask,assessment,state,data,nearestOnly, ...
 @()assessCustomerTask(parentTask,data,state));
end
