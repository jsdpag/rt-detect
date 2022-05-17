
function  e = rt_det_train_event_marker( states )
% 
% e = rt_det_train_event_marker( states )
% 
% Creates unsigned 16-bit integer codes for each state named in states, a
% cell array of strings. Discards special values 1, used by ARCADE for init
% and shutdown time stamps, and the session Pause/Resume codes. The latter
% are found in the session's ArcadeConfig object. All state names must be
% valid MATLAB field names.
% 
  
  % Empty input
  if  isempty( states )
    
    error( 'states is empty' )
  
  % Input arg must be cell array of strings
  elseif  ~ iscellstr( states )
    
    error( 'states must be cell array of strings' )
    
  % All strings must be valid variable/field names
  elseif  any( ~ cellfun( @isvarname , states ) )
    
    error( 'states must contain valid MATLAB variable/field names' )
    
  end % input check
  
  % Constant, reserved ARCADE init/shutdown code
  ARCADE_INIT_SHUTDOWN = 1 ;
  
  % Get session ArcadeConfig object
  cfg = retrieveConfig ;
  
  % Reserved values
  RESERVED = [ ARCADE_INIT_SHUTDOWN ;
               cfg.EventMarker.Pause ;
               cfg.EventMarker.Resume ] ;
  
  % Create a list of possible event marker values, from one to number of
  % states plus number of reserved values
  eval = 1 : numel( states ) + numel( RESERVED ) ;
  
  % Remove reserved values
  eval( ismember( eval , RESERVED ) ) = [ ] ;
  
  % State names and marker codes
  for  i = 1 : numel( states ) , nam = states{ i } ; val = eval( i ) ;
    
    % Assign event marker code to named state
    e.( nam ) = val ;
    
  end % states
	
end % rt_det_train_event_marker

