function action = buildRelocationAction(parentTask,assessment,side,state,data)
%BUILDRELOCATIONACTION Public entry retains live source and stale-request checks.
action=buildRelocationActionCore(parentTask,assessment,side,state,data, ...
 @()assessCustomerTask(parentTask,data,state));
end
