function action = buildCustomerMoveAction(task,assessment,state,data)
%BUILDCUSTOMERMOVEACTION Public entry always re-assesses the supplied live state.
action=buildCustomerMoveActionCore(task,assessment,state,data, ...
 @()assessCustomerTask(task,data,state));
end