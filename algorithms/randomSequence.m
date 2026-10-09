% Function: randomSequence
% Purpose: Return a random permutation using the caller RNG state.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function sequence = randomSequence(tasks)
sequence=randperm(height(tasks)); % Repair is performed centrally by simulator.
end
