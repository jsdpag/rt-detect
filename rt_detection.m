
% 
% rt_detection.m
% 
% Use Win32 Start/EndFix, Start/EndSacc events from EyeLinkServer to
% control the timing on states in this training version of the reaction
% time detection task used by Jackson Smith's optogenetics project in the
% lab of Pascal Fries.
% 
% dbstop in rt_detection.m at 14
%%% GLOBAL INITIALISATION %%%

% Session's ARCADE config object
cfg = retrieveConfig ;

% Gain access to block selection function's global variable
global  ARCADE_BLOCK_SELECTION_GLOBAL ;


%%% FIRST TRIAL INITIALISATION -- PERSISTENT DATA %%%

if  TrialData.currentTrial == 1
  
  % Store local pointer to table defining blocks of trials
  P.tab = ARCADE_BLOCK_SELECTION_GLOBAL.tab ;
  
  % Handle to session's behavioural store object
  P.bhv = SGLBehaviouralStore.launch ;
  
  % Define state names, column of cells
  P.nam = { 'Start' , 'HoldFix' , 'Wait' , 'TargetOn' , ...
    'ResponseWindow' , 'Saccade' , 'GetSaccadeTarget' , 'Evaluate' , ...
      'TargetSelected' , 'Microsaccade' , 'NothingSelected' , 'GetFix' ,...
        'FalseAlarmSaccade' , 'Ignored' , 'Blink' , 'BrokenFix' , ...
          'BrokenSaccade' , 'EyeTrackError' , 'FalseAlarm' , 'Missed' , ...
            'Failed' , 'Correct' , 'cleanUp' }' ;
  
  % Event marker codes for each state
  [ P.evm , P.evh ] = event_marker( P.nam ) ;
  
  % Make copy of trial error name to value mapping
  P.err = ARCADE_BLOCK_SELECTION_GLOBAL.err ;
  
  % Open Win32 inter-process communication events
  for  E = { 'StartSacc' , 'EndSacc' , 'StartFix' , 'FalseAlarmFlag' , ...
      'Waiting' , 'BlinkStart' , 'BlinkEnd' }
    name = E{ 1 } ;
    P.( name ) = IPCEvent( name ) ;
  end
  
  % Calculate pixels per degree of visual field. cm/deg * pix/cm = pix/deg.
  P.pixperdeg = ( cfg.DistanceToScreen * tand( 1 ) )  *  ...
    ( sqrt( str2double( cfg.MonitorResolution.width  ) ^ 2  +  ...
            str2double( cfg.MonitorResolution.height ) ^ 2 ) / ...
      cfg.MonitorDiagonalSize ) ;
  
  % Previous trial eye track window parameters
  P.EyeTrack = struct( 'RfXDeg' , NaN , 'RfYDeg' , NaN , ...
    'RfRadDeg' , NaN , 'RfWinFactor' , NaN , 'FixTolDeg' , NaN ) ;
  
  % Create fixation and target stimulus handles
  P.Target = Gaussian ;
  
    P.Target.position = sqrt( 8 ^ 2 / 2 ) .* [ 1 , -1 ] * P.pixperdeg ;
    P.Target.sdx = 1.5 * P.pixperdeg ;
    P.Target.sdy = P.Target.sdx ;
    P.Target.color( : ) = 255 ;
    
  P.Fix = Rectangle ;
  
    P.Fix.position = [ 0 , 0 ] ;
    P.Fix.faceColor( : ) = 255 ;
    P.Fix.width = sqrt( pi * 0.075 ^ 2 ) * P.pixperdeg ;
    P.Fix.height = P.Fix.width ;
    P.Fix.angle = 45 ;
  
  % Make reaction time start and end time variables, and tic time
  % measurement at end of previous trial for ITI measure
  P.RTstart  = StateRuntimeVariable ;
  P.RTend    = StateRuntimeVariable ;
  P.ITIstart = StateRuntimeVariable ;
  
    % Initialise P.ITIstart to zero, so that we don't wait on first trial
    P.ITIstart.value = zeros( 1 , 'uint64' ) ;
  
% Retrieve persistent data
else
  
  P = persist ;
  
end % first trial init


%%% Trial variables %%%

% Error check editable variables
v = evarchk( RewardMaxMs , RfXDeg , RfYDeg , RfRadDeg , RfWinFactor , ...
  FixTolDeg , BaselineMs , WaitAvgMs , WaitMaxProb , RewardSlope , ...
    RewardMinMs , RewardFailFrac , ScreenGamma , ItiMinMs ) ;
  
% Add type of block
v.BlockType = ARCADE_BLOCK_SELECTION_GLOBAL.typ ;


% Convert variables with degrees into pixels, without destroying original
% value in degrees
for  F = { 'RfXDeg' , 'RfYDeg' , 'RfRadDeg' , 'FixTolDeg' } ; f = F{ 1 } ;
  
  vpix.( f ) = v.( f ) * P.pixperdeg ;
  
