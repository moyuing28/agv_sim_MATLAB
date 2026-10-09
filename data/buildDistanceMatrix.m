% Function: buildDistanceMatrix
% Purpose: Build a complete directed matrix and StationMark index mapping.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function [D, marks, mapping] = buildDistanceMatrix(stations, rows)
marks = unique(stations.StationMark); n=numel(marks);
mapping = containers.Map(num2cell(marks),num2cell(1:n));
[okF,i]=ismember(rows.FromStation,marks); [okT,j]=ismember(rows.ToStation,marks);
assert(all(okF & okT),'AGV:UnknownStation','Distance rows reference unknown stations.');
idx=sub2ind([n n],i,j);
assert(numel(unique(idx))==numel(idx),'AGV:DuplicateDistance','Duplicate From-To pairs.');
assert(numel(idx)==n*n,'AGV:MissingDistance','Expected every directed From-To pair.');
D=nan(n); D(idx)=rows.Distance; % Preserve directed values and NaN exactly.
end
