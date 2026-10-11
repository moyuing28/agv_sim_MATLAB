% Function: generateExampleTasks
% Purpose: Reject the retired station-only auto-generated example mode.
% Inputs: Unused legacy parameters.
% Outputs: None; explicit migration error.
%
% Notes: Never overwrites user cargo/task files.
function tasks = generateExampleTasks(varargin) %#ok<STOUT,INUSD>
error('AGV:RetiredExample','Auto-generated station-only tasks are retired. Use loadTaskConfiguration with cargo_initial.csv and tasks_input.csv.');
end
