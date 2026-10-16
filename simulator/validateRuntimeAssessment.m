function validateRuntimeAssessment(a)
%VALIDATERUNTIMEASSESSMENT Fail fast on contradictory main/preparation flags.
prep=a.SourceAction~="NONE" || a.TargetAction~="NONE";
if a.CustomerMoveReady
 assert(a.SourceReady && a.TargetReady && ~prep && a.MainAction=="CUSTOMER_MOVE", ...
  'AGV:RuntimeAssessment','CustomerMoveReady contradicts preparation or endpoint readiness.');
end
if a.MainAction=="CUSTOMER_MOVE"
 assert(a.CustomerMoveReady,'AGV:RuntimeAssessment','CUSTOMER_MOVE requires CustomerMoveReady.');
elseif a.MainAction=="R_SELF"
 assert(~a.CustomerMoveReady && ~prep,'AGV:RuntimeAssessment','R_SELF must be the only action for its Parent.');
elseif a.MainAction=="CARGO_IN_TRANSIT"
 assert(~a.CustomerMoveReady && ~a.SourceReady && ~a.TargetReady && ~prep, ...
  'AGV:RuntimeAssessment','In-transit cargo cannot expose new actions.');
end
end
