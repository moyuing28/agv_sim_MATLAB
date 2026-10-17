function testAcceptance4x4()
% Shared manual/automated acceptance runner, no duplicated scheduling logic.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'acceptance','4x4'));
cfg=config(); paths={cfg.stationFile,cfg.laneFile,cfg.distanceFile,cfg.metadataFile,cfg.cargoFile,cfg.taskFile};
before=cellfun(@fileread,paths,'UniformOutput',false);
summary=runAcceptance4x4();
after=cellfun(@fileread,paths,'UniformOutput',false);
assert(isequal(before,after),'AGV:AcceptanceInputMutation','Production inputs changed.');
if height(summary)~=7 || any(~summary.Pass)
 error('AGV:AcceptanceFailed','4x4 acceptance failed: %s', ...
  char(join(summary.Scenario(~summary.Pass)+": "+summary.FailureReason(~summary.Pass),'; ')));
end
fprintf('All seven 4x4 Runtime acceptance scenarios passed.\n');
end
