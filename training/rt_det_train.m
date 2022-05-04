
% 
% rt_det_train.m
% 
% Use Win32 Start/EndFix, Start/EndSacc events from EyeLinkServer to
% control the timing on states in this training version of the reaction
% time detection task used by Jackson Smith's optogenetics project in the
% lab of Pascal Fries.
% 
dbstop in rt_det_train.m at 14

%%% FIRST TRIAL INITIALISATION -- PERSISTENT DATA %%%

if  TrialData.currentTrial == 1
  
  % Event marker codes for each state
  P.evm = rt_det_train_event_marker( STATE_TABLE( : , 1 ) ) ;
  
  % Make copy of trial error name to value mapping
  P.err = gettrialerrors( true ) ;
  
  % Open Win32 inter-process communication events
  for  E = { 'StartSacc' , 'EndSacc' , 'StartFix' , 'FalseAlarmFlag' }
    name = E{ 1 } ;
    P.( name ) = IPCEvent( name ) ;
  end
  
  % Create fixation and target stimulus handles
  P.Fix = Rectangle ;
  
    P.Fix.position = [ 0 , 0 ] ;
    P.Fix.faceColor( : ) = 255 ;
    P.Fix.width = 10 ;
    P.Fix.height = 10 ;
    P.Fix.angle = 45 ;
  
  P.Target = Gaussian ;
  
    P.Target.position = [ +420 , -262 ] ;
    P.Target.sdx = 80 ;
    P.Target.sdy = 80 ;
    P.Target.color( : ) = 255 ;
  
  % Keep persistent store of IPCEvent handles
  persist( P )
  
  % Create fixation and target eye windows
  trackeye( P.Fix.position    ,  50 , 'Fix'    )
  trackeye( P.Target.position , 200 , 'Target' )
  
% Retrieve persistent data
else
  
  P = persist ;
  
end % first trial init


%%% DEFINE TASK STATES %%%

% Sample wait duration
WDUR = min( exprnd( 1500 ) , expinv( 0.95 , 1500 ) ) ;

% Table of states. Each row defines a state. Column order is: state name;
% timeout duration; next state after timeout or max repetitions; wait event
% list; next state(s) after wait event(s), latter two are string or cell of
% strings; cell array of additional Name/Value input args for onEntry
% actions. For onEntry args, the State, State event marker, trial error
% code, and Start state handle are automatically generated; only include
% additional args.
STATE_TABLE = ...
{           'Start' , 5000 , 'Ignored'        ,     'FixIn' , 'HoldFix' , { 'Photodiode' , 'off' } ;
          'HoldFix' ,  300 , 'Wait'           ,    'FixOut' , 'GetFix' , { 'Stim' , P.Fix } ;
             'Wait' , WDUR , 'TargetOn'       ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Event' , 'Photodiode' } ;
         'TargetOn' ,  100 , 'ResponseWindow' ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Stim' , 'Event' , 'Photodiode' , 'RunTimeVar' , 'RunTimeVal' } ;
   'ResponseWindow' ,  400 , 'Failed'         ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'Saccade' } , { 'Stim' , 'Event' , 'Photodiode' , 'RunTimeVar' , 'RunTimeVal' } ;
          'Saccade' ,  125 , 'BrokenSaccade'  ,   'EndSacc' , 'GetSaccadeTarget' , { 'Stim' , 'Event' , 'Photodiode' , 'RunTimeVar' , 'RunTimeVal' } ;
 'GetSaccadeTarget' ,  100 , 'EyeTrackError'  ,  'StartFix' , 'Evaluate' , { 'Stim' , 'Event' , 'Photodiode' , 'RunTimeVar' , 'RunTimeVal' } ;
         'Evaluate' ,    0 , 'EyeTrackError'  ,  'TargetIn' , 'TargetSelected' , { 'Stim' , 'Event' , 'Photodiode' , 'RunTimeVar' , 'RunTimeVal' } ;
   'TargetSelected' ,    0 , 'Correct'        , 'FalseAlarmFlag' , 'FalseAlarm' , { 'Stim' , 'Event' , 'Photodiode' , 'RunTimeVar' , 'RunTimeVal' } ;
           'GetFix' , 1000 , 'LostFix'        , 'FixIn' , 'HoldFix' , { 'Stim' , 'Event' , 'Photodiode' , 'RunTimeVar' , 'RunTimeVal' } ;
'FalseAlarmSaccade' ,    0 , 'Saccade'        , {} , {} , { 'Stim' , 'Event' , 'Photodiode' , 'RunTimeVar' , 'RunTimeVal' } ;
          'Ignored' ,    0 , 'cleanUp'        , {} , {} , {} ;
          'LostFix' ,    0 , 'cleanUp'        , {} , {} , {} ;
        'BrokenFix' ,    0 , 'cleanUp'        , {} , {} , {} ;
    'BrokenSaccade' ,    0 , 'cleanUp'        , {} , {} , {} ;
    'EyeTrackError' ,    0 , 'cleanUp'        , {} , {} , {} ; 
       'FalseAlarm' ,    0 , 'cleanUp'        , {} , {} , {} ;
           'Missed' ,    0 , 'cleanUp'        , {} , {} , {} ;
           'Failed' ,    0 , 'cleanUp'        , {} , {} , {} ;
          'Correct' ,    0 , 'cleanUp'        , {} , {} , {} ;
          'cleanUp' ,    0 , 'final'          , {} , {} , {} ;
} ;

% Special constants for value of max reps
MAXREP_DEFAULT = 2 ;
MAXREP_GETFIX  = 100 ;


%%% MAKE ARCADE STATES %%%