end % deg2pix

% Sample wait duration
WaitMs = min( exprnd( WaitAvgMs ) , expinv( WaitMaxProb , WaitAvgMs ) ) ;

  % Make a copy of this trial's waiting time, minus baseline
  v.WaitMs = WaitMs ;

% Compute reward size for correct performance
rew = rewardsize( P.err.Correct , ...
  expcdf( WaitMs , WaitAvgMs ) / WaitMaxProb , RewardSlope , RewardMaxMs );
  
  % And for failed trial [ correct reward , failed reward ]
  rew = [ rew , RewardFailFrac * rew ] ;
  
  % Round up to next millisecond and guarantee minimum reward size
  rew = max( RewardMinMs , ceil( rew ) ) ;
  
  % Store reward sizes
  v.Reward_Correct = rew( 1 ) ;
  v.Reward_Failed  = rew( 2 ) ;
  
% Add baseline period, this is now the duration of the Wait state.
WaitMs = WaitMs  +  BaselineMs ;

% Ask StimServer.exe to apply a measure of luminance Gamma correction
StimServer.InvertGammaCorrection( ScreenGamma ) ;


%%% Eye Tracking %%%

% Check to see if any eye tracking window params have changed since last
% trial, because editable variables were changed during task pause. Don't
% reset and rebuild windows if unnecessary because trackeye wastes 500ms on
% each reset (as of ARCADE v2.6).
if  ~ all(  cellfun( @( f ) v.( f ) == P.EyeTrack.( f ) , ...
                                              fieldnames( P.EyeTrack ) )  )

  % Delete any existing eye window
  trackeye( 'reset' ) ;

  % Create fixation and target eye windows
  trackeye( [ 0 , 0 ] , vpix.FixTolDeg , 'Fix' ) ;
  trackeye( [ vpix.RfXDeg , vpix.RfYDeg ] , vpix.RfRadDeg * RfWinFactor,...
    'Target' ) ;
  
  % Remember new values
  for  F = fieldnames( P.EyeTrack )' , f = F{ 1 } ;
    P.EyeTrack.( f ) = v.( f ) ;
  end

end % update eye windows


%%% Stimulus configuration %%%

P.Target.position = [ vpix.RfXDeg , vpix.RfYDeg ] ;
P.Target.sdx = vpix.RfRadDeg / 3 ;
P.Target.sdy = P.Target.sdx ;


%%% DEFINE TASK STATES %%%

% Special actions executed when state is finished executing. Remember to
% make this a column vector of cells.

  % Correct state. Calculate reaction time, convert unit from seconds to
  % milliseconds. Report RT.
  ENDACT.Correct = ...
    { @( ) reactiontime( 'writeRT' , 1e3 * ( P.RTend.get_value( ) - ...
             P.RTstart.get_value( ) ) ) ;
      @( ) EchoServer.Write( '%8sRT %dms\n' , '' , ...
             ceil( P.bhv.reactionTime( P.bhv.currentTrial ) ) ) } ;
  
  % cleanUp measures time that inter-trial-interval starts, then prints one
  % final message to show that all State objects have finished executing
  % and that control is returning to ARCADE's inter-trial code.
  ENDACT.cleanUp = ...
    { @( ) P.ITIstart.set_value( tic ) ;
      @( ) EchoServer.Write( 'End trial %d\n' , TrialData.currentTrial ) };

% Special constants for value of max reps
MAXREP_DEFAULT = 2 ;
MAXREP_GETFIX  = 100 ;

