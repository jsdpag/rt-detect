
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

%- Session launch parameters -%

% Open a separate EDF file on EyeLink HostPC for each unique session ID
sesslaunchparams.EyeServer_UniqueTmp = true ;

% Place ARCADE remote in upper-right hand corner of screen
sesslaunchparams.Location_ArcadeRemote = 'northeast' ;

% Starting positions of EyeLinkServer and EchoServer
sesslaunchparams.Position_EyeServer  = [ 1 , 1 , -1 , -1 ] ;
sesslaunchparams.Position_EchoServer = [ 870 , 1 , 588 , 564 ] ;
