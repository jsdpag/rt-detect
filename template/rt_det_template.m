
% 
% rt_det_template.m
% 
% Use Win32 Start/EndFix, Start/EndSacc events from EyeLinkServer to
% control the timing on states in this training version of the reaction
% time detection task used by Jackson Smith's optogenetics project in the
% lab of Pascal Fries.
% 

%%% GLOBAL INITIALISATION %%%

% Session's ARCADE config object
cfg = retrieveConfig ;


%%% FIRST TRIAL INITIALISATION -- PERSISTENT DATA %%%

if  TrialData.currentTrial == 1
  
  % Event marker codes for each state
  P.evm = rt_det_template_event_marker( { 'Start' , 'HoldFix' , 'Wait' ,...
    'TargetOn' , 'ResponseWindow' , 'Saccade' , 'GetSaccadeTarget' , ...
      'Evaluate' , 'TargetSelected' , 'NothingSelected' , 'GetFix' , ...
        'FalseAlarmSaccade' , 'Ignored' , 'LostFix' , 'BrokenFix' , ...
          'BrokenSaccade' , 'EyeTrackError' , 'FalseAlarm' , 'Missed' , ...
            'Failed' , 'Correct' , 'cleanUp' } ) ;
  
  % Make copy of trial error name to value mapping
  P.err = gettrialerrors( true ) ;
  
  % Open Win32 inter-process communication events
  for  E = { 'StartSacc' , 'EndSacc' , 'StartFix' , 'FalseAlarmFlag' , ...
      'Waiting' }
    name = E{ 1 } ;
    P.( name ) = IPCEvent( name ) ;
  end
  
  % Calculate pixels per degree of visual field. cm/deg * pix/cm = pix/deg.
  P.pixperdeg = ( cfg.DistanceToScreen * tand( 1 ) )  *  ...
    ( sqrt( str2double( cfg.MonitorResolution.width  ) ^ 2  +  ...
            str2double( cfg.MonitorResolution.height ) ^ 2 ) / ...
      cfg.MonitorDiagonalSize ) ;
  
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
  trackeye( P.Fix.position    ,  50 , 'Fix'    ) ;
  trackeye( P.Target.position , 200 , 'Target' ) ;
  
% Retrieve persistent data
else
  
  P = persist ;
  
end % first trial init


%%% Trial variables %%%

% These will become user variables
WAITAVG = 1500 ;
WAITMAX = 0.95 ;
REWARD_SLOPE =  1.5 ;
REWARD_MAX   =  150 ;
REWARD_MIN   =   20 ;
REWARD_FAIL  = 0.25 ;

% Sample wait duration
WDUR = min( exprnd( WAITAVG ) , expinv( WAITMAX , WAITAVG ) ) ;

% Compute reward size for correct performance
rew = rewardsize( P.err.Correct , expcdf( WDUR , WAITAVG ) / WAITMAX , ...
  REWARD_SLOPE , REWARD_MAX ) ;
  
  % And for failed trial [ correct reward , failed reward ]
  rew = [ rew , REWARD_FAIL * rew ] ;
  
  % Round up to next millisecond and guarantee minimum reward size
  rew = max( REWARD_MIN , ceil( rew ) ) ;


%%% DEFINE TASK STATES %%%