% Table of states. Each row defines a state. Column order is: state name;
% timeout duration; next state after timeout or max repetitions; wait event
% list; next state(s) after wait event(s), latter two are string or cell of
% strings; cell array of additional Name/Value input args for onEntry
% actions. For onEntry args, the State, State event marker, trial error
% code, and time zero state handle are automatically generated; only
% include additional args.
STATE_TABLE = ...
{           'Start' , 5000 , 'Ignored'        ,     'FixIn' , 'HoldFix' , { 'Stim' , { P.Fix } , 'StimProp' , { P.Fix , 'faceColor' , [ 000 , 000 , 000 ] } , 'Photodiode' , 'off' , 'Reset' , P.Waiting } ;
          'HoldFix' ,  300 , 'Wait'           ,    'FixOut' , 'GetFix' , { 'StimProp' , { P.Fix , 'faceColor' , [ 255 , 255 , 255 ] } } ;
             'Wait' ,WaitMs, 'TargetOn'       ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Reset' , [ P.StartSacc , P.EndSacc , P.BlinkStart , P.BlinkEnd , P.FalseAlarmFlag ] , 'Trigger' , P.Waiting , 'Photodiode' , 'on' } ;
         'TargetOn' ,  100 , 'ResponseWindow' ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Stim' , { P.Target } , 'Photodiode' , 'off' , 'RunTimeVal' , P.RTstart } ;
   'ResponseWindow' ,  400 , 'Failed'         ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'Saccade' } , { 'Reset' , P.Waiting } ;
          'Saccade' ,  125 , 'BrokenSaccade'  ,  { 'BlinkStart' , 'EndSacc' } , { 'Blink' , 'GetSaccadeTarget' } , { 'Reset' , P.StartFix , 'RunTimeVal' , P.RTend } ;
 'GetSaccadeTarget' ,  100 , 'EyeTrackError'  ,  'StartFix' , 'Evaluate' , {} ;
         'Evaluate' ,    0 , 'EyeTrackError'  ,  { 'TargetIn' , 'FixIn' , 'FixOut' } , { 'TargetSelected' , 'Microsaccade' , 'NothingSelected' } , {} ;
   'TargetSelected' ,    0 , 'Correct'        , 'FalseAlarmFlag' , 'FalseAlarm' , {} ;
     'Microsaccade' ,    0 , 'EyeTrackError'  , {} , {} , {} ;
  'NothingSelected' ,    0 , 'Missed'         ,   'Waiting' , 'BrokenFix' , {} ;
           'GetFix' , 5000 , 'Ignored'        ,     'FixIn' , 'HoldFix' , { 'StimProp' , { P.Fix , 'faceColor' , [ 000 , 000 , 000 ] } } ;
'FalseAlarmSaccade' ,    0 , 'Saccade'        , {} , {} , { 'Trigger' , P.FalseAlarmFlag } ;
          'Ignored' ,    0 , 'cleanUp'        , {} , {} , {} ;
            'Blink' , 5000 , 'cleanUp'        , 'BlinkEnd' , 'cleanUp' , {} ;
        'BrokenFix' ,    0 , 'cleanUp'        , {} , {} , {} ;
    'BrokenSaccade' ,    0 , 'cleanUp'        , {} , {} , {} ;
    'EyeTrackError' ,    0 , 'cleanUp'        , {} , {} , {} ; 
       'FalseAlarm' ,    0 , 'cleanUp'        , {} , {} , {} ;
           'Missed' ,    0 , 'cleanUp'        , {} , {} , {} ;
           'Failed' ,    0 , 'cleanUp'        , {} , {} , { 'Reward' , v.Reward_Failed  } ;
          'Correct' ,    0 , 'cleanUp'        , {} , {} , { 'Reward' , v.Reward_Correct } ;
          'cleanUp' ,    0 , 'final'          , {} , {} , { 'Photodiode' , 'off' , 'Background' , cfg.BackgroundRGB , 'StimProp' , { P.Fix , 'visible' , false , P.Target , 'visible' , false } } ;
} ;

% Error check first trial, make sure that there is an event marker for
% each state name
if  TrialData.currentTrial == 1 && ~isequal( P.nam , STATE_TABLE( : , 1 ) )
    
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
    'Marker_entry' , P.evm.( [ name , '_entry' ] ) , ...
      'Marker_start' , P.evm.( [ name , '_start' ] ) , ...
        'TimeZero' , states.Start } ] ;
  
  % onEntry input arg struct
  a = onEntry_args( entarg{ : } ) ;
  
  % Define state's onEntry actions
  states.( name ).onEntry = { @( ) onEntry_generic( a ) } ;
  
  % onExit marker values
  states.( name ).onExit = P.evh.( name ) ;
  
end % rows

% States with special action after having executed
for  F = fieldnames( ENDACT )' , name = F{ 1 } ;
  
  % Insert additional actions between event marker triggers
  states.( name ).onExit = [ states.( name ).onExit( 1 ) ;
                                         ENDACT.( name ) ;
                             states.( name ).onExit( 2 ) ] ;
  
end % special onExit actions

% Only GetFix has different Max repetitions
states.GetFix.maxRepetitions = MAXREP_GETFIX ;


%%% Update script's persistent and user variables %%%

persist( P )
storeUserVariables( v )


%%% CREATE TRIAL %%%

states = struct2cell( states ) ;
createTrial( 'Start' , states{ : } )

% Output to message log
EchoServer.Write( '\n%s Start trial %d\n%9sWait %dms = %d + %d\n' , ...
  datestr( now , 'HH:MM:SS' ) , TrialData.currentTrial , '' , ...
    ceil( WaitMs ) , ceil( BaselineMs ) , ceil( v.WaitMs ) )


%%% Complete previous trial's inter-trial-interval %%%

sleep( ItiMinMs  -  1e3 * toc( P.ITIstart.value ) )


%%% --- SCRIPT FUNCTIONS --- %%%

% Maintain local persistent data
function  pout = persist( pin )
  
  persistent  p
  
  if  nargin  ,  p = pin ; end
  if  nargout , pout = p ; end
  
end % persist

