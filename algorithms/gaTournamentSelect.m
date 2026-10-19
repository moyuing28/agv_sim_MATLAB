function [index,draw] = gaTournamentSelect(population,sizeOfTournament,stream)
%GATOURNAMENTSELECT Sample distinct individuals without replacement.
assert(numel(unique(string({population.key})))==numel(population),'AGV:GAPopulation','Tournament population must have unique GS.');
assert(sizeOfTournament>=1 && sizeOfTournament<=numel(population) && sizeOfTournament==fix(sizeOfTournament),'AGV:GATournament','Invalid tournament size.');
draw=randperm(stream,numel(population),sizeOfTournament);
order=gaRankCandidates(population(draw)); index=draw(order(1));
end