% Table of states. Each row defines a state. Column order is: state name;
% timeout duration; next state after timeout or max repetitions; wait event
% list; next state(s) after wait event(s), latter two are string or cell of
% strings; cell array of additional Name/Value input args for onEntry
% actions. For onEntry args, the State, State event marker, trial error
% code, and time zero state handle are automatically generated; only
% include additional args.
STATE_TABLE = ...
{           'Start' , 5000 , 'Ignored'        ,     'FixIn' , 'HoldFix' , { 'Stim' , { P.Fix } , 'Photodiode' , 'off' , 'Reset' , P.Waiting } ;
          'HoldFix' ,  300 , 'Wait'           ,    'FixOut' , 'GetFix' , {} ;
             'Wait' , WDUR , 'TargetOn'       ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Reset' , [ P.StartSacc , P.EndSacc , P.FalseAlarmFlag ] , 'Trigger' , P.Waiting , 'Photodiode' , 'on' } ;
         'TargetOn' ,  100 , 'ResponseWindow' ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Stim' , { P.Target } , 'Photodiode' , 'off' , 'RunTimeVal' , P.RTstart } ;
   'ResponseWindow' ,  400 , 'Failed'         ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'Saccade' } , { 'Reset' , P.Waiting } ;
          'Saccade' ,  125 , 'BrokenSaccade'  ,   'EndSacc' , 'GetSaccadeTarget' , { 'Reset' , P.StartFix , 'RunTimeVal' , P.RTend } ;
 'GetSaccadeTarget' ,  100 , 'EyeTrackError'  ,  'StartFix' , 'Evaluate' , {} ;
         'Evaluate' ,    0 , 'EyeTrackError'  ,  { 'TargetIn' , 'FixOut' } , { 'TargetSelected' , 'NothingSelected' } , {} ;
   'TargetSelected' ,    0 , 'Correct'        , 'FalseAlarmFlag' , 'FalseAlarm' , {} ;
  'NothingSelected' ,    0 , 'Missed'         ,   'Waiting' , 'BrokenFix' , {} ;
           'GetFix' , 1000 , 'LostFix'        ,     'FixIn' , 'HoldFix' , {} ;
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
AUXACT.HoldFix = { @( ) set( P.Fix , 'faceColor' , [ 255 , 255 , 255 ] ) };
AUXACT.GetFix  = { @( ) set( P.Fix , 'faceColor' , [ 000 , 000 , 000 ] ) };
AUXACT.Correct = { @( ) reactiontime( 'writeRT' , P.RTend.get_value( ) -...
                          P.RTstart.get_value( ) ) , ...
                   @( ) reward( rew( 1 ) ) , ...
                   @( ) fprintf( '%8sReward %dms\n' , '' , rew( 1 ) ) } ;
AUXACT.Failed  = { @( ) reward( rew( 2 ) ) , ...
                   @( ) fprintf( '%8sReward %dms\n' , '' , rew( 2 ) ) } ;
AUXACT.cleanUp = { @( ) set( P.Fix    , 'visible' , false ) , ...
                   @( ) set( P.Target , 'visible' , false ) } ;

% Special actions executed when state is finished executing
ENDACT.cleanUp = { @( ) logmessage( sprintf( 'End trial %d' , ...
  TrialData.currentTrial ) ) } ;

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

% States with special actions at beginning of state
for  F = fieldnames( AUXACT )' , name = F{ 1 } ;
  
  % Append additional actions
  states.( name ).onEntry = [ states.( name ).onEntry , AUXACT.( name ) ] ;
  
end % special onEntry actions

% States with special action after having executed
for  F = fieldnames( ENDACT )' , name = F{ 1 } ;
  
  % Append additional actions
  states.( name ).onExit = [ states.( name ).onExit , ENDACT.( name ) ] ;
  
end % special onExit actions

% Only GetFix has different Max repetitions
states.GetFix.maxRepetitions = MAXREP_GETFIX ;


%%% Reset Stimuli %%%

% Black fixation point
P.Fix.faceColor( : ) = 0 ;


%%% CREATE TRIAL %%%

states = struct2cell( states ) ;
createTrial( 'Start' , states{ : } )

% Output to message log
fprintf( '\n' )
logmessage( sprintf( 'Start trial %d' , TrialData.currentTrial ) )
fprintf( '%9sWait %dms\n' , '' , ceil( WDUR ) )


%%% --- SCRIPT FUNCTIONS --- %%%

% Maintain local persistent data
function  pout = persist( pin )
  
  persistent  p
  
  if  nargin  ,  p = pin ; end
  if  nargout , pout = p ; end
  
end % persist

