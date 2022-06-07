
function  onEntry_generic( a )
%
% onEntry_generic( a )
% 
% Generic onEntry_generic function for ARCADE State objects. a must be a
% struct returned by onEntry_args( ).
% 
% Jackson Smith - May 2022 - Fries Lab (ESI Frankfurt)
% 
  
  % Point to logical flags
  flg = a.flg ;
  
  % *_entry event marker
  if  flg.Marker_entry , eventmarker( a.Marker_entry ) ; end

  % Begin stimulus grouping
  if  flg.grpstim , groupStimuli( 'start' ) , end
  
    % Flip stimulus visibility
    for  S = a.Stim , s = S{ 1 } ; s.visible = ~ s.visible ; end

    % Change state of photodiode
    if  flg.Photodiode , photodiode( a.Photodiode ) , end
  
  % Finished stimulus grouping
  if  flg.grpstim , groupStimuli( 'end' ) , end
  
  % Reset events
  for  i = 1 : numel( a.Reset ) , a.Reset( i ).reset , end
  
  % Trigger events
  for  i = 1 : numel( a.Trigger ) , a.Trigger( i ).trigger , end
  
  % Time zero is defined
  if  flg.TimeZero
    
    % Measure elapsed time in seconds
    t = toc( a.TimeZero.startTic ) ;
    
    % Time store provided
    if  flg.RunTimeVal , a.RunTimeVal.value = t ; end
    
    % Format time string.
    ts = sprintf( '%7.3f' , t ) ;
  
  % Low-res, absolute time stamp
  else , ts = datestr( now , 'HH:MM:SS' ) ;
  end
  
  % Print state name with time stamp
  EchoServer.Write( '%s %s\n' , ts , a.State.name ) ;
  
  % Register trial error code on current trial
  if  flg.TrialError , trialerror( a.TrialError ) , end
  
  % *_start event marker
  if  flg.Marker_start , eventmarker( a.Marker_start ) ; end
  
end % onEntry_generic

