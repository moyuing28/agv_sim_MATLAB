function action = buildFillingAction(parentTask,assessment,state,data)
% Public entry retains live reassessment and original error checks.
action=buildFillingActionCore(parentTask,assessment,state,data, ...
 @()assessCustomerTask(parentTask,data,state));
end
