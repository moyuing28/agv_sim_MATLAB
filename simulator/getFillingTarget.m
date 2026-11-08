function [target,reason] = getFillingTarget(parentTask,assessment,state,data)
% Public entry retains live reassessment and original error checks.
[target,reason]=getFillingTargetCore(parentTask,assessment,state,data, ...
 @()assessCustomerTask(parentTask,data,state));
end