% State table rows
for  row = 1 : size( STATE_TABLE , 1 )
  
  % Map table entry to meaningful names
  [ name , timeout , tout_next , waitev , wait_next , entarg ] = ...
    STATE_TABLE{ row , : } ;
  
  % Create new state
  states.( name ) = State( name ) ;
  
  % Set timeout duration, max number executions, and next state after
  % timeout or max reps. Max reps = 2 so that no inf loops, and don't trig
  % wrong state.
  states.( name ).duration                     =        timeout ;
  states.( name ).maxRepetitions               = MAXREP_DEFAULT ;
  states.( name ).nextStateAfterTimeout        =      tout_next ;
  states.( name ).nextStateAfterMaxRepetitions =      tout_next ;
  states.( name ).waitEvents                   =         waitev ;
  states.( name ).nextStateAfterEvent          =      wait_next ;
  
  % Want different number of maximum executions for state
  if  isfield( MAXREP , name )
    states.( name ).maxRepetitions = MAXREP.( name ) ;
  end
  
end % rows

% Special action, only GetFix has different Max repetitions
states.GetFix.maxRepetitions = MAXREP_GETFIX ;


%%% DEFINE STATE ACTIONS %%%

% HoldFix turns Fix point on
states.HoldFix.onEntry = { @() set( P.Fix , 'visible' , 1 ) } ;

% GetFix turns Fix point off
states.GetFix.onEntry = { @() set( P.Fix , 'visible' , 0 ) } ;

% Wait resets saccade and FA events
E = { P.StartSacc , P.EndSacc , P.FalseAlarmFlag } ;
states.Wait.onEntry = { @() cellfun( @( e ) e.reset , E ) } ;

% TargetOn makes target visible
states.TargetOn.onEntry = { @() set( P.Target , 'visible' , 1 ) } ;

% FalseAlarmSaccade raises FalseAlarmFlag event
states.FalseAlarmSaccade.onEntry = { @() P.FalseAlarmFlag.trigger } ;

% Saccade resets StartFix event
states.Saccade.onEntry = { @() P.StartFix.reset } ;

% cleanUp makes all visual stimuli disappear
E = { P.Fix , P.Target } ;
states.cleanUp.onEntry = ...
  { @() cellfun( @( s ) set( s , 'visible' , 0 ) , E ) } ;


%%% CREATE TRIAL %%%

states = struct2cell( states ) ;
createTrial( 'Start' , states{ : } )


%%% --- SCRIPT FUNCTIONS --- %%%

% Maintain local persistent data
function  pout = persist( pin )
  
  persistent  p
  
  if  nargin  ,  p = pin ; end
  if  nargout , pout = p ; end
  
end % persist

% Build input argument struct for state action function. Provide name,
% value pairs. Names are also the fields of an arg struct. Valid names are:
% 'State' - Handle to calling state. 'Marker' - integer event
% marker value sent out of DAQ digital ports when state's onEntry
% executes. 'Stim' - ARCADE stimulus handle,
% visibility is simply flipped to opposite state. 'Event' - Array of
% IPCEvent handles, all connected Win32 events are reset. 'TrialError' -
% scalar numeric trial error code. 'Photodiode' - char vector i.e. string
% of valid input for photodiode helper function. 'TimeZero' - Handle to
% State object, its startTic value is used as time zero, against which time
% is measured. 'RunTimeVal' - Handle to StateRuntimeVariable in which
% elapsed seconds since time zero is stored.
function  ain = argstruct( varargin )
  
  % Default ain field name set
  ain = { 'State' , 'Marker' , 'Stim' , 'Event' , 'TrialError' , ...
    'Photodiode' , 'TimeZero' , 'RunTimeVal' } ;
  
  % Append second row of empty double arrays
  ain = [ ain ; cell( size( ain ) ) ] ;
  
  % Make a copy for logical flags
  flg = ain ;
  
    % Replace empty arrays with scalar logical false
    flg( 2 , : ) = { false } ;
  
  % Create struct of valid input names, for mapping to input values
  ain = struct( ain{ : } ) ;
  flg = struct( flg{ : } ) ;
  
  % Scan input Name/Value pairs
  for  i = 1 : 2 : nargin , nam = varargin{ i } ; val = varargin{ i + 1 } ;
    
    % Store value
    ain.( nam ) = val ;
    
    % Raise flag
    flg.( nam ) = true ;
    
  end % name/val
  
  % Create an additional flag. Raise this if it is necessary to group
  % stimuli before drawing the next frame. This is the case when there are
  % more than one stimulus and/or at least one stimulus with a photodiode
  % change.
  flg.grpstim = numel( ain.Stim ) > 1  ||  ( flg.Stim && flg.Photodiode ) ;
  
  % Store flags in return struct
  ain.flg = flg ;
  
end % argstruct


% Generic onEntry function. a is a struct created by argstruct.
function  onEntry( a )
  
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
  
  % Generate event marker
  if  flg.Marker , eventmarker( a.Marker ) , end
  
  % Time zero is defined
  if  fig.TimeZero
    
    % Measure elapsed time in seconds
    t = toc( a.TimeZero.startTic ) ;
    
    % Time store provided
    if  flg.RunTimeVal , a.RunTimeVal.value = t ; end
    
    % Print state name and time from time zero with ms precision
    fprintf( '%7.3f %s\n' , a.Start.elapsedTime , a.State.name )
  
  % Print State name with low-res, absolute time stamp
  else , logmessage( a.State.name )
  end
  
  % Register trial error code on current trial
  if  flg.TrialError , trialerror( a.TrialError ) , end
  
end % onEntry

