
% 
% session_launch_script.m
% 
% Task-specific launch setting actions go here. Define sesslaunchparams for
% special actions. It is an optional struct with optional fields:
% 
%   .EyeServer_SampleMode - If true then sample mode is enabled.
%   .EyeServer_UniqueTmp  - If true then each session number gets its own
%     tmp<session id>.edf file on the EyeLink host PC. Thus, make sure that
%     each session gets a unique id on a given day.
% 

% Don't open normal ARCADE control screen. Use the minimalist remote,
% instead.
cfg.ControlScreen = 'makeArcadeRemote.m' ;

% Create sesslaunchparams
sesslaunchparams.EyeServer_UniqueTmp = true ;
