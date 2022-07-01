
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
  
    % Task-specific validity tests on block definition table
    P.tab = tabvalchk( P.tab ) ;
  
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
  
  % Get screen parameters
  P.framerate = double( round( StimServer.GetFrameRate ) ) ;
  P.screensize = double( StimServer.GetScreenSize ) ;
  
  % Calculate pixels per degree of visual field. cm/deg * pix/cm = pix/deg.
  P.pixperdeg = ( cfg.DistanceToScreen * tand( 1 ) )  *  ...
    ( sqrt( sum( P.screensize .^ 2 ) ) / cfg.MonitorDiagonalSize ) ;
  
  % Previous trial eye track window parameters
  P.EyeTrack = struct( 'RfXDeg' , NaN , 'RfYDeg' , NaN , ...
    'RfRadDeg' , NaN , 'RfWinFactor' , NaN , 'FixTolDeg' , NaN ) ;
  
  % Create flicker objects
  P.Flicker.stim = Rectangle ;
  P.Flicker.anim =   Flicker ;
  
    % Certain properties are fixed
    P.Flicker.stim.faceColor( : ) = intmax( 'uint8' ) ;
    P.Flicker.stim.width  = P.screensize( 1 ) ;
    P.Flicker.stim.height = P.screensize( 2 ) ;
  
  % Create target stimulus objects, a bit of trickery required to create an
  % empty Stimulus object for 'none'.
  P.Target.gaussian = Gaussian ;
  P.Target.none     = P.Target.gaussian( [ ] ) ;
    
  % Create gaze fixation stimulus
  P.Fix = Rectangle ;
  
    % Parameters are fixed
    P.Fix.position = [ 0 , 0 ] ;
    P.Fix.faceColor( : ) = 255 ;
    P.Fix.lineColor( : ) = 0 ;
    P.Fix.lineWidth = 1 ;
    P.Fix.drawMode = 3 ;
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

% Get properties of current trial condition
c = table2struct(  ...
      P.tab( TrialData.currentCondition == P.tab.Condition , : )  ) ;

% Determine screen background colour during Wait state
switch  c.WaitBackground
  case  'default' , WaitBak = { 'Background' ,   cfg.BackgroundRGB } ;
  case    'black' , WaitBak = { 'Background' , [ 000 , 000 , 000 ] } ;
  case      'red' , WaitBak = { 'Background' , [ 255 , 000 , 000 ] } ;
  otherwise
end

% Background flicker
if  c.BackgroundFlickerHz
  
  % Determine number of frames per cycle. Divided by 2. One half of frames
  % ON, the other half, OFF.
  n = P.framerate  /  c.BackgroundFlickerHz  /  2 ;
  
  % There is a fractional component, so round up to next whole frame
  if  mod( n , 1 ) , n = ceil( n ) ; end
  
  % Set flicker animation object parameters
  P.Flicker.anim.SetFrames( n , n ) ;
  
  % Bind animation to background rectangle
  P.Flicker.stim.play_animation( P.Flicker.anim ) ;
  
  % Point to background rectangle
  BackFlic = P.Flicker.stim ;
  
% No background flicker , point to empty stimulus
else , BackFlic = P.Target.none ;
end

% Point to specified target
Target = P.Target.( c.Target ) ;

  % Configure target stimulus for upcoming trial, according to type
  switch  c.Target
    
    case  'gaussian'
      
      Target.position = [ vpix.RfXDeg , vpix.RfYDeg ] ;
      Target.sdx = vpix.RfRadDeg / 3 ;
      Target.sdy = Target.sdx ;
      Target.color( : ) = Weber( c.Contrast , WaitBak{ 2 } ) ;
      
  end % config targ stim


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
             'Wait' ,WaitMs, 'TargetOn'       ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , [ { 'Reset' , [ P.StartSacc , P.EndSacc , P.BlinkStart , P.BlinkEnd , P.FalseAlarmFlag ] , 'Trigger' , P.Waiting , 'Photodiode' , 'on' , 'Stim' , { BackFlic } } , WaitBak ] ;
         'TargetOn' ,  100 , 'ResponseWindow' ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Stim' , { Target } , 'Photodiode' , 'off' , 'RunTimeVal' , P.RTstart } ;
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
          'cleanUp' ,    0 , 'final'          , {} , {} , { 'Photodiode' , 'off' , 'Background' , cfg.BackgroundRGB , 'StimProp' , { P.Fix , 'visible' , false , Target , 'visible' , false , BackFlic , 'visible' , false } } ;
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
EchoServer.Write( [ '\n%s Start trial %d, cond %d, block %d(%d)\n' , ...
  '%9sWait %dms = %d + %d\n' ] , datestr( now , 'HH:MM:SS' ) , ...
    TrialData.currentTrial , TrialData.currentCondition , ...
      TrialData.currentBlock , v.BlockType , '' , ceil( WaitMs ) , ...
        ceil( BaselineMs ) , ceil( v.WaitMs ) )


