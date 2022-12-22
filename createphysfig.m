
function  ofig = createphysfig(  cfg , evar , tab )
% 
% ofig = createphysfig(  cfg , evar , tab )
% 
% Create and initialise electrophysiology plots. Called by task script. cfg
% is the ArcadeConfig object of the current session. evar is a struct
% containing all editable variables. tab is a Table object containing
% processed version of trial_condition_table.csv, which defines all trial
% conditions and groups them into blocks of trials. Returns an onlinefigure
% object. Create plots before running the first trial.
% 
% Note, creates secondary figure window that allows selection of channel in
% the main window.
% 
  
  ofig = [ ] ;
  
  % Subtract list height by 109, height of remote in upper-right corner
  
end

