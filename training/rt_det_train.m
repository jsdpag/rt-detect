
% 
% rt_det_train.m
% 
% Use Win32 Start/EndFix, Start/EndSacc events from EyeLinkServer to
% control the timing on states in this training version of the reaction
% time detection task used by Jackson Smith's optogenetics project in the
% lab of Pascal Fries.
% 
% dbstop in rt_det_train.m at 14

%%% FIRST TRIAL INITIALISATION -- PERSISTENT DATA %%%

if  TrialData.currentTrial == 1
  
  % Event marker codes for each state
  P.evm = rt_det_train_event_marker( { 'Start' , 'HoldFix' , 'Wait' , ...
    'TargetOn' , 'ResponseWindow' , 'Saccade' , 'GetSaccadeTarget' , ...
      'Evaluate' , 'TargetSelected' , 'GetFix' , 'FalseAlarmSaccade' , ...
        'Ignored' , 'LostFix' , 'BrokenFix' , 'BrokenSaccade' , ...
          'EyeTrackError' , 'FalseAlarm' , 'Missed' , 'Failed' , ...
            'Correct' , 'cleanUp' } ) ;
  
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
  
  % Make reaction time start and end time variables
  P.RTstart = StateRuntimeVariable ;
  P.RTend   = StateRuntimeVariable ;
  
  % Keep persistent store of IPCEvent handles
  persist( P )
  
  % Create fixation and target eye windows
  trackeye( P.Fix.position    ,  50 , 'Fix'    )
  trackeye( P.Target.position , 200 , 'Target' )
  
% Retrieve persistent data
else
  
  P = persist ;
  
end % first trial init


%%% Trial variables %%%

% Session's ARCADE config object
cfg = retrieveConfig ;

% Sample wait duration
WDUR = min( exprnd( 1500 ) , expinv( 0.95 , 1500 ) ) ;


%%% DEFINE TASK STATES %%%

% Table of states. Each row defines a state. Column order is: state name;
% timeout duration; next state after timeout or max repetitions; wait event
% list; next state(s) after wait event(s), latter two are string or cell of
% strings; cell array of additional Name/Value input args for onEntry
% actions. For onEntry args, the State, State event marker, trial error
% code, and time zero state handle are automatically generated; only
% include additional args.
STATE_TABLE = ...
{           'Start' , 5000 , 'Ignored'        ,     'FixIn' , 'HoldFix' , { 'Stim' , { P.Fix } , 'Photodiode' , 'off' } ;
          'HoldFix' ,  300 , 'Wait'           ,    'FixOut' , 'GetFix' , { 'Stim' , { P.Fix } } ;
             'Wait' , WDUR , 'TargetOn'       ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Event' , [ P.StartSacc , P.EndSacc , P.FalseAlarmFlag ] , 'Photodiode' , 'on' } ;
         'TargetOn' ,  100 , 'ResponseWindow' ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Stim' , { P.Target } , 'Photodiode' , 'off' , 'RunTimeVal' , P.RTstart } ;
   'ResponseWindow' ,  400 , 'Failed'         ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'Saccade' } , { } ;
          'Saccade' ,  125 , 'BrokenSaccade'  ,   'EndSacc' , 'GetSaccadeTarget' , { 'Event' , P.StartFix , 'RunTimeVal' , P.RTend } ;
 'GetSaccadeTarget' ,  100 , 'EyeTrackError'  ,  'StartFix' , 'Evaluate' , {} ;
         'Evaluate' ,    0 , 'EyeTrackError'  ,  { 'TargetIn' , 'FixOut' } , { 'TargetSelected' , 'Missed' } , {} ;
   'TargetSelected' ,    0 , 'Correct'        , 'FalseAlarmFlag' , 'FalseAlarm' , {} ;
           'GetFix' , 1000 , 'LostFix'        , 'FixIn' , 'HoldFix' , {} ;
'FalseAlarmSaccade' ,    0 , 'Saccade'        , {} , {} , { 'Trigger' , P.FalseAlarmFlag } ;
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

% Special actions that are not executed by generic onEntry
AUXACT.Correct = { @( ) reactiontime( 'writeRT' , P.RTend.get_value( ) -...
                          P.RTstart.get_value( ) ) , ...
                   @( ) reward( 100 ) } ;
AUXACT.cleanUp = { @( ) set( P.Fix    , 'visible' , false ) , ...
                   @( ) set( P.Target , 'visible' , false ) } ;

% Special constants for value of max reps
MAXREP_DEFAULT = 2 ;
MAXREP_GETFIX  = 100 ;

% Error check first trial, make sure that there is an event marker for
% each state name
if  TrialData.currentTrial == 1  &&  ...
    ~ isequal( fieldnames( P.evm ) , STATE_TABLE( : , 1 ) )
    
  error( 'Mismatched event and state names' )
  
end % state name check


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
  
  % Issue a trial error code if this is an end state i.e. it transitions to
  % cleanUp. Default empty.
  TrialError = { } ;
  if  strcmp( tout_next , 'cleanUp' )
    TrialError = { 'TrialError' , P.err.( name ) } ;
  end
  
  % Default Name/Value pairs for onEntry input argument constructor. Append
  % additional pairs for this state.
  entarg = [ entarg , TrialError , { 'State' , states.( name ) , ...
    'Marker' , P.evm.( name ) , 'TimeZero' , states.Start } ] ;
  
  % onEntry input arg struct
  a = onEntry_args( entarg{ : } ) ;
  
  % Define state's onEntry actions
  states.( name ).onEntry = { @( ) onEntry_generic( a ) } ;
  
end % rows

% States with special actions
for  F = fieldnames( AUXACT )' , name = F{ 1 } ;
  
  % Append additional actions
  states.( name ).onEntry = [ states.( name ).onEntry , AUXACT.( name ) ] ;
  
end % special actions

% Only GetFix has different Max repetitions
states.GetFix.maxRepetitions = MAXREP_GETFIX ;


%%% CREATE TRIAL %%%

states = struct2cell( states ) ;
createTrial( 'Start' , states{ : } )

% Output to message log
fprintf( '\n' )
logmessage( sprintf( 'Trial %d' , TrialData.currentTrial ) )


%%% --- SCRIPT FUNCTIONS --- %%%

% Maintain local persistent data
function  pout = persist( pin )
  
  persistent  p
  
  if  nargin  ,  p = pin ; end
  if  nargout , pout = p ; end
  
end % persist