%%% Complete previous trial's inter-trial-interval %%%

sleep( ItiMinMs  -  1e3 * toc( P.ITIstart.value ) )


%%% --- SCRIPT FUNCTIONS --- %%%

% Maintain local persistent data
function  pout = persist( pin )
  
  persistent  p
  
  if  nargin  ,  p = pin ; end
  if  nargout , pout = p ; end
  
end % persist


% Task-specific checks on the validity of 
function  tab = tabvalchk( tab )
  
  % Required columns, the set of column headers
  colnam = { 'ItiStimulus' , 'WaitBackground' , 'BackgroundFlickerHz' , ...
    'Target' , 'Contrast' } ;
  
  % Numerical type check
  fnumchk = @( c ) isnumeric( c ) && isreal( c ) && all( isfinite( c ) ) ;
  
  % Error checking for each column. Return true if column's type is valid.
  valid.ItiStimulus = @iscellstr ;
  valid.WaitBackground = @iscellstr ;
  valid.BackgroundFlickerHz = fnumchk ;
  valid.Target = @iscellstr ;
  valid.Contrast = fnumchk ;
  
  % Support, what values are valid for each column?
  sup.ItiStimulus = { 'none' } ;
  sup.WaitBackground = { 'default' , 'red' , 'black' } ;
  sup.BackgroundFlickerHz = [ 0 , round( StimServer.GetFrameRate ) / 2 ] ;
  sup.Target = { 'none' , 'gaussian' } ;
  sup.Contrast = [ -1 , +1 ] ;
  
  % Retrieve table's name
  tabnam = tab.Properties.UserData ;
  
  % Check that all required columns are present
  if  ~ all( ismember( colnam , tab.Properties.VariableNames ) )
    
    error( '%s must contain columns: %s' , ...
      tabnam , strjoin( colnam , ' , ' ) )
    
  end % all columns found
  
  % Column names, point to values
  for  C = colnam , c = C{ 1 } ; v = tab.( c ) ;
    
    % Format error string header
    errstr = sprintf( 'Column %s of %s' , c , tabnam ) ;
    
    % Check if column has correct type
    if  ~ valid.( c )( v )
      
      error( '%s has invalid type, violating %s' , ...
        errstr , func2str( valid.( c ) ) )
      
    % Support is numeric
    elseif  isnumeric( sup.( c ) )
      
      % Values are out of range
      if  any( v < sup.( c )( 1 ) | v > sup.( c )( 2 ) )
      
        error( '%s outside range [%.1f,%.1f]' , errstr , sup.( c ) )
        
      end
      
    % Support is cell array of string
    else
      
      % Get lower-case version of column's strings
      str = lower( v ) ;
      
      % Assign these back into the table, returned in output argument
      tab.( c ) = str ;
      
      % Are all of them in the support set?
      if  ~ all( ismember( str , sup.( c ) ) )
        
        error( '%s outside set: %s', errstr, strjoin( sup.( c ) , ' , ' ) )
        
      end % all strings from support set
    end % error check
  end % cols
end % tabvalchk


% Convert Weber contrast value c to RGB I relative to background RGB Ib.
% Reminder, Weber contrast = ( I - Ib ) / Ib where I is target luminance
% and Ib is background luminance.
function  I = Weber( c , Ib )

  % Compute 'luminance', assuming greyscale background and target
  I = Ib .* ( c + 1 ) ;
  
  % 'Hack' solution for training on black or red backgrounds. Scale zero-
  % valued RGB components from 0 to 255 by c.
  I( Ib == 0 ) = c * double( intmax( 'uint8' ) ) ;
  
  % Guarantee that we don't exceed numeric range
  I = max( I , 0 ) ;
  I = min( I , double( intmax( 'uint8' ) ) ) ;
  
end % Weber



