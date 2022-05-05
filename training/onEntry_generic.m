
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

  % Begin stimulus grouping
  if  flg.grpstim , groupStimuli( 'start' ) , end
  
    % Flip stimulus visibility
    for  S = a.Stim , s = S{ 1 } ; s.visible = ~ s.visible ; end

    % Change state of photodiode
    if  flg.Photodiode , photodiode( a.Photodiode ) , end
  
  % Finished stimulus grouping
  if  flg.grpstim , groupStimuli( 'end' ) , end
  
  % Reset events
  for  i = 1 : numel( a.Event ) , a.Event( i ).reset , end
  
  % Trigger events
  for  i = 1 : numel( a.Trigger ) , a.Trigger( i ).trigger , end
  
  % Generate event marker
  if  flg.Marker , eventmarker( a.Marker ) , end
  
  % Time zero is defined
  if  flg.TimeZero
    
    % Measure elapsed time in seconds
    t = toc( a.TimeZero.startTic ) ;
    
    % Time store provided
    if  flg.RunTimeVal , a.RunTimeVal.value = t ; end
    
    % Print state name and time from time zero with ms precision
    fprintf( '%7.3f %s\n' , t , a.State.name )
  
  % Print State name with low-res, absolute time stamp
  else , logmessage( a.State.name )
  end
  
  % Register trial error code on current trial
  if  flg.TrialError , trialerror( a.TrialError ) , end
  
end % onEntry_generic

