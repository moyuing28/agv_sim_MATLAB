function constraints = buildLaneConstraints(tasks,lanes,varargin)
%BUILDLANECONSTRAINTS Deprecated compatibility wrapper for target precedence.
% Source Lane depth no longer creates Customer Task hard edges.
constraints=buildTargetConstraints(tasks,lanes,varargin{:});
end