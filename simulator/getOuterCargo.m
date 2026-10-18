function cargo = getOuterCargo(pocketKey,state,data)
%GETOUTERCARGO One-row CargoID/StationMark/Sequence table; empty Lane: 0 rows.
[station,sequence,id]=getLaneFrontier(pocketKey,state,data);
if sequence~=-1
 % The former row assignment converted into string/double/double columns.
 id=string(id); station=double(station); sequence=double(sequence);
else
 id=strings(0,1); station=zeros(0,1); sequence=zeros(0,1);
end
cargo=table(id,station,sequence,'VariableNames',{'CargoID','StationMark','Sequence'});
end
